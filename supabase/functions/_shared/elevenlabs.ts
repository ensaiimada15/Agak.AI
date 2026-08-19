// Shared helpers for the ElevenLabs API (STT + TTS).

const BASE = "https://api.elevenlabs.io"

function apiKey(): string {
  const key = Deno.env.get("ELEVENLABS_API_KEY")
  if (!key) throw new Error("ELEVENLABS_API_KEY not set")
  return key
}

function voiceId(): string {
  const id = Deno.env.get("ELEVENLABS_VOICE_ID")
  if (!id) throw new Error("ELEVENLABS_VOICE_ID not set")
  return id
}

// ---- STT (scribe) ----

const MIME_BY_FORMAT: Record<string, string> = {
  wav: "audio/wav",
  m4a: "audio/mp4",
  aac: "audio/aac",
  mp3: "audio/mpeg",
  ogg: "audio/ogg",
  opus: "audio/ogg",
  flac: "audio/flac",
  amr: "audio/amr",
  webm: "audio/webm",
}

export function base64ToBytes(b64: string): Uint8Array {
  const raw = atob(b64)
  const bytes = new Uint8Array(raw.length)
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i)
  return bytes
}

export function bytesToBase64(bytes: Uint8Array): string {
  let bin = ""
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i])
  return btoa(bin)
}

/**
 * Transcribe audio. `data` is base64-encoded audio, `format` is the container
 * extension (m4a, wav, ogg, ...). Returns the transcript text.
 */
export async function stt(data: string, format: string = "m4a"): Promise<string> {
  const bytes = base64ToBytes(data)
  const mime = MIME_BY_FORMAT[format] ?? "audio/mp4"
  const form = new FormData()
  form.append("file", new Blob([bytes], { type: mime }), `audio.${format}`)
  form.append("model_id", Deno.env.get("ELEVENLABS_STT_MODEL") ?? "scribe_v1")

  const res = await fetch(`${BASE}/v1/speech-to-text`, {
    method: "POST",
    headers: { "xi-api-key": apiKey() },
    body: form,
  })
  if (!res.ok) {
    const text = await res.text()
    throw new Error(`ElevenLabs STT error ${res.status}: ${text}`)
  }
  const json = await res.json()
  return (json.text ?? "").trim()
}

// ---- TTS (streaming HTTP) ----

/**
 * Synthesize speech for `text` and return the audio body as a ReadableStream.
 * First bytes arrive in a few hundred ms — pipe this to the client as it streams.
 * Output format: mp3 44.1kHz 128kbps.
 */
export async function ttsStream(text: string): Promise<ReadableStream<Uint8Array>> {
  const url = `${BASE}/v1/text-to-speech/${voiceId()}/stream` +
    "?output_format=mp3_44100_128&optimize_streaming_latency=4"
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "xi-api-key": apiKey(),
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      text,
      model_id: Deno.env.get("ELEVENLABS_TTS_MODEL") ?? "eleven_flash_v2_5",
      voice_settings: { stability: 0.5, similarity_boost: 0.75 },
    }),
  })
  if (!res.ok || !res.body) {
    const body = await res.text().catch(() => "")
    throw new Error(`ElevenLabs TTS error ${res.status}: ${body}`)
  }
  return res.body
}

/** Synthesize speech and return all audio bytes (used by non-streaming callers). */
export async function ttsFull(text: string): Promise<Uint8Array> {
  const stream = await ttsStream(text)
  const reader = stream.getReader()
  const chunks: Uint8Array[] = []
  let total = 0
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    chunks.push(value)
    total += value.length
  }
  const out = new Uint8Array(total)
  let offset = 0
  for (const c of chunks) {
    out.set(c, offset)
    offset += c.length
  }
  return out
}
