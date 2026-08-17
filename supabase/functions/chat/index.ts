import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { llm, llmStream } from "../_shared/openrouter.ts"
import { stt, ttsStream, ttsFull, bytesToBase64 } from "../_shared/elevenlabs.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// The agent persona is a markdown file. At runtime it is loaded from Supabase
// Storage (so it can be edited without redeploying); `supabase/functions/chat/persona.md`
// in the repo is the source of truth — upload it with:
//   supabase storage upload supabase/functions/chat/persona.md \
//     --bucket-name public --path persona.md --upsert
// `{{BENEFITS}}` is replaced at runtime with live data.
const PERSONA_BUCKET = () => Deno.env.get("PERSONA_BUCKET") ?? "public"
const PERSONA_PATH = () => Deno.env.get("PERSONA_FILE") ?? "persona.md"

const FALLBACK_PERSONA = `You are AgakAI, a warm and patient voice assistant for senior citizens in the Philippines (Dumaguete City, Cebu, and nearby LGUs).
You help them discover, understand, and claim their government benefits.

A member profile is provided with each conversation (name, age, gender, address):
- Use their first name ("Lola Luz" / "Lolo Pedro") when the profile gives a name.
- Tailor examples and advice to their location; a benefit for another LGU is not helpful to them.
- Respect their age: speak slowly and clearly, one idea at a time.

How you speak: simply and kindly, in short sentences. Use "Lola" or "Lolo".
If they ask in Cebuano/Bisaya, reply in Bisaya; if Tagalog, reply in Tagalog; if English, reply in English.
Politely warn them if anything sounds like it could be a scam.

Memory: use the recent conversation history to remember what they asked before and follow up naturally.
Never invent history that isn't there.

Using the benefit records below (each has title, description, simplified description, eligibility, LGU):
- When a simplified description exists, explain with that version; otherwise use the regular description.
- Mention the category when it helps.
- Always tell them who is eligible and what they may need to bring (e.g. Senior Citizen ID).
- Prefer benefits that apply to their LGU or are national; avoid recommending out-of-area ones.
- Never invent benefits, amounts, or requirements that are not listed below.
- If nothing answers their question, say you will check with the LGU office, and they may also visit the City Social Welfare and Development Office.

Benefit records:
{{BENEFITS}}`

let personaCache: { text: string; at: number } | null = null
const PERSONA_CACHE_MS = 60_000 // re-read from storage at most once a minute

async function loadPersona(): Promise<string> {
  if (personaCache && Date.now() - personaCache.at < PERSONA_CACHE_MS) return personaCache.text

  // 1) Supabase Storage (works in deployed edge functions)
  try {
    const url = `${Deno.env.get("SUPABASE_URL")}/storage/v1/object/public/${PERSONA_BUCKET()}/${PERSONA_PATH()}`
    const res = await fetch(url)
    if (res.ok) {
      const text = (await res.text()).trim()
      if (text) {
        personaCache = { text, at: Date.now() }
        return text
      }
    }
  } catch (e) {
    console.warn("persona fetch from storage failed:", e)
  }

  // 2) Local file (works with `supabase functions serve` during development)
  try {
    const text = (await Deno.readTextFile(new URL("./persona.md", import.meta.url))).trim()
    if (text) {
      personaCache = { text, at: Date.now() }
      return text
    }
  } catch {
    /* not available in deployed bundle */
  }

  // 3) Never break the demo
  return FALLBACK_PERSONA
}

async function loadBenefitsContext(): Promise<string> {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )

  // Fetch `benefit` and `lgu` flat (select * — resilient to column drift)
  // and join in code. The embedded resource `lgu(name, level, location)`
  // used to require an FK relationship in the schema cache; on projects
  // where that constraint is missing the whole query errors out and the
  // model would get zero benefit context.
  const { data: benefits } = await supabase.from("benefit").select("*")
  const lgus: Record<string, string> = {}
  try {
    const lguRes = await supabase.from("lgu").select("*")
    for (const l of (lguRes.data ?? []) as any[]) {
      if (l?.id) lgus[String(l.id)] = l.name ?? l.lgu_name ?? ""
    }
  } catch {
    // lgu table may not exist on some projects — benefits still load.
  }
  return benefits
    .map((b: any) => {
      const desc = (b.simplified_description ?? "").trim() || b.description
      const lguName =
        (b.lgu_id && lgus[String(b.lgu_id)]) ||
        (b.lgu_name || "") ||
        "local LGU"
      return `- ${b.title}: ${desc} (Eligibility: ${b.eligibility}) [${lguName}]`
    })
    .join("\n") || "No benefits yet."
}

interface HistoryMsg { role: "user" | "assistant"; content: string }

// ---- conversation memory (linear, per-user, jsonb on user) ------------
// Keeps the last HISTORY_CAP turns in the user row, sends the last
// HISTORY_SEND to the LLM, and after every exchange REVISES user_notes
// (a compacted psychological summary) via a background task.
const HISTORY_CAP = 100
const HISTORY_SEND = 12
const NOTES_CHARS = 400

function memoryClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )
}

