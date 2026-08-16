import 'package:flutter/material.dart';

class Benefit {
  final String title;
  final String? description;
  final String? date;
  final String? location;
  final IconData iconData;

  Benefit({
    required this.title,
    this.description,
    this.date,
    this.location,
    required this.iconData,
  });

  // Combines date and location for home_screen.dart
  String get dateAndLocation {
    final formattedDate = date ?? 'Available Daily';
    final formattedLocation = location ?? 'Barangay Hall';
    return '$formattedDate • $formattedLocation';
  }

  // Parses JSON data safely
  factory Benefit.fromJson(Map<String, dynamic> json) {
    return Benefit(
      title: json['title'] as String? ?? 'Unnamed Benefit',
      description: json['description'] as String? ??
          'Cash assistance and community welfare program.',
      date: json['date'] as String? ?? 'Available Daily',
      location: json['location'] as String? ?? 'Barangay Hall',
      iconData: _getIconFromName(json['icon'] as String?),
    );
  }

  // Maps JSON string names to actual Flutter Icons
  static IconData _getIconFromName(String? iconName) {
    switch (iconName) {
      case 'medical':
        return Icons.medical_services_outlined;
      case 'cash':
        return Icons.payments_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      default:
        return Icons.card_giftcard_outlined;
    }
  }
}