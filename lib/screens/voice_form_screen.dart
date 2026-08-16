import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

import '../models/voice_form_field.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';

enum _Stage { speaking, listening, confirming, summary, submitted }

/// Walks a user through [form] one field at a time by voice: speaks each
/// question aloud, listens for the answer, shows it back as large text to
/// confirm, then advances. Says "back" or "repeat" to navigate by voice;
/// every step also has large on-screen buttons for the same actions so
/// nothing here depends on speech recognition actually working.
class VoiceFormScreen extends StatefulWidget {
  const VoiceFormScreen({super.key, required this.form, this.onExit});

  final VoiceFormDefinition form;
  final VoidCallback? onExit;

  @override
  State<VoiceFormScreen> createState() => _VoiceFormScreenState();
}

class _VoiceFormScreenState extends State<VoiceFormScreen> {
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  final _manualController = TextEditingController();

  int _fieldIndex = 0;
  _Stage _stage = _Stage.speaking;
  String _liveText = '';
  String _capturedAnswer = '';
  final Map<String, String> _answers = {};
  bool _speechAvailable = false;
  bool _showManualInput = false;

  VoiceFormField get _field => widget.form.fields[_fieldIndex];

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);

    try {
      _speechAvailable = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _showManualInput = true);
        },
        onStatus: (status) {
          if (!mounted) return;
          if ((status == 'done' || status == 'notListening') &&
              _stage == _Stage.listening) {
            setState(() => _showManualInput = true);
          }
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }

    if (!_speechAvailable && mounted) {
      setState(() => _showManualInput = true);
    }

    _askCurrentField();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _askCurrentField() async {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.speaking;
      _liveText = '';
      _showManualInput = !_speechAvailable;
    });
    try {
      await _tts.speak(_field.question);
    } catch (_) {
      // Ignore TTS failures (e.g. unsupported platform) and keep going.
    }
    if (!mounted) return;
    if (_speechAvailable) {
      _startListening();
    } else {
      setState(() => _stage = _Stage.listening);
    }
  }

  void _startListening() {
    setState(() {
      _stage = _Stage.listening;
      _liveText = '';
    });
    _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _liveText = result.recognizedWords);
    if (result.finalResult) {
      _handleRecognized(result.recognizedWords);
    }
  }

  bool _isCommand(String normalized, List<String> keywords) {
    if (normalized.split(RegExp(r'\s+')).length > 3) return false;
    return keywords.any((k) => normalized == k || normalized.contains(k));
  }

  void _handleRecognized(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      if (_speechAvailable) _startListening();
      return;
    }
    if (_isCommand(normalized, const ['back', 'go back', 'balik'])) {
      _goBack();
      return;
    }
    if (_isCommand(normalized, const ['repeat', 'say again', 'balik sulti'])) {
      _askCurrentField();
      return;
    }
    setState(() {
      _capturedAnswer = text.trim();
      _stage = _Stage.confirming;
    });
  }

  void _submitManualText() {
    final text = _manualController.text.trim();
    if (text.isEmpty) return;
    _manualController.clear();
    _handleRecognized(text);
  }

  void _goBack() {
    if (_fieldIndex == 0) {
      _askCurrentField();
      return;
    }
    setState(() => _fieldIndex -= 1);
    _askCurrentField();
  }

  void _retry() => _askCurrentField();

  void _confirmAnswer() {
    _answers[_field.id] = _capturedAnswer;
    if (_fieldIndex == widget.form.fields.length - 1) {
      _goToSummary();
    } else {
      setState(() => _fieldIndex += 1);
      _askCurrentField();
    }
  }

  void _editField(int index) {
    setState(() => _fieldIndex = index);
    _askCurrentField();
  }

  Future<void> _goToSummary() async {
    setState(() => _stage = _Stage.summary);
    final lines = widget.form.fields
        .map((f) => '${f.label}: ${_answers[f.id]}')
        .join('. ');
    try {
      await _tts.speak(
          "Here's a summary of your answers. $lines. Tap submit when you're ready.");
    } catch (_) {}
  }

  Future<void> _submit() async {
    setState(() => _stage = _Stage.submitted);
    try {
      await _tts.speak('Your application has been submitted. Salamat, Lola!');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: widget.form.title,
              subtitle: widget.form.subtitle,
              onBack: widget.onExit ?? () => Navigator.of(context).maybePop(),
            ),
            if (_stage != _Stage.summary && _stage != _Stage.submitted)
              _ProgressBar(
                current: _fieldIndex + 1,
                total: widget.form.fields.length,
              ),
            Expanded(
              child: switch (_stage) {
                _Stage.speaking => _SpeakingBody(question: _field.question),
                _Stage.listening => _ListeningBody(
                    field: _field,
                    liveText: _liveText,
                    speechAvailable: _speechAvailable,
                    showManualInput: _showManualInput,
                    manualController: _manualController,
                    onToggleManual: () =>
                        setState(() => _showManualInput = !_showManualInput),
                    onSubmitManual: _submitManualText,
                    onBack: _fieldIndex > 0 ? _goBack : null,
                  ),
                _Stage.confirming => _ConfirmingBody(
                    label: _field.label,
                    answer: _capturedAnswer,
                    onConfirm: _confirmAnswer,
                    onRetry: _retry,
                    onBack: _fieldIndex > 0 ? _goBack : null,
                  ),
                _Stage.summary => _SummaryBody(
                    form: widget.form,
                    answers: _answers,
                    onEdit: _editField,
                    onSubmit: _submit,
                  ),
                _Stage.submitted => _SubmittedBody(
                    onDone: widget.onExit ?? () => Navigator.of(context).maybePop(),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question $current of $total',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slateText)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 8,
              backgroundColor: AppColors.fieldBg,
              valueColor: const AlwaysStoppedAnimation(AppColors.brightBlue),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakingBody extends StatelessWidget {
  const _SpeakingBody({required this.question});
  final String question;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.paleBlueBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_up_rounded, size: 44, color: AppColors.brightBlue),
            ),
            const SizedBox(height: 24),
            Text(
              question,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 16),
            const Text('Reading the question...',
                style: TextStyle(fontSize: 15, color: AppColors.slateText)),
          ],
        ),
      ),
    );
  }
}

