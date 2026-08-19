import 'package:flutter_dotenv/flutter_dotenv.dart';
/// Runtime config for the AgakAI backend.
///
/// Mirrors the repo-root .env file. Only the public ANON key belongs here —
/// NEVER put the service_role key in client code.
class AppConfig {
  static final String? supabaseUrl = dotenv.env['SUPABASE_URL'];
  static final String? supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
}
