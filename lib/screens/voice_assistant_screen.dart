import 'dart:async';

import 'package:flutter/material.dart';
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

const _sampleTranscript =
    'Nangutana ta ko, adto ba kos Robinsons para sa libreng sine ig-Miyerkules? Ug unsa gan...';

const _sampleAnswer =
    '"Nang Rosa, dili Biyernes o Miyerkules-kada Martes ang libre nga sine sa Robinsons Place, sugod 11:00 sa buntag. Ayaw kalimti pagdala sa imong Senior Citizen ID ug sa Special Movie Pass ID gikan sa OSCA.\n\n'
    'Para sa imong Social Pension payout sa Barangay Junob Hall, dad-a ra ang imong OSCA ID. Kon dili ka kalakaw ug adunay mokuha para nimo, kinahanglan og Authorization Letter ug ID sa tawo nga imong gipadala.';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  _VoiceState _state = _VoiceState.idle;
  Timer? _timer;

  void _startListening() {
    setState(() => _state = _VoiceState.listening);
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _state = _VoiceState.answering);
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() => _state = _VoiceState.idle);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
              title: 'Ask Anything',
              subtitle: 'Ako ang imong OSCA assistant',
              trailing: _state == _VoiceState.idle
                  ? _CircleButton(icon: Icons.help_outline_rounded, onTap: () {})
                  : null,
            ),
            Expanded(
              child: switch (_state) {
                _VoiceState.idle => _IdleBody(onMicTap: _startListening),
                _VoiceState.listening =>
                  _ListeningBody(onMicTap: _reset),
                _VoiceState.answering => _AnsweringBody(onMicTap: _reset),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleBody extends StatelessWidget {
  const _IdleBody({required this.onMicTap});
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Try asking...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 12),
          for (final q in _suggestedQuestions) ...[
            _QuestionButton(question: q),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          _KeyboardInputField(text: 'Type here instead...'),
          const SizedBox(height: 40),
          Center(child: _MicButton(onTap: onMicTap, listening: false)),
          const SizedBox(height: 16),
          const Center(
            child: Text('Tap to Speak',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ),
        ],
      ),
    );
  }
}

class _ListeningBody extends StatelessWidget {
  const _ListeningBody({required this.onMicTap});
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Try asking...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 12),
          for (final q in _suggestedQuestions) ...[
            _QuestionButton(question: q),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.focusBlue, width: 2.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(_sampleTranscript,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slateText)),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.paleBlueBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.brightBlue, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Center(child: _MicButton(onTap: onMicTap, listening: true)),
          const SizedBox(height: 16),
          const Center(
            child: Text('Listening...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ),
        ],
      ),
    );
  }
}

class _AnsweringBody extends StatelessWidget {
  const _AnsweringBody({required this.onMicTap});
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        children: [
          Container(
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _sampleAnswer,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, color: AppColors.slateText, height: 1.6),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.navy, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 56),
          _MicButton(onTap: onMicTap, listening: true),
          const SizedBox(height: 16),
          const Text('Listening...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      ),
    );
  }
}

class _QuestionButton extends StatelessWidget {
  const _QuestionButton({required this.question});
  final _SuggestedQuestion question;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _KeyboardInputField extends StatelessWidget {
  const _KeyboardInputField({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.focusBlue, width: 2.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.keyboard_alt_outlined, color: AppColors.slateText),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slateText)),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.paleBlueBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_forward_rounded,
                color: AppColors.brightBlue, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.onTap, required this.listening});
  final VoidCallback onTap;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 146,
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.paleBlueBg,
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
            color: AppColors.brightBlue,
            borderRadius: BorderRadius.circular(55),
            border: Border.all(color: Colors.white, width: 3.4),
          ),
          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 46),
        ),
      ),
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