class _ListeningBody extends StatefulWidget {
  const _ListeningBody({
    required this.field,
    required this.liveText,
    required this.speechAvailable,
    required this.showManualInput,
    required this.manualController,
    required this.onToggleManual,
    required this.onSubmitManual,
    required this.onBack,
  });

  final VoiceFormField field;
  final String liveText;
  final bool speechAvailable;
  final bool showManualInput;
  final TextEditingController manualController;
  final VoidCallback onToggleManual;
  final VoidCallback onSubmitManual;
  final VoidCallback? onBack;

  @override
  State<_ListeningBody> createState() => _ListeningBodyState();
}

class _ListeningBodyState extends State<_ListeningBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          Text(widget.field.question,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          if (widget.speechAvailable && !widget.showManualInput) ...[
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.08).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.paleBlueBg,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 2, offset: Offset(0, 4)),
                  ],
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.brightBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3.4),
                  ),
                  child: const Icon(Icons.mic_rounded, color: Colors.white, size: 44),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Listening...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 4),
            Text(widget.field.hint ?? '',
                style: const TextStyle(fontSize: 13, color: AppColors.slateText)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.focusBlue, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.liveText.isEmpty ? 'Say your answer, or say "back" / "repeat"...' : widget.liveText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: widget.liveText.isEmpty ? AppColors.slateText : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: widget.onToggleManual,
              icon: const Icon(Icons.keyboard_alt_outlined),
              label: const Text('Type instead',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ] else ...[
            if (!widget.speechAvailable)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.orangeBg2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.orange, width: 1.5),
                ),
                child: const Text(
                  "Voice input isn't available on this device — please type your answer.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.forestDark),
                ),
              ),
            TextField(
              controller: widget.manualController,
              autofocus: true,
              style: const TextStyle(fontSize: 20),
              onSubmitted: (_) => widget.onSubmitManual(),
              decoration: InputDecoration(
                hintText: widget.field.hint ?? 'Type your answer...',
                filled: true,
                fillColor: AppColors.fieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
            const SizedBox(height: 16),
            _BigButton(label: 'Use This Answer', onTap: widget.onSubmitManual),
            if (widget.speechAvailable) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: widget.onToggleManual,
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Use voice instead',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
          if (widget.onBack != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmingBody extends StatelessWidget {
  const _ConfirmingBody({
    required this.label,
    required this.answer,
    required this.onConfirm,
    required this.onRetry,
    required this.onBack,
  });

  final String label;
  final String answer;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.slateText)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.dashboardAccentBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.dashboardAccent, width: 2),
            ),
            child: Text(
              answer,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 28),
          _BigButton(
            label: "Yes, That's Right",
            icon: Icons.check_rounded,
            color: AppColors.dashboardGreen,
            onTap: onConfirm,
          ),
          const SizedBox(height: 12),
          _BigOutlineButton(
            label: 'Try Again',
            icon: Icons.refresh_rounded,
            onTap: onRetry,
          ),
          if (onBack != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Previous Question',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.form,
    required this.answers,
    required this.onEdit,
    required this.onSubmit,
  });

  final VoiceFormDefinition form;
  final Map<String, String> answers;
  final ValueChanged<int> onEdit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please review your answers',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                for (int i = 0; i < form.fields.length; i++) ...[
                  _SummaryRow(
                    label: form.fields[i].label,
                    answer: answers[form.fields[i].id] ?? '',
                    onEdit: () => onEdit(i),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: _BigButton(
            label: 'Submit Application',
            icon: Icons.send_rounded,
            color: AppColors.dashboardGreen,
            onTap: onSubmit,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.answer, required this.onEdit});
  final String label;
  final String answer;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slateText)),
                const SizedBox(height: 4),
                Text(answer,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: AppColors.brightBlue),
          ),
        ],
      ),
    );
  }
}

class _SubmittedBody extends StatelessWidget {
  const _SubmittedBody({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.dashboardAccentBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 56, color: AppColors.dashboardGreen),
            ),
            const SizedBox(height: 24),
            const Text('Application Submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Salamat! Someone from OSCA will contact you soon.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.slateText)),
            const SizedBox(height: 28),
            _BigButton(label: 'Done', onTap: onDone),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.color = AppColors.navy,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 10)],
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _BigOutlineButton extends StatelessWidget {
  const _BigOutlineButton({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.slateBorder, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.ink),
              const SizedBox(width: 10),
            ],
            Text(label,
                style: const TextStyle(
                    color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
