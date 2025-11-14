import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/supabase_client.dart';

/// Provider to fetch current authenticated profile (only emits Profile when non-null)
/// (Moved from dashboard_screen.dart for consolidation)
final homeownerProfileProvider = Provider<Profile>((ref) {
  final authState = ref.watch(authNotifierProvider);
  // Use maybeWhen to safely get data, or throw if auth state is not ready.
  // This provider assumes the user is authenticated as a homeowner.
  return authState.maybeWhen(
    data: (data) {
      if (data.profile == null) {
        throw Exception('Homeowner profile not found in auth state.');
      }
      return data.profile!;
    },
    orElse: () => throw Exception('Auth state not loaded or in error'),
  );
});

/// --- NEW: Single StreamProvider for Pending Bookings ---
///
/// Fetches and listens to all bookings for the current homeowner's properties
/// where the status is 'pending'.
///
/// Returns a `List<Map<String, dynamic>>` containing joined data from:
/// - bookings (*)
/// - properties (title)
/// - profiles (tenant's full_name, avatar_url)
final pendingBookingsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final profile = ref.watch(homeownerProfileProvider);
  final hostId = profile.id;

  // 1. Get all property IDs owned by this homeowner
  final propertyRows =
      await supabase.from('properties').select('id').eq('host_id', hostId);

  final propertyIds =
      (propertyRows as List<dynamic>).map((e) => e['id'] as int).toList();

  // 2. If no properties, yield an empty list and stop.
  if (propertyIds.isEmpty) {
    yield [];
    return;
  }

  // 3. Create a controller to manually manage data fetching with joins
  final controller = StreamController<List<Map<String, dynamic>>>();

  // 4. Define the function to fetch joined data
  Future<void> fetchPendingBookings() async {
    try {
      final data = await supabase
          .from('bookings')
          .select(
              '*, properties:property_id(title), profiles:tenant_id(full_name, avatar_url)')
          .inFilter('property_id', propertyIds)
          .eq('status', 'pending') // Filter for pending status
          .order('created_at', ascending: false);

      if (!controller.isClosed) {
        controller.add(List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e, StackTrace.current);
      }
    }
  }

  // 5. Fetch initial data
  await fetchPendingBookings();

  // 6. Set up Realtime listener
  // Listen to *any* change on bookings related to our properties.
  // This will re-fetch the list, automatically adding new 'pending'
  // bookings and removing ones that are 'confirmed' or 'declined'.
  final subscription = supabase
      .from('bookings')
      .stream(primaryKey: ['id'])
      .inFilter('property_id', propertyIds)
      .listen((_) => fetchPendingBookings());

  // 7. Clean up controller and subscription on dispose
  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  // 8. Yield the stream from the controller
  yield* controller.stream;
});