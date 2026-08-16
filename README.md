# AgakAI Backend

Supabase Edge Functions backend for AgakAI (voice assistant for senior
citizens in Dumaguete City). Frontend lives in a separate repo — see
[frontend-kit/](frontend-kit/) for the copy-paste client the frontend repo
should use, and [BACKEND_API.md](BACKEND_API.md) for the full wire spec.

## Stack

- **Runtime**: Supabase Edge Functions (Deno)
- **STT**: ElevenLabs Scribe (`scribe_v1`)
- **TTS**: ElevenLabs streaming TTS (`eleven_flash_v2_5`, sentence-level)
- **LLM**: OpenRouter (OpenAI-compatible, streamed)
- **Persona**: editable markdown (`supabase/functions/chat/persona.md`) served
  from Supabase Storage — no redeploy to change it
- **DB**: Supabase Postgres (`benefits`, `documents`, `seniors` tables;
  migration in `supabase/migrations/`)

## Pipeline (POST /functions/v1/chat, `stream: true`)

```
audio upload → STT → `transcript` event
           → LLM tokens → `delta` events
           → per-sentence TTS → `audio` mp3 chunk events (interleaved)
           → `done`
```

## Deploy

```bash
supabase login
supabase link --project-ref <your-project-ref>

# secrets (required)
supabase secrets set \
  OPENROUTER_API_KEY=sk-or-v1-... \
  ELEVENLABS_API_KEY=sk_... \
  ELEVENLABS_VOICE_ID=...

# optional overrides
supabase secrets set \
  OPENROUTER_LLM_MODEL=openai/gpt-4o-mini \
  ELEVENLABS_STT_MODEL=scribe_v1 \
  ELEVENLABS_TTS_MODEL=eleven_flash_v2_5 \
  PERSONA_BUCKET=persona

# database (seniors table + trigger) — paste into Dashboard → SQL Editor, or:
supabase db push

# dashboard prerequisite: Auth → Providers → Email → turn OFF "Confirm email"

# functions
supabase functions deploy chat
supabase functions deploy tts
supabase functions deploy simplify

# persona into storage (bucket `persona`, public)
supabase storage cp supabase/functions/chat/persona.md storage://persona/persona.md
```

`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` are auto-injected into edge
functions — never set them as secrets.

## Layout

```
├── BACKEND_API.md                  # wire spec for frontend devs
├── frontend-kit/                   # copy-paste Dart client for the frontend repo
│   ├── README.md
│   ├── agakai_api.dart             # SSE client, typed events, tts(), seniorEmail()
│   ├── live_audio_player.dart      # gapless live mp3 chunk player
│   └── example_usage.dart          # events → UI states wiring
└── supabase/
    ├── config.toml
    ├── migrations/20260816000000_seniors.sql
    └── functions/
        ├── _shared/  openrouter.ts · elevenlabs.ts
        ├── chat/     index.ts · persona.md
        ├── tts/      index.ts
        └── simplify/ index.ts
```

## Editing the persona

Edit `supabase/functions/chat/persona.md`, then:

```bash
supabase storage cp supabase/functions/chat/persona.md storage://persona/persona.md
```

No redeploy needed (function re-reads it within 60s). `{{BENEFITS}}` is
replaced at runtime from the `benefits` table.
