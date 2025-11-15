import 'package:homiego/core/models/property.dart';
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

/// --- REFACTORED: StreamProvider for ALL Homeowner Bookings ---
///
/// Fetches and listens to *all* bookings (pending, confirmed, etc.)
/// for the current homeowner's properties.
/// This is the "source of truth" stream for bookings.
///
/// Returns a `List<Map<String, dynamic>>` containing joined data from:
/// - bookings (*)
/// - properties (title)
/// - profiles (tenant's full_name, avatar_url)
final homeownerBookingsStreamProvider =
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
  Future<void> fetchBookings() async {
    try {
      final data = await supabase
          .from('bookings')
          .select(
              // --- THIS IS THE CORRECT JOIN ---
              '*, properties:property_id(title), profiles:tenant_id(full_name, avatar_url)')
          .inFilter('property_id', propertyIds)
          // --- FILTER REMOVED ---
          // .eq('status', 'pending') // <-- This filter was removed
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
  await fetchBookings();

  // 6. Set up Realtime listener
  // Listen to *any* change on bookings related to our properties.
  // This will re-fetch the list, automatically updating all listeners.
  final subscription = supabase
      .from('bookings')
      .stream(primaryKey: ['id'])
      .inFilter('property_id', propertyIds)
      .listen((_) => fetchBookings());

  // 7. Clean up controller and subscription on dispose
  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  // 8. Yield the stream from the controller
  yield* controller.stream;
});

// --- CHANGES ---
// MOVED this provider from my_listings_screen.dart
/// --- Riverpod FutureProvider for all properties owned by current homeowner ---
final myListingsProvider = FutureProvider<List<Property>>((ref) async {
  // --- THIS NOW WORKS: It watches the correct, centralized provider ---
  final profile = ref.watch(homeownerProfileProvider);

  // Query Supabase for properties owned by this homeowner
  final rows =
      await supabase.from('properties').select().eq('host_id', profile.id);

  // Parse the data into List<Property>
  return (rows as List<dynamic>).map((e) => Property.fromMap(e)).toList();
});
// --- END CHANGES ---