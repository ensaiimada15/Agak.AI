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

const FALLBACK_PERSONA = `You are AgakAI, a warm and patient voice assistant for senior citizens in Dumaguete City, Philippines.
You help them discover, understand, and claim their government benefits.
Speak simply and kindly, in short sentences. Use "Lola" or "Lolo" when addressing them.
If they ask in Cebuano/Bisaya, reply in Bisaya; if Tagalog, reply in Tagalog; if English, reply in English.
Politely warn them if anything sounds like it could be a scam.
Prefer the simplified description of a benefit when available, mention its category and eligibility.
Never invent benefits or requirements that are not listed below.

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
  const { data: benefits } = await supabase
    .from("benefit")
    .select(
      "title, description, simplified_description, iconkey, eligibility, date, lgu(name, level, location)",
    )
  return (benefits ?? [])
    .map((b: any) => {
      const desc = (b.simplified_description ?? "").trim() || b.description
      return `- ${b.title}: ${desc} (Eligibility: ${b.eligibility}) [${b.lgu?.name ?? "local LGU"}]`
    })
    .join("\n") || "No benefits yet."
}

interface HistoryMsg { role: "user" | "assistant"; content: string }

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
    const { audio_data, audio_format, text, history, stream } = await req.json()

    // ---------------- LEGACY (non-streaming) MODE ----------------
    // Default for backwards compatibility: one JSON blob, same shape as before.
    if (!stream) {
      const [persona, benefitsContext] = await Promise.all([loadPersona(), loadBenefitsContext()])

      let question = typeof text === "string" ? text : ""
      if (!question.trim() && audio_data) {
        question = await stt(audio_data, audio_format ?? "m4a")
      }
      if (!question.trim()) throw new Error("No speech detected")

      const messages = [
        { role: "system" as const, content: persona.replace("{{BENEFITS}}", benefitsContext) },
        ...((history ?? []) as HistoryMsg[]),
        { role: "user" as const, content: question },
      ]
      const answer = await llm(messages)
      const audio = await ttsFull(answer)

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

            const [persona, benefitsContext] = await Promise.all([personaPromise, benefitsPromise])
            const messages = [
              { role: "system" as const, content: persona.replace("{{BENEFITS}}", benefitsContext) },
              ...((history ?? []) as HistoryMsg[]),
              { role: "user" as const, content: question },
            ]

            // TTS runs concurrently with LLM generation: each completed
            // sentence is synthesized and streamed to the client right away.
            const queue = makeQueue<string>()
            const ttsDone = (async () => {
              const CHUNK_BYTES = 16 * 1024
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
                  send("audio", { chunk_base64: bytesToBase64(merged), mime: "audio/mpeg" })
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
