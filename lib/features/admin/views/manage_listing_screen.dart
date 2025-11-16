import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/property_image.dart';
import 'package:homiego/features/admin/providers/admin_providers.dart';
import 'package:homiego/features/admin/views/property_detail_screen.dart';
import 'package:homiego/core/services/supabase_client.dart';

class ManageListingScreen extends ConsumerStatefulWidget {
  const ManageListingScreen({super.key});

  @override
  ConsumerState<ManageListingScreen> createState() => _ManageListingScreenState();
}

class _ManageListingScreenState extends ConsumerState<ManageListingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Listings'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'View All', icon: Icon(Icons.list)),
            Tab(text: 'Verify/Approve', icon: Icon(Icons.verified_user)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ViewAllTab(
            searchController: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
          ),
          const _VerifyApproveTab(),
        ],
      ),
    );
  }
}

class _ViewAllTab extends ConsumerWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _ViewAllTab({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  List<Property> _filterProperties(List<Property> properties) {
    if (searchQuery.isEmpty) return properties;
    
    final query = searchQuery.toLowerCase();
    return properties.where((property) {
      return property.title.toLowerCase().contains(query) ||
          property.address.toLowerCase().contains(query) ||
          property.description.toLowerCase().contains(query) ||
          property.propertyType.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPropertiesAsync = ref.watch(allPropertiesProvider);

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search properties...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ),

        // Properties List
        Expanded(
          child: allPropertiesAsync.when(
            data: (properties) {
              final filtered = _filterProperties(properties);
              
              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        searchQuery.isNotEmpty ? Icons.search_off : Icons.home_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchQuery.isNotEmpty
                            ? 'No properties found'
                            : 'No properties available',
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final property = filtered[index];
                  return _PropertyCard(property: property);
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
                  Text(
                    'Error loading properties',
                    style: TextStyle(fontSize: 18, color: Colors.red[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(allPropertiesProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VerifyApproveTab extends ConsumerWidget {
  const _VerifyApproveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingPropertiesAsync = ref.watch(pendingPropertiesProvider);

    return pendingPropertiesAsync.when(
      data: (properties) {
        if (properties.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending listings',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'All property listings have been processed',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: properties.length,
          itemBuilder: (context, index) {
            final property = properties[index];
            return _PropertyVerificationCard(property: property);
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
            Text(
              'Error loading listings',
              style: TextStyle(fontSize: 18, color: Colors.red[700]),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(pendingPropertiesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyCard extends ConsumerStatefulWidget {
  final Property property;

  const _PropertyCard({required this.property});

  @override
  ConsumerState<_PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends ConsumerState<_PropertyCard> {
  String? _firstImageUrl;
  bool _loadingImage = true;

  @override
  void initState() {
    super.initState();
    _loadFirstImage();
  }

  Future<void> _loadFirstImage() async {
    debugPrint('=== ManageListingScreen: Loading first image for property ID: ${widget.property.id} ===');
    try {
      debugPrint('ManageListingScreen: Querying property_images table...');
      debugPrint('ManageListingScreen: Current user: ${supabase.auth.currentUser?.id}');
      debugPrint('ManageListingScreen: Current user role: ${supabase.auth.currentUser?.userMetadata?['role']}');
      
      final response = await supabase
          .from('property_images')
          .select()
          .eq('property_id', widget.property.id)
          .order('position', ascending: true)
          .limit(1)
          .maybeSingle();

      debugPrint('ManageListingScreen: Query response received');
      debugPrint('ManageListingScreen: Response: $response');

      if (response != null) {
        debugPrint('ManageListingScreen: Image found in response');
        final image = PropertyImage.fromMap(response);
        debugPrint('ManageListingScreen: Image storage path: ${image.storagePath}');
        
        // Check if storage_path is already a full URL
        String imageUrl;
        if (image.storagePath.startsWith('http://') || image.storagePath.startsWith('https://')) {
          // Already a full URL, use it directly
          imageUrl = image.storagePath;
          debugPrint('ManageListingScreen: Storage path is already a full URL, using directly');
        } else {
          // Generate URL from storage bucket
          imageUrl = supabase.storage
              .from('property_images')
              .getPublicUrl(image.storagePath);
          debugPrint('ManageListingScreen: Generated image URL from storage bucket');
        }
        debugPrint('ManageListingScreen: Final image URL: $imageUrl');
        
        setState(() {
          _firstImageUrl = imageUrl;
          _loadingImage = false;
        });
        debugPrint('ManageListingScreen: Successfully loaded first image');
      } else {
        debugPrint('ManageListingScreen: No image found for this property');
        setState(() {
          _loadingImage = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('ManageListingScreen: ERROR loading first image: $e');
      debugPrint('ManageListingScreen: Stack trace: $stackTrace');
      setState(() {
        _loadingImage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PropertyDetailScreen(property: widget.property),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: 200,
              width: double.infinity,
              child: _loadingImage
                  ? Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : _firstImageUrl != null
                      ? Image.network(
                          _firstImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.image_not_supported, size: 48),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 48),
                          ),
                        ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.property.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          widget.property.status.name.toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: widget.property.status == PropertyStatus.approved
                            ? Colors.green[100]
                            : widget.property.status == PropertyStatus.rejected
                                ? Colors.red[100]
                                : Colors.orange[100],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.property.address,
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.home, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        widget.property.propertyType,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.people, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.property.maxGuest} guests',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      Text(
                        'RM ${widget.property.pricePerNight.toStringAsFixed(2)}/night',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyVerificationCard extends ConsumerWidget {
  final Property property;

  const _PropertyVerificationCard({required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: property.status == PropertyStatus.pending
              ? Colors.orange.withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.home_work, color: Colors.blue[700], size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property.address,
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: property.status == PropertyStatus.approved
                        ? Colors.green[100]
                        : property.status == PropertyStatus.rejected
                            ? Colors.red[100]
                            : Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    property.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: property.status == PropertyStatus.approved
                          ? Colors.green[900]
                          : property.status == PropertyStatus.rejected
                              ? Colors.red[900]
                              : Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // Property details in a grid
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _DetailChip(
                  icon: Icons.home,
                  label: property.propertyType,
                  color: Colors.blue,
                ),
                _DetailChip(
                  icon: Icons.people,
                  label: '${property.maxGuest} guests',
                  color: Colors.purple,
                ),
                _DetailChip(
                  icon: Icons.attach_money,
                  label: 'RM ${property.pricePerNight.toStringAsFixed(2)}/night',
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                property.description,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(context, ref),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApprove(context, ref),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleApprove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Approve Property'),
          ],
        ),
        content: Text(
          'Are you sure you want to approve "${property.title}"?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(
        updatePropertyStatusProvider({
          'property_id': property.id,
          'status': 'approved',
        }).future,
      );

      ref.invalidate(pendingPropertiesProvider);
      ref.invalidate(allPropertiesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Property approved successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _handleReject(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.close, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Reject Property'),
          ],
        ),
        content: Text(
          'Are you sure you want to reject "${property.title}"? This action cannot be undone.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(
          updatePropertyStatusProvider({
            'property_id': property.id,
            'status': 'rejected',
          }).future,
        );

        ref.invalidate(pendingPropertiesProvider);
        ref.invalidate(allPropertiesProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Property rejected'),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error: ${e.toString()}')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    }
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Color.lerp(color, Colors.black, 0.3) ?? color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
