import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/review.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/services/property_service.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/providers/comparison_provider.dart';
import 'package:homiego/core/constants/app_constants.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/features/booking/views/booking_detail_screen.dart';
import 'package:homiego/features/tenant/views/property_reviews_screen.dart';
import 'package:homiego/widgets/comparison_bottom_sheet.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final Property property;

  const PropertyDetailScreen({
    super.key,
    required this.property,
  });

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  List<String> _images = [];
  double _rating = 0.0;
  int _reviewCount = 0;
  List<Review> _reviews = [];
  Profile? _hostProfile;
  bool _isFavorite = false;
  bool _isLoading = true;
  int _currentImageIndex = 0;
  final PageController _imagePageController = PageController();
  bool _wishlistChanged = false;

  @override
  void initState() {
    super.initState();
    _loadPropertyData();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _loadPropertyData() async {
    try {
      final results = await Future.wait([
        PropertyService.getPropertyImages(widget.property.id),
        PropertyService.getPropertyRating(widget.property.id),
        PropertyService.getPropertyReviews(widget.property.id),
        PropertyService.getHostProfile(widget.property.hostId),
        _checkWishlistStatus(),
      ]);

      if (mounted) {
        setState(() {
          _images = results[0] as List<String>;
          final ratingData = results[1] as Map<String, dynamic>;
          _rating = ratingData['rating'] as double;
          _reviewCount = ratingData['reviewCount'] as int;
          _reviews = results[2] as List<Review>;
          _hostProfile = results[3] as Profile?;
          _isFavorite = results[4] as bool;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _checkWishlistStatus() async {
    try {
      final authState = ref.read(authNotifierProvider);
      final user = authState.value?.user;
      if (user == null) return false;

      final response = await supabase
          .from('wishlists')
          .select()
          .eq('tenant_id', user.id)
          .eq('property_id', widget.property.id)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _toggleWishlist() async {
    debugPrint("_toggleWishlist called");
    try {
      final authState = ref.read(authNotifierProvider);
      final user = authState.value?.user;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to add properties to your wishlist'),
            ),
          );
        }
        return;
      }

      if (_isFavorite) {
        // Remove from wishlist
        await supabase
            .from('wishlists')
            .delete()
            .eq('tenant_id', user.id)
            .eq('property_id', widget.property.id);
        
        if (mounted) {
          setState(() {
            _isFavorite = false;
            _wishlistChanged = true; // Mark that wishlist was changed
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from wishlist'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Add to wishlist
        await supabase.from('wishlists').insert({
          'tenant_id': user.id,
          'property_id': widget.property.id,
        });
        
        if (mounted) {
          setState(() {
            _isFavorite = true;
            _wishlistChanged = true; // Mark that wishlist was changed
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to wishlist'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('Error toggling wishlist: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Handle back button - return wishlist changed status
          Navigator.of(context).pop(_wishlistChanged);
        }
      },
      child: Scaffold(
        body: CustomScrollView(
        slivers: [
          // Header with image carousel
          _buildImageHeader(),
          
          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Property Info Section
                _buildPropertyInfo(),
                const Divider(color: Colors.grey, indent: 24, endIndent: 24),
                
                // Description Section
                _buildDescriptionSection(),
                const Divider(color: Colors.grey, indent: 24, endIndent: 24),
                
                // Host Info Section
                _buildHostInfoSection(),
                const Divider(color: Colors.grey, indent: 24, endIndent: 24),
                
                // Amenities Section
                _buildAmenitiesSection(),
                const Divider(color: Colors.grey, indent: 24, endIndent: 24),
                
                // Reviews Section
                _buildReviewsSection(),
                const Divider(color: Colors.grey, indent: 24, endIndent: 24),
                
                // Cancellation Policy Section
                _buildCancellationPolicySection(),
                
                // Bottom spacing for fixed bar
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      
      // Fixed bottom bar
      bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildImageHeader() {
  // CASE 1: No images available
  if (_images.isEmpty) {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 300,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Placeholder background
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
              ),
            ),

            // Top-left buttons overlay
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: Row(
                children: [
                  _buildBackButton(),
                  const SizedBox(width: 8),
                  _buildWishlistButton(),
                ],
              ),
            ),
            // Top-right Compare button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: _buildCompareButton(),
            ),
          ],
        ),
      ),
    );
  }

  // CASE 2: Images available
  return SliverAppBar(
    automaticallyImplyLeading: false,
    expandedHeight: 300,
    pinned: true,

    flexibleSpace: FlexibleSpaceBar(
      background: Stack(
        fit: StackFit.expand,
        children: [
          // Image Carousel
          PageView.builder(
            controller: _imagePageController,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemCount: _images.length,
            itemBuilder: (context, index) {
              return Image.network(
                _images[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                  ),
                ),
              );
            },
          ),

          // Top-left buttons overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Row(
              children: [
                _buildBackButton(),
                const SizedBox(width: 8),
                _buildWishlistButton(),
              ],
            ),
          ),
          // Top-right Compare button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: _buildCompareButton(),
          ),

          // Image index indicator (bottom-right)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${_images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context, _wishlistChanged),
        ),
      ),
    );
  }

  Widget _buildWishlistButton() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.pink : Colors.white,
            size: 20,
          ),
          onPressed: _toggleWishlist,
        ),
      ),
    );
  }

  Widget _buildCompareButton() {
    final comparisonState = ref.watch(comparisonProvider);
    final isInComparison = comparisonState.containsProperty(widget.property);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) => SingleChildScrollView(
                controller: scrollController,
                child: ComparisonBottomSheet(
                  currentProperty: widget.property,
                ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Compare',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.compare_arrows,
                color: isInComparison ? Colors.blue.shade200 : Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.property.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          
          // Rating row
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(
                _rating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(width: 4),
              Text(
                '($_reviewCount Reviews)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Address
          Text(
            widget.property.address,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Property Type', widget.property.propertyType),
          const SizedBox(height: 8),
          _buildInfoRow('Max Guest Size', '${widget.property.maxGuest} guests'),
          const SizedBox(height: 8),
          _buildInfoRow('Price per Night', 'RM ${widget.property.pricePerNight.toStringAsFixed(2)}'),
          if (widget.property.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.property.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildHostInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Host Info',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Host avatar
              CircleAvatar(
                radius: 30,
                backgroundImage: _hostProfile?.avatarUrl != null
                    ? NetworkImage(_hostProfile!.avatarUrl!)
                    : null,
                child: _hostProfile?.avatarUrl == null
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              const SizedBox(width: 12),
              // Host name and verification
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _hostProfile?.fullName ?? 'Host',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        if (_hostProfile?.isVerified == true) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    if (_hostProfile?.contactNo != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _hostProfile!.contactNo!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_hostProfile?.shortBio != null && _hostProfile!.shortBio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _hostProfile!.shortBio!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              "Host's Short Bio...",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmenitiesSection() {
    if (widget.property.amenities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amenities',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3,
            ),
            itemCount: widget.property.amenities.length,
            itemBuilder: (context, index) {
              final amenity = widget.property.amenities[index];
              // Always use the icon from AppConstants.amenityIcons map
              final icon = AppConstants.getAmenityIcon(amenity) ?? Icons.check_circle_outline;
              
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        amenity,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviews',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (_reviews.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PropertyReviewsScreen(
                          property: widget.property,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'See All Reviews',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: Theme.of(context).colorScheme.primary,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_reviews.isEmpty)
            Text(
              'No reviews yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  return _buildReviewCard(_reviews[index]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return FutureBuilder<String?>(
      future: PropertyService.getBookingById(review.bookingId)
          .then((booking) => booking != null 
              ? PropertyService.getTenantName(booking.tenantId)
              : Future.value(null)),
      builder: (context, snapshot) {
        final userName = snapshot.data ?? 'Anonymous';
        
        return Container(
          width: 280,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < review.rating ? Icons.star : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  review.comment,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCancellationPolicySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cancellation Policy',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              AppConstants.cancellationPolicy,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Price
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RM ${widget.property.pricePerNight.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '/night',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const Spacer(),
            // Book Now button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingDetailScreen(property: widget.property),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Book Now'),
            ),
          ],
        ),
      ),
    );
  }
}

