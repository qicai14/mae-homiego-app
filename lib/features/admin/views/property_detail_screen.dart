import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/property_image.dart';
import 'package:homiego/core/services/supabase_client.dart';

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
  List<PropertyImage>? _images;
  bool _loadingImages = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    debugPrint('=== PropertyDetailScreen: Loading images for property ID: ${widget.property.id} ===');
    try {
      debugPrint('PropertyDetailScreen: Querying property_images table...');
      debugPrint('PropertyDetailScreen: Current user: ${supabase.auth.currentUser?.id}');
      debugPrint('PropertyDetailScreen: Current user role: ${supabase.auth.currentUser?.userMetadata?['role']}');
      
      final response = await supabase
          .from('property_images')
          .select()
          .eq('property_id', widget.property.id)
          .order('position', ascending: true);

      debugPrint('PropertyDetailScreen: Query response received');
      debugPrint('PropertyDetailScreen: Response type: ${response.runtimeType}');
      debugPrint('PropertyDetailScreen: Response: $response');

      final imagesList = response as List? ?? [];
      debugPrint('PropertyDetailScreen: Images found: ${imagesList.length}');
      
      if (imagesList.isNotEmpty) {
        debugPrint('PropertyDetailScreen: First image data: ${imagesList[0]}');
      }

      setState(() {
        _images = imagesList
            .map((data) => PropertyImage.fromMap(data as Map<String, dynamic>))
            .toList();
        _loadingImages = false;
      });
      
      debugPrint('PropertyDetailScreen: Successfully loaded ${_images?.length ?? 0} images');
    } catch (e, stackTrace) {
      debugPrint('PropertyDetailScreen: ERROR loading images: $e');
      debugPrint('PropertyDetailScreen: Stack trace: $stackTrace');
      setState(() {
        _loadingImages = false;
      });
    }
  }

  String _getImageUrl(String storagePath) {
    // Get the public URL from Supabase storage
    try {
      debugPrint('PropertyDetailScreen: Getting image URL for storage path: $storagePath');
      
      // Check if storage_path is already a full URL
      String url;
      if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
        // Already a full URL, use it directly
        url = storagePath;
        debugPrint('PropertyDetailScreen: Storage path is already a full URL, using directly');
      } else {
        // Generate URL from storage bucket
        url = supabase.storage.from('property_images').getPublicUrl(storagePath);
        debugPrint('PropertyDetailScreen: Generated image URL from storage bucket');
      }
      debugPrint('PropertyDetailScreen: Final image URL: $url');
      return url;
    } catch (e) {
      debugPrint('PropertyDetailScreen: ERROR getting image URL: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images Section
            if (_loadingImages)
              const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_images != null && _images!.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: _images!.length,
                  itemBuilder: (context, index) {
                    final imageUrl = _getImageUrl(_images![index].storagePath);
                    return Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 64),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 300,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 64),
                ),
              ),

            // Property Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.property.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          widget.property.status.name.toUpperCase(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: widget.property.status == PropertyStatus.approved
                            ? Colors.green[100]
                            : widget.property.status == PropertyStatus.rejected
                                ? Colors.red[100]
                                : Colors.orange[100],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Address
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.property.address,
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Property Info Row
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.home,
                        label: widget.property.propertyType,
                      ),
                      const SizedBox(width: 12),
                      _InfoChip(
                        icon: Icons.people,
                        label: '${widget.property.maxGuest} guests',
                      ),
                      const SizedBox(width: 12),
                      _InfoChip(
                        icon: Icons.attach_money,
                        label: 'RM ${widget.property.pricePerNight.toStringAsFixed(2)}/night',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price Breakdown
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Price Breakdown',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _PriceRow(
                            label: 'Price per night',
                            value: 'RM ${widget.property.pricePerNight.toStringAsFixed(2)}',
                          ),
                          _PriceRow(
                            label: 'Cleaning fee',
                            value: 'RM ${widget.property.cleaningFee.toStringAsFixed(2)}',
                          ),
                          _PriceRow(
                            label: 'Service fee',
                            value: 'RM ${widget.property.serviceFee.toStringAsFixed(2)}',
                          ),
                          const Divider(),
                          _PriceRow(
                            label: 'Total per night',
                            value: 'RM ${(widget.property.pricePerNight + widget.property.cleaningFee + widget.property.serviceFee).toStringAsFixed(2)}',
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.property.description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 16),

                  // Amenities
                  if (widget.property.amenities.isNotEmpty) ...[
                    const Text(
                      'Amenities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.property.amenities
                          .map((amenity) => Chip(
                                label: Text(amenity),
                                backgroundColor: Colors.blue[50],
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Additional Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Additional Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            label: 'Property ID',
                            value: widget.property.id.toString(),
                          ),
                          _InfoRow(
                            label: 'Host ID',
                            value: widget.property.hostId,
                          ),
                          _InfoRow(
                            label: 'Created At',
                            value: widget.property.createdAt.toString().split(' ')[0],
                          ),
                          _InfoRow(
                            label: 'Verified',
                            value: widget.property.verified ? 'Yes' : 'No',
                          ),
                          _InfoRow(
                            label: 'Coordinates',
                            value: '${widget.property.latitude.toStringAsFixed(6)}, ${widget.property.longitude.toStringAsFixed(6)}',
                          ),
                        ],
                      ),
                    ),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: Colors.grey[100],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

