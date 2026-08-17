import 'dart:async';

import 'package:flutter/material.dart';
import '../models/benefit.dart';
import '../models/benefit_service.dart';
import '../models/profile_service.dart';

class BenefitsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  /// Benefit id to scroll to + briefly highlight (set when the user taps a
  /// benefit card on the home tab).
  final String? highlightBenefitId;

  const BenefitsScreen({super.key, this.onBack, this.highlightBenefitId});

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen> {
  late Future<List<Benefit>> _benefitsFuture;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  String? _highlightedId;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    // Only benefits that are relevant to THIS senior's location.
    _benefitsFuture = ProfileService.loadProfile()
        .then((p) => BenefitService.loadRelevantBenefits(p.address))
        .catchError((_) => BenefitService.loadBenefits());
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls the tapped benefit into view and flashes its border.
  void _scrollToHighlight(List<Benefit> benefits) {
    final id = widget.highlightBenefitId;
    if (id == null || _highlightedId != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[id];
      if (key?.currentContext == null) return;
      setState(() => _highlightedId = id);
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _highlightedId = null);
      });
    });
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
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Color(0xFF0F172A)),
                    onPressed:
                        widget.onBack ?? () => Navigator.maybePop(context),
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

          _scrollToHighlight(benefits);

          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: benefits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final benefit = benefits[index];
              final key = _itemKeys.putIfAbsent(benefit.id, () => GlobalKey());
              return Container(
                key: key,
                child: BenefitCard(
                  benefit: benefit,
                  highlighted: benefit.id == _highlightedId,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class BenefitCard extends StatelessWidget {
  final Benefit benefit;

  /// True while this card is being pointed out after a home-tab tap.
  final bool highlighted;

  const BenefitCard(
      {super.key, required this.benefit, this.highlighted = false});

  /// benefit.dart stores date + location as a single combined
  /// `dateAndLocation` string (e.g. "Jan 15, 2026 • City Hall").
  /// Split it back apart here so the two-row layout below is unchanged.
  List<String> get _dateAndLocationParts {
    return benefit.dateAndLocation
        .split('•')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final parts = _dateAndLocationParts;
    final date = parts.isNotEmpty ? parts[0] : '';
    final location = parts.length > 1 ? parts[1] : '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              highlighted ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
          width: highlighted ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                highlighted ? const Color(0x333B82F6) : const Color(0x0A0F172A),
            blurRadius: highlighted ? 12 : 12,
            offset: const Offset(0, 4),
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
                if (date.isNotEmpty)
                  _MetaRow(
                    icon: Icons.calendar_today_rounded,
                    label: date,
                  ),
                if (location.isNotEmpty) ...[
                  if (date.isNotEmpty) const SizedBox(height: 8),
                  _MetaRow(
                    icon: Icons.location_on_rounded,
                    label: location,
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
