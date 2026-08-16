// Gapless live TTS playback. Copy into the frontend repo (lib/services/).
// Deps: just_audio.
//
// The backend sends consecutive pieces of ONE mp3 stream. This player starts
// speaking as soon as the first chunk arrives and keeps playing seamlessly
// while more chunks stream in (just_audio custom StreamAudioSource).

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

class LiveTtsPlayer {
  final AudioPlayer _player = AudioPlayer();
  final _LiveMp3Source _source = _LiveMp3Source();
  bool _started = false;

  /// Feed audio chunks in arrival order. Starts playback on first chunk.
  Future<void> addChunk(Uint8List bytes) async {
    _source.add(bytes);
    if (!_started) {
      _started = true;
      await _player.setAudioSource(_source);
      await _player.play();
    }
  }

  /// Call when the backend stream ends (`done` event).
  Future<void> finish() async => _source.close();

  /// Abort playback (barge-in / error / new question).
  Future<void> stop() async {
    _source.close();
    await _player.stop();
    _source.reset();
    _started = false;
  }

  Future<void> dispose() async => _player.dispose();
}

/// A StreamAudioSource over a byte buffer that grows while the player reads.
class _LiveMp3Source extends StreamAudioSource {
  final List<Uint8List> _chunks = <Uint8List>[];
  final List<Completer<void>> _waiters = <Completer<void>>[];
  int _len = 0;
  bool _closed = false;

  void add(Uint8List b) {
    _chunks.add(b);
    _len += b.length;
    _wake();
  }

  void close() {
    _closed = true;
    _wake();
  }

  void reset() {
    _chunks.clear();
    _len = 0;
    _closed = false;
  }

  void _wake() {
    for (final w in _waiters) {
      if (!w.isCompleted) w.complete();
    }
    _waiters.clear();
  }

  Future<void> _waitUntil(bool Function() cond) async {
    while (!cond()) {
      final w = Completer<void>();
      _waiters.add(w);
      await w.future;
    }
  }

  Uint8List _slice(int start, int end) {
    final out = BytesBuilder(copy: false);
    var pos = 0;
    for (final c in _chunks) {
      final cEnd = pos + c.length;
      if (cEnd <= start) {
        pos = cEnd;
        continue;
      }
      if (pos >= end) break;
      final from = math.max(start - pos, 0);
      final to = math.min(end - pos, c.length);
      out.add(c.sublist(from, to));
      pos = cEnd;
    }
    return out.takeBytes();
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    await _waitUntil(() => _len > s || _closed);
    final e = end == null ? _len : math.min(end, _len);
    final count = math.max(0, e - s);
    return StreamAudioResponse(
      // null = "live, length unknown" → player keeps requesting more.
      sourceLength: _closed ? _len : null,
      contentLength: count,
      offset: s,
      stream: Stream.value(_slice(s, s + count)),
      contentType: 'audio/mpeg',
    );
  }
}
