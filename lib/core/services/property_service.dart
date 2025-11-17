import 'dart:math';
import '../models/property.dart';
import '../models/property_image.dart';
import '../models/review.dart';
import '../models/profile.dart';
import '../models/booking.dart';
import '../services/supabase_client.dart';
import '../constants/app_constants.dart';

/// Property service
class PropertyService {
  /// Get recommended properties (random)
  static Future<List<Property>> getRecommendedProperties() async {
    try {
      final response = await supabase
          .from('properties')
          .select()
          .eq('status', 'approved')
          .limit(AppConstants.recommendedCount * 3);

      final properties = (response as List)
          .map((json) => Property.fromMap(json))
          .toList();

      properties.shuffle(Random());
      return properties.take(AppConstants.recommendedCount).toList();
    } catch (e) {
      print('Error fetching recommended properties: $e');
      return [];
    }
  }

  /// Get recently added properties
  static Future<List<Property>> getRecentlyAddedProperties() async {
    try {
      final response = await supabase
          .from('properties')
          .select()
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(AppConstants.recentlyAddedCount);

      return (response as List)
          .map((json) => Property.fromMap(json))
          .toList();
    } catch (e) {
      print('Error fetching recently added properties: $e');
      return [];
    }
  }

  /// Get budget-friendly properties
  static Future<List<Property>> getBudgetFriendlyProperties() async {
    try {
      final response = await supabase
          .from('properties')
          .select()
          .eq('status', 'approved')
          .lt('price_per_night', AppConstants.budgetFriendlyThreshold)
          .order('price_per_night', ascending: true);

      return (response as List)
          .map((json) => Property.fromMap(json))
          .toList();
    } catch (e) {
      print('Error fetching budget-friendly properties: $e');
      return [];
    }
  }

  /// Get group/family properties
  static Future<List<Property>> getGroupFamilyProperties() async {
    try {
      final response = await supabase
          .from('properties')
          .select()
          .eq('status', 'approved')
          .gte('max_guests', 5)
          .order('max_guests', ascending: false);

      return (response as List)
          .map((json) => Property.fromMap(json))
          .toList();
    } catch (e) {
      print('Error fetching group/family properties: $e');
      return [];
    }
  }

  /// Get private room properties
  static Future<List<Property>> getPrivateStayProperties() async {
    try {
      final response = await supabase
          .from('properties')
          .select()
          .eq('status', 'approved')
          .eq('property_type', 'Private Room');

      return (response as List)
          .map((json) => Property.fromMap(json))
          .toList();
    } catch (e) {
      print('Error fetching private stay properties: $e');
      return [];
    }
  }

  /// Get top host properties
  static Future<List<Property>> getTopHostProperties() async {
    try {
      final propertiesResponse = await supabase
          .from('properties')
          .select()
          .eq('status', 'approved');

      final allProperties = (propertiesResponse as List)
          .map((json) => Property.fromMap(json))
          .toList();

      if (allProperties.isEmpty) return [];

      final reviewsResponse = await supabase.from('reviews').select();
      final allReviews = (reviewsResponse as List)
          .map((json) => Review.fromMap(json))
          .toList();

      final bookingsResponse = await supabase.from('bookings').select();
      final allBookings = (bookingsResponse as List)
          .map((json) => Booking.fromMap(json))
          .toList();

      final bookingToPropertyMap = <int, int>{};
      for (final booking in allBookings) {
        bookingToPropertyMap[booking.id] = booking.propertyId;
      }

      final Map<String, List<int>> hostRatings = {};
      final Map<String, int> hostReviewCounts = {};

      for (final review in allReviews) {
        final propertyId = bookingToPropertyMap[review.bookingId];
        if (propertyId == null) continue;

        final property = allProperties.firstWhere(
          (p) => p.id == propertyId,
          orElse: () => allProperties.first,
        );

        hostRatings.putIfAbsent(property.hostId, () => []).add(review.rating);
        hostReviewCounts[property.hostId] =
            (hostReviewCounts[property.hostId] ?? 0) + 1;
      }

      final Map<String, double> hostAvgRatings = {};
      hostRatings.forEach((hostId, ratings) {
        hostAvgRatings[hostId] =
            ratings.reduce((a, b) => a + b) / ratings.length;
      });

      final topHostIds = hostAvgRatings.entries
          .where((entry) =>
              entry.value >= 4.0 &&
              (hostReviewCounts[entry.key] ?? 0) >= 3)
          .map((entry) => entry.key)
          .toSet();

      final topHostProperties = allProperties
          .where((property) => topHostIds.contains(property.hostId))
          .toList();

      topHostProperties.sort((a, b) {
        final ratingA = hostAvgRatings[a.hostId] ?? 0.0;
        final ratingB = hostAvgRatings[b.hostId] ?? 0.0;
        return ratingB.compareTo(ratingA);
      });

      return topHostProperties;
    } catch (e) {
      print('Error fetching top host properties: $e');
      return [];
    }
  }

