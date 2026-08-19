# AgakAI

**AgakAI** is a senior-citizen assistance app for the Philippines. It helps *Lolas* and *Lolos* discover, understand, and claim their government benefits — through a simple, voice-first interface designed for aging users.

> "Ako ang imong OSCA assistant." — AgakAI is a warm, patient companion that speaks your language and keeps you company.

AgakAI was built as an entry for **Can You HackIT 2026**, held at **Cebu Institute of Technology – University (CIT-U)**, Cebu City.

---

## ✨ What it does

### 🏠 Home (Balay)
- Personalized greeting using the logged-in senior's first name.
- A quick view of the **available benefits** most relevant to their address.
- One-tap shortcuts to the **Voice Assistant** and **My Benefits**.
- Profile details (Senior ID, age, address, etc.) available from the menu.
- Language switcher built into the home menu.

### 🎙️ Voice Assistant (Tingog) — *the centerpiece*
- **Tap-to-talk voice chat**: no on-device speech recognizer, so nothing cuts you off on silence — speak as long as you like, tap the mic when done.
- **Server-side speech-to-text** (ElevenLabs), then a **streaming AI answer** (OpenRouter LLM) rendered live and read back aloud with **whole-answer text-to-speech** (no skipped or garbled audio).
- Replies in the same language you ask in — **Bisaya, Tagalog, or English**.
- **Personalized**: AgakAI greets each senior by name and tailors advice to their city/barangay using their profile.
- **Support notes**: a rolling, LLM-maintained summary of how AgakAI is getting to know each Lola/Lolo, updated after every conversation (viewable via the `?` button).
- Suggested questions for a quick start (Social Pension, free check-ups, Senior Discount), plus a **type-instead** field for seniors who prefer typing.

### 🪪 My Benefits
- A catalog of government benefits — pension payouts, free medical check-ups, food subsidies, transport pass renewals, and more.
- Each card shows category, date, location (LGU), and a plain-language description, with a "How To Claim" action.
- **Location-aware filtering**: national benefits always show; local ones only appear when they match the senior's city/barangay.
- **Realtime alerts**: when a new benefit is published, AgakAI pops a notification — *"We think you might like this!"* — computed from the senior's address.

### ♿ Built for seniors
- **Light-only theme** (dark mode intentionally dropped — calm and predictable for aging eyes).
- **Standard / Enlarged text** toggle (1.2×) applied app-wide.
- Large touch targets, high-contrast colors, and calm fades — never bouncy animations.
- Bilingual labels (English + Bisaya/Tagalog) throughout.
- A centered mobile-width frame on desktop browsers so the app never stretches awkwardly on a wide screen.

---

## 🧱 Tech stack

| Layer | Technology |
|---|---|
| Frontend | Flutter / Dart (Android, iOS, Web, macOS, Windows, Linux) |
| Backend | Supabase (Postgres, Auth, Realtime, Storage, Edge Functions) |
| AI | OpenRouter (LLM), ElevenLabs (streaming STT + TTS) |
| Key packages | `supabase_flutter`, `http`, `flutter_dotenv`, `flutter_markdown`, `just_audio`, `record`, `google_fonts`, `flutter_tts` |

### Architecture notes
- **Client** (`lib/`) — clean separation of screens, widgets, models, services, theme, and settings (i18n + text scale via an `InheritedWidget`-backed `ChangeNotifier`).
- **Edge functions** (`supabase/functions/`) —
  - `chat` — the full pipeline: STT → LLM → streaming SSE events (`transcript`, `delta`, `audio`, `done`, `error`) → TTS audio chunks.
  - `tts` — one-shot speech synthesis for fixed phrases.
  - `simplify` — benefit simplification.
- **Edge function persona** (`supabase/functions/chat/persona.md`) — the agent's instructions, loaded from Supabase Storage so it can be tuned without redeploying.
- **DB migrations** (`supabase/migrations/`) — seniors registry (auth trigger), `benefit` table, and per-user conversation memory (`conversation_history` jsonb + rolling `user_notes`).

---

## 🚀 Getting started

### Prerequisites
- Flutter SDK (≥3.3.0) and Dart
- A Supabase project with the migrations applied and edge functions deployed
- API keys for OpenRouter and ElevenLabs configured as edge-function secrets

### Setup
1. **Clone & install**
   ```bash
   flutter pub get
   ```

2. **Configure environment** — create a `.env` file at the project root (not committed; see `.gitignore`):
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_PUBLISHABLE_KEY=your_publishable_key
   ```

3. **Run**
   ```bash
   flutter run
   ```

### Tooling / extras
- Regenerate the app launcher icon:
  ```bash
  dart run flutter_launcher_icons
  ```
- Regenerate the native splash screen:
  ```bash
  dart run flutter_native_splash:create
  ```

---

## 📂 Project structure

```
lib/
├── main.dart                 # App entry: dotenv, Supabase init, i18n scope, theming
├── screens/                  # login, home, voice assistant, benefits, app shell
├── widgets/                  # bottom nav, responsive frame, screen header
├── models/                   # benefit, profile, benefit service, profile service
├── services/                 # AgakAI API client (SSE chat), TTS player, recorder, notifier
├── settings/                 # app settings: language (Bisaya/Tagalog/English) + text scale
└── theme/                    # colors & theme

supabase/
├── functions/                # chat / tts / simplify edge functions (+ persona.md)
└── migrations/               # seniors, benefits, conversation memory, realtime

assets/
├── lang/                     # bis.json, tl.json, en.json translations
├── data/                     # sample benefits & profile JSON
└── images/                   # logo, avatar, splash, dashboard hero
```

---

## 🗺️ Roadmap ideas
- Persist language & text-size preferences (currently in-memory).
- Complete the "How To Claim" flow end-to-end.
- OS-level sign-up for seniors (the migrations already scaffold auth-user sync).
- Multi-LGU rollout as more `benefit` records are added.
