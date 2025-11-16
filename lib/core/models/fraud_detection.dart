import 'package:homiego/core/models/booking.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/profile.dart';

/// Represents a fraud detection flag with details
class FraudFlag {
  final String type; // 'excessive_cancellations', 'multiple_accounts', 'high_value_anomaly', 'rapid_bookings'
  final String description;
  final DateTime detectedAt;
  final Map<String, dynamic> metadata; // Additional context

  FraudFlag({
    required this.type,
    required this.description,
    required this.detectedAt,
    this.metadata = const {},
  });
}

/// Fraud score for a user
class UserFraudScore {
  final String userId;
  final String? userEmail;
  final String? userName;
  final double score; // 0-100, higher = more suspicious
  final List<FraudFlag> flags;
  final int totalBookings;
  final int cancelledBookings;
  final double totalSpent;

  UserFraudScore({
    required this.userId,
    this.userEmail,
    this.userName,
    required this.score,
    required this.flags,
    required this.totalBookings,
    required this.cancelledBookings,
    required this.totalSpent,
  });
}

/// Fraud score for a property
class PropertyFraudScore {
  final int propertyId;
  final String propertyTitle;
  final String hostId;
  final String? hostName;
  final double score; // 0-100, higher = more suspicious
  final List<FraudFlag> flags;
  final int totalBookings;
  final double averagePrice;
  final double highestPrice;

  PropertyFraudScore({
    required this.propertyId,
    required this.propertyTitle,
    required this.hostId,
    this.hostName,
    required this.score,
    required this.flags,
    required this.totalBookings,
    required this.averagePrice,
    required this.highestPrice,
  });
}

/// Overall system fraud detection summary
class SystemFraudSummary {
  final double overallScore; // 0-100, average of all user/property scores
  final int flaggedUsers;
  final int flaggedProperties;
  final List<UserFraudScore> topSuspiciousUsers;
  final List<PropertyFraudScore> topSuspiciousProperties;
  final Map<String, int> flagCounts; // Count of each fraud type

  SystemFraudSummary({
    required this.overallScore,
    required this.flaggedUsers,
    required this.flaggedProperties,
    required this.topSuspiciousUsers,
    required this.topSuspiciousProperties,
    required this.flagCounts,
  });
}

/// Detailed fraud detection result for a specific entity
class FraudDetectionResult {
  final String? userId;
  final int? propertyId;
  final List<FraudFlag> flags;
  final double score;
  final Profile? userProfile;
  final Property? property;
  final List<Booking> relatedBookings;

  FraudDetectionResult({
    this.userId,
    this.propertyId,
    required this.flags,
    required this.score,
    this.userProfile,
    this.property,
    required this.relatedBookings,
  });
}

