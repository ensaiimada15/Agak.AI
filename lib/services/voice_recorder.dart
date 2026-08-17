// Plain mic recorder for server-side speech-to-text.
// Deps: record, path_provider.
//
// Unlike speech_to_text, this is ONLY audio capture — no on-device
// recognizer running, so nothing can "cut off on silence". The user taps,
// speaks as long as they like (pauses included), taps again, and the whole
// clip is sent to the chat edge function which transcribes it with
// ElevenLabs STT.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  String? _path;

  final StreamController<double> _amplitude =
      StreamController<double>.broadcast();

  /// Live mic level in dB (approx -60 quiet … -5 loud), for the pulse UI.
  Stream<double> get amplitude => _amplitude.stream;

  bool _recording = false;
  bool get isRecording => _recording;

  /// Starts recording to a temp m4a file. Returns false on failure.
  Future<bool> start() async {
    try {
      if (!await _recorder.hasPermission()) {
        debugPrint('VoiceRecorder: mic permission denied');
        return false;
      }
      final dir = await getTemporaryDirectory();
      _path =
          '${dir.path}/agakai_mic_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: _path!,
      );
      _recording = true;
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((amp) => _amplitude.add(amp.current));
      return true;
    } catch (e) {
      debugPrint('VoiceRecorder: start failed: $e');
      return false;
    }
  }

  /// Stops recording and returns the captured audio bytes (m4a), or null.
  Future<Uint8List?> stop() async {
    await _ampSub?.cancel();
    _ampSub = null;
    _recording = false;
    final path = _path;
    _path = null;
    if (path == null) return null;
    try {
      await _recorder.stop();
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      try {
        await file.delete();
      } catch (_) {}
      return bytes;
    } catch (e) {
      debugPrint('VoiceRecorder: stop failed: $e');
      return null;
    }
  }

  /// Discards the current recording without returning it.
  Future<void> cancel() async {
    await _ampSub?.cancel();
    _ampSub = null;
    _recording = false;
    final path = _path;
    _path = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
    await _amplitude.close();
  }
}
