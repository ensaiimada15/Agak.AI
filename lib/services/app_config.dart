import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central configuration loaded once from the `.env` file.
///
/// This is the ONLY file that may import `flutter_dotenv`. Everything else
/// should read values through [AppConfig] instead of touching dotenv
/// directly, so the env wiring lives in a single place.
class AppConfig {
  static bool _loaded = false;

  static String? get supabaseUrl => dotenv.env['SUPABASE_URL'];
  static String? get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'];

  /// Loads the `.env` file (once). Call at startup, before reading any
  /// value. Safe to call multiple times.
  static Future<void> load() async {
    if (_loaded) return;
    await dotenv.load(fileName: '.env');
    _loaded = true;
  }
}
