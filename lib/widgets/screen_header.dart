import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The white header bar with a back chevron, title + subtitle, and an
/// optional trailing action (help button or language badge) used across
/// the Voice Assistant / Ask Anything screens.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onBack ?? () => Navigator.maybePop(context),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.arrow_back_rounded, size: 24, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.headline(size: 26)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, color: AppColors.navy),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// The green-forest header variant used on My Benefits / Chatbot.
class ForestScreenHeader extends StatelessWidget {
  const ForestScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.forestBorder, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onBack ?? () => Navigator.maybePop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.forestSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.forest, width: 2),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.forest),
                      SizedBox(width: 4),
                      Text('Balik',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.forest)),
                    ],
                  ),
                ),
              ),
              const LangBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Text(title,
              style: AppTheme.headline(size: 26, color: AppColors.forest)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 15, color: AppColors.forestBody)),
        ],
      ),
    );
  }
}

class LangBadge extends StatelessWidget {
  const LangBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.forestBorder, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('🇵🇭 Bisaya / Eng',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
