import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';

enum _Lang { bisaya, english, filipino }

class _ChatMessage {
  const _ChatMessage(this.fromBot, this.text);
  final bool fromBot;
  final String text;
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  _Lang _lang = _Lang.bisaya;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [
    const _ChatMessage(true,
        'Maayong adlaw, Lola! Unsay akong ikatabang nimo karon? (How can I help you today?)'),
    const _ChatMessage(false, 'How do I claim my Robinsons movie ticket?'),
    const _ChatMessage(true,
        'Adto lang sa Robinsons Place Dumaguete, Lola. Ipakita ang imong Senior Citizen ID sa counter aron mahatagan ka og libreng tiket!'),
  ];

  void _send([String? text]) {
    final value = (text ?? _controller.text).trim();
    if (value.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(false, value));
      _controller.clear();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _messages.add(const _ChatMessage(
            true, 'Salamat sa imong pangutana! Susihon nako kini para nimo.'));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forestBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ForestScreenHeader(
              title: 'AI Civic Chatbot',
              subtitle: 'Pakighisgot sa Dumaguete AI Assistant',
              onBack: widget.onBack,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.forestSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.forestBorder, width: 2),
                ),
                child: Row(
                  children: [
                    _LangTab(
                      label: 'Bisaya',
                      selected: _lang == _Lang.bisaya,
                      onTap: () => setState(() => _lang = _Lang.bisaya),
                    ),
                    _LangTab(
                      label: 'English',
                      selected: _lang == _Lang.english,
                      onTap: () => setState(() => _lang = _Lang.english),
                    ),
                    _LangTab(
                      label: 'Filipino',
                      selected: _lang == _Lang.filipino,
                      onTap: () => setState(() => _lang = _Lang.filipino),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  for (final m in _messages) ...[
                    _ChatBubble(message: m),
                    const SizedBox(height: 16),
                  ],
                  const Text('PINDOTA KANI PARA DALI NGA PANGUTANA:',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.forestBody)),
                  const SizedBox(height: 12),
                  _QuickQuestion(
                    label: 'How to claim pension? / Unsaon pagkuha sa pensyon?',
                    onTap: () => _send('How to claim pension?'),
                  ),
                  const SizedBox(height: 12),
                  _QuickQuestion(
                    label: 'When is next vaccine? / Kanus-a ang bakuna?',
                    onTap: () => _send('When is next vaccine?'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.forestBorder, width: 2),
                      ),
                      child: TextField(
                        controller: _controller,
                        onSubmitted: _send,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Isulat ang imong pangutana...',
                          hintStyle: TextStyle(color: AppColors.forestBody),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _send(),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.forest,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.forestBorder, width: 2),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangTab extends StatelessWidget {
  const _LangTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.forest : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: selected ? Colors.white : AppColors.forestBody)),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.fromBot) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.forest,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.forestBorder, width: 2),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Text(message.text,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.forestDark,
                      height: 1.4)),
            ),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 270),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.forestSoft,
          border: Border.all(color: AppColors.forest, width: 2),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
            topLeft: Radius.circular(20),
          ),
        ),
        child: Text(message.text,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.forestDark,
                height: 1.4)),
      ),
    );
  }
}

class _QuickQuestion extends StatelessWidget {
  const _QuickQuestion({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.orangeBg2,
          border: Border.all(color: AppColors.orange, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app_outlined, color: AppColors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.forestDark)),
            ),
          ],
        ),
      ),
    );
  }
}
