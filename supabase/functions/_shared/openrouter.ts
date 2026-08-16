// Shared helpers for the OpenRouter API (LLM only).
// OpenRouter is OpenAI-compatible.
// Env vars:
//   OPENROUTER_API_KEY    required
//   OPENROUTER_LLM_MODEL  optional, defaults to openai/gpt-4o-mini

const BASE = "https://openrouter.ai/api/v1"

function apiKey(): string {
  const key = Deno.env.get("OPENROUTER_API_KEY")
  if (!key) throw new Error("OPENROUTER_API_KEY not set")
  return key
}

const headers = () => ({
  "Authorization": `Bearer ${apiKey()}`,
  "Content-Type": "application/json",
  // Optional attribution headers recommended by OpenRouter
  "HTTP-Referer": Deno.env.get("OPENROUTER_APP_URL") ?? "https://agakai.app",
  "X-Title": Deno.env.get("OPENROUTER_APP_NAME") ?? "AgakAI",
})

function model(): string {
  return Deno.env.get("OPENROUTER_LLM_MODEL") || "openai/gpt-4o-mini"
}

export interface LlmMessage {
  role: "system" | "user" | "assistant"
  content: string
}

// ---- LLM (non-streaming) ----
export async function llm(messages: LlmMessage[], opts: { temperature?: number } = {}) {
  const res = await fetch(`${BASE}/chat/completions`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      model: model(),
      messages,
      temperature: opts.temperature ?? 0.7,
    }),
  })
  const json = await res.json()
  if (!res.ok) {
    throw new Error(`OpenRouter error ${res.status}: ${json.error?.message ?? JSON.stringify(json)}`)
  }
  return json.choices[0].message.content as string
}

// ---- LLM (streaming) ----
// Yields incremental text deltas as the model generates them (OpenAI SSE format).
export async function* llmStream(
  messages: LlmMessage[],
  opts: { temperature?: number } = {},
): AsyncGenerator<string> {
  const res = await fetch(`${BASE}/chat/completions`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      model: model(),
      messages,
      temperature: opts.temperature ?? 0.7,
      stream: true,
    }),
  })
  if (!res.ok || !res.body) {
    const text = await res.text().catch(() => "")
    throw new Error(`OpenRouter stream error ${res.status}: ${text}`)
  }

  const reader = res.body.getReader()
  const decoder = new TextDecoder()
  let buf = ""
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    buf += decoder.decode(value, { stream: true })

    let nl: number
    while ((nl = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, nl).trim()
      buf = buf.slice(nl + 1)
      if (!line.startsWith("data:")) continue
      const payload = line.slice(5).trim()
      if (!payload || payload === "[DONE]") continue
      try {
        const json = JSON.parse(payload)
        const delta: string = json.choices?.[0]?.delta?.content ?? ""
        if (delta) yield delta
      } catch {
        // ignore keep-alive / partial lines
      }
    }
  }
}
