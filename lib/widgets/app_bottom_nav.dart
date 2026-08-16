import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.activeBg = const Color(0xFFD2ECFF),
    this.activeColor = const Color(0xFF093582),
    this.inactiveColor = const Color(0xFF093582),
    this.topBorder = const Color(0xFFD2E2FF),
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
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: topBorder, width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, left: 12, right: 12, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final selected = i == currentIndex;
              final label = tab.labelBottom == null
                  ? tab.labelTop
                  : '${tab.labelTop} / ${tab.labelBottom}';

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onTap(i),
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: selected ? activeBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? activeColor : inactiveColor,
                              fontSize: 11,
                              fontFamily: 'Rubik',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}