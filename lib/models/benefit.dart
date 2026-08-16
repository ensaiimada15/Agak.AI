import 'package:flutter/material.dart'; // REQUIRED for IconData and Icons

class Benefit {
  const Benefit({
    required this.id,
    required this.title,
    required this.dateAndLocation,
    required this.iconKey,
    required this.category,
    required this.description,
  });

  final String id;
  final String title;
  final String dateAndLocation;
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
    final date = json['date'] as String? ?? '';
    final location = json['location'] as String? ?? '';

    String combinedDateLoc = json['dateAndLocation'] as String? ?? '';
    if (combinedDateLoc.isEmpty && (date.isNotEmpty || location.isNotEmpty)) {
      combinedDateLoc = [date, location].where((e) => e.isNotEmpty).join(' • ');
    }

    return Benefit(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      dateAndLocation: combinedDateLoc,
      iconKey: json['iconKey'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      description: json['description'] as String? ?? '',
    );
  }
}