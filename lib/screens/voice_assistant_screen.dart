import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/agakai_api.dart';
import '../services/app_config.dart';
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

/// How long to keep the "Listening…" card visible after the speech engine
/// reports the final result before settling it into the transcript view.
const _settleDelay = Duration(milliseconds: 1200);

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

  String _transcript = '';
  bool _transcriptFinal = false;
  Timer? _settleTimer;

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

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final ready = await _speech.initialize(
      onError: _onSpeechError,
      finalTimeout: const Duration(seconds: 3),
    );
    if (mounted) setState(() => _speechReady = ready);
  }

  // ------------------------------------------------------------ speech ----

  void _onSpeechError(SpeechRecognitionError error) {
    // Android fires lots of "benign" errors mid-session on pauses/noise
    // (no_match, speech_timeout, network…), all marked permanent. If we
    // already caught some words, treat it as "end of utterance" and KEEP
    // the transcript — never wipe what the user already said.
    if (!mounted) return;
    if (_transcript.trim().isNotEmpty) {
      _finalizeSession();
      return;
    }
    if (_state == _VoiceState.listening) {
      setState(() => _state = _VoiceState.idle);
      _showNotCaught();
    }
  }

  void _showNotCaught() {
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
    _settleTimer?.cancel();
    setState(() {
      _state = _VoiceState.listening;
      _transcript = '';
      _transcriptFinal = false;
    });
    await _speech.listen(
      onResult: _onRecognitionResult,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 5),
        // Better long-form behavior on iOS (sentences, not commands).
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _onRecognitionResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords.trim();

    if (result.finalResult) {
      // A final can arrive with empty text on some devices (or right after
      // a blank partial). Never let it wipe what we already caught:
      // keep the last live text as the fallback.
      if (words.isNotEmpty) _transcript = words;
      _transcriptFinal = true;
      setState(() {});
      // Let the live card show the finalized phrase for a beat, then settle.
      _settleTimer?.cancel();
      _settleTimer = Timer(_settleDelay, _finalizeSession);
      return;
    }

    // ---- partial result ----
    // The #1 cause of "the text clears": platforms (especially Android)
    // send EMPTY partial events mid-session. Ignore them entirely.
    if (words.isEmpty || words == _transcript) return;

    final current = _transcript;
    if (current.isEmpty) {
      _transcript = words;
    } else if (words.startsWith(current) || words.contains(current)) {
      // Cumulative platforms (iOS, most Android) resend the full text so
      // far — just replace with the newest full version.
      _transcript = words;
    } else if (current.contains(words)) {
      return; // subset of what we already have — no-op
    } else {
      // Delta-style OEM recognizers send only the NEW words: append.
      _transcript = '$current $words';
    }
    setState(() {});
  }

  /// Settles the listening session: asks AgakAI with the captured question.
  void _finalizeSession() {
    _settleTimer?.cancel();
    if (!mounted || _state != _VoiceState.listening) return;
    final question = _transcript.trim();
    if (question.isEmpty) {
      setState(() => _state = _VoiceState.idle);
      _showNotCaught();
      return;
    }
    _ask(question);
  }

  Future<void> _stopListening() async {
    _settleTimer?.cancel();
    if (_speech.isListening) await _speech.stop(); // fires a final result
    // Belt-and-suspenders: if the platform goes silent after stop() with no
    // final event, finalize anyway so the UI never hangs on "Listening…".
    _settleTimer = Timer(const Duration(milliseconds: 2500), _finalizeSession);
  }

  // ------------------------------------------------------------ chat ------

  /// Starts a streaming chat for [question] and renders the answer live.
  void _ask(String question) {
    final q = question.trim();
    if (q.isEmpty) return;
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
    try {
      await for (final event in _api.chatStream(text: question)) {
        if (!mounted || gen != _chatGen) return; // superseded by a newer ask
        setState(() {
          switch (event) {
            case AgakTranscript():
              _question = event.question;
            case AgakDelta():
              _answer += event.text;
            case AgakAudio():
              break; // voice chunk playback is the next step
            case AgakDone():
              _answer = event.answer;
              _chatDone = true;
            case AgakError():
              _chatError = true;
              _chatErrorMessage = event.message;
          }
        });
        if (_answer.length % 6 == 0) _scrollToBottom();
      }
    } catch (e) {
      if (!mounted || gen != _chatGen) return;
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
    if (_speech.isListening) await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _state = _VoiceState.idle;
      _transcript = '';
      _transcriptFinal = false;
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
    _speech.cancel();
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
                  ? _CircleButton(icon: Icons.help_outline_rounded, onTap: () {})
                  : null,
            ),
            Expanded(
              child: switch (_state) {
                _VoiceState.idle => _IdleBody(
                    onMicTap: _startListening,
                    controller: _textController,
                    onSubmit: _ask,
                    onSuggestedTap: _ask,
                  ),
                _VoiceState.listening => _ListeningBody(
                    onMicTap: _stopListening,
                    transcript: _transcript,
                    transcriptFinal: _transcriptFinal,
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
  const _MicHero({required this.onMicTap, required this.listening, required this.label});

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
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 12),
                for (final q in _suggestedQuestions) ...[
                  _QuestionButton(question: q, onTap: () => onSuggestedTap(q.title)),
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
  const _ListeningBody({
    required this.onMicTap,
    required this.transcript,
    required this.transcriptFinal,
  });

  final VoidCallback onMicTap;
  final String transcript;
  final bool transcriptFinal;

  @override
  Widget build(BuildContext context) {
    final bool hasWords = transcript.trim().isNotEmpty;
    return Column(
      children: [
        _MicHero(onMicTap: onMicTap, listening: true, label: 'Listening...'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.focusBlue, width: 2.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LiveDot(finalized: transcriptFinal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasWords
                              ? '$transcript${transcriptFinal ? '' : '▌'}'
                              : 'Say something, Lola...',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slateText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Try asking...',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 12),
                for (final q in _suggestedQuestions) ...[
                  _QuestionButton(question: q, onTap: null),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Red dot that pulses while transcribing, turns solid once the final
/// result arrives so the user can see the engine "locked in" the phrase.
class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.finalized});
  final bool finalized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 700),
        tween: Tween(begin: 0, end: finalized ? 1 : 0),
        builder: (context, t, _) {
          final blinking = finalized ? 1.0 : (0.35 + 0.65 * t);
          return Opacity(
            opacity: blinking,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: finalized ? AppColors.claimGreen : AppColors.brightBlue,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
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
    final markdownStyle = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: const TextStyle(fontSize: 18, color: AppColors.slateText, height: 1.6),
      listBullet: const TextStyle(fontSize: 18, color: AppColors.slateText),
      strong: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
      blockquote: const TextStyle(fontSize: 17, color: AppColors.slateText, fontStyle: FontStyle.italic),
      h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.navy),
      h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.navy),
      h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy),
    );

    return Column(
      children: [
        _MicHero(onMicTap: onMicTap, listening: true, label: 'Tap to Ask Again'),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Container(
              padding: const EdgeInsets.all(23),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 14)),
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
                    _ErrorBox(message: errorMessage, onRetry: onRetry)
                  else if (answer.isEmpty && !done)
                    const _ThinkingIndicator()
                  else ...[
                    MarkdownBody(
                      data: answer,
                      styleSheet: markdownStyle,
                      selectable: true,
                    ),
                    const SizedBox(height: 12),
                    if (!done)
                      const Row(
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
                  ],
                ],
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
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.midBlue)),
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
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB3261E), size: 26),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 4)),
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

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(covariant _MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening == oldWidget.listening) return;
    if (widget.listening) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
        return InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onTap,
          child: Container(
            width: 146,
            height: 160,
            decoration: BoxDecoration(
              color: outer,
              borderRadius: BorderRadius.circular(76),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 2, offset: Offset(0, 4)),
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
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 46),
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
            BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 22, color: AppColors.ink),
      ),
    );
  }
}