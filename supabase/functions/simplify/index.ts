import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { llm } from "../_shared/openrouter.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const SIMPLIFY_PROMPT = `You are a document simplifier for senior citizens in the Philippines.
Rewrite the document below in simple, clear language that a 68-year-old can easily understand.
- Use short sentences
- Avoid legal or technical jargon
- Explain complex terms in everyday words
- Be warm and respectful (address elderly as "Lola"/"Lolo")
- If the original is in Cebuano/Bisaya, translate to Bisaya; Tagalog to Tagalog; English to English
- Do not invent information not present in the document`

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { document_text, benefit_id } = await req.json()
    if (!document_text?.trim()) throw new Error("document_text is required")

    const simplified = await llm([
      { role: "system", content: SIMPLIFY_PROMPT },
      { role: "user", content: document_text },
    ], { temperature: 0.3 })

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    const { data: doc, error } = await supabase
      .from("documents")
      .insert({ original_text: document_text, simplified_text: simplified, benefit_id: benefit_id || null })
      .select()
      .single()
    if (error) throw error

    return new Response(
      JSON.stringify({ document_id: doc.id, simplified_text: simplified }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (error) {
    console.error("simplify error:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})