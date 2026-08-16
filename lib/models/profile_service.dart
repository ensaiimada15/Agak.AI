import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile.dart';

class ProfileService {
  static Profile? _cachedProfile;

  static Future<Profile> loadProfile({String? userId}) async {
    if (_cachedProfile != null) {
      return _cachedProfile!;
    }

    try {
      final supabase = Supabase.instance.client;

      // Option A: If authenticated via Supabase Auth
      final currentUserId = userId ?? supabase.auth.currentUser?.id;

      // Query the 'profiles' table (adjust table name if different)
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', currentUserId ?? '') // Match primary key or senior_id
          .single();

      _cachedProfile = Profile.fromJson(data);
      debugPrint('PROFILE PARSED FROM SUPABASE: ${_cachedProfile!.name}');

      return _cachedProfile!;
    } catch (e, stackTrace) {
      debugPrint('==============================');
      debugPrint('SUPABASE PROFILE LOAD ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('==============================');
      rethrow;
    }
  }

  /// Optional: Clear cache on user logout
  static void clearCache() {
    _cachedProfile = null;
  }
}