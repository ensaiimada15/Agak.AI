import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _Category {
  const _Category(this.label, this.icon, this.color, this.bg);
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
}

const _categories = [
  _Category('Repair', Icons.handyman_outlined, AppColors.orange, AppColors.orangeBg),
  _Category('Cleaning', Icons.cleaning_services_outlined, AppColors.dashboardGreen,
      AppColors.dashboardAccentBg),
  _Category('Caregiving', Icons.favorite_outline, AppColors.navy, AppColors.skyBlueBg),
  _Category('Delivery', Icons.local_shipping_outlined, AppColors.brightBlue,
      AppColors.paleBlueBg),
  _Category('Gardening', Icons.grass_outlined, AppColors.forest, AppColors.forestSoft),
  _Category('Tutoring', Icons.school_outlined, AppColors.claimGreen, AppColors.claimGreenBg),
];

class _Job {
  const _Job(this.title, this.category, this.price, this.location, this.rating,
      this.reviews, this.icon, this.color, this.bg, {this.recommended = false});
  final String title;
  final String category;
  final String price;
  final String location;
  final double rating;
  final int reviews;
  final IconData icon;
  final Color color;
  final Color bg;
  final bool recommended;
}

const _jobs = [
  _Job('House Cleaning Helper', 'Cleaning', '₱350 - ₱500 / visit', 'Rovira Road, Dumaguete',
      4.8, 23, Icons.cleaning_services_outlined, AppColors.dashboardGreen,
      AppColors.dashboardAccentBg,
      recommended: true),
  _Job('Elderly Companion Care', 'Caregiving', '₱400 / day', 'Piapi, Dumaguete', 4.9, 41,
      Icons.favorite_outline, AppColors.navy, AppColors.skyBlueBg),
  _Job('Garden Maintenance', 'Gardening', '₱250 - ₱450 / visit', 'Bantayan, Dumaguete', 4.6,
      15, Icons.grass_outlined, AppColors.forest, AppColors.forestSoft),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenVoiceAssistant,
    required this.onOpenBenefits,
  });

  final VoidCallback onOpenVoiceAssistant;
  final VoidCallback onOpenBenefits;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DashboardHeader(onSearchTap: onOpenVoiceAssistant, onExplore: onOpenBenefits),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(title: 'Service Categories'),
                  const SizedBox(height: 16),
                  const _ServiceCategoriesGrid(),
                  const SizedBox(height: 28),
                  const _SectionHeader(title: 'Jobs Near You'),
                  const SizedBox(height: 16),
                  for (final job in _jobs) ...[
                    _JobCard(job: job),
                    if (job != _jobs.last) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onSearchTap, required this.onExplore});

  final VoidCallback onSearchTap;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.dashboardGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(9),
          bottomRight: Radius.circular(9),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 4)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Location',
                            style: TextStyle(color: Colors.white, fontSize: 13)),
                        SizedBox(height: 2),
                        Text('Dumaguete City',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline)),
                      ],
                    ),
                  ),
                  Container(
                    width: 39,
                    height: 39,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white24,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/images/avatar.png', fit: BoxFit.cover),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onSearchTap,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.fieldBg),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: AppColors.slateText),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('AI Search...',
                            style: TextStyle(color: AppColors.ink, fontSize: 13)),
                      ),
                      const Icon(Icons.auto_awesome, size: 20, color: AppColors.dashboardGreen),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Check out the latest job opportunities!',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: onExplore,
                          child: Container(
                            height: 40,
                            width: 107,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Explore',
                                style: TextStyle(
                                    color: AppColors.dashboardGreen,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Image.asset('assets/images/dashboard_hero.png', height: 100),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink)),
        const Text('View All>',
            style: TextStyle(fontSize: 14, color: AppColors.dashboardAccent)),
      ],
    );
  }
}

class _ServiceCategoriesGrid extends StatelessWidget {
  const _ServiceCategoriesGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 94 / 78,
      children: [
        for (final category in _categories)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDEDED)),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: category.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(category.icon, size: 18, color: category.color),
                ),
                const SizedBox(height: 8),
                Text(category.label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink)),
              ],
            ),
          ),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final _Job job;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: job.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(job.icon, size: 32, color: job.color),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(job.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink)),
              ),
              Row(
                children: [
                  Text(job.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13, color: AppColors.ink)),
                  const SizedBox(width: 2),
                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('(${job.reviews})',
                      style: const TextStyle(fontSize: 13, color: AppColors.slateText)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(job.price,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.dashboardGreen)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.slateText),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(job.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.slateText)),
                    ),
                  ],
                ),
              ),
              if (job.recommended)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.dashboardAccentBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('AI Recommend!',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dashboardAccent)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
