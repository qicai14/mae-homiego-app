import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/features/homeowner/providers/booking_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Count properties by status
final dashboardPropertyCountProvider =
    FutureProvider.family<int, PropertyStatus>((ref, status) async {
  final profile = ref.watch(homeownerProfileProvider);

  try {
    final response = await supabase
        .from('properties')
        .count(CountOption.exact)
        .eq('host_id', profile.id)
        .eq('status', status.name);

    return response;
  } catch (e) {
    debugPrint('Error counting properties ($status): $e');
    return 0;
  }
});

/// Pending bookings provider (filtered from main stream)
final dashboardPendingBookingsProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final allBookingsAsync = ref.watch(homeownerBookingsStreamProvider);

  return allBookingsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (bookings) {
      try {
        final pending = bookings
            .where((booking) => booking['status'] == 'pending')
            .toList();
        return AsyncValue.data(pending);
      } catch (e, st) {
        return AsyncValue.error(e, st);
      }
    },
  );
});