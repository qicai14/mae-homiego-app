import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/property.dart';
import '../services/property_service.dart';

/// Provider for recommended properties (with caching)
final recommendedPropertiesProvider =
    FutureProvider.autoDispose<List<Property>>((ref) async {
  return await PropertyService.getRecommendedProperties();
});

/// Provider for recently added properties (with caching)
final recentlyAddedPropertiesProvider =
    FutureProvider.autoDispose<List<Property>>((ref) async {
  return await PropertyService.getRecentlyAddedProperties();
});

/// Provider for budget-friendly properties (with caching)
final budgetFriendlyPropertiesProvider =
    FutureProvider.autoDispose<List<Property>>((ref) async {
  return await PropertyService.getBudgetFriendlyProperties();
});

/// Provider for group/family properties (with caching)
final groupFamilyPropertiesProvider =
    FutureProvider.autoDispose<List<Property>>((ref) async {
  return await PropertyService.getGroupFamilyProperties();
});

/// Provider for private stay properties (with caching)
final privateStayPropertiesProvider =
    FutureProvider.autoDispose<List<Property>>((ref) async {
  return await PropertyService.getPrivateStayProperties();
});

/// Provider for top host properties (with caching)
final topHostPropertiesProvider = FutureProvider.autoDispose<List<Property>>((ref) async {
  return await PropertyService.getTopHostProperties();
});

/// Search parameters model
class SearchParams {
  final String? query;
  final String? propertyType;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final int? minMaxGuests;

  const SearchParams({
    this.query,
    this.propertyType,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.minMaxGuests,
  });

  bool get isEmpty => 
      (query == null || query!.isEmpty) &&
      (propertyType == null || propertyType!.isEmpty) &&
      minPrice == null &&
      maxPrice == null &&
      minRating == null &&
      minMaxGuests == null;

  SearchParams copyWith({
    String? query,
    String? propertyType,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    int? minMaxGuests,
    bool clearQuery = false,
    bool clearPropertyType = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearMinRating = false,
    bool clearMinMaxGuests = false,
  }) {
    return SearchParams(
      query: clearQuery ? null : (query ?? this.query),
      propertyType: clearPropertyType ? null : (propertyType ?? this.propertyType),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      minMaxGuests: clearMinMaxGuests ? null : (minMaxGuests ?? this.minMaxGuests),
    );
  }
}

/// Provider for search results
final searchPropertiesProvider =
    FutureProvider.autoDispose.family<List<Property>, SearchParams>((ref, params) async {
  if (params.isEmpty) {
    return [];
  }
  return await PropertyService.searchProperties(
    query: params.query,
    propertyType: params.propertyType,
    minPrice: params.minPrice,
    maxPrice: params.maxPrice,
    minRating: params.minRating,
    minMaxGuests: params.minMaxGuests,
  );
});

/// Provider for search state
final searchStateProvider = StateProvider<SearchParams>((ref) {
  return const SearchParams();
});

