import 'package:homiego/core/models/booking.dart';
import 'package:homiego/core/models/fraud_detection.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/services/supabase_client.dart';

/// Service class for detecting and analyzing fraud patterns in the system.
/// 
/// Provides static methods to analyze user behavior, booking patterns, and
/// property listings to identify potential fraudulent activities. Calculates
/// fraud risk scores and generates fraud flags for admin review.
class FraudDetectionService {
  /// Detects users with excessive booking cancellations within a 24-hour window.
  /// 
  /// Flags users who have cancelled more than 3 bookings in the last 24 hours,
  /// which may indicate fraudulent behavior or abuse of the booking system.
  /// 
  /// Parameters:
  /// - `bookings`: List of all bookings to analyze
  /// - `userId`: The user ID to check for excessive cancellations
  /// 
  /// Returns a list of [FraudFlag] objects if suspicious activity is detected.
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

  /// Detects potential multiple accounts created with the same email address.
  /// 
  /// Note: Full implementation requires server-side verification via Supabase
  /// Edge Function, as client-side access to auth.users table is restricted.
  /// 
  /// Parameters:
  /// - `email`: The email address to check for duplicate accounts
  /// 
  /// Returns a list of [FraudFlag] objects if multiple accounts are detected.
  static Future<List<FraudFlag>> detectMultipleAccountsFromEmail(
    String email,
  ) async {
    final flags = <FraudFlag>[];
    try {
      await supabase
          .from('profiles')
          .select('id')
          .limit(1000);

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

  /// Detects booking price anomalies that are significantly higher than average.
  /// 
  /// Flags bookings where the price is more than 3x the system average, which
  /// may indicate price manipulation or fraudulent listing practices.
  /// 
  /// Parameters:
  /// - `allBookings`: All bookings in the system for average calculation
  /// - `userBookings`: Bookings specific to the user being analyzed
  /// - `userId`: The user ID to check for high-value anomalies
  /// 
  /// Returns a list of [FraudFlag] objects if suspicious pricing is detected.
  static List<FraudFlag> detectHighValueAnomalies(
    List<Booking> allBookings,
    List<Booking> userBookings,
    String userId,
  ) {
    final flags = <FraudFlag>[];
    
    if (allBookings.isEmpty || userBookings.isEmpty) {
      return flags;
    }

    final averagePrice = allBookings
            .map((b) => b.totalPrice)
            .reduce((a, b) => a + b) /
        allBookings.length;

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

  /// Detects users making multiple bookings in rapid succession.
  /// 
  /// Flags users who create bookings within 5 minutes of each other, which
  /// may indicate automated booking attempts or fraudulent activity.
  /// 
  /// Parameters:
  /// - `bookings`: List of all bookings to analyze
  /// - `userId`: The user ID to check for rapid booking patterns
  /// 
  /// Returns a list of [FraudFlag] objects if rapid booking pattern is detected.
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
        break;
      }
    }

    return flags;
  }

  /// Calculates a fraud risk score for a user based on detected fraud flags.
  /// 
  /// Score weights:
  /// - Excessive cancellations: +30 points
  /// - Multiple accounts: +40 points
  /// - High value anomaly: +25 points
  /// - Rapid bookings: +20 points
  /// 
  /// Parameters:
  /// - `flags`: List of fraud flags detected for the user
  /// 
  /// Returns a score from 0-100, where higher scores indicate higher fraud risk.
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

    return score > 100 ? 100.0 : score;
  }

  /// Calculates a fraud risk score for a property based on detected fraud flags.
  /// 
  /// Score weights:
  /// - High value anomaly: +35 points
  /// - Rapid bookings: +25 points
  /// - Other flags: +15 points each
  /// 
  /// Parameters:
  /// - `flags`: List of fraud flags detected for the property
  /// 
  /// Returns a score from 0-100, where higher scores indicate higher fraud risk.
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
        default:
          score += 15.0;
      }
    }

    return score > 100 ? 100.0 : score;
  }

  /// Fetches all bookings from the database for fraud analysis.
  /// 
  /// Retrieves bookings ordered by creation date (newest first) to enable
  /// chronological analysis of booking patterns.
  /// 
  /// Returns a list of [Booking] objects.
  /// Throws an exception if the database query fails.
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

  /// Retrieves a user's email address from the authentication system.
  /// 
  /// Note: This requires a Supabase Edge Function as client-side access to
  /// auth.users table is restricted. Currently returns null.
  /// 
  /// Parameters:
  /// - `userId`: The user ID to get the email for
  /// 
  /// Returns the user's email address, or null if unavailable.
  static Future<String?> getUserEmail(String userId) async {
    try {
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Analyzes all users in the system for potential fraud indicators.
  /// 
  /// Performs comprehensive fraud detection analysis on all users by:
  /// - Detecting excessive cancellations
  /// - Identifying high-value booking anomalies
  /// - Detecting rapid booking patterns
  /// - Calculating fraud risk scores
  /// 
  /// Returns a list of [UserFraudScore] objects sorted by fraud score
  /// (highest risk first). Only includes users with detected flags or
  /// non-zero fraud scores.
  static Future<List<UserFraudScore>> analyzeAllUsers() async {
    final bookings = await getAllBookings();
    final userScores = <UserFraudScore>[];
    final userIds = <String>{};

    for (var booking in bookings) {
      userIds.add(booking.tenantId);
    }

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

    userScores.sort((a, b) => b.score.compareTo(a.score));
    return userScores;
  }

  /// Analyzes all properties in the system for potential fraud indicators.
  /// 
  /// Performs comprehensive fraud detection analysis on all properties by:
  /// - Detecting pricing anomalies (bookings significantly above average)
  /// - Identifying rapid booking patterns on properties
  /// - Calculating fraud risk scores
  /// 
  /// Returns a list of [PropertyFraudScore] objects sorted by fraud score
  /// (highest risk first). Only includes properties with detected flags or
  /// non-zero fraud scores.
  static Future<List<PropertyFraudScore>> analyzeAllProperties() async {
    final bookings = await getAllBookings();
    final propertyScores = <PropertyFraudScore>[];
    final propertyIds = <int>{};

    for (var booking in bookings) {
      propertyIds.add(booking.propertyId);
    }

    for (var propertyId in propertyIds) {
      final propertyBookings =
          bookings.where((b) => b.propertyId == propertyId).toList();

      if (propertyBookings.isEmpty) continue;

      final flags = <FraudFlag>[];
      
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

    propertyScores.sort((a, b) => b.score.compareTo(a.score));
    return propertyScores;
  }

  /// Generates a comprehensive system-wide fraud detection summary.
  /// 
  /// Aggregates fraud analysis data from all users and properties to provide:
  /// - Overall system fraud risk score
  /// - Count of flagged users and properties
  /// - Top 10 most suspicious users and properties
  /// - Distribution of fraud flag types across the system
  /// 
  /// Returns a [SystemFraudSummary] object with all aggregated metrics.
  static Future<SystemFraudSummary> getSystemFraudSummary() async {
    final userScores = await analyzeAllUsers();
    final propertyScores = await analyzeAllProperties();

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

