import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/providers/property_providers.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/property_service.dart';
import 'package:homiego/core/constants/app_constants.dart';
import 'package:homiego/widgets/property_box.dart';
import 'package:homiego/features/tenant/views/property_detail_screen.dart';

class TenantHomeScreen extends ConsumerStatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  ConsumerState<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends ConsumerState<TenantHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _minRatingController = TextEditingController();
  final TextEditingController _minMaxGuestsController = TextEditingController();
  
  String? _selectedPropertyType;
  bool _showFilters = false;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minRatingController.dispose();
    _minMaxGuestsController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    final currentSearch = ref.read(searchStateProvider);
    
    if (query.isEmpty && currentSearch.isEmpty) {
      return;
    }
    
    ref.read(searchStateProvider.notifier).state = currentSearch.copyWith(
      query: query.isEmpty ? null : query,
    );
  }

  void _applyFilters() {
    final searchParams = SearchParams(
      query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      propertyType: _selectedPropertyType,
      minPrice: _minPriceController.text.isEmpty ? null : double.tryParse(_minPriceController.text),
      maxPrice: _maxPriceController.text.isEmpty ? null : double.tryParse(_maxPriceController.text),
      minRating: _minRatingController.text.isEmpty ? null : double.tryParse(_minRatingController.text),
      minMaxGuests: _minMaxGuestsController.text.isEmpty ? null : int.tryParse(_minMaxGuestsController.text),
    );
    
    ref.read(searchStateProvider.notifier).state = searchParams;
    setState(() {
      _showFilters = false;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _minPriceController.clear();
    _maxPriceController.clear();
    _minRatingController.clear();
    _minMaxGuestsController.clear();
    _selectedPropertyType = null;
    ref.read(searchStateProvider.notifier).state = const SearchParams();
    setState(() {
      _showFilters = false;
    });
  }


  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final isSearching = !searchState.isEmpty;
    final authStateAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: authStateAsync.when(
          data: (authState) {
            final userName = authState.profile?.fullName?.split(' ').first ?? 'Guest';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getGreeting(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12,
                      ),
                ),
                Text(
                  userName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                ),
              ],
            );
          },
          loading: () => const Text('Home'),
          error: (_, __) => const Text('Home'),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search properties...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : IconButton(
                            icon: const Icon(Icons.tune),
                            onPressed: () {
                              setState(() {
                                _showFilters = !_showFilters;
                              });
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
                if (_showFilters) ...[
                  const SizedBox(height: 12),
                  _buildFilters(),
                ],
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (isSearching) {
                  ref.invalidate(searchPropertiesProvider(searchState));
                } else {
                  // Refresh all providers
                  ref.invalidate(recommendedPropertiesProvider);
                  ref.invalidate(recentlyAddedPropertiesProvider);
                  ref.invalidate(budgetFriendlyPropertiesProvider);
                  ref.invalidate(groupFamilyPropertiesProvider);
                  ref.invalidate(privateStayPropertiesProvider);
                  ref.invalidate(topHostPropertiesProvider);
                }
              },
              child: isSearching
                  ? _buildSearchResults()
                  : _buildCategories(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            
            // Property Type
            DropdownButtonFormField<String>(
              value: _selectedPropertyType,
              decoration: const InputDecoration(
                labelText: 'Property Type',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Types'),
                ),
                ...AppConstants.propertyTypes.map((type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPropertyType = value;
                });
              },
            ),
            const SizedBox(height: 12),
            
            // Price Range
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Min Price (RM)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Max Price (RM)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Rating
            TextField(
              controller: _minRatingController,
              decoration: const InputDecoration(
                labelText: 'Min Rating (0-5)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            
            // Max Guests
            TextField(
              controller: _minMaxGuestsController,
              decoration: const InputDecoration(
                labelText: 'Min Max Guests',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            
            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSearchResults() {
    final searchState = ref.watch(searchStateProvider);
    final searchResultsAsync = ref.watch(searchPropertiesProvider(searchState));

    return searchResultsAsync.when(
      data: (properties) {
        if (properties.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No properties found',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75, // Fixed aspect ratio for property boxes
          ),
          itemCount: properties.length,
          itemBuilder: (context, index) {
            return AspectRatio(
              aspectRatio: 0.75, // Wrapper aspect ratio to prevent UI glitching
              child: _PropertyCard(property: properties[index]),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return ListView(
      children: [
        // Recommended for You
        _CategorySection(
          title: 'Recommended for You',
          provider: recommendedPropertiesProvider,
        ),

        // Recently Added
        _CategorySection(
          title: 'Recently Added',
          provider: recentlyAddedPropertiesProvider,
        ),

        // Budget-Friendly
        _CategorySection(
          title: 'Budget-Friendly',
          provider: budgetFriendlyPropertiesProvider,
        ),

        // Group / Families
        _CategorySection(
          title: 'Group / Families',
          provider: groupFamilyPropertiesProvider,
        ),

        // Private Stays
        _CategorySection(
          title: 'Private Stays',
          provider: privateStayPropertiesProvider,
        ),

        // Top Host
        _CategorySection(
          title: 'Top Host',
          provider: topHostPropertiesProvider,
        ),
      ],
    );
  }
}

/// Widget for displaying a category section with carousel horizontal scrolling
class _CategorySection extends ConsumerStatefulWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<Property>>> provider;

  const _CategorySection({
    required this.title,
    required this.provider,
  });

  @override
  ConsumerState<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends ConsumerState<_CategorySection> {


  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(widget.provider);

    return propertiesAsync.when(
      data: (properties) {
        // Only show if we have at least 2 properties
        if (properties.length < AppConstants.minPropertiesPerCategory) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            SizedBox(
              height: 230, // Fixed height for property boxes
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: AspectRatio(
                      aspectRatio: 0.75, // Fixed aspect ratio for property boxes
                      child: _PropertyCard(property: properties[index]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const SizedBox.shrink(), // Don't show loading, just hide section
      error: (error, stack) => const SizedBox.shrink(), // Hide on error
    );
  }
}


/// Widget for displaying a property card with image and rating
class _PropertyCard extends ConsumerStatefulWidget {
  final Property property;

  const _PropertyCard({required this.property});

  @override
  ConsumerState<_PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends ConsumerState<_PropertyCard> {
  String? imageUrl;
  double rating = 0.0;
  int reviewCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPropertyData();
  }

  Future<void> _loadPropertyData() async {
    try {
      // Load image and rating in parallel
      final results = await Future.wait([
        PropertyService.getPropertyImageUrl(widget.property.id),
        PropertyService.getPropertyRating(widget.property.id),
      ]);

      if (mounted) {
        setState(() {
          imageUrl = results[0] as String?;
          final ratingData = results[1] as Map<String, dynamic>;
          rating = ratingData['rating'] as double;
          reviewCount = ratingData['reviewCount'] as int;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PropertyBox(
      imageUrl: imageUrl ??
          'https://media.istockphoto.com/id/1147544807/vector/thumbnail-image-vector-graphic.jpg?s=612x612&w=0&k=20&c=rnCKVbdxqkjlcs3xH87-9gocETqpspHFXu5dIGB4wuM=',
      name: widget.property.title,
      location: widget.property.address,
      rating: rating,
      reviewCount: reviewCount,
      price: widget.property.pricePerNight,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PropertyDetailScreen(property: widget.property),
          ),
        );
      },
    );
  }
}
