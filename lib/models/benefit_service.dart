import 'dart:convert';
import 'package:http/http.dart' as http;
import 'benefit.dart';

/// Retrieval service for the `benefit` table in Supabase,
/// using plain HTTP calls to Supabase's auto-generated REST API (PostgREST)
/// instead of the supabase_flutter package.
class BenefitService {
  // TODO: replace with your project's values.
  // Found in Supabase dashboard: Project Settings > API.
  static const String _baseUrl = "https://nkstwuyayvzncisjaghg.supabase.co";
  static const String _apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5rc3R3dXlheXZ6bmNpc2phZ2hnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3ODM0ODAsImV4cCI6MjEwMjM1OTQ4MH0.oB24PuOLB4c67sFidiS0b9K1tWYPPkMOPOPbdXJNhO0';
  static const String _table = 'benefit';

  static List<Benefit>? _cachedBenefits;

  /// Fetches all benefits.
  /// Set [forceRefresh] to true to bypass the in-memory cache.
  static Future<List<Benefit>> loadBenefits({bool forceRefresh = false}) async {
    if (_cachedBenefits != null && !forceRefresh) return _cachedBenefits!;

    final uri = Uri.parse(
      'https://nkstwuyayvzncisjaghg.supabase.co/rest/v1/benefit?select=*&order=date.asc',
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'apikey': _apiKey,
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load benefits: ${response.statusCode} ${response.body}',
        );
      }

      final List<dynamic> data = json.decode(response.body) as List<dynamic>;

      _cachedBenefits = data
          .map((item) => Benefit.fromJson(item as Map<String, dynamic>))
          .toList();

      return _cachedBenefits!;
    } catch (e) {
      throw Exception('Failed to load benefits: $e');
    }
  }
}