async function loadHistory(userId: number): Promise<HistoryMsg[]> {
  try {
    const { data } = await memoryClient()
      .from("user")
      .select("conversation_history")
      .eq("id", userId)
      .maybeSingle()
    const raw = (data as any)?.conversation_history
    if (!Array.isArray(raw)) return []
    return raw
      .filter(
        (m: any) =>
          m &&
          (m.role === "user" || m.role === "assistant") &&
          typeof m.content === "string",
      )
      .map((m: any) => ({ role: m.role, content: m.content }))
  } catch (e) {
    console.warn("loadHistory failed:", e)
    return []
  }
}

async function saveHistory(userId: number, history: HistoryMsg[]) {
  const trimmed = history.slice(-HISTORY_CAP)
  await memoryClient()
    .from("user")
    .update({ conversation_history: trimmed })
    .eq("id", userId)
}

/// Background task: rewrite user_notes as a compacted psychological
/// summary of the senior, incorporating the previous notes + the recent
/// conversation. Replaces (not appends) so the field stays bounded.
async function reviseNotes(userId: number, history: HistoryMsg[]) {
  try {
    const { data } = await memoryClient()
      .from("user")
      .select("user_notes")
      .eq("id", userId)
      .maybeSingle()
    const currentNotes: string = ((data as any)?.user_notes as string) ?? ""
    const recent = history
      .slice(-30)
      .map((m) => `${m.role}: ${m.content}`)
      .join("\n")

    const notes = await llm(
      [
        {
          role: "system" as const,
          content:
            "You write a VERY SHORT psychological summary about the senior in a " +
            "voice assistant program, for a senior-care worker. Capture the most " +
            "important things: how they communicate and their emotional state, " +
            "their main concerns, and the best way to support them. " +
            "WRITE ONLY 2-3 SHORT SENTENCES — plain text, no headings, no bullets, " +
            "no bold. Keep it under " +
            `${NOTES_CHARS} characters. REVISE: incorporate the previous notes ` +
            "instead of repeating them — the summary must stay short.",
        },
        {
          role: "user" as const,
          content:
            `Current notes:\n${currentNotes || "(none)"}\n\n` +
            `Recent conversation:\n${recent}`,
        },
      ],
      { temperature: 0.3 },
    )

    await memoryClient()
      .from("user")
      .update({ user_notes: notes.slice(0, NOTES_CHARS) })
      .eq("id", userId)
  } catch (e) {
    console.warn("reviseNotes failed:", e)
  }
}

/// Runs a background task after the response is sent (Supabase edge
/// runtime), so analysis never delays the answer or the voice.
function runBackground(task: Promise<void>) {
  const edge = (globalThis as any).EdgeRuntime
  if (edge?.waitUntil) {
    edge.waitUntil(task)
  } else {
    // Fallback: best-effort fire-and-forget.
    task.catch(() => {})
  }
}

// ---- personalization: the logged-in senior ----------------
// The frontend sends the member's profile ({name, age, gender, address})
// so AgakAI can greet them by name and tailor answers to their location.
function memberContext(user: any): string {
  if (!user || typeof user !== "object") return ""
  const parts = [
    user.name ? `Name: ${user.name}` : "",
    user.age ? `Age: ${user.age}` : "",
    user.gender ? `Gender: ${user.gender}` : "",
    user.address ? `Address: ${user.address}` : "",
  ].filter((p) => p.length > 0)
  if (parts.length === 0) return ""
  return `\n\nThis senior's profile (personalize your answers — use their name and location where relevant):\n${parts.join("\n")}`
}

