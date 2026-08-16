import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Centers the app's mobile-first UI as a floating card on wide (desktop
/// browser) viewports so it doesn't stretch edge-to-edge. On narrow
/// (phone-sized) viewports it renders the child untouched.
class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({super.key, required this.child});

  final Widget child;

  static const double maxContentWidth = 430;
  static const double wideBreakpoint = 700;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < wideBreakpoint) return child;

        const verticalMargin = 32.0;
        final frameHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight - verticalMargin * 2
            : 800.0;

        return ColoredBox(
          color: AppColors.webBackdrop,
          child: Center(
            child: SizedBox(
              width: maxContentWidth,
              height: frameHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 48,
                        offset: const Offset(0, 24),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
