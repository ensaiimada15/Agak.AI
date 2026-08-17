import 'package:flutter/material.dart';

// Package imports avoid relative path errors:
import 'package:agakai/models/benefit.dart';
import 'package:agakai/services/benefit_notifier.dart';
import 'package:agakai/theme/app_colors.dart';
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

  /// Listens for new benefit rows and pops a "we think you might like this"
  /// notification (relevant benefits only, computed from the senior's
  /// address).
  final BenefitNotifier _notifier = BenefitNotifier();
  bool _benefitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _notifier.onNewBenefit = _showNewBenefitNotification;
    _notifier.start();
  }

  @override
  void dispose() {
    _notifier.onNewBenefit = null;
    _notifier.stop();
    super.dispose();
  }

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

  void _showNewBenefitNotification(Benefit benefit, bool relevant) {
    if (!mounted || _benefitDialogOpen) return;
    _benefitDialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                relevant
                    ? Icons.celebration_outlined
                    : Icons.new_releases_outlined,
                color: relevant ? AppColors.claimGreen : AppColors.navy,
                size: 26,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'New benefit available',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                relevant
                    ? 'We think you might like this!'
                    : 'A new benefit is now available.',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.midBlue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                benefit.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  height: 1.3,
                ),
              ),
              if (benefit.description.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  benefit.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.slateText,
                    height: 1.45,
                  ),
                ),
              ],
              if (benefit.lgu.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        color: AppColors.slateText, size: 15),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        benefit.lgu,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.slateText),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _benefitDialogOpen = false;
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.slateText),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _benefitDialogOpen = false;
                _goTo(1); // open the My Benefits tab
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
              ),
              child: const Text('View benefits'),
            ),
          ],
        );
      },
    ).whenComplete(() => _benefitDialogOpen = false);
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
