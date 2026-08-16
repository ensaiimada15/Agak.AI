// Reference wiring for the frontend repo — shows how events map to UI states.
// Not a complete screen; lift the pattern into your own widgets.

import 'dart:typed_data';

import 'agakai_api.dart';
import 'live_audio_player.dart';

// final api = AgakApi(
//   supabaseUrl: dotenv.env['SUPABASE_URL']!,
//   anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
// );
// final player = LiveTtsPlayer();

Future<void> ask({
  required AgakApi api,
  required LiveTtsPlayer player,
  Uint8List? audioBytes,
  String? text,
  required void Function(String label) setStateLabel, // "transcribing", "thinking", "speaking", "idle"
  required void Function(String question) onUserMessage,
  required void Function(String fullAnswerSoFar) onAnswerGrow,
  required void Function(String message) onError,
}) async {
  setStateLabel('transcribing'); // audio uploaded, waiting for STT

  String answer = '';
  await for (final ev in api.chatStream(audioBytes: audioBytes, text: text)) {
    switch (ev) {
      case AgakTranscript(:final question):
        onUserMessage(question);   // render the user bubble
        setStateLabel('thinking'); // STT done, waiting for first LLM token

      case AgakDelta(:final text):
        answer += text;
        onAnswerGrow(answer);      // answer bubble types out live

      case AgakAudio(:final chunk):
        setStateLabel('speaking'); // voice starts on first chunk
        await player.addChunk(chunk);

      case AgakDone():
        await player.finish();     // let queued audio drain, then idle
        setStateLabel('idle');

      case AgakError(:final message):
        onError(message);
        setStateLabel('idle');
    }
  }
}

// Barge-in (optional, later): while label == 'speaking', watch the mic;
// on speech, call player.stop() and start a new recording.

// One-shot welcome greeting (no streaming needed):
//
//   final bytes = await api.tts('Hello! I am AgakAI...');
//   // play with audioplayers: AudioPlayer().play(BytesSource(bytes));

// Senior login (supabase_flutter client):
//
//   final email = AgakApi.seniorEmail(seniorId);
//   await supabase.auth.signInWithPassword(email: email, password: password);
//   // sign-up once with metadata:
//   await supabase.auth.signUp(
//     email: email,
//     password: password,
//     data: {'full_name': fullName, 'senior_id': seniorId.trim().toUpperCase()},
//   );
