import 'package:flutter/material.dart';

// Package imports avoid relative path errors:
import 'package:agakai/widgets/app_bottom_nav.dart';
import 'package:agakai/screens/benefits_screen.dart';
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
      // Index 0: Home / Balay
      HomeScreen(
        onOpenBenefits: () => _goTo(2),       // Updated to point to Benefits (Index 2)
        onViewAllBenefits: () => _goTo(2),     // Updated to point to Benefits (Index 2)
        onOpenVoiceAssistant: () => _goTo(1),  // Updated to point to Voice (Index 1)
      ),
      // Index 1: Voice / Tingog (Center Tab)
      const VoiceAssistantScreen(),

      // Index 2: Benefits
      BenefitsScreen(
        onBack: () => _goTo(0),
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: _selectedIndex == 1
          ? null
          : AppBottomNav(
        currentIndex: _selectedIndex,
        onTap: _goTo,
      ),
    );
  }
}