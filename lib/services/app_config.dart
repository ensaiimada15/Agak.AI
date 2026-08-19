import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static final String? supabaseUrl = dotenv.env['SUPABASE_URL'];
  static final String? supabasePublishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'];
}
