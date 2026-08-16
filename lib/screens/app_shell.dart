import 'package:flutter/material.dart';

// Package imports avoid relative path errors:
import 'package:agakai/widgets/app_bottom_nav.dart';
import 'package:agakai/screens/benefits_screen.dart';   // Updated to match your original benefits_screen.dart file
import 'package:agakai/screens/home_screen.dart';
import 'package:agakai/screens/voice_assistant_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _goTo(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // Index 0: Home
      HomeScreen(
        onOpenBenefits: () => _goTo(1),
        onViewAllBenefits: () => _goTo(1),
        onOpenVoiceAssistant: () => _goTo(2),
      ),
      // Index 1: Benefits
      BenefitsScreen(
        onBack: () => _goTo(0),
      ),
      // Index 2: Voice
      const VoiceAssistantScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _selectedIndex,
        onTap: _goTo,
      ),
    );
  }
}