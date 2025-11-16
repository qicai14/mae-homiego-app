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

      // Step 1: Fetch wishlist IDs only (avoid recursive queries)
      final wishlistResponse = await supabase
          .from('wishlists')
          .select('property_id')
          .eq('tenant_id', user.id);

      final wishlistData = wishlistResponse as List;
      
      if (wishlistData.isEmpty) {
        setState(() {
          _wishlistProperties = [];
          _isLoading = false;
        });
        return;
      }

      // Extract property IDs
      final propertyIds = wishlistData
          .map((item) => item['property_id'] as int)
          .whereType<int>()
          .toList();

      if (propertyIds.isEmpty) {
        setState(() {
          _wishlistProperties = [];
          _isLoading = false;
        });
        return;
      }

      // Step 2: Fetch properties separately using the IDs
      // This avoids recursive foreign key traversal that causes stack overflow
      final propertiesResponse = await supabase
          .from('properties')
          .select()
          .inFilter('id', propertyIds)
          .eq('status', PropertyStatus.approved.name);

      final properties = (propertiesResponse as List)
          .map((json) {
            try {
              return Property.fromMap(json);
            } catch (e) {
              print('Error parsing property from wishlist: $e');
              return null;
            }
          })
          .whereType<Property>()
          .toList();

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
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75, // Fixed aspect ratio for property boxes
                        ),
                        itemCount: _wishlistProperties!.length,
                        itemBuilder: (context, index) {
                          return _PropertyCard(
                            property: _wishlistProperties![index],
                            onWishlistChanged: refreshWishlist,
                          );
                        },
                      ),
                    ),
    );
  }

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

