// AgakAI backend client. Copy into the frontend repo (lib/services/).
// Deps: http. No other backend-specific dependencies.
//
// Backend: Supabase Edge Functions. Full spec: BACKEND_API.md (backend repo).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

// ---------------------------------------------------------------- events ----

sealed class AgakEvent {}

/// STT finished — the user's question as text. Show the user bubble now.
class AgakTranscript extends AgakEvent {
  AgakTranscript({required this.question});
  final String question;
}

/// One LLM text fragment. Append to the answer bubble.
class AgakDelta extends AgakEvent {
  AgakDelta({required this.text});
  final String text;
}

/// One mp3 chunk of the spoken answer (consecutive pieces of ONE mp3 stream).
/// Feed to the audio player in arrival order, immediately.
class AgakAudio extends AgakEvent {
  AgakAudio({required this.chunk});
  final Uint8List chunk;
}

/// Pipeline finished.
class AgakDone extends AgakEvent {
  AgakDone({required this.question, required this.answer});
  final String question;
  final String answer;
}

/// Something failed; the stream closes after this.
class AgakError extends AgakEvent {
  AgakError({required this.message});
  final String message;
}

// ---------------------------------------------------------------- client ----

class AgakApi {
  AgakApi({required this.supabaseUrl, required this.anonKey});

  final String supabaseUrl;
  final String anonKey;

  Map<String, String> get _headers => {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      };

  /// Streaming voice/text chat.
  ///
  /// Provide EITHER [text] (typed question) OR [audioBytes] (recording).
  /// [audioFormat] is the container: m4a (default), wav, ogg, mp3, webm...
  /// [history] = prior turns: [{'role':'user'|'assistant','content':'...'}].
  Stream<AgakEvent> chatStream({
    String? text,
    Uint8List? audioBytes,
    String audioFormat = 'm4a',
    List<Map<String, String>>? history,
  }) async* {
    final req = http.Request(
      'POST',
      Uri.parse('$supabaseUrl/functions/v1/chat'),
    );
    req.headers.addAll(_headers);
    req.body = jsonEncode({
      if (text != null) 'text': text,
      if (audioBytes != null) ...{
        'audio_data': base64Encode(audioBytes),
        'audio_format': audioFormat,
      },
      if (history != null && history.isNotEmpty) 'history': history,
      'stream': true,
    });

    final res = await req.send();
    if (res.statusCode != 200) {
      final body = await res.stream.bytesToString();
      yield AgakError(message: 'HTTP ${res.statusCode}: $body');
      return;
    }

    String? event;
    final lines = res.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.startsWith('event: ')) {
        event = line.substring(7).trim();
      } else if (line.startsWith('data: ') && event != null) {
        final dynamic raw = jsonDecode(line.substring(6));
        final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
        switch (event) {
          case 'transcript':
            yield AgakTranscript(question: (data['question'] ?? '') as String);
          case 'delta':
            yield AgakDelta(text: (data['text'] ?? '') as String);
          case 'audio':
            yield AgakAudio(
              chunk: base64Decode((data['chunk_base64'] ?? '') as String),
            );
          case 'done':
            yield AgakDone(
              question: (data['question'] ?? '') as String,
              answer: (data['answer'] ?? '') as String,
            );
          case 'error':
            yield AgakError(message: (data['message'] ?? 'unknown') as String);
        }
        event = null;
      }
    }
  }

  /// One-shot TTS for fixed phrases (e.g. the welcome greeting).
  /// Returns complete mp3 bytes.
  Future<Uint8List> tts(String text) async {
    final res = await http.post(
      Uri.parse('$supabaseUrl/functions/v1/tts'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
    if (res.statusCode != 200) {
      throw Exception('TTS failed: ${res.statusCode} ${res.body}');
    }
    return res.bodyBytes;
  }

  /// Synthetic email for the senior auth pattern (see README).
  static String seniorEmail(String seniorId) =>
      '${seniorId.trim().toUpperCase()}@seniors.agakai.app';
}