  /// Get first property image URL
  static Future<String?> getPropertyImageUrl(int propertyId) async {
    try {
      final response = await supabase
          .from('property_images')
          .select()
          .eq('property_id', propertyId)
          .order('position', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final image = PropertyImage.fromMap(response);
      
      if (image.storagePath.startsWith('http://') || 
          image.storagePath.startsWith('https://')) {
        return image.storagePath;
      }
      
      try {
        final publicUrl = supabase.storage
            .from('property-images')
            .getPublicUrl(image.storagePath);
        return publicUrl;
      } catch (e) {
        print('Error getting public URL from storage: $e');
        return null;
      }
    } catch (e) {
      print('Error fetching property image: $e');
      return null;
    }
  }

  /// Get property rating and review count
  static Future<Map<String, dynamic>> getPropertyRating(int propertyId) async {
    try {
      final bookingsResponse = await supabase
          .from('bookings')
          .select('id')
          .eq('property_id', propertyId);

      final bookings = (bookingsResponse as List).map((json) => json['id'] as int).toList();
      
      if (bookings.isEmpty) {
        return {'rating': 0.0, 'reviewCount': 0};
      }

      final reviewsResponse = await supabase
          .from('reviews')
          .select()
          .inFilter('booking_id', bookings);

      final reviews = (reviewsResponse as List)
          .map((json) => Review.fromMap(json))
          .toList();

      if (reviews.isEmpty) {
        return {'rating': 0.0, 'reviewCount': 0};
      }

      final avgRating =
          reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

      return {
        'rating': avgRating,
        'reviewCount': reviews.length,
      };
    } catch (e) {
      print('Error fetching property rating: $e');
      return {'rating': 0.0, 'reviewCount': 0};
    }
  }

  /// Search properties
  static Future<List<Property>> searchProperties({
    String? query,
    String? propertyType,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    int? minMaxGuests,
  }) async {
    try {
      var queryBuilder = supabase
          .from('properties')
          .select()
          .eq('status', 'approved');

      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('title', '%$query%');
      }

      if (propertyType != null && propertyType.isNotEmpty) {
        queryBuilder = queryBuilder.eq('property_type', propertyType);
      }

      if (minPrice != null) {
        queryBuilder = queryBuilder.gte('price_per_night', minPrice);
      }
      if (maxPrice != null) {
        queryBuilder = queryBuilder.lte('price_per_night', maxPrice);
      }

      if (minMaxGuests != null) {
        queryBuilder = queryBuilder.gte('max_guests', minMaxGuests);
      }

      final response = await queryBuilder;

      final properties = (response as List)
          .map((json) => Property.fromMap(json))
          .toList();

      if (minRating != null && minRating > 0) {
        final filteredProperties = <Property>[];
        for (final property in properties) {
          final ratingData = await getPropertyRating(property.id);
          final rating = ratingData['rating'] as double;
          if (rating >= minRating) {
            filteredProperties.add(property);
          }
        }
        return filteredProperties;
      }

      return properties;
    } catch (e) {
      print('Error searching properties: $e');
      return [];
    }
  }

  /// Get all property images
  static Future<List<String>> getPropertyImages(int propertyId) async {
    try {
      final response = await supabase
          .from('property_images')
          .select()
          .eq('property_id', propertyId)
          .order('position', ascending: true);

      final images = (response as List)
          .map((json) => PropertyImage.fromMap(json))
          .toList();

      final imageUrls = <String>[];
      for (final image in images) {
        if (image.storagePath.startsWith('http://') || 
            image.storagePath.startsWith('https://')) {
          imageUrls.add(image.storagePath);
        } else {
          try {
            final publicUrl = supabase.storage
                .from('property-images')
                .getPublicUrl(image.storagePath);
            imageUrls.add(publicUrl);
          } catch (e) {
            print('Error getting public URL for image ${image.id}: $e');
          }
        }
      }
      return imageUrls;
    } catch (e) {
      print('Error fetching property images: $e');
      return [];
    }
  }

  /// Get property reviews
  static Future<List<Review>> getPropertyReviews(int propertyId) async {
    try {
      final bookingsResponse = await supabase
          .from('bookings')
          .select('id')
          .eq('property_id', propertyId);

      final bookings = (bookingsResponse as List).map((json) => json['id'] as int).toList();
      
      if (bookings.isEmpty) {
        return [];
      }

      final response = await supabase
          .from('reviews')
          .select()
          .inFilter('booking_id', bookings)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Review.fromMap(json))
          .toList();
    } catch (e) {
      print('Error fetching property reviews: $e');
      return [];
    }
  }

  /// Get host profile
  static Future<Profile?> getHostProfile(String hostId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', hostId)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromMap(response);
    } catch (e) {
      print('Error fetching host profile: $e');
      return null;
    }
  }

  /// Get tenant name
  static Future<String?> getTenantName(String tenantId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', tenantId)
          .maybeSingle();

      return response?['full_name'] as String?;
    } catch (e) {
      print('Error fetching tenant name: $e');
      return null;
    }
  }

  /// Get booking by ID
  static Future<Booking?> getBookingById(int bookingId) async {
    try {
      final response = await supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .maybeSingle();

      if (response == null) return null;
      return Booking.fromMap(response);
    } catch (e) {
      print('Error fetching booking: $e');
      return null;
    }
  }

  /// Get property by ID
  static Future<Property?> getPropertyById(int propertyId) async {
    try {
      final response = await supabase
          .from('properties')
          .select()
          .eq('id', propertyId)
          .maybeSingle();

      if (response == null) return null;
      return Property.fromMap(response);
    } catch (e) {
      print('Error fetching property: $e');
      return null;
    }
  }
}

