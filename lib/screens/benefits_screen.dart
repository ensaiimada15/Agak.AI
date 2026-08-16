import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Benefit {
  const Benefit({
    required this.id,
    required this.title,
    required this.date,
    required this.location,
    required this.iconKey,
    required this.category,
    required this.description,
  });

  final String id;
  final String title;
  final String date;
  final String location;
  final String iconKey;
  final String category;
  final String description;

  IconData get iconData {
    switch (iconKey.toLowerCase()) {
      case 'pension':
      case 'cash':
      case 'money':
        return Icons.payments_rounded;
      case 'medical':
      case 'hospital':
      case 'health':
        return Icons.health_and_safety_rounded;
      case 'food':
      case 'grocery':
        return Icons.local_dining_rounded;
      case 'transport':
      case 'bus':
      case 'fare':
        return Icons.directions_bus_filled_rounded;
      default:
        return Icons.card_membership_rounded;
    }
  }

  factory Benefit.fromJson(Map<String, dynamic> json) {
    // Gracefully handle combined 'dateAndLocation' or separate 'date' and 'location'
    final rawDate = json['date'] as String? ?? '';
    final rawLocation = json['location'] as String? ?? '';
    final combined = json['dateAndLocation'] as String? ?? '';

    String parsedDate = rawDate;
    String parsedLocation = rawLocation;

    if (combined.isNotEmpty && parsedDate.isEmpty && parsedLocation.isEmpty) {
      final parts = combined.split('•');
      parsedDate = parts.isNotEmpty ? parts[0].trim() : combined;
      parsedLocation = parts.length > 1 ? parts[1].trim() : '';
    }

    return Benefit(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      date: parsedDate,
      location: parsedLocation,
      iconKey: json['iconKey'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      description: json['description'] as String? ?? '',
    );
  }
}

class BenefitsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const BenefitsScreen({super.key, this.onBack});

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen> {
  late Future<List<Benefit>> _benefitsFuture;

  @override
  void initState() {
    super.initState();
    _benefitsFuture = _loadBenefitsJson();
  }

  Future<List<Benefit>> _loadBenefitsJson() async {
    final String response =
        await rootBundle.loadString('assets/data/benefits.json');
    final List<dynamic> data = json.decode(response) as List<dynamic>;
    return data
        .map((item) => Benefit.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                    onPressed: widget.onBack ?? () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'My Benefits',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Akong mga Benepisyo ug Pribilehiyo',
                          style: TextStyle(
                            color: Color(0xFF093582),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Benefit>>(
        future: _benefitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading benefits list: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final benefits = snapshot.data ?? [];

          if (benefits.isEmpty) {
            return const Center(child: Text('No benefits found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: benefits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return BenefitCard(benefit: benefits[index]);
            },
          );
        },
      ),
    );
  }
}

class BenefitCard extends StatelessWidget {
  final Benefit benefit;

  const BenefitCard({super.key, required this.benefit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Accent Indicator + Title + Category Icon Container
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        margin: const EdgeInsets.only(top: 2, right: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF093582),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          benefit.title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    benefit.iconData,
                    color: const Color(0xFF093582),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // Details Block
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (benefit.date.isNotEmpty)
                  _MetaRow(
                    icon: Icons.calendar_today_rounded,
                    label: benefit.date,
                  ),
                if (benefit.location.isNotEmpty) ...[
                  if (benefit.date.isNotEmpty) const SizedBox(height: 8),
                  _MetaRow(
                    icon: Icons.location_on_rounded,
                    label: benefit.location,
                  ),
                ],
                if (benefit.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        left: BorderSide(
                          color: Color(0xFFCBD5E1),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      benefit.description,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF093582),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {},
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'How To Claim',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
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

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF64748B),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}