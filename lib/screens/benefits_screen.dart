import 'package:flutter/material.dart';
import '../models/benefit.dart';
import '../models/benefit_service.dart';
import '../models/voice_form_field.dart';
import '../theme/app_colors.dart';
import 'voice_form_screen.dart';

class BenefitsScreen extends StatefulWidget {
  const BenefitsScreen({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen> {
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
        child: Column(
          children: [
            _HeaderBar(onBack: widget.onBack),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFD2E2FF),
                            width: 2,
                          ),
                        ),
                        child: const Text(
                          '🇵🇭 Bisaya / Eng',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontFamily: 'Rubik',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Benefit>>(
                      future: _benefitsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Error loading benefits: ${snapshot.error}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('No available benefits at this time.');
                        }

                        final benefits = snapshot.data!;

                        return Column(
                          children: [
                            for (int i = 0; i < benefits.length; i++) ...[
                              _BenefitActionCard(
                                title: benefits[i].title,
                                subtitle: 'CLAIM NOW / KUHAA NA',
                                date: benefits[i].date ?? 'Available Daily',
                                location: benefits[i].location ?? 'Barangay Hall',
                                description: benefits[i].description ??
                                    'P1,000 Monthly Cash assistance for senior residents.',
                                icon: benefits[i].iconData,
                                onClaimTap: benefits[i].iconKey == 'pension'
                                    ? () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const VoiceFormScreen(
                                                form: pensionApplicationForm),
                                          ),
                                        )
                                    : () {},
                              ),
                              if (i < benefits.length - 1)
                                const SizedBox(height: 16),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF3E4D9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF0F172A),
              size: 24,
            ),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'My Benefits',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 24,
                    fontFamily: 'LINE Seed Sans',
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Akong mga Benepisyo ug Pribilehiyo',
                  style: TextStyle(
                    color: Color(0xFF093582),
                    fontSize: 13,
                    fontFamily: 'LINE Seed Sans',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitActionCard extends StatelessWidget {
  const _BenefitActionCard({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.location,
    required this.description,
    required this.icon,
    required this.onClaimTap,
  });

  final String title;
  final String subtitle;
  final String date;
  final String location;
  final String description;
  final IconData icon;
  final VoidCallback onClaimTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFD2ECFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF0284C7),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF11221D),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Rubik',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Rubik',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF334D47),
              fontSize: 14,
              fontFamily: 'Rubik',
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Date & Location Info Chips
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        date,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 13,
                          fontFamily: 'Rubik',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 13,
                          fontFamily: 'Rubik',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onClaimTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF093582),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'How To Claim',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Rubik',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}