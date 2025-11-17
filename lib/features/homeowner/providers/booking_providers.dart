// lib/features/homeowner/providers/booking_providers.dart

import 'package:homiego/core/models/property.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/supabase_client.dart';

/// Homeowner profile provider
final homeownerProfileProvider = Provider<Profile>((ref) {
  final authState = ref.watch(authNotifierProvider);
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

/// All homeowner bookings stream (source of truth)
/// Returns joined data: bookings, properties, profiles
final homeownerBookingsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final profile = ref.watch(homeownerProfileProvider);
  final hostId = profile.id;

  // Get property IDs
  final propertyRows =
      await supabase.from('properties').select('id').eq('host_id', hostId);

  final propertyIds =
      (propertyRows as List<dynamic>).map((e) => e['id'] as int).toList();

  if (propertyIds.isEmpty) {
    yield [];
    return;
  }

  final controller = StreamController<List<Map<String, dynamic>>>();

  Future<void> fetchBookings() async {
    try {
      final data = await supabase
          .from('bookings')
          .select(
            '*, properties:property_id(title), profiles:tenant_id(full_name, avatar_url, is_verified)',
          )
          .inFilter('property_id', propertyIds)
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

  await fetchBookings();

  // Realtime listener for booking changes
  final subscription = supabase
      .from('bookings')
      .stream(primaryKey: ['id'])
      .inFilter('property_id', propertyIds)
      .listen((_) => fetchBookings());

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  yield* controller.stream;
});

/// All properties owned by homeowner
final myListingsProvider = FutureProvider<List<Property>>((ref) async {
  final profile = ref.watch(homeownerProfileProvider);

  debugPrint('[myListingsProvider] Fetching listings for host_id: ${profile.id}');

  final rows = await supabase
      .from('properties')
      .select('*, property_images(*)')
      .eq('host_id', profile.id);

  debugPrint('[myListingsProvider] Rows received from Supabase: $rows');

  return (rows as List<dynamic>).map((e) => Property.fromMap(e)).toList();
});