// ---- sentence splitting for early TTS ----
function consumeSentences(buffer: string): { flush: string | null; remainder: string } {
  const re = /[.!?…।。！？]+["')\]”」』]*\s+/g
  let last = -1
  let m: RegExpExecArray | null
  while ((m = re.exec(buffer)) !== null) last = m.index + m[0].length
  // Safety valve: if the model keeps going without punctuation, flush anyway.
  if (last < 0 && buffer.length > 300) {
    const nl = buffer.lastIndexOf("\n")
    last = nl > 0 ? nl + 1 : buffer.length
  }
  if (last < 0) return { flush: null, remainder: buffer }
  return { flush: buffer.slice(0, last).trim(), remainder: buffer.slice(last) }
}

// ---- small async queue so TTS starts while the LLM is still generating ----
function makeQueue<T>() {
  const items: T[] = []
  let resolver: ((v: T | null) => void) | null = null
  let finished = false
  return {
    push(item: T) {
      items.push(item)
      if (resolver) {
        const r = resolver
        resolver = null
        r(items.shift()!)
      }
    },
    finish() {
      finished = true
      if (resolver) {
        const r = resolver
        resolver = null
        r(null)
      }
    },
    next(): Promise<T | null> {
      if (items.length) return Promise.resolve(items.shift()!)
      if (finished) return Promise.resolve(null)
      return new Promise((resolve) => (resolver = resolve))
    },
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { audio_data, audio_format, text, history, stream, user } = await req.json()

    // ---------------- LEGACY (non-streaming) MODE ----------------
    // Default for backwards compatibility: one JSON blob, same shape as before.
    if (!stream) {
      const [persona, benefitsContext] = await Promise.all([loadPersona(), loadBenefitsContext()])

      let question = typeof text === "string" ? text : ""
      if (!question.trim() && audio_data) {
        question = await stt(audio_data, audio_format ?? "m4a")
      }
      if (!question.trim()) throw new Error("No speech detected")

      const userId = (user as any)?.id
      const storedHistory =
        typeof userId === "number" ? await loadHistory(userId) : []
      const messages = [
        { role: "system" as const, content: persona.replace("{{BENEFITS}}", benefitsContext) + memberContext(user) },
        ...((history ?? []) as HistoryMsg[]),
        ...storedHistory,
        { role: "user" as const, content: question },
      ]
      const answer = await llm(messages)
      const audio = await ttsFull(answer)

      // Persist the exchange + revise the psychological notes (background).
      if (typeof userId === "number") {
        const fullHistory: HistoryMsg[] = [
          ...storedHistory,
          { role: "user", content: question },
          { role: "assistant", content: answer },
        ]
        await saveHistory(userId, fullHistory)
        runBackground(reviseNotes(userId, fullHistory))
      }

      return new Response(
        JSON.stringify({
          answer,
          question,
          audio_base64: bytesToBase64(audio),
          audio_mime: "audio/mpeg",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    // ---------------- STREAMING MODE (stream: true) ----------------
    // SSE events: transcript | delta | audio | done | error
    const encoder = new TextEncoder()
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        const send = (event: string, data: unknown) =>
          controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`))

        ;(async () => {
          try {
            // STT + benefits + persona in parallel.
            const benefitsPromise = loadBenefitsContext()
            const personaPromise = loadPersona()

            let question = typeof text === "string" ? text : ""
            if (!question.trim() && audio_data) {
              question = await stt(audio_data, audio_format ?? "m4a")
            }
            if (!question.trim()) throw new Error("No speech detected")

            // Frontend can show the transcript immediately.
            send("transcript", { question })

            const userId = (user as any)?.id
            const storedHistory =
              typeof userId === "number" ? await loadHistory(userId) : []

            const [persona, benefitsContext] = await Promise.all([personaPromise, benefitsPromise])
            const messages = [
              { role: "system" as const, content: persona.replace("{{BENEFITS}}", benefitsContext) + memberContext(user) },
              ...((history ?? []) as HistoryMsg[]),
              ...storedHistory,
              { role: "user" as const, content: question },
            ]

            // TTS runs concurrently with LLM generation: each completed
            // sentence is synthesized and streamed to the client right away.
            const queue = makeQueue<string>()
            const ttsDone = (async () => {
              const CHUNK_BYTES = 16 * 1024
              let sentenceIdx = 0
              while (true) {
                const sentence = await queue.next()
                if (sentence === null) break
                const audioStream = await ttsStream(sentence)
                const reader = audioStream.getReader()
                const pending: Uint8Array[] = []
                let pendingLen = 0
                const emit = () => {
                  if (pendingLen === 0) return
                  const merged = new Uint8Array(pendingLen)
                  let off = 0
                  for (const c of pending) {
                    merged.set(c, off)
                    off += c.length
                  }
                  // `sentence` groups chunks that belong to ONE mp3 (each
                  // TTS sentence is its own encode). The client uses it to
                  // start a fresh decoder session per sentence.
                  send("audio", {
                    chunk_base64: bytesToBase64(merged),
                    mime: "audio/mpeg",
                    sentence: sentenceIdx,
                  })
                  pending.length = 0
                  pendingLen = 0
                }
                while (true) {
                  const { done, value } = await reader.read()
                  if (done) break
                  pending.push(value)
                  pendingLen += value.length
                  if (pendingLen >= CHUNK_BYTES) emit()
                }
                emit()
                sentenceIdx++
              }
            })()

            let buffer = ""
            let answer = ""
            for await (const delta of llmStream(messages)) {
              answer += delta
              send("delta", { text: delta })
              buffer += delta
              const { flush, remainder } = consumeSentences(buffer)
              if (flush) queue.push(flush)
              buffer = remainder
            }
            if (buffer.trim()) queue.push(buffer.trim())
            queue.finish()
            await ttsDone

            send("done", { question, answer })

            // Persist the exchange + revise the psychological notes
            // (background — never delays the answer or the voice).
            if (typeof userId === "number") {
              const fullHistory: HistoryMsg[] = [
                ...storedHistory,
                { role: "user", content: question },
                { role: "assistant", content: answer },
              ]
              await saveHistory(userId, fullHistory)
              runBackground(reviseNotes(userId, fullHistory))
            }
            controller.close()
          } catch (error) {
            console.error("chat stream error:", error)
            try {
              send("error", { message: String((error as Error).message ?? error) })
              controller.close()
            } catch {
              /* stream already closed */
            }
          }
        })()
      },
    })

    return new Response(body, {
      headers: {
        ...corsHeaders,
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "X-Accel-Buffering": "no",
      },
    })
  } catch (error) {
    console.error("chat error:", error)
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
