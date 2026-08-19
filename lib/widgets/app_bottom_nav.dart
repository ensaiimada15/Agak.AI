import 'package:flutter/material.dart';

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

  // Make sure this index matches your PageView / IndexedStack order in the Parent Screen:
  // Index 0: Home / Balay
  // Index 1: Voice / Tingog (Center)
  // Index 2: Benefits
  static const _tabs = [
    (icon: Icons.home_rounded, labelTop: 'Home', labelBottom: 'Balay'),
    (icon: Icons.mic_rounded, labelTop: 'Voice', labelBottom: 'Tingog'),
    (icon: Icons.military_tech_rounded, labelTop: 'Benefits', labelBottom: null),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Main bottom navigation bar box
        Container(
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
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final selected = i == currentIndex;
                  final isCenterMic = i == 1;
                  final label = tab.labelBottom == null
                      ? tab.labelTop
                      : '${tab.labelTop} / ${tab.labelBottom}';

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onTap(i), // Triggers page switch for index i
                        child: SizedBox(
                          height: 64,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isCenterMic)
                              // Spacer reserves room under the floating button
                                const SizedBox(height: 38)
                              else
                                Container(
                                  height: 38,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: selected ? activeBg : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    tab.icon,
                                    size: 24,
                                    color: selected ? activeColor : inactiveColor,
                                  ),
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
                                  fontWeight: isCenterMic || selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
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
        ),

        // Floating overflow Mic button
        Positioned(
          top: -14,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onTap(1), // Voice / Tingog index
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}