import 'package:flutter/material.dart';

// Package imports avoid relative path errors:
import 'package:agakai/models/benefit.dart';
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

  /// Benefit the user tapped on the home tab — the Benefits tab scrolls to
  /// it and highlights it briefly.
  String? _highlightBenefitId;

  void _goTo(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Open the Benefits tab and jump to the tapped benefit.
  void _openBenefit(Benefit benefit) {
    setState(() {
      _highlightBenefitId = benefit.id;
      _selectedIndex = 2; // Benefits tab
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // Index 0: Home / Balay
      HomeScreen(
        onOpenBenefits: () =>
            _goTo(2), // Updated to point to Benefits (Index 2)
        onViewAllBenefits: () =>
            _goTo(2), // Updated to point to Benefits (Index 2)
        onOpenVoiceAssistant: () =>
            _goTo(1), // Updated to point to Voice (Index 1)
        onOpenBenefit: _openBenefit,
      ),
      // Index 1: Voice / Tingog (Center Tab)
      VoiceAssistantScreen(
        onBack: () => _goTo(0),
      ),

      // Index 2: Benefits
      BenefitsScreen(
        onBack: () => _goTo(0),
        highlightBenefitId: _highlightBenefitId,
      ),
    ];

    return Scaffold(
      // Android system back: from any tab go Home; only exit the app from
      // the Home tab itself.
      body: PopScope(
        canPop: _selectedIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selectedIndex != 0) {
            _goTo(0);
          }
        },
        child: TweenAnimationBuilder<double>(
          // Calm crossfade on tab change (IndexedStack keeps all tabs
          // alive so their state is preserved; the fade just eases the
          // switch instead of hard-cutting).
          key: ValueKey(_selectedIndex),
          tween: Tween(begin: 0.35, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
        ),
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
