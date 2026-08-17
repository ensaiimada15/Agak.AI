// Whole-answer TTS playback.
// Deps: just_audio, path_provider.
//
// The client intentionally does NOT stream audio playback anymore: it
// accumulates every mp3 chunk the backend sends (over SSE) and, when the
// full answer arrives (`done`), plays the complete mp3 from a temp file.
// A real file read is the most reliable playback path on Android — no
// local HTTP proxy, no "live, unknown length" sources, no timeouts, and
// nothing to skip. The audio arrives over the network fast enough that
// the whole-answer wait stays small.

import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class LiveTtsPlayer {
  final AudioPlayer _player = AudioPlayer();

  /// Plays a complete mp3 (the accumulated answer).
  Future<void> play(Uint8List mp3) async {
    if (mp3.isEmpty) return;
    try {
      // 1) Write the complete audio to a temp file.
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/agakai_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await file.writeAsBytes(mp3, flush: true);

      // 2) Play it from disk — a plain file data source, no streaming.
      await _player.stop();
      await _player.setAudioSource(AudioSource.file(file.path));
      await _player.play();
    } catch (e) {
      // Never let broken audio take down the answer that's already on
      // screen; the text + markdown remain usable.
      debugPrint('LiveTtsPlayer: playback unavailable: $e');
    }
  }

  /// Abort playback (barge-in / error / new question). Safe to call
  /// repeatedly and on a fresh player. Also RELEASES the Android audio
  /// session so the speech recognizer can grab the mic afterwards —
  /// otherwise a played answer can wedge the audio path (the recognizer
  /// runs but hears nothing).
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {
      // already stopped
    }
    try {
      // Deactivate our audio session entirely: next STT starts clean.
      // (setActive(false) is a no-op when already inactive.)
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {
      // audio session may not be configured yet — harmless
    }
  }

  Future<void> dispose() => _player.dispose();
}
