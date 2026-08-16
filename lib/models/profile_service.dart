import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'profile.dart';

class ProfileService {
  static Profile? _cachedProfile;

  static Future<Profile> loadProfile() async {
    if (_cachedProfile != null) {
      return _cachedProfile!;
    }

    try {
      final response = await rootBundle.loadString(
        'assets/data/profile.json',
      );

      debugPrint('PROFILE JSON LOADED: $response');

      final data = json.decode(response) as Map<String, dynamic>;

      _cachedProfile = Profile.fromJson(data);

      debugPrint('PROFILE PARSED: ${_cachedProfile!.name}');

      return _cachedProfile!;
    } catch (e, stackTrace) {
      debugPrint('==============================');
      debugPrint('PROFILE LOAD ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('==============================');
      rethrow;
    }
  }
}