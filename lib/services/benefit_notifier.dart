import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/benefit.dart';
import '../models/benefit_service.dart';
import '../models/profile_service.dart';

/// Listens (Supabase Realtime) for NEW rows inserted into the `benefit`
/// table and reports them with an algorithmic relevance hint:
///
///   relevant → "We think you might like this!"
///   other    → "A new benefit is now available"
///
/// Relevance is computed from the logged-in senior's address (same logic
/// as the benefits filter): national benefits always count, plus any whose
/// LGU matches the senior's city/barangay.
class BenefitNotifier {
  RealtimeChannel? _channel;

  /// Called on the UI thread with the newly inserted benefit and whether
  /// it is relevant to this senior. Attach your popup/banner here.
  void Function(Benefit benefit, bool relevant)? onNewBenefit;

  /// Start listening. Safe to call multiple times (idempotent).
  Future<void> start() async {
    if (_channel != null) return;

    final profile = await ProfileService.loadProfileOrNull();
    final address = profile?.address;

    _channel = Supabase.instance.client
        .channel('benefit-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'benefit',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            final benefit = Benefit.fromJson(
              Map<String, dynamic>.from(record as Map),
            );
            final relevant = BenefitService.isRelevantFor(benefit, address);
            unawaited(
              Future<void>.delayed(Duration.zero, () {
                onNewBenefit?.call(benefit, relevant);
              }),
            );
          },
        )
        .subscribe();
  }

  Future<void> stop() async {
    await _channel?.unsubscribe();
    _channel = null;
  }
}
