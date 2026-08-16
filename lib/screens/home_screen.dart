import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(title: 'Service Categories'),
                  const SizedBox(height: 14),
                  const _ServiceCategoriesGrid(),
                  const SizedBox(height: 24),
                  const _SectionHeader(title: 'Hiring'),
                  const SizedBox(height: 14),
                  const _JobCard(
                    title: 'Something',
                    price: '12\$ - 30\$',
                    location: 'Rovira Road, 912..',
                    rating: '4.5',
                    reviews: '(23 Reviews)',
                  ),
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
      childAspectRatio: 94 / 46,
      children: List.generate(
        6,
        (_) => Container(
          decoration: BoxDecoration(
            color: AppColors.placeholderGrey,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.title,
    required this.price,
    required this.location,
    required this.rating,
    required this.reviews,
  });

  final String title;
  final String price;
  final String location;
  final String rating;
  final String reviews;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 112,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.imagePlaceholderBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.image_outlined, size: 24, color: AppColors.slateText),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink)),
              Row(
                children: [
                  Text('$rating ', style: const TextStyle(fontSize: 14, color: AppColors.ink)),
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(reviews, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(location, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
              Container(
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
