import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/features/homeowner/providers/booking_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Efficiently counts properties for the current homeowner based on a given status.
///
/// This uses the `.count()` method on Supabase for maximum efficiency,
/// returning only an integer instead of a large list.
final dashboardPropertyCountProvider =
    FutureProvider.family<int, PropertyStatus>((ref, status) async {
  final profile = ref.watch(homeownerProfileProvider);

  try {
    final response = await supabase
        .from('properties')
        .count(CountOption.exact) // Use efficient count
        .eq('host_id', profile.id)
        .eq('status', status.name);

    return response;
  } catch (e) {
    debugPrint('Error counting properties ($status): $e');
    // Return 0 on error so the UI can still build
    return 0;
  }
});

/// A derived provider that shows *only* pending bookings for the dashboard.
///
/// It watches the main [homeownerBookingsStreamProvider] and filters the
/// list in Dart. This is efficient as it re-uses the existing stream.
final dashboardPendingBookingsProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  // Watch the "source of truth" stream
  final allBookingsAsync = ref.watch(homeownerBookingsStreamProvider);

  // Propagate loading/error states
  return allBookingsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (bookings) {
      try {
        // Filter the list in Dart
        final pending = bookings
            .where((booking) => booking['status'] == 'pending')
            .toList();
        // Return the new, filtered list
        return AsyncValue.data(pending);
      } catch (e, st) {
        return AsyncValue.error(e, st);
      }
    },
  );
});