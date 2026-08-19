# AgakAI
Voice-first AI assistant that helps Filipino seniors find, understand, and claim government benefits.
Speaks Bisaya, Tagalog, or English.

**Best Use of AI Award** — Can You HackIT 2026, Cebu Institute of Technology – University.
Team representing **Silliman University**.

> 🎬 **Watch the demo** — full screen-recording of the app showing the STT → LLM → TTS voice flow: a senior speaking, the live transcript appearing, and the assistant replying aloud in the same language (Bisaya/Tagalog/English) — no menus, answers play as they're generated.
>
> [▶️ Watch the demo video](docs/demo.mp4)

---

## Problem

Filipino seniors qualify for government benefits — pensions, free check-ups, food subsidies, transport passes — but most never claim them. Three barriers, all in the interface:

- Official info is dense and rarely in their language (Bisaya / Tagalog / English).
- Interfaces assume digital fluency: tiny text, complex forms, English-only.
- Existing voice assistants give generic answers and know nothing about the user.

## Solution

A conversational voice assistant. Seniors talk to it, it talks back, no menus or forms.

- **Streaming voice.** Speech in (STT) → reasoning (LLM) → speech out (TTS). Streamed live so the answer plays as it's generated.
- **Matches your language.** Ask in Bisaya, get Bisaya. Same for Tagalog and English.
- **Personalized.** Grounded in the senior's profile — name, age, city. Greets by name, tailors advice to their LGU, flags scams.

## What's unique: a psychological profile

Most assistants answer what you ask. AgakAI models **who is asking**.

After every conversation the LLM writes a rolling psychological profile of the senior — mood, what confused them, what matters to them, what they've been told. Each reply is then read against that history.

Net effect: it remembers across sessions. It notices a topic upsets someone and treads carefully. It re-explains what they didn't grasp. It picks up threads it started last week. Builds a real picture of each person over time.

Why for seniors: they trust a companion who remembers them, not a one-shot Q&A bot.

## Built with

| What | Used for |
|---|---|
| LLM (OpenRouter) | reasoning, multilingual answers, personalization, rolling memory |
| ElevenLabs | streaming speech-to-text and text-to-speech |
| Flutter | cross-platform UI, senior-friendly (light theme, enlarged text, big targets) |
| Supabase | Postgres + Edge Functions hosting the AI pipeline and data |
