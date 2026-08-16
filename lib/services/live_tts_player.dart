// Gapless live TTS playback for the streaming voice assistant.
// Deps: just_audio (https://pub.dev/packages/just_audio).
//
// The backend sends mp3 audio via SSE `audio` events. IMPORTANT: each
// sentence is its OWN mp3 (own ElevenLabs encode, own bitrate/ID3 header);
// the events carry a `sentence` id so the client groups them. Feeding two
// different mp3s into one decoder session corrupts playback (the decoder
// discards "unknown buffers" and the audio cuts off), so this player:
//   - starts playback as soon as the FIRST chunk of sentence 1 arrives,
//   - keeps each sentence in its own decoder session,
//   - completed sentences go to a FIFO queue and are played IN ARRIVAL
//     ORDER — a sentence that finishes buffering while an earlier one is
//     still playing must NOT be dropped or reordered.
// If `sentence` is absent (old backend), it falls back to sniffing the
// mp3 ID3 header ("ID3") at chunk starts to detect boundaries.
//
// Note: streaming source playback is fully supported on Android/iOS/macOS.
// On web, just_audio encodes the first response as a data URL, so only the
// initially available bytes play — voice on web should use a browser TTS
// fallback instead.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';

class LiveTtsPlayer {
  final AudioPlayer _player = AudioPlayer();

  /// The mp3 currently being filled by incoming chunks (the newest one).
  _Mp3Source? _filling;
  int _fillingSentence = -1;

  /// Sentences whose audio has fully arrived, waiting to play (FIFO).
  final List<_Mp3Source> _ready = [];

  /// The source currently bound to the player.
  _Mp3Source? _activeSource;

  bool _stopped = false;
  bool _pumping = false;

  /// Feed audio chunks in arrival order. [sentence] groups chunks that
  /// belong to the same mp3 (one per backend TTS sentence).
  Future<void> addChunk(Uint8List bytes, {int? sentence}) async {
    _stopped = false;

    // Detect a sentence boundary: explicit `sentence` id from the backend,
    // or (legacy backend) a new mp3 ID3 header at the start of a chunk.
    final bool id3Start = bytes.length >= 3 &&
        bytes[0] == 0x49 && // 'I'
        bytes[1] == 0x44 && // 'D'
        bytes[2] == 0x33; // '3'
    final bool boundary = _filling != null &&
        ((sentence != null && sentence != _fillingSentence) ||
            (sentence == null && id3Start));

    if (_filling == null || boundary) {
      // This sentence is complete — queue it for playback (FIFO, so it
      // plays in order even if earlier sentences are still playing).
      if (_filling != null) {
        _filling!.close(); // known length → clean EOF for the player
        _ready.add(_filling!);
      }
      _fillingSentence = sentence ?? _fillingSentence + 1;
      _filling = _Mp3Source();
    }
    _filling!.add(bytes);
    unawaited(_pump());
  }

  /// Call when the backend stream ends (`done` event).
  Future<void> finish() async {
    if (_filling != null) {
      _filling!.close();
      _ready.add(_filling!);
      _filling = null;
    }
    unawaited(_pump());
  }

  /// Abort playback (barge-in / error / new question). Safe to call
  /// repeatedly and on a fresh player. Chunks arriving after stop() are
  /// discarded (the caller's generation guard prevents them anyway).
  Future<void> stop() async {
    _stopped = true;
    if (_filling != null) _filling!.close(); // wake any pending reads
    await _player.stop();
    _filling = null;
    _fillingSentence = -1;
    _ready.clear();
    _activeSource = null;
    _pumping = false;
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }

  /// Single-flight pump: plays each sentence to its natural end, in FIFO
  /// arrival order.
  Future<void> _pump() async {
    if (_pumping || _stopped) return;
    _pumping = true;
    try {
      while (!_stopped) {
        _Mp3Source? next;
        if (_ready.isNotEmpty) {
          next = _ready.removeAt(0);
        } else if (_filling != null && !identical(_filling, _activeSource)) {
          // Nothing queued: stream whatever sentence is still arriving.
          next = _filling;
        }
        if (next == null) break;
        _activeSource = next;
        try {
          await _player.setAudioSource(next);
          // play() completes when this sentence reaches EOF — i.e. when the
          // next sentence's first chunk closed it out, or `done` did.
          await _player.play();
        } catch (e) {
          // A broken source must not wedge the loop or kill the app:
          // drop it and keep the rest of the pipeline going.
          debugPrint('LiveTtsPlayer: playback problem: $e');
          _activeSource = null;
          await _player.stop();
        }
      }
    } finally {
      _pumping = false;
    }
  }
}

/// A StreamAudioSource over a byte buffer that grows while the player
/// reads it. One instance per TTS sentence; close() makes its length known
/// so the player hits a clean EOF.
class _Mp3Source extends StreamAudioSource {
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
    if (_closed) return;
    _closed = true;
    _wake();
  }

  void _wake() {
    for (final w in _waiters) {
      if (!w.isCompleted) w.complete();
    }
    _waiters.clear();
  }

  Future<void> _waitUntil(bool Function() cond, {Duration? timeout}) async {
    final watch = Stopwatch()..start();
    while (!cond()) {
      if (timeout != null && watch.elapsed > timeout) return;
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
    if (end != null) {
      // Bounded range request: NEVER short-fill it. ExoPlayer mistakes a
      // partial range read for end-of-stream and truncates playback.
      await _waitUntil(
        () => _closed || _len >= end,
        timeout: const Duration(seconds: 15),
      );
    } else {
      await _waitUntil(() => _closed || _len > s);
    }
    final e = end == null ? _len : math.min(end, _len);
    final count = math.max(0, e - s);
    return StreamAudioResponse(
      // null while open = "live, length unknown" → player keeps requesting.
      // Once closed, the true length makes the player hit clean EOF.
      sourceLength: _closed ? _len : null,
      contentLength: count,
      offset: s,
      stream: Stream.value(_slice(s, s + count)),
      contentType: 'audio/mpeg',
    );
  }
}