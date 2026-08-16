import 'dart:convert';
import 'package:flutter/services.dart';
import 'benefit.dart';

class BenefitService {
  static List<Benefit>? _cachedBenefits;

  static Future<List<Benefit>> loadBenefits() async {
    if (_cachedBenefits != null) return _cachedBenefits!;

    try {
      final String response =
          await rootBundle.loadString('assets/data/benefits.json');
      final List<dynamic> data = json.decode(response) as List<dynamic>;

      _cachedBenefits = data
          .map((item) => Benefit.fromJson(item as Map<String, dynamic>))
          .toList();

      return _cachedBenefits!;
    } catch (_) {
      // Fallback mock data if assets/data/benefits.json is missing
      _cachedBenefits = const [
        Benefit(
          id: 'pension',
          title: 'Monthly Social Pension',
          dateAndLocation: 'Claim by end of month • Local Barangay Hall',
          iconKey: 'pension',
          category: 'Financial',
          description: 'Regular financial support for eligible senior citizens.',
        ),
        Benefit(
          id: 'health_check',
          title: 'Free Annual Health Checkup',
          dateAndLocation: 'Valid until Dec 2026 • City Health Office',
          iconKey: 'medical',
          category: 'Health',
          description: 'Comprehensive annual medical checkup and routine blood tests.',
        ),
        Benefit(
          id: 'groceries',
          title: '5% Grocery Discount',
          dateAndLocation: 'Always Active • Participating Supermarkets',
          iconKey: 'food',
          category: 'Discounts',
          description: 'Mandatory OSCA 5% discount on basic necessities and prime commodities.',
        ),
      ];
      return _cachedBenefits!;
    }
  }
}