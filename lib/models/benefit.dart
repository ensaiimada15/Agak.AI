import 'package:flutter/material.dart';

class Benefit {
  final String title;
  final String date;
  final String location;
  final String iconKey;

  const Benefit({
    required this.title,
    required this.date,
    required this.location,
    required this.iconKey,
  });

  String get dateAndLocation => '$date, $location';

  factory Benefit.fromJson(Map<String, dynamic> json) {
    return Benefit(
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      location: json['location'] ?? '',
      iconKey: json['iconKey'] ?? 'default',
    );
  }

  // Predefined icon registry (10+ common types)
  IconData get iconData {
    switch (iconKey) {
      case 'pension':
      case 'payment':
        return Icons.payments_outlined;
      case 'health':
      case 'hospital':
        return Icons.local_hospital_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'transport':
        return Icons.directions_bus_outlined;
      case 'housing':
        return Icons.home_work_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'shield':
      case 'insurance':
        return Icons.verified_user_outlined;
      case 'work':
        return Icons.work_outline;
      default:
        return Icons.card_giftcard_outlined;
    }
  }
}