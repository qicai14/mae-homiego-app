import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/models/fraud_detection.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/features/admin/services/fraud_detection_service.dart';

// Rental Statistics Model
class RentalStatistics {
  final int inactiveProperties; // Pending or Rejected
  final int activeProperties; // Approved

  RentalStatistics({
    required this.inactiveProperties,
    required this.activeProperties,
  });
}

// Booking Statistics Model
class BookingStatistics {
  final int totalBookings;
  final int pendingBookings;
  final int confirmedBookings;
  final int declinedBookings;
  final int cancelledBookings;
  final double totalRevenue;
  final int paidBookings;
  final int unpaidBookings;

  BookingStatistics({
    required this.totalBookings,
    required this.pendingBookings,
    required this.confirmedBookings,
    required this.declinedBookings,
    required this.cancelledBookings,
    required this.totalRevenue,
    required this.paidBookings,
    required this.unpaidBookings,
  });
}

// Provider for rental statistics
final rentalStatisticsProvider = FutureProvider<RentalStatistics>((ref) async {
  try {
    // Fetch all properties with their status
    final propertiesResponse = await supabase
        .from('properties')
        .select('status');

    final propertyList = propertiesResponse as List? ?? [];
    if (propertyList.isEmpty) {
      return RentalStatistics(inactiveProperties: 0, activeProperties: 0);
    }

    int activeCount = 0;
    int inactiveCount = 0;

    for (var property in propertyList) {
      final status = property['status'] as String?;
      if (status == 'approved') {
        activeCount++;
      } else if (status == 'pending' || status == 'rejected') {
        inactiveCount++;
      }
    }

    return RentalStatistics(
      inactiveProperties: inactiveCount,
      activeProperties: activeCount,
    );
  } catch (e) {
    throw Exception('Failed to fetch rental statistics: $e');
  }
});


// Provider for booking statistics
final bookingStatisticsProvider = FutureProvider<BookingStatistics>((ref) async {
  try {
    // DEBUG: Check session
    final session = supabase.auth.currentSession;
    print("=== BOOKING STATS SESSION TOKEN (first 20 chars) ===");
    print(session?.accessToken.substring(0, 20) ?? "NO SESSION FOUND");

    // DEBUG: Check user ID
    print("CURRENT USER ID: ${supabase.auth.currentUser?.id}");

    // Perform the query
    final bookingsResponse = await supabase
        .from('bookings')
        .select('status, payment_status, total_price');

    print("BOOKINGS RESPONSE RAW: $bookingsResponse");

    final bookingsList = bookingsResponse as List? ?? [];
    print("BOOKINGS COUNT FROM SUPABASE: ${bookingsList.length}");

    // The rest of your logic remains unchanged
    int totalBookings = bookingsList.length;
    int pendingCount = 0;
    int confirmedCount = 0;
    int declinedCount = 0;
    int cancelledCount = 0;
    int paidCount = 0;
    int unpaidCount = 0;
    double totalRevenue = 0.0;

    for (var booking in bookingsList) {
      final status = booking['status'] as String?;
      final paymentStatus = booking['payment_status'] as String?;
      final price = booking['total_price'] as num?;

      switch (status) {
        case 'pending':
          pendingCount++;
          break;
        case 'confirmed':
          confirmedCount++;
          break;
        case 'declined':
          declinedCount++;
          break;
        case 'cancelled':
          cancelledCount++;
          break;
      }

      if (paymentStatus == 'paid') {
        paidCount++;
        totalRevenue += price?.toDouble() ?? 0.0;
      } else if (paymentStatus == 'unpaid') {
        unpaidCount++;
      }
    }

    return BookingStatistics(
      totalBookings: totalBookings,
      pendingBookings: pendingCount,
      confirmedBookings: confirmedCount,
      declinedBookings: declinedCount,
      cancelledBookings: cancelledCount,
      totalRevenue: totalRevenue,
      paidBookings: paidCount,
      unpaidBookings: unpaidCount,
    );
  } catch (e) {
    throw Exception('Failed to fetch booking statistics: $e');
  }
});

// Provider for pending properties (status == 'pending')
final pendingPropertiesProvider = FutureProvider<List<Property>>((ref) async {
  try {
    final response = await supabase
        .from('properties')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final responseList = response as List? ?? [];
    return responseList
        .map((data) => Property.fromMap(data as Map<String, dynamic>))
        .toList();
  } catch (e) {
    throw Exception('Failed to fetch pending properties: $e');
  }
});

// Provider for unverified profiles (homeowners)
final unverifiedProfilesProvider = FutureProvider<List<Profile>>((ref) async {
  try {
    final response = await supabase
        .from('profiles')
        .select()
        .eq('is_verified', false)
        .eq('role', 'homeowner')
        .order('created_at', ascending: false);

    final responseList = response as List? ?? [];
    return responseList
        .map((data) => Profile.fromMap(data as Map<String, dynamic>))
        .toList();
  } catch (e) {
    throw Exception('Failed to fetch unverified profiles: $e');
  }
});

