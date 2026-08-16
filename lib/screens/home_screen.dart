import 'package:flutter/material.dart';
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
    this.onMenuTap,
  });

  final VoidCallback onOpenVoiceAssistant;
  final VoidCallback onOpenBenefits;
  final VoidCallback onViewAllBenefits;
  final VoidCallback? onMenuTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<Benefit>> _benefitsFuture;
  late final Future<Profile> _profileFuture;

  // App state variables
  bool _isMenuExpanded = false;
  bool _isDarkMode = false;
  String _selectedLanguage = 'Bisaya';

  @override
  void initState() {
    super.initState();
    _benefitsFuture = BenefitService.loadBenefits();
    _profileFuture = ProfileService.loadProfile();
  }

  // Input-stealing modal dialog helper
  void _showAppModal({
    required String title,
    required Widget content,
    required String confirmText,
    required VoidCallback onConfirm,
  }) {
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
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
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

  // Profile Modal Pop-up connected to ProfileService
  void _openProfileModal() {
    _showAppModal(
      title: 'Profile Details',
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
              'Failed to load profile: ${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 13, fontFamily: 'Rubik'),
            );
          }

          if (!snapshot.hasData) {
            return const Text('No profile data available.', style: TextStyle(fontFamily: 'Rubik'));
          }

          final profile = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileDetailRow(label: 'Name', value: profile.name),
                _ProfileDetailRow(label: 'Senior ID', value: profile.seniorId),
                _ProfileDetailRow(label: 'Mobile No.', value: profile.mobileNo),
                _ProfileDetailRow(label: 'Age', value: '${profile.age} years old'),
                _ProfileDetailRow(label: 'Birthday', value: profile.birthday),
                _ProfileDetailRow(label: 'Address', value: profile.address, isLast: true),
              ],
            ),
          );
        },
      ),
      confirmText: 'Close',
      onConfirm: () {},
    );
  }

  void _openLogoutModal() {
    _showAppModal(
      title: 'Log Out',
      content: const Text(
        'Are you sure you want to log out of your account?',
        style: TextStyle(color: Color(0xFF334D47), fontSize: 14, fontFamily: 'Rubik'),
      ),
      confirmText: 'Log Out',
      onConfirm: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Full-Width Nav-Bar Style Profile Header (Zero Outer/Inner Padding)
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
                    // Dynamic Header Bar Content using Profile Service
                    FutureBuilder<Profile>(
                      future: _profileFuture,
                      builder: (context, snapshot) {
                        final displayName = snapshot.hasData ? snapshot.data!.name.split(' ').first : 'Maria';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: _GreetingHeader(
                            userName: displayName,
                            subtitle: 'Kuyogan tika karong adlawa.',
                            avatarUrl: 'https://placehold.co/52x52',
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

                    // Inline Cascading Dropdown Bar
                    if (_isMenuExpanded) ...[
                      const Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),

                      // 1. Profile Link
                      _CascadingMenuRow(
                        icon: Icons.person_outline,
                        title: 'Profile',
                        subtitle: 'View details',
                        onTap: _openProfileModal,
                      ),

                      // 2. Direct Dark Mode Toggle Row
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.dark_mode_outlined, color: Color(0xFF093582), size: 22),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Dark Mode',
                                style: TextStyle(
                                  color: Color(0xFF11221D),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Rubik',
                                ),
                              ),
                            ),
                            Switch(
                              value: _isDarkMode,
                              activeColor: const Color(0xFF093582),
                              onChanged: (val) {
                                setState(() {
                                  _isDarkMode = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      // 3. Direct 3-Way Inline Language Toggle Row
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.language_outlined, color: Color(0xFF093582), size: 22),
                                SizedBox(width: 14),
                                Text(
                                  'Language',
                                  style: TextStyle(
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
                              child: ToggleButtons(
                                isSelected: [
                                  _selectedLanguage == 'Bisaya',
                                  _selectedLanguage == 'Tagalog',
                                  _selectedLanguage == 'English',
                                ],
                                onPressed: (int index) {
                                  setState(() {
                                    _selectedLanguage = ['Bisaya', 'Tagalog', 'English'][index];
                                  });
                                },
                                fillColor: const Color(0xFF093582),
                                selectedColor: Colors.white,
                                color: const Color(0xFF11221D),
                                borderRadius: BorderRadius.zero,
                                constraints: const BoxConstraints(
                                  minHeight: 32,
                                  minWidth: 0,
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      'Bisaya',
                                      style: TextStyle(fontSize: 12, fontFamily: 'Rubik', fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      'Tagalog',
                                      style: TextStyle(fontSize: 12, fontFamily: 'Rubik', fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      'English',
                                      style: TextStyle(fontSize: 12, fontFamily: 'Rubik', fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 4. Log Out Link
                      _CascadingMenuRow(
                        icon: Icons.logout,
                        title: 'Log Out',
                        subtitle: 'Sign out',
                        isDestructive: true,
                        onTap: _openLogoutModal,
                      ),
                    ],
                  ],
                ),
              ),

              // Rest of Screen Content with Standard Page Padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Available Benefits Section
                    _SectionHeader(
                      title: 'Available Benefits',
                      onViewAll: widget.onViewAllBenefits,
                    ),
                    const SizedBox(height: 14),

                    FutureBuilder<List<Benefit>>(
                      future: _benefitsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Error loading benefits: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('No available benefits at this time.');
                        }

                        final displayedBenefits = snapshot.data!.take(3).toList();

                        return Column(
                          children: [
                            for (int i = 0; i < displayedBenefits.length; i++) ...[
                              _BenefitCard(
                                title: displayedBenefits[i].title,
                                dateAndLocation: displayedBenefits[i].dateAndLocation,
                                icon: displayedBenefits[i].iconData,
                              ),
                              if (i < displayedBenefits.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // 3. Action / Function Squares
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            title: 'Voice Assistant',
                            subtitle: 'Tingog Tabang',
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
                            title: 'My Benefits',
                            subtitle: 'Mga Benepisyo',
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

// =============================================================================
// SUB-WIDGET DEFINITIONS
// =============================================================================

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
    required this.userName,
    required this.subtitle,
    required this.avatarUrl,
    required this.isMenuExpanded,
    this.onMenuTap,
  });

  final String userName;
  final String subtitle;
  final String avatarUrl;
  final bool isMenuExpanded;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE3EFEA),
            border: Border.all(color: const Color(0xFF093582), width: 2.6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF093582)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maayong adlaw, $userName!',
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
                color: isDestructive ? Colors.red.withOpacity(0.7) : const Color(0xFF64748B),
                fontSize: 13,
                fontFamily: 'Rubik',
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: isDestructive ? Colors.red.withOpacity(0.5) : const Color(0xFF94A3B8),
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
    required this.onViewAll,
  });

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontFamily: 'LINE Seed Sans',
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        InkWell(
          onTap: onViewAll,
          child: const Text(
            'view all >',
            style: TextStyle(
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
  });

  final String title;
  final String dateAndLocation;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          height: 150,
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