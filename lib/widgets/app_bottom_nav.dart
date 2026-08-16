import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.activeBg = AppColors.skyBlueBg,
    this.activeColor = AppColors.navy,
    this.inactiveColor = AppColors.slateText,
    this.topBorder = AppColors.skyBlueBg2,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color activeBg;
  final Color activeColor;
  final Color inactiveColor;
  final Color topBorder;

  static const _tabs = [
    (icon: Icons.home_rounded, labelTop: 'Home', labelBottom: 'Balay'),
    (icon: Icons.military_tech_rounded, labelTop: 'Benefits', labelBottom: null),
    (icon: Icons.mic_rounded, labelTop: 'Voice', labelBottom: 'Tingog'),
    (icon: Icons.chat_bubble_rounded, labelTop: 'Chat', labelBottom: 'Chika'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: topBorder, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_tabs.length, (i) {
            final tab = _tabs[i];
            final selected = i == currentIndex;
            final label = tab.labelBottom == null
                ? tab.labelTop
                : '${tab.labelTop} / ${tab.labelBottom}';
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(i),
                child: Container(
                  height: 70,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected ? activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.icon,
                        size: 26,
                        color: selected ? activeColor : inactiveColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: selected ? activeColor : inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
