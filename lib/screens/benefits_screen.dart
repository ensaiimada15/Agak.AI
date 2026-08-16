import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';

class BenefitEntry {
  const BenefitEntry({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.status,
    required this.statusBg,
    required this.statusColor,
    required this.description,
    required this.buttonLabel,
    required this.buttonColor,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final String status;
  final Color statusBg;
  final Color statusColor;
  final String description;
  final String buttonLabel;
  final Color buttonColor;
}

const _benefits = [
  BenefitEntry(
    icon: Icons.account_balance_wallet_outlined,
    iconBg: AppColors.claimGreenBg,
    title: 'Social Pension from LGU',
    status: 'CLAIM NOW / KUHAA NA',
    statusBg: AppColors.claimGreenBg,
    statusColor: AppColors.claimGreen,
    description: 'P1,000 Monthly Cash assistance for senior residents.',
    buttonLabel: 'Claim Pension (Pindota)',
    buttonColor: AppColors.claimGreen,
  ),
  BenefitEntry(
    icon: Icons.local_hospital_outlined,
    iconBg: AppColors.forestSoft,
    title: 'Priority Healthcare Access',
    status: 'Next schedule: Friday, 8am',
    statusBg: AppColors.forestSoft,
    statusColor: AppColors.forest,
    description: 'Free Vaccines & Checkups at Dumaguete Health Office.',
    buttonLabel: 'View Schedule (Tan-awa)',
    buttonColor: AppColors.forest,
  ),
  BenefitEntry(
    icon: Icons.confirmation_number_outlined,
    iconBg: AppColors.orangeBg2,
    title: 'Free Robinsons Movie Ticket',
    status: 'Claim at Robinsons Place',
    statusBg: AppColors.orangeBg2,
    statusColor: AppColors.orange,
    description: 'Free cinema access on Monday and Tuesday mornings.',
    buttonLabel: 'How to Claim (Unsaon)',
    buttonColor: AppColors.orange,
  ),
];

class BenefitsScreen extends StatelessWidget {
  const BenefitsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forestBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ForestScreenHeader(
              title: 'My Benefits',
              subtitle: 'Akong mga Benepisyo ug Pribilehiyo',
              onBack: onBack,
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _benefits.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, i) => _BenefitCard(entry: _benefits[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.entry});

  final BenefitEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.forestBorder, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x140B4D3A), blurRadius: 4, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: entry.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, color: entry.statusColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.forestDark)),
                    const SizedBox(height: 2),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: entry.statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(entry.status,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: entry.statusColor)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(entry.description,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.forestBody, height: 1.4)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: entry.buttonColor,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(entry.buttonLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
