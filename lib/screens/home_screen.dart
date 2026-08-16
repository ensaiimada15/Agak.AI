import 'package:flutter/material.dart';
import '../models/benefit.dart';
import '../models/benefit_service.dart';
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

  @override
  void initState() {
    super.initState();
    _benefitsFuture = BenefitService.loadBenefits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Profile / Greeting Header
              _GreetingHeader(
                userName: 'Maria',
                subtitle: 'Kuyogan tika karong adlawa.',
                avatarUrl: 'https://placehold.co/52x52',
                onMenuTap: widget.onMenuTap,
              ),
              const SizedBox(height: 24),

              // 2. Available Benefits Section (Placed below header)
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

              // 3. Action / Function Squares (Voice Assistant & My Benefits)
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
      ),
    );
  }
}

// =============================================================================
// SUB-WIDGET DEFINITIONS
// =============================================================================

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.userName,
    required this.subtitle,
    required this.avatarUrl,
    this.onMenuTap,
  });

  final String userName;
  final String subtitle;
  final String avatarUrl;
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
          icon: const Icon(
            Icons.menu,
            color: Color(0xFF11221D),
            size: 28,
          ),
          onPressed: onMenuTap ??
              () {
                Scaffold.of(context).openDrawer();
              },
        ),
      ],
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
            blurRadius: 8,
            offset: Offset(0, 4),
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