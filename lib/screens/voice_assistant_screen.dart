import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/profile_service.dart';
import '../services/agakai_api.dart';
import '../services/app_config.dart';
import '../services/live_tts_player.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';

enum _VoiceState { idle, listening, answering }

class _SuggestedQuestion {
  const _SuggestedQuestion(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

const _suggestedQuestions = [
  _SuggestedQuestion('Social Pension', 'unsaon pag dawat o i check an...'),
  _SuggestedQuestion('Mag-pa Check up', 'libreang pa check up sa cit...'),
  _SuggestedQuestion('Senior Discount', 'unsaon pag-gamit sa Senior C...'),
];

/// How long to hold the mic screen after the final transcript lands before
/// moving on to the answer view.
const _settleDelay = Duration(milliseconds: 500);

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  _VoiceState _state = _VoiceState.idle;

  // ---- speech to text ----
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;

  Timer? _settleTimer;

  // Continuous listening: committed sentence segments only. Partial STT
  // results are deliberately NOT shown or stored — live transcription on
  // Android/OEM recognizers is unreliable (frozen first-word, garbled
  // updates). We wait for final results; the LLM remains the only stream.
  final List<String> _segments = [];
  int _silentFinals = 0;
  bool _stopRequested = false;
  Timer? _relistenTimer;

  SpeechListenOptions get _listenOptions => SpeechListenOptions(
        listenFor: const Duration(minutes: 2),
        // pauseFor maps to EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS
        // on Android, but many devices ignore it and finalize after ~2-3s
        // of silence anyway. That's fine: `_scheduleRelisten` seamlessly
        // restarts the recognizer, so the mic stays open until the user taps.
        pauseFor: const Duration(minutes: 1),
        // Better long-form behavior on iOS (sentences, not commands).
        listenMode: ListenMode.dictation,
      );

  String get _fullTranscript =>
      _segments.where((s) => s.trim().isNotEmpty).join(' ');

  // ---- streaming chat ----
  late final AgakApi _api = AgakApi(
    supabaseUrl: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  /// Bumped on every new ask/reset so stale in-flight streams are discarded.
  int _chatGen = 0;
  String _question = '';
  String _answer = '';
  bool _chatDone = false;
  bool _chatError = false;
  String _chatErrorMessage = '';

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ---- whole-answer voice playback ----
  final LiveTtsPlayer _tts = LiveTtsPlayer();
  final BytesBuilder _audioBytes = BytesBuilder();

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final ready = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: (status) => debugPrint('STT status: $status'),
      finalTimeout: const Duration(seconds: 3),
    );
    if (mounted) setState(() => _speechReady = ready);
  }

  // ------------------------------------------------------------ speech ----

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('STT error: ${error.errorMsg} (permanent=${error.permanent})');
    // Android fires lots of "benign" permanent errors on pauses/noise.
    // If we caught words and the user wasn't stopping, just keep the
    // session alive by restarting the recognizer — never wipe or bail.
    if (!mounted) return;

    // We already captured words: the error is just the engine ending the
    // session (noise/silence/stop). NEVER lose what we heard — ask now.
    final question = _fullTranscript.trim();
    if (question.isNotEmpty) {
      _settleTimer?.cancel();
      _relistenTimer?.cancel();
      if (_state == _VoiceState.listening) {
        _ask(question);
      }
      return;
    }

