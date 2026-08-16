import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav.dart';
import 'benefits_screen.dart';
import 'chatbot_screen.dart';
import 'home_screen.dart';
import 'voice_assistant_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onOpenVoiceAssistant: () => _goTo(2),
        onOpenBenefits: () => _goTo(1),
      ),
      BenefitsScreen(onBack: () => _goTo(0)),
      const VoiceAssistantScreen(),
      ChatbotScreen(onBack: () => _goTo(0)),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: AppBottomNav(currentIndex: _index, onTap: _goTo),
    );
  }
}
