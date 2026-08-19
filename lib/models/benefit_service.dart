import 'dart:convert';
import 'package:http/http.dart' as http;
import 'benefit.dart';
import '../services/app_config.dart';

/// Retrieval service for the `benefit` table in Supabase,
/// using plain HTTP calls to Supabase's auto-generated REST API (PostgREST)
/// instead of the supabase_flutter package.
class BenefitService {
  static List<Benefit>? _cachedBenefits;

  /// Fetches all benefits.
  /// Set [forceRefresh] to true to bypass the in-memory cache.
  static Future<List<Benefit>> loadBenefits({bool forceRefresh = false}) async {
    if (_cachedBenefits != null && !forceRefresh) return _cachedBenefits!;

    final uri = Uri.parse(
      '${AppConfig.supabaseUrl!}/rest/v1/benefit?select=*',
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'apikey': AppConfig.supabasePublishableKey!,
          'Authorization': 'Bearer ${AppConfig.supabasePublishableKey!}',
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

  /// Benefits that are approximate/relevant to the senior at [address]:
  /// national/universal benefits always count, plus any benefit whose LGU
  /// matches a city/barangay name found in the address. If nothing matches
  /// specifically, falls back to the full list so the screen is never empty.
  static Future<List<Benefit>> loadRelevantBenefits(String? address) async {
    final all = await loadBenefits();
    if ((address ?? '').trim().isEmpty) return all;
    final relevant = all.where((b) => isRelevantFor(b, address)).toList();
    return relevant.isEmpty ? all : relevant;
  }

  /// Is a single benefit relevant to the senior at [address]? Used by the
  /// benefits filter to surface the most useful benefits for a senior.
  static bool isRelevantFor(Benefit benefit, String? address) {
    final tokens = _addressTokens(address ?? '');
    if (tokens.isEmpty) {
      return true; // no address → treat everything as relevant
    }
    final lgu = benefit.lgu.toLowerCase();
    if (lgu.startsWith('national') || lgu.contains('all lgu')) return true;
    return tokens.any(lgu.contains);
  }

  /// Pulls candidate place names out of an address like
  /// "Barangay Gun-ob, Lapu-Lapu City" → {lapu, gun} (>= 3 letters, minus
  /// common words).
  static Set<String> _addressTokens(String address) {
    const stopWords = {
      'the',
      'and',
      'barangay',
      'brgy',
      'city',
      'province',
      'philippines',
      'street',
      'st',
      'zone',
      'purok',
      'sitio',
      'village',
      'road',
      'blvd',
    };
    final cleaned = address
        .toLowerCase()
        .replaceAll(RegExp(r'\bbrgy\.?\b'), ' ')
        .replaceAll(RegExp(r'[.,;\-]'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 3 && !stopWords.contains(t))
        .toSet();
  }
}
