import 'dart:math';
import '../models/property.dart';
import '../models/property_image.dart';
import '../models/review.dart';
import '../models/profile.dart';
import '../models/booking.dart';
import '../services/supabase_client.dart';
import '../constants/app_constants.dart';
import '../utils/distance_calculator.dart';

/// Service for fetching and filtering properties
class PropertyService {
  /// Fetch recommended properties (5 random listings)
  static Future<List<Property>> getRecommendedProperties() async {
    try {
      final response = await supabase
          .from('properties')
          .select()
          .eq('status', 'approved')
          .limit(AppConstants.recommendedCount * 3); // Fetch more to randomize

      final properties = (response as List)
          .map((json) => Property.fromMap(json))
          .toList();

      // Shuffle and take first 5
      properties.shuffle(Random());
      return properties.take(AppConstants.recommendedCount).toList();
    } catch (e) {
      print('Error fetching recommended properties: $e');
      return [];
    }
  }

  /// Fetch recently added properties
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

  /// Fetch properties near user's location
  static Future<List<Property>> getNearMeProperties(
    double userLat,
    double userLon,
  ) async {
    try {
      // Fetch all approved properties
      final response = await supabase
          .from('properties')
          .select()
          .eq('status', 'approved');

      final allProperties = (response as List)
          .map((json) => Property.fromMap(json))
          .toList();

      // Filter by distance
      final nearProperties = allProperties.where((property) {
        final distance = DistanceCalculator.calculateDistance(
          userLat,
          userLon,
          property.latitude,
          property.longitude,
        );
        return distance <= AppConstants.nearMeRadiusKm;
      }).toList();

      // Sort by distance (closest first)
      nearProperties.sort((a, b) {
        final distA = DistanceCalculator.calculateDistance(
          userLat,
          userLon,
          a.latitude,
          a.longitude,
        );
        final distB = DistanceCalculator.calculateDistance(
          userLat,
          userLon,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });

      return nearProperties;
    } catch (e) {
      print('Error fetching near me properties: $e');
      return [];
    }
  }

  /// Fetch budget-friendly properties
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

  /// Fetch properties suitable for groups/families
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

  /// Fetch private room properties
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

  /// Fetch properties from top hosts (hosts with high ratings/many reviews)
  static Future<List<Property>> getTopHostProperties() async {
    try {
      // First, get all approved properties
      final propertiesResponse = await supabase
          .from('properties')
          .select()
          .eq('status', 'approved');

      final allProperties = (propertiesResponse as List)
          .map((json) => Property.fromMap(json))
          .toList();

      if (allProperties.isEmpty) return [];

      // Get all reviews to calculate host ratings
      final reviewsResponse = await supabase.from('reviews').select();

      final allReviews = (reviewsResponse as List)
          .map((json) => Review.fromMap(json))
          .toList();

      // Get all bookings to map booking_id to property_id
      final bookingsResponse = await supabase.from('bookings').select();
      final allBookings = (bookingsResponse as List)
          .map((json) => Booking.fromMap(json))
          .toList();

      // Create a map from booking_id to property_id
      final bookingToPropertyMap = <int, int>{};
      for (final booking in allBookings) {
        bookingToPropertyMap[booking.id] = booking.propertyId;
      }

      // Calculate average rating and review count per host
      final Map<String, List<int>> hostRatings = {};
      final Map<String, int> hostReviewCounts = {};

      for (final review in allReviews) {
        // Get property_id from booking_id
        final propertyId = bookingToPropertyMap[review.bookingId];
        if (propertyId == null) continue;

        // Find the property to get host_id
        final property = allProperties.firstWhere(
          (p) => p.id == propertyId,
          orElse: () => allProperties.first,
        );

        hostRatings.putIfAbsent(property.hostId, () => []).add(review.rating);
        hostReviewCounts[property.hostId] =
            (hostReviewCounts[property.hostId] ?? 0) + 1;
      }

      // Calculate average ratings
      final Map<String, double> hostAvgRatings = {};
      hostRatings.forEach((hostId, ratings) {
        hostAvgRatings[hostId] =
            ratings.reduce((a, b) => a + b) / ratings.length;
      });

      // Filter hosts with high ratings (>= 4.0) and multiple reviews (>= 3)
      final topHostIds = hostAvgRatings.entries
          .where((entry) =>
              entry.value >= 4.0 &&
              (hostReviewCounts[entry.key] ?? 0) >= 3)
          .map((entry) => entry.key)
          .toSet();

      // Get properties from top hosts
      final topHostProperties = allProperties
          .where((property) => topHostIds.contains(property.hostId))
          .toList();

      // Sort by host rating (descending)
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

  /// Fetch verified properties
  static Future<List<Property>> getVerifiedProperties() async {
    try {
      final response = await supabase
          .from('properties')
          .select()
          .eq('status', 'approved')
          .eq('verified', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Property.fromMap(json))
          .toList();
    } catch (e) {
      print('Error fetching verified properties: $e');
      return [];
    }
  }

  /// Get the first image URL for a property
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
      
      // If storage_path is already a full URL, return it
      if (image.storagePath.startsWith('http://') || 
          image.storagePath.startsWith('https://')) {
        return image.storagePath;
      }
      
      // Otherwise, get the public URL from Supabase storage
      // Assuming images are stored in a 'property-images' bucket
      try {
        final publicUrl = supabase.storage
            .from('property-images')
            .getPublicUrl(image.storagePath);
        return publicUrl;
      } catch (e) {
        // If storage bucket doesn't exist or path is invalid, return null
        print('Error getting public URL from storage: $e');
        return null;
      }
    } catch (e) {
      print('Error fetching property image: $e');
      return null;
    }
  }

  /// Get average rating and review count for a property
  static Future<Map<String, dynamic>> getPropertyRating(int propertyId) async {
    try {
      // Get all bookings for this property
      final bookingsResponse = await supabase
          .from('bookings')
          .select('id')
          .eq('property_id', propertyId);

      final bookings = (bookingsResponse as List).map((json) => json['id'] as int).toList();
      
      if (bookings.isEmpty) {
        return {'rating': 0.0, 'reviewCount': 0};
      }

      // Get all reviews for these bookings
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

  /// Search properties with filters
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

      // Filter by property name (title)
      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('title', '%$query%');
      }

      // Filter by property type
      if (propertyType != null && propertyType.isNotEmpty) {
        queryBuilder = queryBuilder.eq('property_type', propertyType);
      }

      // Filter by price range
      if (minPrice != null) {
        queryBuilder = queryBuilder.gte('price_per_night', minPrice);
      }
      if (maxPrice != null) {
        queryBuilder = queryBuilder.lte('price_per_night', maxPrice);
      }

      // Filter by max guests
      if (minMaxGuests != null) {
        queryBuilder = queryBuilder.gte('max_guests', minMaxGuests);
      }

      final response = await queryBuilder;

      final properties = (response as List)
          .map((json) => Property.fromMap(json))
          .toList();

      // Filter by rating (requires fetching reviews)
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

  /// Get all images for a property
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
        // If storage_path is already a full URL, use it
        if (image.storagePath.startsWith('http://') || 
            image.storagePath.startsWith('https://')) {
          imageUrls.add(image.storagePath);
        } else {
          // Otherwise, get the public URL from Supabase storage
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

  /// Get reviews for a property
  static Future<List<Review>> getPropertyReviews(int propertyId) async {
    try {
      // Get all bookings for this property
      final bookingsResponse = await supabase
          .from('bookings')
          .select('id')
          .eq('property_id', propertyId);

      final bookings = (bookingsResponse as List).map((json) => json['id'] as int).toList();
      
      if (bookings.isEmpty) {
        return [];
      }

      // Get all reviews for these bookings
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

  /// Get host profile by host ID
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

  /// Get tenant name for a review
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
}