    if (_stopRequested) {
      // The user tapped stop; the FINAL result (real, or the plugin's
      // fabricated one at ~3s after stop) may still be on its way with the
      // words. Give it a grace window before concluding we heard nothing —
      // never flash "didn't catch" while the transcript is about to land.
      _settleTimer?.cancel();
      _settleTimer =
          Timer(const Duration(milliseconds: 3500), _finalizeSession);
      return;
    }
    if (_state == _VoiceState.listening) {
      setState(() => _state = _VoiceState.idle);
      _showNotCaught();
    }
  }

  void _showNotCaught() {
    debugPrint('SHOW NOT CAUGHT (state=$_state stop=$_stopRequested '
        'transcript=$_fullTranscript)');
    // Only ever surface this while we're still on the listening screen.
    // If the answer pane is already showing, a stale timer/error must not
    // spam a contradictory "didn't catch" snackbar.
    if (_state != _VoiceState.listening) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('I didn\'t catch that. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSttUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice isn\'t available on this device right now. '
            'You can still type your question below.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startListening() async {
    if (!_speechReady) {
      _showSttUnavailable();
      return;
    }
    _relistenTimer?.cancel();
    _settleTimer?.cancel();
    _stopRequested = false;
    _segments.clear();
    _silentFinals = 0;
    setState(() {
      _state = _VoiceState.listening;
    });
    await _beginListen();
  }

  /// Safe wrapper around `_speech.listen` — never lets a platform error
  /// leave the UI stuck on "Listening…" with a dead mic.
  Future<void> _beginListen() async {
    try {
      await _speech.listen(
        onResult: _onRecognitionResult,
        listenOptions: _listenOptions,
      );
    } catch (e) {
      debugPrint('STT listen failed: $e');
      if (!mounted || _state != _VoiceState.listening) return;
      setState(() => _state = _VoiceState.idle);
      _showNotCaught();
    }
  }

  void _onRecognitionResult(SpeechRecognitionResult result) {
    if (!mounted) return;

    // Only FINAL results matter. Partial results are deliberately ignored:
    // live transcription on Android/OEM recognizers is unreliable (stuck
    // first word, blank flashes), and the user asked for the transcript to
    // appear only when the request finishes.
    if (!result.finalResult) return;

    final words = result.recognizedWords.trim();
    debugPrint('STT final (${words.length} chars): '
        '${words.length > 60 ? words.substring(0, 60) : words}');
    if (words.isNotEmpty && (_segments.isEmpty || _segments.last != words)) {
      _segments.add(words);
      _silentFinals = 0;
    } else if (words.isEmpty) {
      _silentFinals++;
    }

    if (_stopRequested) {
      // User tapped the mic: wrap up NOW and ask. (Even if an engine error
      // raced in first, whatever we caught is still in [_segments].)
      _settleTimer?.cancel();
      _relistenTimer?.cancel();
      final question = _fullTranscript.trim();
      if (question.isNotEmpty) {
        _ask(question);
      } else {
        _finalizeSession(); // nothing heard → gentle "didn't catch"
      }
      return;
    }

    if (_segments.isEmpty && _silentFinals >= 5) {
      // Nothing but silence for several engine finals: give up gently.
      _finalizeSession();
      return;
    }
    // Many Androids ignore the silence extra and finalize after ~2-3s
    // of pause. That must NOT end the session: seamlessly restart the
    // recognizer and keep accumulating the user's words.
    _scheduleRelisten();
  }

  /// Restarts the recognizer after the engine finalizes on its own, so the
  /// mic effectively stays open until the user taps it. The committed
  /// segments keep the full transcript across restarts.
  void _scheduleRelisten() {
    _relistenTimer?.cancel();
    // Keep the gap between engine restarts short so pauses don't feel like
    // the mic "stopped".
    _relistenTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || _state != _VoiceState.listening || _stopRequested) return;
      if (_speech.isListening) return;
      await _beginListen();
    });
  }

  /// Settles the listening session: asks AgakAI with the captured question.
  void _finalizeSession() {
    _settleTimer?.cancel();
    _relistenTimer?.cancel();
    if (!mounted || _state != _VoiceState.listening) return;
    final question = _fullTranscript.trim();
    if (question.isEmpty) {
      setState(() => _state = _VoiceState.idle);
      _showNotCaught();
      return;
    }
    _ask(question);
  }

  Future<void> _stopListening() async {
    _stopRequested = true;
    _relistenTimer?.cancel();
    _settleTimer?.cancel();
    try {
      if (_speech.isListening) {
        await _speech.stop(); // fires a final result → settle → ask
      }
    } catch (e) {
      debugPrint('STT stop failed: $e');
    }
    if (_speech.isListening) {
      // Belt-and-suspenders: if no final event arrives, don't hang.
      _settleTimer =
          Timer(const Duration(milliseconds: 2500), _finalizeSession);
    } else {
      // Engine already ended on its own (silence final): settle now.
      _settleTimer = Timer(_settleDelay, _finalizeSession);
    }
  }

  // ------------------------------------------------------------ chat ------

  /// Starts a streaming chat for [question] and renders the answer live.
  void _ask(String question) {
    final q = question.trim();
    if (q.isEmpty) return;
    // Cancel any pending speech-session timers: we're moving to answering.
    _settleTimer?.cancel();
    _relistenTimer?.cancel();
    // Barge-in: cut off any speech from a previous session before moving on.
    unawaited(_tts.stop());
    _audioBytes.clear();
    setState(() {
      _state = _VoiceState.answering;
      _question = q;
      _answer = '';
      _chatDone = false;
      _chatError = false;
      _chatErrorMessage = '';
    });
    _textController.clear();
    unawaited(_runChat(q));
  }

  Future<void> _runChat(String question) async {
    final gen = ++_chatGen;

    // Personalize: send the logged-in senior's profile so AgakAI greets
    // them by name and tailors answers to their location.
    final profile = await ProfileService.loadProfileOrNull();
    final user = profile == null
        ? null
        : <String, Object?>{
            'name': profile.name,
            'age': profile.age,
            'gender': profile.gender,
            'address': profile.address,
          };
    if (!mounted || gen != _chatGen) return;

    try {
      await for (final event in _api.chatStream(text: question, user: user)) {
        if (!mounted || gen != _chatGen) return; // superseded by a newer ask
        switch (event) {
          case AgakTranscript():
            setState(() => _question = event.question);
          case AgakDelta():
            setState(() => _answer += event.text);
            if (_answer.length % 6 == 0) _scrollToBottom();
          case AgakAudio():
            // Accumulate the mp3 chunks; the full answer is played as one
            // file when `done` arrives (whole-answer playback — nothing
            // streams, so nothing can skip).
            _audioBytes.add(event.chunk);
          case AgakDone():
            setState(() {
              _answer = event.answer;
              _chatDone = true;
            });
            await _tts.play(_audioBytes.takeBytes());
          case AgakError():
            setState(() {
              _chatError = true;
              _chatErrorMessage = event.message;
            });
            await _tts.stop();
        }
      }
    } catch (e) {
      if (!mounted || gen != _chatGen) return;
      await _tts.stop();
      setState(() {
        _chatError = true;
        _chatErrorMessage = 'Network error: $e';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _reset() async {
    _chatGen++; // discard any in-flight stream
    _settleTimer?.cancel();
    _relistenTimer?.cancel();
    if (_speech.isListening) await _speech.cancel();
    await _tts.stop();
    _audioBytes.clear();
    if (!mounted) return;
    setState(() {
      _state = _VoiceState.idle;
      _segments.clear();
      _stopRequested = false;
      _question = '';
      _answer = '';
      _chatDone = false;
      _chatError = false;
    });
  }

  @override
  void dispose() {
    _chatGen++;
    _settleTimer?.cancel();
    _relistenTimer?.cancel();
    _speech.cancel();
    unawaited(_tts.dispose());
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ build -----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: 'Ask Anything',
              subtitle: 'Ako ang imong OSCA assistant',
              trailing: _state == _VoiceState.idle
                  ? _CircleButton(
                      icon: Icons.help_outline_rounded, onTap: () {})
                  : null,
            ),
            Expanded(
              // Gentle crossfade between idle / listening / answering so
              // state changes never hard-cut (calm for seniors).
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                // Without this, the switcher's Stack gives its children
                // UNBOUNDED height during the crossfade and the scrolling
                // bodies overflow wildly. StackFit.expand keeps every child
                // pinned to the screen bounds.
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: switch (_state) {
                  _VoiceState.idle => _IdleBody(
                      onMicTap: _startListening,
                      controller: _textController,
                      onSubmit: _ask,
                      onSuggestedTap: _ask,
                    ),
                  _VoiceState.listening => _ListeningBody(
                      onMicTap: _stopListening,
                    ),
                  _VoiceState.answering => _AnsweringBody(
                      onMicTap: _reset,
                      question: _question,
                      answer: _answer,
                      done: _chatDone,
                      error: _chatError,
                      errorMessage: _chatErrorMessage,
                      onRetry: () => _ask(_question),
                      scrollController: _scrollController,
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pins the mic button + status label at the top of every voice-assistant
/// state so the primary action is visible immediately, with
/// state-specific detail scrolling underneath instead of pushing it down.
class _MicHero extends StatelessWidget {
  const _MicHero(
      {required this.onMicTap, required this.listening, required this.label});

  final VoidCallback onMicTap;
  final bool listening;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Column(
        children: [
          _MicButton(onTap: onMicTap, listening: listening),
          const SizedBox(height: 12),
          // Soft fade when the status label changes (silent, easy to read).
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              label,
              key: ValueKey(label),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleBody extends StatelessWidget {
  const _IdleBody({
    required this.onMicTap,
    required this.controller,
    required this.onSubmit,
    required this.onSuggestedTap,
  });

  final VoidCallback onMicTap;
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onSuggestedTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MicHero(onMicTap: onMicTap, listening: false, label: 'Tap to Speak'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Try asking...',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 12),
                for (final q in _suggestedQuestions) ...[
                  _QuestionButton(
                      question: q, onTap: () => onSuggestedTap(q.title)),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                _AskBar(controller: controller, onSubmit: onSubmit),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Live speech-to-text card: updates word-by-word while the user speaks,
/// with a blinking cursor until the engine finalizes the utterance.
class _ListeningBody extends StatelessWidget {
  const _ListeningBody({required this.onMicTap});

  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MicHero(
          onMicTap: onMicTap,
          listening: true,
          label: 'Listening… tap the mic when you\'re done',
        ),
        const Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ListeningPulse(),
                  SizedBox(height: 20),
                  Text(
                    'I\'m listening — go ahead and speak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Tap the mic again when you\'re finished.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: AppColors.slateText),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Calm pulsing dot + soft rings while the mic is live.
class _ListeningPulse extends StatelessWidget {
  const _ListeningPulse();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1100),
      tween: Tween(begin: 0, end: 1),
      builder: (context, t, child) {
        final wide = 56 + 22 * t;
        return SizedBox(
          width: wide,
          height: wide,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 56 + 22 * (1 - t),
                height: 56 + 22 * (1 - t),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.paleBlueBg,
                ),
              ),
              Opacity(
                opacity: 0.45,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.skyBlueBg2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Question bubble + live streaming answer (markdown, rendered as deltas
/// arrive). Auto-scrolls while the answer grows.
class _AnsweringBody extends StatelessWidget {
  const _AnsweringBody({
    required this.onMicTap,
    required this.question,
    required this.answer,
    required this.done,
    required this.error,
    required this.errorMessage,
    required this.onRetry,
    required this.scrollController,
  });

  final VoidCallback onMicTap;
  final String question;
  final String answer;
  final bool done;
  final bool error;
  final String errorMessage;
  final VoidCallback onRetry;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final markdownStyle =
        MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: const TextStyle(fontSize: 18, color: AppColors.slateText, height: 1.6),
      listBullet: const TextStyle(fontSize: 18, color: AppColors.slateText),
      strong:
          const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
      blockquote: const TextStyle(
          fontSize: 17,
          color: AppColors.slateText,
          fontStyle: FontStyle.italic),
      h1: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.navy),
      h2: const TextStyle(
          fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.navy),
      h3: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy),
    );

    return Column(
      children: [
        _MicHero(
            onMicTap: onMicTap, listening: true, label: 'Tap to Ask Again'),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            // Calm entrance: the card fades in with a barely-there scale.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
              ),
              child: Container(
                padding: const EdgeInsets.all(23),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 14,
                        offset: Offset(0, 14)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- the question ----
                    const Row(
                      children: [
                        Icon(Icons.mic_rounded,
                            color: AppColors.navy, size: 20),
                        SizedBox(width: 8),
                        Text('Your question',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                                letterSpacing: 0.3)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      question,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18,
                          color: AppColors.slateText,
                          height: 1.6),
                    ),
                    const Divider(height: 32),

                    // ---- the streaming answer ----
                    if (error)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 200),
                        builder: (context, t, child) =>
                            Opacity(opacity: t, child: child),
                        child:
                            _ErrorBox(message: errorMessage, onRetry: onRetry),
                      )
                    else if (answer.isEmpty && !done)
                      const _ThinkingIndicator()
                    else ...[
                      MarkdownBody(
                        data: answer,
                        styleSheet: markdownStyle,
                        selectable: true,
                      ),
                      const SizedBox(height: 12),
                      // The working indicator fades out on completion and is
                      // replaced by a quiet confirmation.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: done
                            ? const Row(
                                key: ValueKey('done'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded,
                                      color: AppColors.claimGreen, size: 16),
                                  SizedBox(width: 8),
                                  Text('Answer complete',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.claimGreen)),
                                ],
                              )
                            : const Row(
                                key: ValueKey('answering'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _ThinkingDot(),
                                  SizedBox(width: 10),
                                  Text('AgakAI is answering…',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.midBlue)),
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Three pulsing dots shown while waiting for the first LLM token.
class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ThinkingDot(),
          SizedBox(width: 10),
          Text('AgakAI is thinking…',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.midBlue)),
        ],
      ),
    );
  }
}

class _ThinkingDot extends StatelessWidget {
  const _ThinkingDot();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 900),
      tween: Tween(begin: 0, end: 1),
      builder: (context, t, child) => Opacity(
        opacity: 0.4 + 0.6 * t,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.brightBlue,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3C1BE)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFB3261E), size: 26),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF8C1D18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.midBlue,
              side: const BorderSide(color: AppColors.midBlue),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionButton extends StatelessWidget {
  const _QuestionButton({required this.question, required this.onTap});
  final _SuggestedQuestion question;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.slateBorder, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: AppColors.ink)),
                  Text(question.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.slateText)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.slateText),
          ],
        ),
      ),
    );
  }
}

