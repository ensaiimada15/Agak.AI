import 'dart:convert';
import 'package:flutter/services.dart';
import 'profile.dart';

class ProfileService {
  static Profile? _cachedProfile;

  static Future<Profile> loadProfile() async {
    if (_cachedProfile != null) return _cachedProfile!;

    try {
      final String response =
          await rootBundle.loadString('assets/data/profile.json');
      final Map<String, dynamic> data =
          json.decode(response) as Map<String, dynamic>;
      _cachedProfile = Profile.fromJson(data);
      return _cachedProfile!;
    } catch (_) {
      _cachedProfile = const Profile(
        name: 'Juan Dela Cruz',
        email: 'juan.delacruz@example.com',
        seniorId: 'OSCA-2024-8921',
        mobileNo: '+63 912 345 6789',
        age: 68,
        birthday: 'October 12, 1957',
        address: 'Brgy. Luz, Cebu City',
      );
      return _cachedProfile!;
    }
  }
}