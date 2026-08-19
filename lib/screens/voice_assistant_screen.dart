import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/profile_service.dart';
import '../services/agakai_api.dart';
import '../services/app_config.dart';
import '../services/live_tts_player.dart';
import '../services/voice_recorder.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';

enum _VoiceState { idle, listening, processing, answering }

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

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key, this.onBack});

  /// Optional back handler (e.g. switch to the Home tab). When null, the
  /// header arrow falls back to [Navigator.maybePop] — which does nothing
  /// inside an IndexedStack, so shells that host this screen in a tab
  /// should pass an explicit handler.
  final VoidCallback? onBack;

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  _VoiceState _state = _VoiceState.idle;

  // ---- microphone (server-side STT) ----
  /// Pure audio capture. Transcription happens on the server (ElevenLabs
  /// STT via the chat edge function), so no on-device recognizer can cut
  /// off on silence — the user speaks as long as they like, then taps.
  final VoiceRecorder _recorder = VoiceRecorder();
  StreamSubscription<double>? _ampSub;

  /// Raw mic level in dB (~ -60 quiet … -5 loud). Drives the mic pulse.
  double _soundLevel = 0;

  // ---- streaming chat ----
  late final AgakApi _api = AgakApi(
    supabaseUrl: AppConfig.supabaseUrl!,
    anonKey: AppConfig.supabaseAnonKey!,
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
    // Warm the profile cache so the first ask has no hidden network delay
    // before the chat stream opens.
    unawaited(ProfileService.loadProfileOrNull());
  }

  // ------------------------------------------------------------ speech ----

  void _showNotCaught() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('I didn\'t catch that. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMicUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice isn\'t available on this device right now. '
            'You can still type your question below.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Tap the mic: start pure audio capture. NO on-device recognizer runs,
  /// so nothing can cut off on silence — the user speaks as long as they
  /// want and taps again when done.
  Future<void> _startListening() async {
    final ok = await _recorder.start();
    if (!ok) {
      if (mounted) _showMicUnavailable();
      return;
    }
    _ampSub?.cancel();
    _ampSub = _recorder.amplitude.listen(_onAmplitude);
    _soundLevel = 0;
    if (!mounted) return;
    setState(() => _state = _VoiceState.listening);
  }

  /// Live mic level (dB) → drives the mic button animation.
  void _onAmplitude(double db) {
    if (!mounted || _state != _VoiceState.listening) return;
    _soundLevel = db;
    setState(() {});
  }

  /// Tap the mic again: stop recording, send the clip to the edge function
  /// for server-side STT (ElevenLabs), then stream the answer.
  Future<void> _stopListening() async {
    if (!mounted || _state != _VoiceState.listening) return;
    _ampSub?.cancel();
    _ampSub = null;
    // INSTANT feedback: switch to the "reading your question" pane while
    // the recording is finalized and transcribed on the server.
    setState(() => _state = _VoiceState.processing);
    final bytes = await _recorder.stop();
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _state = _VoiceState.idle);
      _showNotCaught();
      return;
    }
    await _askAudio(bytes);
  }

  // ------------------------------------------------------------ chat ------

  /// Starts a streaming chat for a typed [question] and renders the answer
  /// live.
  void _ask(String question) {
    final q = question.trim();
    if (q.isEmpty) return;
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
    unawaited(_runChat(text: q));
  }

  /// Sends a recorded mic clip for server-side STT + chat. The screen is
  /// already on the "Reading what you said…" pane; the `transcript` event
  /// (the STT result) moves it to the answer view.
  Future<void> _askAudio(Uint8List bytes) async {
    await _runChat(audioBytes: bytes);
  }

  Future<void> _runChat({String? text, Uint8List? audioBytes}) async {
    final gen = ++_chatGen;

    // Personalize: send the logged-in senior's profile so AgakAI greets
    // them by name and tailors answers to their location.
    final profile = await ProfileService.loadProfileOrNull();
    final user = profile == null
        ? null
        : <String, Object?>{
            'id': profile.id,
            'name': profile.name,
            'age': profile.age,
            'gender': profile.gender,
            'address': profile.address,
          };
    if (!mounted || gen != _chatGen) return;

    try {
      await for (final event in _api.chatStream(
        text: text,
        audioBytes: audioBytes,
        audioFormat: 'm4a',
        user: user,
      )) {
        if (!mounted || gen != _chatGen) return; // superseded by a newer ask
        switch (event) {
          case AgakTranscript():
            // Server-side STT result — this is the question. If we were on
            // the processing pane (audio path), move to the answer view.
            setState(() {
              _state = _VoiceState.answering;
              _question = event.question;
            });
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
              // Ensure the error box is visible even from the processing
              // pane (e.g. STT failed on the server).
              _state = _VoiceState.answering;
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
        _state = _VoiceState.answering;
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

  /// `?` button: reveals the senior's rolling support notes (`user_notes`),
  /// maintained by the LLM after every exchange.
  void _openNotes() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Container(
          height: MediaQuery.of(context).size.height * 0.62 + bottomInset,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology_outlined,
                      color: AppColors.navy, size: 24),
                  SizedBox(width: 10),
                  Text('Support notes',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'How AgakAI is getting to know Lola/Lolo — updated after '
                'each conversation.',
                style: TextStyle(fontSize: 13, color: AppColors.slateText),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<String?>(
                  future: ProfileService.loadUserNotes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final notes = snapshot.data;
                    if (notes == null) {
                      return const Center(
                        child: Text('Could not load notes.',
                            style: TextStyle(color: AppColors.slateText)),
                      );
                    }
                    if (notes.trim().isEmpty) {
                      return const Center(
                        child: Text('No notes yet — start a conversation.',
                            style: TextStyle(color: AppColors.slateText)),
                      );
                    }
                    return SingleChildScrollView(
                      child: MarkdownBody(
                        data: notes,
                        selectable: true,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(Theme.of(context))
                                .copyWith(
                          p: const TextStyle(
                              fontSize: 15,
                              color: AppColors.slateText,
                              height: 1.55),
                          strong: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink),
                          listBullet: const TextStyle(
                              fontSize: 15, color: AppColors.slateText),
                          h1: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy),
                          h2: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy),
                          h3: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reset() async {
    _chatGen++; // discard any in-flight stream
    await _recorder.cancel(); // no-op if not recording
    _ampSub?.cancel();
    _ampSub = null;
    await _tts.stop();
    _audioBytes.clear();
    _soundLevel = 0;
    if (!mounted) return;
    setState(() {
      _state = _VoiceState.idle;
      _question = '';
      _answer = '';
      _chatDone = false;
      _chatError = false;
    });
  }

  @override
  @override
  void dispose() {
    _chatGen++;
    _ampSub?.cancel();
    unawaited(_recorder.dispose());
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
              onBack: widget.onBack,
              trailing: _CircleButton(
                icon: Icons.help_outline_rounded,
                onTap: _openNotes,
              ),
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
                      controller: _textController,
                      onSubmit: _ask,
                      onSuggestedTap: _ask,
                    ),
                  _VoiceState.listening => const _ListeningBody(),
                  _VoiceState.processing => const _ProcessingBody(),
                  _VoiceState.answering => _AnsweringBody(
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
            // Mic dock pinned at the BOTTOM, always visible: the button
            // pulses with the live voice level while listening, and the
            // label explains the current action.
            _MicDock(
              onMicTap: switch (_state) {
                _VoiceState.idle => _startListening,
                _VoiceState.listening => _stopListening,
                _VoiceState.processing => () {},
                _VoiceState.answering => _reset,
              },
              listening: _state == _VoiceState.listening,
              label: switch (_state) {
                _VoiceState.idle => 'Tap to Speak',
                _VoiceState.listening =>
                  'Listening… tap the mic when you\'re done',
                _VoiceState.processing => 'Reading what you said…',
                _VoiceState.answering => 'Tap to Ask Again',
              },
              soundLevel: _soundLevel,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed bottom bar holding the mic button + status label, used by every
/// voice-assistant state. The mic pulses with the live voice level while
/// listening (see [_MicButton.soundLevel]).
class _MicDock extends StatelessWidget {
  const _MicDock({
    required this.onMicTap,
    required this.listening,
    required this.label,
    this.soundLevel = 0,
  });

  final VoidCallback onMicTap;
  final bool listening;
  final String label;
  final double soundLevel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEFF2), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MicButton(
                onTap: onMicTap,
                listening: listening,
                soundLevel: soundLevel,
              ),
              const SizedBox(height: 12),
              // Soft fade when the status label changes (silent, easy to
              // read — no sudden pop for aging eyes).
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  label,
                  key: ValueKey(label),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdleBody extends StatelessWidget {
  const _IdleBody({
    required this.controller,
    required this.onSubmit,
    required this.onSuggestedTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onSuggestedTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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

/// Centered hint shown while the mic is live (the mic itself lives in the
/// bottom dock and pulses with the voice level).
class _ListeningBody extends StatelessWidget {
  const _ListeningBody();

  @override
  Widget build(BuildContext context) {
    // Just the calm pulse here — the "Listening… tap the mic when you're
    // done" instruction already lives in the bottom dock, so repeating it
    // in the middle would be redundant.
    return const Expanded(
      child: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 0, 32, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ListeningPulse(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown the instant the user taps the mic to stop: confirms the query
/// was heard while the engine finalizes the transcript.
class _ProcessingBody extends StatelessWidget {
  const _ProcessingBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ListeningPulse(),
                  SizedBox(height: 20),
                  Text(
                    'Reading what you said…',
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
                    'One moment, Lola/Lolo.',
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
    required this.question,
    required this.answer,
    required this.done,
    required this.error,
    required this.errorMessage,
    required this.onRetry,
    required this.scrollController,
  });

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

    return Expanded(
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
                    Icon(Icons.mic_rounded, color: AppColors.navy, size: 20),
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
                      fontSize: 18, color: AppColors.slateText, height: 1.6),
                ),
                const Divider(height: 32),

                // ---- the streaming answer ----
                if (error)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 200),
                    builder: (context, t, child) =>
                        Opacity(opacity: t, child: child),
                    child: _ErrorBox(message: errorMessage, onRetry: onRetry),
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
  const _MicButton({
    required this.onTap,
    required this.listening,
    this.soundLevel = 0,
  });
  final VoidCallback onTap;
  final bool listening;
  final double soundLevel;

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

  /// Smoothed 0..1 voice level driving the enlarge/shrink while listening.
  /// Animated (rather than snapped) so rapid raw updates from the speech
  /// engine read as a gentle grow/shrink instead of a jittery flicker.
  late final AnimationController _voice = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );

  double get _normalizedLevel {
    // Mic levels from the recorder run roughly -60 dB (quiet) to -5 dB
    // (loud). Normalize to 0..1 and guard against out-of-range values.
    final v = (widget.soundLevel + 50) / 50;
    return v.clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    if (!widget.listening) _breathe.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Voice level updates arrive continuously WHILE listening — handle
    // them BEFORE the listening-state early return, otherwise the mic
    // never reacts to the user's voice.
    if (widget.listening && widget.soundLevel != oldWidget.soundLevel) {
      _voice.animateTo(_normalizedLevel, curve: Curves.easeOut);
    }
    if (widget.listening == oldWidget.listening) return;
    if (widget.listening) {
      _controller.repeat(reverse: true);
      _breathe.stop();
      _breathe.value = 0;
    } else {
      _controller.stop();
      _controller.value = 0;
      _voice.animateTo(0, curve: Curves.easeOut);
      _breathe.repeat(reverse: true);
    }
    if (widget.listening && widget.soundLevel != oldWidget.soundLevel) {
      _voice.animateTo(_normalizedLevel, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _breathe.dispose();
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _breathe, _voice]),
      builder: (context, child) {
        final t = _controller.value;
        final outer = Color.lerp(AppColors.paleBlueBg, AppColors.skyBlueBg, t)!;
        final inner = Color.lerp(AppColors.brightBlue, AppColors.midBlue, t)!;
        // Idle: gentle ±1.5% breathing. Listening: the button grows up to
        // ~22% larger as the user's voice gets louder, and eases back down
        // in quiet moments — a clear, direct "it hears me" signal.
        final scale = widget.listening
            ? 1 + 0.22 * _voice.value
            : 1 + 0.015 * _breathe.value;
        return Transform.scale(
          scale: scale,
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
