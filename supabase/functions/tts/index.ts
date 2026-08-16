import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { ttsFull } from "../_shared/elevenlabs.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { text } = await req.json()
    if (!text?.trim()) throw new Error("text is required")

    // Returns mp3 audio bytes (ElevenLabs, 44.1kHz 128kbps).
    const audio = await ttsFull(text)
    return new Response(audio, {
      headers: { ...corsHeaders, "Content-Type": "audio/mpeg" },
    })
  } catch (error) {
    console.error("tts error:", error)
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