/// Real text field so seniors who prefer typing (or with no mic) can ask.
class _AskBar extends StatelessWidget {
  const _AskBar({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.focusBlue, width: 2.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.keyboard_alt_outlined, color: AppColors.slateText),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: onSubmit,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'Type here instead...',
                hintStyle: TextStyle(fontSize: 18, color: AppColors.slateText),
              ),
              style: const TextStyle(fontSize: 18, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onSubmit(controller.text),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.paleBlueBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.brightBlue, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mic button; while [listening] the outer ring pulses blue so the user
/// can see the microphone is live.
class _MicButton extends StatefulWidget {
  const _MicButton({required this.onTap, required this.listening});
  final VoidCallback onTap;
  final bool listening;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with TickerProviderStateMixin {
  /// Color pulse while listening.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Slow, subtle "breathing" scale at idle.
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.listening) _breathe.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening == oldWidget.listening) return;
    if (widget.listening) {
      _controller.repeat(reverse: true);
      _breathe.stop();
      _breathe.value = 0;
    } else {
      _controller.stop();
      _controller.value = 0;
      _breathe.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final outer = Color.lerp(AppColors.paleBlueBg, AppColors.skyBlueBg, t)!;
        final inner = Color.lerp(AppColors.brightBlue, AppColors.midBlue, t)!;
        // Gentle idle breathing: ±1.5% scale, slow enough to be soothing.
        final breath = 1 + 0.015 * _breathe.value;
        return Transform.scale(
          scale: breath,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: Container(
              width: 146,
              height: 160,
              decoration: BoxDecoration(
                color: outer,
                borderRadius: BorderRadius.circular(76),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 2,
                      offset: Offset(0, 4)),
                ],
              ),
              alignment: Alignment.center,
              child: Container(
                width: 106,
                height: 116,
                decoration: BoxDecoration(
                  color: inner,
                  borderRadius: BorderRadius.circular(55),
                  border: Border.all(color: Colors.white, width: 3.4),
                ),
                child: const Icon(Icons.mic_rounded,
                    color: Colors.white, size: 46),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 22, color: AppColors.ink),
      ),
    );
  }
}