// Provider for updating property status (pending, approved, or rejected)
final updatePropertyStatusProvider =
    FutureProvider.family<bool, Map<String, dynamic>>((ref, params) async {
  try {
    final propertyId = params['property_id'] as int;
    final status = params['status'] as String; // 'pending', 'approved', or 'rejected'

    print('Attempting to update property $propertyId to status: $status');

    // First, verify the property exists and get its current status
    try {
      final checkResponse = await supabase
          .from('properties')
          .select('id, status')
          .eq('id', propertyId)
          .single();
      
      print('Property check result: $checkResponse');
    } catch (e) {
      print('Could not find property: $e');
      throw Exception('Property with ID $propertyId not found or not accessible');
    }

    // Attempt the update
    final response = await supabase
        .from('properties')
        .update({'status': status})
        .eq('id', propertyId)
        .select();

    print('Update response: $response');

    // Verify the update was successful
    final responseList = response as List?;
    if (responseList == null || responseList.isEmpty) {
      // Check if it's an RLS issue by trying to see what error we get
      print('Update returned empty result. This might be an RLS policy issue.');
      print('Current user: ${supabase.auth.currentUser?.id}');
      
      // Try to get user's role
      try {
        final profileResponse = await supabase
            .from('profiles')
            .select('role')
            .eq('id', supabase.auth.currentUser?.id ?? '')
            .single();
        print('Current user role: $profileResponse');
      } catch (e) {
        print('Could not fetch user role: $e');
      }
      
      throw Exception('Update failed: No rows were updated. This is likely due to RLS policies blocking the update. Please ensure admin users have UPDATE permissions in Supabase RLS policies.');
    }

    print('Update successful! Updated property: ${responseList[0]}');

    // Invalidate the pending properties provider to refresh the list
    // Use Future.microtask to ensure invalidation happens after the update completes
    Future.microtask(() {
      ref.invalidate(pendingPropertiesProvider);
      ref.invalidate(rentalStatisticsProvider);
    });

    return true;
  } catch (e, stackTrace) {
    print('Error updating property status: $e');
    print('Stack trace: $stackTrace');
    throw Exception('Failed to update property status: $e');
  }
});

// Provider for updating profile verification
final updateProfileVerificationProvider =
    FutureProvider.family<bool, Map<String, dynamic>>((ref, params) async {
  try {
    final profileId = params['profile_id'] as String;
    final isVerified = params['is_verified'] as bool;

    print('Attempting to update profile $profileId to is_verified: $isVerified');

    // First, verify the profile exists
    try {
      final checkResponse = await supabase
          .from('profiles')
          .select('id, is_verified, role')
          .eq('id', profileId)
          .single();
      
      print('Profile check result: $checkResponse');
    } catch (e) {
      print('Could not find profile: $e');
      throw Exception('Profile with ID $profileId not found or not accessible');
    }

    // Attempt the update
    final response = await supabase
        .from('profiles')
        .update({'is_verified': isVerified})
        .eq('id', profileId)
        .select();

    print('Update response: $response');

    // Verify the update was successful
    final responseList = response as List?;
    if (responseList == null || responseList.isEmpty) {
      print('Update returned empty result. This might be an RLS policy issue.');
      print('Current user: ${supabase.auth.currentUser?.id}');
      
      // Try to get user's role
      try {
        final profileResponse = await supabase
            .from('profiles')
            .select('role')
            .eq('id', supabase.auth.currentUser?.id ?? '')
            .single();
        print('Current user role: $profileResponse');
      } catch (e) {
        print('Could not fetch user role: $e');
      }
      
      throw Exception('Update failed: No rows were updated. This is likely due to RLS policies blocking the update. Please ensure admin users have UPDATE permissions in Supabase RLS policies for the profiles table.');
    }

    print('Update successful! Updated profile: ${responseList[0]}');

    // Invalidate the unverified profiles provider to refresh the list
    // Use Future.microtask to ensure invalidation happens after the update completes
    Future.microtask(() {
      ref.invalidate(unverifiedProfilesProvider);
    });

    return true;
  } catch (e, stackTrace) {
    print('Error updating profile verification: $e');
    print('Stack trace: $stackTrace');
    throw Exception('Failed to update profile verification: $e');
  }
});

// Provider for system fraud summary
final systemFraudSummaryProvider = FutureProvider<SystemFraudSummary>((ref) async {
  try {
    return await FraudDetectionService.getSystemFraudSummary();
  } catch (e) {
    throw Exception('Failed to fetch fraud summary: $e');
  }
});

// Provider for user fraud scores
final userFraudScoresProvider = FutureProvider<List<UserFraudScore>>((ref) async {
  try {
    return await FraudDetectionService.analyzeAllUsers();
  } catch (e) {
    throw Exception('Failed to fetch user fraud scores: $e');
  }
});

// Provider for property fraud scores
final propertyFraudScoresProvider = FutureProvider<List<PropertyFraudScore>>((ref) async {
  try {
    return await FraudDetectionService.analyzeAllProperties();
  } catch (e) {
    throw Exception('Failed to fetch property fraud scores: $e');
  }
});

// Provider for all properties (excluding admin properties)
final allPropertiesProvider = FutureProvider<List<Property>>((ref) async {
  try {
    final response = await supabase
        .from('properties')
        .select()
        .order('created_at', ascending: false);

    final responseList = response as List? ?? [];
    return responseList
        .map((data) => Property.fromMap(data as Map<String, dynamic>))
        .toList();
  } catch (e) {
    throw Exception('Failed to fetch all properties: $e');
  }
});

// Provider for all profiles (excluding admin)
final allProfilesProvider = FutureProvider<List<Profile>>((ref) async {
  try {
    final response = await supabase
        .from('profiles')
        .select()
        .neq('role', 'admin')
        .order('created_at', ascending: false);

    final responseList = response as List? ?? [];
    return responseList
        .map((data) => Profile.fromMap(data as Map<String, dynamic>))
        .toList();
  } catch (e) {
    throw Exception('Failed to fetch all profiles: $e');
  }
});

