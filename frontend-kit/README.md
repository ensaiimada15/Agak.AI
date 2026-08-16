# Frontend Kit — copy this into the frontend repo

Drop-in client for the AgakAI backend (Supabase Edge Functions).
Full backend spec lives in `../BACKEND_API.md` in the backend repo.

## Copy these files

| File | Put it in | What it is |
|---|---|---|
| `agakai_api.dart` | `lib/services/` | Streaming chat client (SSE), TTS, event types |
| `live_audio_player.dart` | `lib/services/` | Gapless player that starts speaking on the first audio chunk |
| `example_usage.dart` | reference only | How to wire events → UI states |

## Dependencies (pubspec.yaml)

```yaml
dependencies:
  http: ^1.2.2              # SSE streaming client
  just_audio: ^0.9.40       # gapless chunk playback
  supabase_flutter: ^2.8.0    # auth (senior login)
  flutter_dotenv: ^6.0.1    # env config
  record: ^7.1.1            # mic recording (you already have this)
```

## Config (.env)

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

```dart
final api = AgakApi(
  supabaseUrl: dotenv.env['SUPABASE_URL']!,
  anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
);
```

## The one rule

Call `POST /functions/v1/chat` with `"stream": true` and consume events in
order: `transcript` → `delta`(s) → `audio`(s) → `done`. Feed `audio` chunks to
`LiveTtsPlayer.addChunk()` **as they arrive** — the voice starts speaking
while the model is still generating. See `example_usage.dart`.

## Senior login (Supabase Auth)

Synthetic email pattern — senior ID + password:

```dart
final email = '${seniorId.trim().toUpperCase()}@seniors.agakai.app';

// sign up (once)
await supabase.auth.signUp(
  email: email,
  password: password,
  data: {'full_name': fullName, 'senior_id': seniorId.trim().toUpperCase()},
);

// sign in (every session)
await supabase.auth.signInWithPassword(email: email, password: password);
```

`chat`/`tts` work with or without login (anon key is enough).

## Welcome greeting

```dart
final bytes = await api.tts('Hello! I am AgakAI...');  // returns mp3 bytes
await AudioPlayer().play(BytesSource(bytes));          // audioplayers, one-shot
```

## UI state machine (recommended)

```
idle → recording (show mic level) → transcribing… (on upload done)
     → thinking… (on `transcript`) → speaking (first `audio` chunk;
       answer text keeps growing via `delta`) → idle (on `done`)
```
