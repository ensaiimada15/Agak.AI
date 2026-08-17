import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile.dart';

/// Loads the logged-in senior's record from the `user` table.
///
/// Login (`LoginScreen`) queries `user` by senior_id + password and then
/// calls [setCurrentUser] so the rest of the app loads THE logged-in
/// senior — no static/Maria fallback anymore.
class ProfileService {
  static Profile? _cachedProfile;
  static int? _currentUserId;

  /// Called right after a successful login with the `user` row id.
  static void setCurrentUser(int userId) {
    _currentUserId = userId;
    _cachedProfile = null;
  }

  static bool get hasCurrentUser => _currentUserId != null;

  /// Loads the current senior's profile (cached). Throws when nobody is
  /// logged in or the row can't be found — screens handle the error.
  static Future<Profile> loadProfile() async {
    final cached = _cachedProfile;
    if (cached != null) return cached;

    final id = _currentUserId;
    if (id == null) {
      throw StateError('No user logged in');
    }

    final supabase = Supabase.instance.client;
    final data = await supabase.from('user').select().eq('id', id).single();

    _cachedProfile = Profile.fromJson(data);
    debugPrint('PROFILE PARSED FROM SUPABASE: ${_cachedProfile!.name}');
    return _cachedProfile!;
  }

  /// Non-throwing variant for optional contexts (e.g. sending the profile
  /// to the LLM for personalization) — returns null instead of failing.
  static Future<Profile?> loadProfileOrNull() async {
    try {
      return await loadProfile();
    } catch (e, st) {
      debugPrint('PROFILE LOAD (optional) FAILED: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  /// Fetches the senior's `user_notes` (the LLM's rolling psychological
  /// summary) fresh from the DB — it changes after every exchange.
  static Future<String?> loadUserNotes() async {
    final id = _currentUserId;
    if (id == null) return null;
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('user')
          .select('user_notes')
          .eq('id', id)
          .maybeSingle();
      return (data?['user_notes'] as String?)?.trim() ?? '';
    } catch (e, st) {
      debugPrint('LOAD USER NOTES FAILED: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  /// Clear cache + current user (e.g. on log out).
  static void clearCache() {
    _cachedProfile = null;
    _currentUserId = null;
  }
}
