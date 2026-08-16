import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenVoiceAssistant,
    required this.onOpenBenefits,
    required this.onOpenDocumentScanner,
    required this.onViewAllBenefits,
  });

  final VoidCallback onOpenVoiceAssistant;
  final VoidCallback onOpenBenefits;
  final VoidCallback onOpenDocumentScanner;
  final VoidCallback onViewAllBenefits;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GreetingHeader(
                userName: 'Maria',
                subtitle: 'Kuyogan tika karong adlawa.',
                avatarUrl: 'https://placehold.co/52x52',
              ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Available Benefits',
                onViewAll: onViewAllBenefits,
              ),
              const SizedBox(height: 14),
              const _BenefitCard(
                title: 'Pension Payout / Pensyon',
                dateAndLocation: 'March 15, City Hall',
                icon: Icons.payments_outlined,
              ),
              const SizedBox(height: 12),
              const _BenefitCard(
                title: 'Robinsons Place Free...',
                dateAndLocation: 'March 18, Robinsons Place Du...',
                icon: Icons.local_hospital_outlined,
              ),
              const SizedBox(height: 28),
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
                      onTap: onOpenVoiceAssistant,
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
                      onTap: onOpenBenefits,
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
  });

  final String userName;
  final String subtitle;
  final String avatarUrl;

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
          height: 165,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: accentColor,
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
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

class _WideActionBanner extends StatelessWidget {
  const _WideActionBanner({
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
          width: double.infinity,
          height: 140,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: accentColor,
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Rubik',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textColor.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Rubik',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: textColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}