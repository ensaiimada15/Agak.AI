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

  /// Parses either shape of JSON:
  /// - Local asset shape: { id, title, dateAndLocation | date + location, iconKey, category, description }
  /// - Supabase row shape: { id, title, date, lgu, iconkey, description, simplified_description, eligibility }
  factory Benefit.fromJson(Map<String, dynamic> json) {
    // --- date ---
    // Local asset may send a pre-formatted date string.
    // Supabase sends an ISO date string (e.g. "2026-01-15") from a `date` column.
    final rawDate = json['date'] as String? ?? '';
    final date = _formatDate(rawDate);

    // --- location ---
    // Local asset uses 'location'; Supabase uses 'lgu' (local government unit).
    final location = (json['location'] as String?) ??
        (json['lgu'] as String?) ??
        '';

    // --- combined date/location display string ---
    String combinedDateLoc = json['dateAndLocation'] as String? ?? '';
    if (combinedDateLoc.isEmpty && (date.isNotEmpty || location.isNotEmpty)) {
      combinedDateLoc = [date, location].where((e) => e.isNotEmpty).join(' • ');
    }

    // --- icon key ---
    // Local asset uses 'iconKey'; Supabase column is lowercase 'iconkey'.
    final iconKey = (json['iconKey'] as String?) ??
        (json['iconkey'] as String?) ??
        '';

    // --- description ---
    // Fall back to Supabase's 'simplified_description' if 'description' is missing.
    final description = (json['description'] as String?) ??
        (json['simplified_description'] as String?) ??
        '';

    return Benefit(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      dateAndLocation: combinedDateLoc,
      iconKey: iconKey,
      category: json['category'] as String? ?? 'General',
      description: description,
    );
  }

  /// Converts an ISO date string ("2026-01-15") into a friendlier
  /// display format ("Jan 15, 2026"). Leaves non-ISO or empty strings as-is,
  /// so pre-formatted local asset dates pass through untouched.
  static String _formatDate(String raw) {
    if (raw.isEmpty) return raw;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }
}