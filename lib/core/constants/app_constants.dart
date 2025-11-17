import 'package:flutter/material.dart';

/// Application constants for property types and amenities
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  /// List of all available property types
  static const List<String> propertyTypes = [
    'Private Room',
    'Studio',
    'Apartment',
    'Condominium',
    'Terrace House',
    'Semi-D',
    'Bungalow',
  ];

  /// Map of amenities to their corresponding Material icons
  static final Map<String, IconData> amenityIcons = {
    'Wi-Fi': Icons.wifi,
    'Air Conditioning': Icons.ac_unit,
    'Heating': Icons.thermostat,
    'TV': Icons.tv,
    'Private Entrance': Icons.door_front_door,
    'Washing Machine': Icons.local_laundry_service,
    'Dryer': Icons.dry_cleaning,
    'Iron': Icons.iron,
    'Hot Water': Icons.water_drop,
    'Hair Dryer': Icons.content_cut,
    'Refrigerator': Icons.kitchen,
    'Microwave': Icons.microwave,
    'Stove': Icons.local_fire_department,
    'Oven': Icons.bakery_dining_outlined,
    'Electric Kettle': Icons.electric_bolt,
    'Cooking Basics': Icons.restaurant_menu,
    'Dining Table': Icons.table_restaurant,
    'Dishwasher': Icons.water_drop_outlined,
    'Coffee Maker': Icons.coffee_maker,
    'Kitchen Utensils': Icons.restaurant,
    'Towels & Linens': Icons.bed,
    'Closet': Icons.checkroom,
    'Pillows & Blankets': Icons.hotel,
    'Shower Gel & Shampoo': Icons.shower,
    'Private Bathroom': Icons.bathroom,
    'Elevator': Icons.elevator,
    'Swimming Pool': Icons.pool,
    'Fitness Centre': Icons.fitness_center,
    'Security': Icons.security,
    'Parking': Icons.local_parking,
    'CCTV': Icons.videocam,
    'Balcony': Icons.balcony,
    'Outdoor Space': Icons.yard,
    'Smart TV': Icons.tv,
    'Netflix Ready': Icons.movie,
    'Workspace': Icons.work,
  };

  /// List of all available amenities
  static List<String> get amenities => amenityIcons.keys.toList();

  /// Get icon for a specific amenity
  /// Returns null if amenity is not found
  /// Case-insensitive lookup to handle variations in naming
  static IconData? getAmenityIcon(String amenity) {
    // First try exact match
    if (amenityIcons.containsKey(amenity)) {
      return amenityIcons[amenity];
    }
    
    // Try case-insensitive lookup
    final lowerAmenity = amenity.toLowerCase().trim();
    for (final entry in amenityIcons.entries) {
      if (entry.key.toLowerCase().trim() == lowerAmenity) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Check if a property type is valid
  static bool isValidPropertyType(String propertyType) {
    return propertyTypes.contains(propertyType);
  }

  /// Check if an amenity is valid
  static bool isValidAmenity(String amenity) {
    return amenityIcons.containsKey(amenity);
  }

  // --- Property Listing Constants ---

  /// Budget-friendly price threshold in MYR
  static const double budgetFriendlyThreshold = 150.0;

  /// Minimum number of properties required to display a category
  static const int minPropertiesPerCategory = 2;

  /// Number of recommended properties to show
  static const int recommendedCount = 5;

  /// Number of recently added properties to show
  static const int recentlyAddedCount = 10;

  // --- Booking Constants ---

  /// Standard check-in time (3:00 PM)
  static const int checkInHour = 15;
  static const int checkInMinute = 0;

  /// Standard check-out time (12:00 PM)
  static const int checkOutHour = 13;
  static const int checkOutMinute = 50;

  /// Cleanup/rest period in days (1 day between checkout and next checkin)
  static const int cleaningPeriodDays = 1;

  // --- Cancellation Policy ---

  /// Cancellation policy for Homiego platform
  static const String cancellationPolicy = '''
1. Tenant Cancellations

Full Refund:
Tenants can cancel their booking and receive a full refund (excluding service fees) as long as the check-in date and time is more than 24 hours away from the current time.

No Refund:
To avoid last minute cancellations, once the check-in date and time is 24 hours or less away from the current time, the payment becomes non-refundable.

Early Checkout:
If a tenant decides to leave before the checkout date, the remaining nights will not be refunded.

2. Homeowner Cancellations

Homeowners must honor all confirmed bookings.

If a homeowner cancels:
The tenant will receive a full refund.
The homeowner's account may face temporary suspension or reduced listing visibility for reliability reasons.

3. No-Show Policy

If a tenant fails to check in within 24 hours of the scheduled check-in time and does not contact the host or Homiego Support, the booking will be treated as a no-show with no refund.

4. Exceptional Circumstances

Full refunds may be granted only for verified cases such as:
• Natural disasters or severe weather affecting the property
• Government restrictions or emergencies
• Property safety or habitability issues confirmed by Homiego

5. Refund Process

Approved refunds will be processed within 7–14 business days via the original payment method.
''';
}

