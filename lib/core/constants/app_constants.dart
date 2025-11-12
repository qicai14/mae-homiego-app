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
    'Extra Pillows & Blankets': Icons.hotel,
    'Shower Gel & Shampoo': Icons.shower,
    'Private Bathroom': Icons.bathroom,
    'Elevator': Icons.elevator,
    'Swimming Pool': Icons.pool,
    'Fitness Centre': Icons.fitness_center,
    'Security': Icons.security,
    'Parking (Free or Paid)': Icons.local_parking,
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
  static IconData? getAmenityIcon(String amenity) {
    return amenityIcons[amenity];
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
  static const double budgetFriendlyThreshold = 100.0;

  /// Maximum radius for "Near Me" category in kilometers
  static const double nearMeRadiusKm = 15.0;

  /// Minimum number of properties required to display a category
  static const int minPropertiesPerCategory = 2;

  /// Number of recommended properties to show
  static const int recommendedCount = 5;

  /// Number of recently added properties to show
  static const int recentlyAddedCount = 10;
}

