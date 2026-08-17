import 'package:flutter/material.dart';

import '../settings/app_settings.dart'; // Navigates up from lib/screens to lib/
import '../main.dart'; // Navigates up from lib/screens to lib/ to get AppSettingsScope
import '../models/benefit.dart';
import '../models/benefit_service.dart';
import '../models/profile.dart';
import '../models/profile_service.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenVoiceAssistant,
    required this.onOpenBenefits,
    required this.onViewAllBenefits,
    required this.onOpenBenefit,
    this.onMenuTap,
  });

  final VoidCallback onOpenVoiceAssistant;
  final VoidCallback onOpenBenefits;
  final VoidCallback onViewAllBenefits;

  /// Tap a benefit card → jump to that benefit on the Benefits tab.
  final void Function(Benefit benefit) onOpenBenefit;
  final VoidCallback? onMenuTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<Benefit>> _benefitsFuture;
  late final Future<Profile> _profileFuture;

  bool _isMenuExpanded = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = ProfileService.loadProfile();
    _benefitsFuture = _profileFuture
        .then((p) => BenefitService.loadRelevantBenefits(p.address))
        .catchError((_) => BenefitService.loadBenefits());
  }

  void _showAppModal({
    required String title,
    required Widget content,
    required String confirmText,
    required VoidCallback onConfirm,
  }) {
    final settings = AppSettingsScope.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF11221D),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'LINE Seed Sans',
                    ),
                  ),
                  const SizedBox(height: 16),
                  content,
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFCBD5E1),
                                width: 2,
                              ),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            child: Text(
                              settings.t('cancel'),
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 14,
                                fontFamily: 'Rubik',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              onConfirm();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF093582),
                              elevation: 0,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            child: Text(
                              confirmText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'Rubik',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openProfileModal() {
    final settings = AppSettingsScope.of(context);

    _showAppModal(
      title: settings.t('profile_details'),
      content: FutureBuilder<Profile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Text(
              '${settings.t('failed_to_load_profile')}: ${snapshot.error}',
              style: const TextStyle(
                  color: Colors.red, fontSize: 13, fontFamily: 'Rubik'),
            );
          }

          if (!snapshot.hasData) {
            return Text(settings.t('no_profile_data'),
                style: const TextStyle(fontFamily: 'Rubik'));
          }

          final profile = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileDetailRow(
                    label: settings.t('name'), value: profile.name),
                _ProfileDetailRow(
                    label: settings.t('senior_id'), value: profile.seniorId),
                _ProfileDetailRow(
                    label: settings.t('mobile_no'), value: profile.mobileNo),
                _ProfileDetailRow(
                  label: settings.t('age'),
                  value: settings.t('age_years', {'age': '${profile.age}'}),
                ),
                _ProfileDetailRow(label: 'Gender', value: profile.gender),
                _ProfileDetailRow(
                    label: settings.t('birthday'), value: profile.birthday),
                _ProfileDetailRow(
                    label: settings.t('address'),
                    value: profile.address,
                    isLast: true),
              ],
            ),
          );
        },
      ),
      confirmText: settings.t('close'),
      onConfirm: () {},
    );
  }

  void _openLogoutModal() {
    final settings = AppSettingsScope.of(context);

    _showAppModal(
      title: settings.t('log_out'),
      content: Text(
        settings.t('are_you_sure_logout'),
        style: const TextStyle(
            color: Color(0xFF334D47), fontSize: 14, fontFamily: 'Rubik'),
      ),
      confirmText: settings.t('log_out'),
      onConfirm: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: EdgeInsets.zero,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    FutureBuilder<Profile>(
                      future: _profileFuture,
                      builder: (context, snapshot) {
                        final displayName = snapshot.hasData
                            ? snapshot.data!.firstName
                            : 'Lola';

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: _GreetingHeader(
                            greetingPrefix: settings.t('greeting_prefix'),
                            userName: displayName,
                            subtitle: settings.t('greeting_subtitle'),
                            isMenuExpanded: _isMenuExpanded,
                            onMenuTap: () {
                              if (widget.onMenuTap != null) {
                                widget.onMenuTap!();
                              } else {
                                setState(() {
                                  _isMenuExpanded = !_isMenuExpanded;
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                    if (_isMenuExpanded) ...[
                      const Divider(
                          color: Color(0xFFE2E8F0), height: 1, thickness: 1),
                      _CascadingMenuRow(
                        icon: Icons.person_outline,
                        title: settings.t('profile'),
                        subtitle: settings.t('view_details'),
                        onTap: _openProfileModal,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom:
                                BorderSide(color: Color(0xFFF1F5F9), width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.language_outlined,
                                    color: Color(0xFF093582), size: 22),
                                const SizedBox(width: 14),
                                Text(
                                  settings.t('language'),
                                  style: const TextStyle(
                                    color: Color(0xFF11221D),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Rubik',
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 32,
                              // Flexible + FittedBox: the three language
                              // buttons scale down to fit even when the
                              // enlarged text setting is on (no overflow).
                              child: Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: ToggleButtons(
                                    isSelected: AppLanguage.values
                                        .map(
                                            (lang) => settings.language == lang)
                                        .toList(),
                                    onPressed: (int index) {
                                      settings.setLanguage(
                                          AppLanguage.values[index]);
                                    },
                                    fillColor: const Color(0xFF093582),
                                    selectedColor: Colors.white,
                                    color: const Color(0xFF11221D),
                                    borderRadius: BorderRadius.zero,
                                    constraints: const BoxConstraints(
                                      minHeight: 32,
                                      minWidth: 0,
                                    ),
                                    children: AppLanguage.values.map((lang) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Text(
                                          lang.nativeLabel,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'Rubik',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom:
                                BorderSide(color: Color(0xFFF1F5F9), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.text_fields,
                                color: Color(0xFF093582), size: 22),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    settings.t('text_size'),
                                    style: const TextStyle(
                                      color: Color(0xFF11221D),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Rubik',
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 32,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: ToggleButtons(
                                        isSelected: [
                                          !settings.largeText,
                                          settings.largeText,
                                        ],
                                        onPressed: (int index) =>
                                            settings.setLargeText(index == 1),
                                        fillColor: const Color(0xFF093582),
                                        selectedColor: Colors.white,
                                        color: const Color(0xFF11221D),
                                        borderRadius: BorderRadius.circular(8),
                                        constraints: const BoxConstraints(
                                          minHeight: 32,
                                          minWidth: 0,
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text(
                                              settings.t('text_size_standard'),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontFamily: 'Rubik',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text(
                                              settings.t('text_size_enlarged'),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontFamily: 'Rubik',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CascadingMenuRow(
                        icon: Icons.logout,
                        title: settings.t('log_out'),
                        subtitle: settings.t('sign_out'),
                        isDestructive: true,
                        onTap: _openLogoutModal,
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: settings.t('available_benefits'),
                      viewAllLabel: settings.t('view_all'),
                      onViewAll: widget.onViewAllBenefits,
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<List<Benefit>>(
                      future: _benefitsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              '${settings.t('error_loading_benefits')}: ${snapshot.error}',
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text(settings.t('no_benefits'));
                        }

                        final displayedBenefits =
                            snapshot.data!.take(3).toList();

                        return Column(
                          children: [
                            for (int i = 0;
                                i < displayedBenefits.length;
                                i++) ...[
                              _BenefitCard(
                                title: displayedBenefits[i].title,
                                dateAndLocation:
                                    displayedBenefits[i].dateAndLocation,
                                icon: displayedBenefits[i].iconData,
                                onTap: () =>
                                    widget.onOpenBenefit(displayedBenefits[i]),
                              ),
                              if (i < displayedBenefits.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            title: settings.t('voice_assistant'),
                            subtitle: settings.t('voice_assistant_sub'),
                            icon: Icons.mic,
                            bgColor: const Color(0xFFD2ECFF),
                            accentColor: const Color(0xFF0284C7),
                            textColor: const Color(0xFF093582),
                            onTap: widget.onOpenVoiceAssistant,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ActionTile(
                            title: settings.t('my_benefits'),
                            subtitle: settings.t('my_benefits_sub'),
                            icon: Icons.card_membership,
                            bgColor: const Color(0xFFFFE7D2),
                            accentColor: const Color(0xFFD35400),
                            textColor: const Color(0xFFD35400),
                            onTap: widget.onOpenBenefits,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontFamily: 'Rubik',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF11221D),
                fontSize: 14,
                fontFamily: 'Rubik',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.greetingPrefix,
    required this.userName,
    required this.subtitle,
    required this.isMenuExpanded,
    this.onMenuTap,
  });

  final String greetingPrefix;
  final String userName;
  final String subtitle;
  final bool isMenuExpanded;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Gender-neutral 2D avatar: soft blue circle + white person
        // silhouette. No photo, no network — works offline, works for
        // any Lola or Lolo.
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF093582), Color(0xFF0284C7)],
            ),
            border: Border.fromBorderSide(BorderSide(
              color: Colors.white,
              width: 2.6,
            )),
            boxShadow: [
              BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 4,
                  offset: Offset(0, 2)),
            ],
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greetingPrefix $userName!',
                style: const TextStyle(
                  color: Color(0xFF11221D),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'LINE Seed Sans',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF334D47),
                  fontSize: 12,
                  fontFamily: 'LINE Seed Sans',
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            isMenuExpanded ? Icons.close : Icons.menu,
            color: const Color(0xFF11221D),
            size: 28,
          ),
          onPressed: onMenuTap,
        ),
      ],
    );
  }
}

class _CascadingMenuRow extends StatelessWidget {
  const _CascadingMenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final textColor = isDestructive ? Colors.red : const Color(0xFF11221D);
    final iconColor = isDestructive ? Colors.red : const Color(0xFF093582);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Rubik',
                ),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isDestructive
                    ? Colors.red.withOpacity(0.7)
                    : const Color(0xFF64748B),
                fontSize: 13,
                fontFamily: 'Rubik',
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: isDestructive
                  ? Colors.red.withOpacity(0.5)
                  : const Color(0xFF94A3B8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.viewAllLabel,
    required this.onViewAll,
  });

  final String title;
  final String viewAllLabel;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Expanded + ellipsis so long titles never overflow on narrow
        // screens or with large system fonts (senior devices).
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontFamily: 'LINE Seed Sans',
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: onViewAll,
          child: Text(
            viewAllLabel,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.dashboardAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.title,
    required this.dateAndLocation,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String dateAndLocation;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF4FB152),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Rubik',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateAndLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      fontFamily: 'Rubik',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bgColor,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color bgColor;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // min-height (not fixed) so tiles grow gracefully when the
          // system font scale is large instead of overflowing.
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: accentColor,
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Rubik',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Rubik',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
