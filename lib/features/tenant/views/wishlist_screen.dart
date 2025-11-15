import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/property_service.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/widgets/property_box.dart';
import 'package:homiego/features/tenant/views/property_detail_screen.dart';

class TenantWishlistScreen extends ConsumerStatefulWidget {
  const TenantWishlistScreen({super.key});

  @override
  ConsumerState<TenantWishlistScreen> createState() => _TenantWishlistScreenState();
}

class _TenantWishlistScreenState extends ConsumerState<TenantWishlistScreen> with AutomaticKeepAliveClientMixin {
  List<Property>? _wishlistProperties;
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  // Public method to refresh wishlist from parent
  void refreshWishlist() {
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = ref.read(authNotifierProvider);
      final user = authState.value?.user;
      
      if (user == null) {
        setState(() {
          _isLoading = false;
          _error = 'Please log in to view your wishlist';
        });
        return;
      }

      // Fetch wishlist items with properties using a join
      final wishlistResponse = await supabase
          .from('wishlists')
          .select('property_id, properties(*)')
          .eq('tenant_id', user.id);

      final wishlistData = wishlistResponse as List;
      
      if (wishlistData.isEmpty) {
        setState(() {
          _wishlistProperties = [];
          _isLoading = false;
        });
        return;
      }

      // Extract properties from the joined response
      final properties = <Property>[];
      for (final item in wishlistData) {
        try {
          final propertyData = item['properties'];
          if (propertyData != null && propertyData is Map) {
            final property = Property.fromMap(Map<String, dynamic>.from(propertyData));
            // Only include approved properties
            if (property.status == PropertyStatus.approved) {
              properties.add(property);
            }
          }
        } catch (e) {
          // Skip properties that fail to parse
          print('Error parsing property from wishlist: $e');
        }
      }

      if (mounted) {
        setState(() {
          _wishlistProperties = properties;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading wishlist: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadWishlist,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _wishlistProperties == null || _wishlistProperties!.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Your wishlist is empty',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadWishlist,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final gridConfig = _calculateGridConfig(constraints.maxWidth);
                          
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridConfig.crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: gridConfig.childAspectRatio,
                            ),
                            itemCount: _wishlistProperties!.length,
                            itemBuilder: (context, index) {
                              return SizedBox(
                                width: gridConfig.boxWidth,
                                child: _PropertyCard(
                                  property: _wishlistProperties![index],
                                  onWishlistChanged: refreshWishlist,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }

  _GridConfig _calculateGridConfig(double availableWidth) {
    const double minBoxWidth = 190.0;
    const double maxBoxWidth = 250.0;
    const double horizontalPadding = 16.0;
    const double boxSpacing = 12.0;
    
    final double usableWidth = availableWidth - (horizontalPadding * 2);
    
    int crossAxisCount = 2;
    double boxWidth = minBoxWidth;
    
    // Calculate how many boxes can fit
    for (int i = 2; i <= 4; i++) {
      final double calculatedWidth = (usableWidth - (boxSpacing * (i - 1))) / i;
      
      if (calculatedWidth >= minBoxWidth && calculatedWidth <= maxBoxWidth) {
        crossAxisCount = i;
        boxWidth = calculatedWidth;
      } else if (calculatedWidth < minBoxWidth) {
        break;
      }
    }
    
    boxWidth = boxWidth.clamp(minBoxWidth, maxBoxWidth);
    
    // PropertyBox height is approximately boxWidth * 1.2
    final double childAspectRatio = boxWidth / (boxWidth * 1.2);
    
    return _GridConfig(
      crossAxisCount: crossAxisCount,
      boxWidth: boxWidth,
      childAspectRatio: childAspectRatio,
    );
  }
}

class _GridConfig {
  final int crossAxisCount;
  final double boxWidth;
  final double childAspectRatio;

  _GridConfig({
    required this.crossAxisCount,
    required this.boxWidth,
    required this.childAspectRatio,
  });
}

/// Widget for displaying a property card with image and rating
class _PropertyCard extends ConsumerStatefulWidget {
  final Property property;
  final VoidCallback onWishlistChanged;

  const _PropertyCard({
    required this.property,
    required this.onWishlistChanged,
  });

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
          'https://via.placeholder.com/300x200?text=No+Image',
      name: widget.property.title,
      location: widget.property.address,
      rating: rating,
      reviewCount: reviewCount,
      price: widget.property.pricePerNight,
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PropertyDetailScreen(property: widget.property),
          ),
        );
        // Refresh wishlist if it was changed in the detail screen
        if (result == true && mounted) {
          widget.onWishlistChanged();
        }
      },
    );
  }
}

