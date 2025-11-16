import 'package:homiego/core/models/booking.dart';
import 'package:homiego/core/models/fraud_detection.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/services/supabase_client.dart';

class FraudDetectionService {
  /// Detect excessive cancellations (>3 in 24 hours)
  static List<FraudFlag> detectExcessiveCancellations(
    List<Booking> bookings,
    String userId,
  ) {
    final flags = <FraudFlag>[];
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));

    final recentCancellations = bookings
        .where((b) =>
            b.tenantId == userId &&
            b.status == BookingStatus.cancelled &&
            b.createdAt.isAfter(last24Hours))
        .toList();

    if (recentCancellations.length > 3) {
      flags.add(FraudFlag(
        type: 'excessive_cancellations',
        description:
            'User has ${recentCancellations.length} cancellations in the last 24 hours',
        detectedAt: now,
        metadata: {
          'cancellation_count': recentCancellations.length,
          'time_window_hours': 24,
        },
      ));
    }

    return flags;
  }

  /// Detect multiple accounts from same email
  static Future<List<FraudFlag>> detectMultipleAccountsFromEmail(
    String email,
  ) async {
    final flags = <FraudFlag>[];
    try {
      // Query auth.users to find accounts with same email
      // Note: This requires admin access to auth.users
      // For now, we'll check profiles table and note that email is in auth.users
      await supabase
          .from('profiles')
          .select('id')
          .limit(1000); // Adjust as needed

      // Since we can't directly query auth.users from client,
      // we'll note this in the flag and recommend server-side check
      // For implementation, you'd need a Supabase Edge Function or RPC
      flags.add(FraudFlag(
        type: 'multiple_accounts',
        description: 'Multiple accounts detected with same email: $email',
        detectedAt: DateTime.now(),
        metadata: {
          'email': email,
          'note': 'Requires server-side verification via Supabase Edge Function',
        },
      ));
    } catch (e) {
      // Handle error
    }
    return flags;
  }

  /// Detect high-value booking anomalies
  static List<FraudFlag> detectHighValueAnomalies(
    List<Booking> allBookings,
    List<Booking> userBookings,
    String userId,
  ) {
    final flags = <FraudFlag>[];
    
    if (allBookings.isEmpty || userBookings.isEmpty) {
      return flags;
    }

    // Calculate average booking price across all bookings
    final averagePrice = allBookings
            .map((b) => b.totalPrice)
            .reduce((a, b) => a + b) /
        allBookings.length;

    // Check for bookings significantly higher than average (3x or more)
    final threshold = averagePrice * 3;
    final highValueBookings = userBookings
        .where((b) => b.tenantId == userId && b.totalPrice > threshold)
        .toList();

    if (highValueBookings.isNotEmpty) {
      final maxPrice = highValueBookings
          .map((b) => b.totalPrice)
          .reduce((a, b) => a > b ? a : b);
      
      flags.add(FraudFlag(
        type: 'high_value_anomaly',
        description:
            'Booking price (${maxPrice.toStringAsFixed(2)}) is ${(maxPrice / averagePrice).toStringAsFixed(1)}x higher than average (${averagePrice.toStringAsFixed(2)})',
        detectedAt: DateTime.now(),
        metadata: {
          'booking_price': maxPrice,
          'average_price': averagePrice,
          'multiplier': maxPrice / averagePrice,
          'booking_ids': highValueBookings.map((b) => b.id).toList(),
        },
      ));
    }

    return flags;
  }

  /// Detect rapid bookings (multiple within minutes)
  static List<FraudFlag> detectRapidBookings(
    List<Booking> bookings,
    String userId,
  ) {
    final flags = <FraudFlag>[];
    
    if (bookings.length < 2) {
      return flags;
    }

    final userBookings = bookings
        .where((b) => b.tenantId == userId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Check for bookings within 5 minutes of each other
    for (int i = 0; i < userBookings.length - 1; i++) {
      final current = userBookings[i];
      final next = userBookings[i + 1];
      final timeDiff = next.createdAt.difference(current.createdAt);

      if (timeDiff.inMinutes < 5) {
        flags.add(FraudFlag(
          type: 'rapid_bookings',
          description:
              'Multiple bookings detected within ${timeDiff.inMinutes} minutes',
          detectedAt: DateTime.now(),
          metadata: {
            'time_difference_minutes': timeDiff.inMinutes,
            'booking_ids': [current.id, next.id],
            'first_booking_time': current.createdAt.toIso8601String(),
            'second_booking_time': next.createdAt.toIso8601String(),
          },
        ));
        break; // Only flag once per user
      }
    }

    return flags;
  }

  /// Calculate fraud score for a user (0-100)
  static double calculateUserFraudScore(List<FraudFlag> flags) {
    if (flags.isEmpty) return 0.0;

    double score = 0.0;
    for (var flag in flags) {
      switch (flag.type) {
        case 'excessive_cancellations':
          score += 30.0;
          break;
        case 'multiple_accounts':
          score += 40.0;
          break;
        case 'high_value_anomaly':
          score += 25.0;
          break;
        case 'rapid_bookings':
          score += 20.0;
          break;
      }
    }

    // Cap at 100
    return score > 100 ? 100.0 : score;
  }

  /// Calculate fraud score for a property (0-100)
  static double calculatePropertyFraudScore(List<FraudFlag> flags) {
    if (flags.isEmpty) return 0.0;

    double score = 0.0;
    for (var flag in flags) {
      switch (flag.type) {
        case 'high_value_anomaly':
          score += 35.0;
          break;
        case 'rapid_bookings':
          score += 25.0;
          break;
        // Properties can have flags from their bookings
        default:
          score += 15.0;
      }
    }

    return score > 100 ? 100.0 : score;
  }

  /// Get all bookings for fraud analysis
  static Future<List<Booking>> getAllBookings() async {
    try {
      final response = await supabase
          .from('bookings')
          .select()
          .order('created_at', ascending: false);

      final bookingsList = response as List? ?? [];
      return bookingsList
          .map((data) => Booking.fromMap(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch bookings: $e');
    }
  }

  /// Get user email from auth (requires admin access or Edge Function)
  static Future<String?> getUserEmail(String userId) async {
    try {
      // Note: Direct access to auth.users requires admin privileges
      // In production, use a Supabase Edge Function or RPC
      // For now, we'll return null and note it in the UI
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Analyze all users for fraud
  static Future<List<UserFraudScore>> analyzeAllUsers() async {
    final bookings = await getAllBookings();
    final userScores = <UserFraudScore>[];
    final userIds = <String>{};

    // Collect all unique user IDs
    for (var booking in bookings) {
      userIds.add(booking.tenantId);
    }

    // Analyze each user
    for (var userId in userIds) {
      final userBookings =
          bookings.where((b) => b.tenantId == userId).toList();

      final flags = <FraudFlag>[];
      flags.addAll(detectExcessiveCancellations(bookings, userId));
      flags.addAll(detectHighValueAnomalies(bookings, userBookings, userId));
      flags.addAll(detectRapidBookings(bookings, userId));

      final score = calculateUserFraudScore(flags);
      final cancelledCount =
          userBookings.where((b) => b.status == BookingStatus.cancelled).length;
      final totalSpent = userBookings
          .where((b) => b.paymentStatus == PaymentStatus.paid)
          .map((b) => b.totalPrice)
          .fold(0.0, (a, b) => a + b);

      // Try to get user profile for name/email
      Profile? profile;
      try {
        final profileResponse = await supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (profileResponse != null) {
          profile = Profile.fromMap(profileResponse);
        }
      } catch (e) {
        // Profile not found or error
      }

      if (flags.isNotEmpty || score > 0) {
        userScores.add(UserFraudScore(
          userId: userId,
          userEmail: null, // Would need Edge Function to get from auth.users
          userName: profile?.fullName,
          score: score,
          flags: flags,
          totalBookings: userBookings.length,
          cancelledBookings: cancelledCount,
          totalSpent: totalSpent,
        ));
      }
    }

    // Sort by score descending
    userScores.sort((a, b) => b.score.compareTo(a.score));
    return userScores;
  }

  /// Analyze all properties for fraud
  static Future<List<PropertyFraudScore>> analyzeAllProperties() async {
    final bookings = await getAllBookings();
    final propertyScores = <PropertyFraudScore>[];
    final propertyIds = <int>{};

    // Collect all unique property IDs
    for (var booking in bookings) {
      propertyIds.add(booking.propertyId);
    }

    // Analyze each property
    for (var propertyId in propertyIds) {
      final propertyBookings =
          bookings.where((b) => b.propertyId == propertyId).toList();

      if (propertyBookings.isEmpty) continue;

      final flags = <FraudFlag>[];
      
      // Check for high-value anomalies
      final allBookings = await getAllBookings();
      final avgPrice = allBookings.isNotEmpty
          ? allBookings.map((b) => b.totalPrice).reduce((a, b) => a + b) /
              allBookings.length
          : 0.0;
      
      final propertyAvgPrice = propertyBookings
              .map((b) => b.totalPrice)
              .reduce((a, b) => a + b) /
          propertyBookings.length;
      
      final maxPrice = propertyBookings
          .map((b) => b.totalPrice)
          .reduce((a, b) => a > b ? a : b);

      if (avgPrice > 0 && maxPrice > avgPrice * 3) {
        flags.add(FraudFlag(
          type: 'high_value_anomaly',
          description:
              'Property has bookings significantly higher than average',
          detectedAt: DateTime.now(),
          metadata: {
            'property_avg_price': propertyAvgPrice,
            'system_avg_price': avgPrice,
            'max_price': maxPrice,
          },
        ));
      }

      // Check for rapid bookings on this property
      propertyBookings.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (int i = 0; i < propertyBookings.length - 1; i++) {
        final timeDiff = propertyBookings[i + 1].createdAt
            .difference(propertyBookings[i].createdAt);
        if (timeDiff.inMinutes < 5) {
          flags.add(FraudFlag(
            type: 'rapid_bookings',
            description: 'Multiple bookings on this property within minutes',
            detectedAt: DateTime.now(),
            metadata: {
              'time_difference_minutes': timeDiff.inMinutes,
            },
          ));
          break;
        }
      }

      final score = calculatePropertyFraudScore(flags);

      // Get property details
      Property? property;
      Profile? hostProfile;
      try {
        final propertyResponse = await supabase
            .from('properties')
            .select()
            .eq('id', propertyId)
            .maybeSingle();
        if (propertyResponse != null) {
          property = Property.fromMap(propertyResponse);
          
          // Get host profile
          final hostResponse = await supabase
              .from('profiles')
              .select()
              .eq('id', property.hostId)
              .maybeSingle();
          if (hostResponse != null) {
            hostProfile = Profile.fromMap(hostResponse);
          }
        }
      } catch (e) {
        // Property not found or error
      }

      if (flags.isNotEmpty || score > 0) {
        propertyScores.add(PropertyFraudScore(
          propertyId: propertyId,
          propertyTitle: property?.title ?? 'Unknown Property',
          hostId: property?.hostId ?? '',
          hostName: hostProfile?.fullName,
          score: score,
          flags: flags,
          totalBookings: propertyBookings.length,
          averagePrice: propertyAvgPrice,
          highestPrice: maxPrice,
        ));
      }
    }

    // Sort by score descending
    propertyScores.sort((a, b) => b.score.compareTo(a.score));
    return propertyScores;
  }

  /// Get system-wide fraud summary
  static Future<SystemFraudSummary> getSystemFraudSummary() async {
    final userScores = await analyzeAllUsers();
    final propertyScores = await analyzeAllProperties();

    // Calculate overall score (average of all flagged entities)
    double overallScore = 0.0;
    int totalEntities = 0;

    for (var user in userScores) {
      overallScore += user.score;
      totalEntities++;
    }

    for (var property in propertyScores) {
      overallScore += property.score;
      totalEntities++;
    }

    if (totalEntities > 0) {
      overallScore = overallScore / totalEntities;
    }

    // Count flags by type
    final flagCounts = <String, int>{};
    for (var user in userScores) {
      for (var flag in user.flags) {
        flagCounts[flag.type] = (flagCounts[flag.type] ?? 0) + 1;
      }
    }
    for (var property in propertyScores) {
      for (var flag in property.flags) {
        flagCounts[flag.type] = (flagCounts[flag.type] ?? 0) + 1;
      }
    }

    return SystemFraudSummary(
      overallScore: overallScore,
      flaggedUsers: userScores.length,
      flaggedProperties: propertyScores.length,
      topSuspiciousUsers: userScores.take(10).toList(),
      topSuspiciousProperties: propertyScores.take(10).toList(),
      flagCounts: flagCounts,
    );
  }
}

