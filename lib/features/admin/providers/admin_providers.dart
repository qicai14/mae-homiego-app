import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/models/fraud_detection.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/features/admin/services/fraud_detection_service.dart';

/// Represents rental property statistics for admin dashboard.
/// 
/// Tracks the count of active and inactive properties in the system.
/// Active properties are those with 'approved' status, while inactive
/// properties include those with 'pending' or 'rejected' status.
class RentalStatistics {
  /// Number of inactive properties (pending or rejected status)
  final int inactiveProperties;
  
  /// Number of active properties (approved status)
  final int activeProperties;

  RentalStatistics({
    required this.inactiveProperties,
    required this.activeProperties,
  });
}

/// Represents booking statistics for admin dashboard.
/// 
/// Provides comprehensive booking metrics including counts by status
/// (pending, confirmed, declined, cancelled) and payment information
/// (paid/unpaid bookings and total revenue).
class BookingStatistics {
  /// Total number of bookings in the system
  final int totalBookings;
  
  /// Number of bookings with 'pending' status
  final int pendingBookings;
  
  /// Number of bookings with 'confirmed' status
  final int confirmedBookings;
  
  /// Number of bookings with 'declined' status
  final int declinedBookings;
  
  /// Number of bookings with 'cancelled' status
  final int cancelledBookings;
  
  /// Total revenue from all paid bookings
  final double totalRevenue;
  
  /// Number of bookings with 'paid' payment status
  final int paidBookings;
  
  /// Number of bookings with 'unpaid' payment status
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

/// Provider that fetches rental property statistics from the database.
/// 
/// Retrieves all properties and categorizes them into active (approved)
/// and inactive (pending/rejected) counts. Returns a [RentalStatistics]
/// object with the aggregated data.
/// 
/// Throws an exception if the database query fails.
final rentalStatisticsProvider = FutureProvider<RentalStatistics>((ref) async {
  try {
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


/// Provider that fetches comprehensive booking statistics from the database.
/// 
/// Retrieves all bookings and calculates:
/// - Total booking count
/// - Bookings grouped by status (pending, confirmed, declined, cancelled)
/// - Payment statistics (paid/unpaid counts)
/// - Total revenue from paid bookings
/// 
/// Returns a [BookingStatistics] object with all aggregated metrics.
/// Throws an exception if the database query fails.
final bookingStatisticsProvider = FutureProvider<BookingStatistics>((ref) async {
  try {
    final session = supabase.auth.currentSession;
    print("=== BOOKING STATS SESSION TOKEN (first 20 chars) ===");
    print(session?.accessToken.substring(0, 20) ?? "NO SESSION FOUND");

    print("CURRENT USER ID: ${supabase.auth.currentUser?.id}");

    final bookingsResponse = await supabase
        .from('bookings')
        .select('status, payment_status, total_price');

    print("BOOKINGS RESPONSE RAW: $bookingsResponse");

    final bookingsList = bookingsResponse as List? ?? [];
    print("BOOKINGS COUNT FROM SUPABASE: ${bookingsList.length}");

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

/// Provider that fetches all properties with 'pending' status.
/// 
/// Retrieves properties awaiting admin approval, ordered by creation date
/// (newest first). Used by admin to review and approve/reject property listings.
/// 
/// Returns a list of [Property] objects.
/// Throws an exception if the database query fails.
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

/// Provider that fetches all unverified homeowner profiles.
/// 
/// Retrieves homeowner profiles that have not been verified by admin,
/// ordered by creation date (newest first). Used by admin to review
/// and verify homeowner accounts.
/// 
/// Returns a list of [Profile] objects.
/// Throws an exception if the database query fails.
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

/// Provider that updates a property's status (approve/reject/pending).
/// 
/// Parameters:
/// - `property_id` (int): The ID of the property to update
/// - `status` (String): The new status ('approved', 'rejected', or 'pending')
/// 
/// Verifies the property exists before updating, then updates the status
/// in the database. Invalidates related providers after successful update.
/// 
/// Returns `true` if the update was successful.
/// Throws an exception if the property doesn't exist, update fails, or
/// RLS policies block the operation.
final updatePropertyStatusProvider =
    FutureProvider.family<bool, Map<String, dynamic>>((ref, params) async {
  try {
    final propertyId = params['property_id'] as int;
    final status = params['status'] as String;

    print('Attempting to update property $propertyId to status: $status');

    // Verify property exists
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

    final response = await supabase
        .from('properties')
        .update({'status': status})
        .eq('id', propertyId)
        .select();

    print('Update response: $response');

    final responseList = response as List?;
    if (responseList == null || responseList.isEmpty) {
      print('Update returned empty result. This might be an RLS policy issue.');
      print('Current user: ${supabase.auth.currentUser?.id}');
      
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

    // Invalidate providers after update
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

/// Provider that updates a profile's verification status.
/// 
/// Parameters:
/// - `profile_id` (String): The ID of the profile to update
/// - `is_verified` (bool): The new verification status (true/false)
/// 
/// Verifies the profile exists before updating, then updates the
/// `is_verified` field in the database. Invalidates related providers
/// after successful update.
/// 
/// Returns `true` if the update was successful.
/// Throws an exception if the profile doesn't exist, update fails, or
/// RLS policies block the operation.
final updateProfileVerificationProvider =
    FutureProvider.family<bool, Map<String, dynamic>>((ref, params) async {
  try {
    final profileId = params['profile_id'] as String;
    final isVerified = params['is_verified'] as bool;

    print('Attempting to update profile $profileId to is_verified: $isVerified');

    // Verify profile exists
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

    final response = await supabase
        .from('profiles')
        .update({'is_verified': isVerified})
        .eq('id', profileId)
        .select();

    print('Update response: $response');

    final responseList = response as List?;
    if (responseList == null || responseList.isEmpty) {
      print('Update returned empty result. This might be an RLS policy issue.');
      print('Current user: ${supabase.auth.currentUser?.id}');
      
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

    // Invalidate provider after update
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

/// Provider that fetches system-wide fraud detection summary.
/// 
/// Retrieves aggregated fraud statistics across all users and properties
/// in the system. Uses the [FraudDetectionService] to analyze and
/// summarize potential fraud indicators.
/// 
/// Returns a [SystemFraudSummary] object with overall fraud metrics.
/// Throws an exception if the fraud analysis fails.
final systemFraudSummaryProvider = FutureProvider<SystemFraudSummary>((ref) async {
  try {
    return await FraudDetectionService.getSystemFraudSummary();
  } catch (e) {
    throw Exception('Failed to fetch fraud summary: $e');
  }
});

/// Provider that fetches fraud scores for all users in the system.
/// 
/// Analyzes all user accounts using the [FraudDetectionService] to
/// calculate fraud risk scores based on various indicators (booking
/// patterns, payment behavior, profile completeness, etc.).
/// 
/// Returns a list of [UserFraudScore] objects, one for each user.
/// Throws an exception if the fraud analysis fails.
final userFraudScoresProvider = FutureProvider<List<UserFraudScore>>((ref) async {
  try {
    return await FraudDetectionService.analyzeAllUsers();
  } catch (e) {
    throw Exception('Failed to fetch user fraud scores: $e');
  }
});

/// Provider that fetches fraud scores for all properties in the system.
/// 
/// Analyzes all property listings using the [FraudDetectionService] to
/// calculate fraud risk scores based on various indicators (pricing
/// anomalies, description quality, image authenticity, owner verification, etc.).
/// 
/// Returns a list of [PropertyFraudScore] objects, one for each property.
/// Throws an exception if the fraud analysis fails.
final propertyFraudScoresProvider = FutureProvider<List<PropertyFraudScore>>((ref) async {
  try {
    return await FraudDetectionService.analyzeAllProperties();
  } catch (e) {
    throw Exception('Failed to fetch property fraud scores: $e');
  }
});

/// Provider that fetches all properties in the system.
/// 
/// Retrieves every property regardless of status, ordered by creation date
/// (newest first). Used by admin for comprehensive property management
/// and oversight.
/// 
/// Returns a list of [Property] objects.
/// Throws an exception if the database query fails.
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

/// Provider that fetches all user profiles excluding admin accounts.
/// 
/// Retrieves all homeowner and tenant profiles, ordered by creation date
/// (newest first). Used by admin for user management and oversight.
/// Admin profiles are excluded from the results.
/// 
/// Returns a list of [Profile] objects.
/// Throws an exception if the database query fails.
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

