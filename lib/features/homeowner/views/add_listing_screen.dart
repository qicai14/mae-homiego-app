import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/gestures.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:homiego/core/constants/app_constants.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/property_image.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  final Property? propertyToEdit;

  const AddListingScreen({
    super.key,
    this.propertyToEdit,
  });

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  bool _isLoading = false;

  late final bool _isEditMode;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxGuestsController = TextEditingController();
  final _cleaningFeeController = TextEditingController();
  final _addressController = TextEditingController();
  final _pageController = PageController();

  // Map State
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  LatLng _initialCameraPosition =
      const LatLng(3.1390, 101.6869); // Kuala Lumpur

  int _currentPage = 0;
  String _propertyType = AppConstants.propertyTypes.first;
  final List<String> _selectedAmenities = [];
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.propertyToEdit != null;

    if (_isEditMode) {
      final property = widget.propertyToEdit!;
      _titleController.text = property.title;
      _descriptionController.text = property.description;
      _priceController.text = property.pricePerNight.toStringAsFixed(0);
      _maxGuestsController.text = property.maxGuest.toString();
      _cleaningFeeController.text = property.cleaningFee.toStringAsFixed(0);
      _addressController.text = property.address;
      _propertyType = property.propertyType;
      _selectedAmenities.addAll(List<String>.from(property.amenities));
      _selectedLocation = LatLng(property.latitude, property.longitude);
      _initialCameraPosition = _selectedLocation!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _maxGuestsController.dispose();
    _cleaningFeeController.dispose();
    _addressController.dispose();
    _pageController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // --- All helper functions (_pickImages, geocoding, etc.) ---
  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage();
      setState(() {
        _selectedImages.addAll(pickedFiles);
      });
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error picking images: $e', isError: true);
      }
    }
  }

  Future<void> _updateAddressFromLatLng(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final address =
            '${p.street}, ${p.subLocality}, ${p.locality}, ${p.postalCode}, ${p.country}';
        _addressController.text = address;
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error getting address: $e', isError: true);
      }
    }
  }

  Future<void> _updateMapFromAddress() async {
    if (_addressController.text.isEmpty) {
      showSnackBar(context, 'Please enter an address to search', isError: true);
      return;
    }
    try {
      final locations = await locationFromAddress(_addressController.text);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);
        setState(() {
          _selectedLocation = latLng;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 15),
        );
      } else {
        if (mounted) {
          showSnackBar(context, 'Address not found', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error finding address: $e', isError: true);
      }
    }
  }

  void _onAmenityToggle(String amenity) {
    setState(() {
      if (_selectedAmenities.contains(amenity)) {
        _selectedAmenities.remove(amenity);
      } else {
        _selectedAmenities.add(amenity);
      }
    });
  }
  // --- End of helper functions ---

  // --- Main Save/Create/Update Logic ---
  Future<void> _saveListing() async {
    if (!_formKey.currentState!.validate()) {
      if (_titleController.text.isEmpty ||
          _descriptionController.text.isEmpty ||
          _priceController.text.isEmpty ||
          _maxGuestsController.text.isEmpty) {
        _pageController.animateToPage(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        showSnackBar(context, 'Please fill all required fields on Page 1.',
            isError: true);
        return;
      }
      showSnackBar(context, 'Please fix the errors in the form.', isError: true);
      return;
    }

    if (!_isEditMode && _selectedImages.isEmpty) {
      showSnackBar(context, 'Please upload at least one image.', isError: true);
      _pageController.animateToPage(1,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    if (_selectedLocation == null) {
      showSnackBar(context, 'Please select a location on the map.',
          isError: true);
      _pageController.animateToPage(2,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (_isEditMode) {
      await _updateListing();
    } else {
      await _createListing();
    }
  }

  Future<void> _updateListing() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final maxGuests = int.parse(_maxGuestsController.text.trim());
      final cleaningFee =
          double.tryParse(_cleaningFeeController.text.trim()) ?? 0.0;
      final address = _addressController.text.trim();
      final serviceFee = price * 0.10;

      final Map<String, dynamic> updatedData = {
        'title': title,
        'description': description,
        'price_per_night': price,
        'max_guests': maxGuests,
        'cleaning_fee': cleaningFee,
        'service_fee': serviceFee,
        'address': address,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'property_type': _propertyType,
        'amenities': _selectedAmenities,
      };

      await supabase
          .from('properties')
          .update(updatedData)
          .eq('id', widget.propertyToEdit!.id);

      if (context.mounted) {
        showSnackBar(context, 'Listing updated successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Failed to update listing: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createListing() async {
    final supabase = ref.read(supabaseClientProvider);
    final hostId = supabase.auth.currentUser!.id;

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final pricePerNight = double.parse(_priceController.text.trim());
      final maxGuests = int.parse(_maxGuestsController.text.trim());
      final cleaningFee =
          double.tryParse(_cleaningFeeController.text.trim()) ?? 0.0;
      final address = _addressController.text.trim();
      final latitude = _selectedLocation!.latitude;
      final longitude = _selectedLocation!.longitude;
      final serviceFee = pricePerNight * 0.10;

      final propertyData = {
        'host_id': hostId,
        'title': title,
        'description': description,
        'property_type': _propertyType,
        'price_per_night': pricePerNight,
        'max_guests': maxGuests,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'amenities': _selectedAmenities,
        'status': 'pending',
        'cleaning_fee': cleaningFee,
        'service_fee': serviceFee,
      };

      final result = await supabase
          .from('properties')
          .insert(propertyData)
          .select('id')
          .single();

      final newPropertyId = result['id'] as int;

      final List<Map<String, dynamic>> imageRecords = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final file = File(image.path);
        final fileExtension = image.path.split('.').last.toLowerCase();
        final storagePath = '$newPropertyId/image_$i.$fileExtension';

        await supabase.storage.from('property_image').upload(
              storagePath,
              file,
              fileOptions: FileOptions(contentType: 'image/$fileExtension'),
            );

        final publicUrl = supabase.storage
            .from('property_image')
            .getPublicUrl(storagePath);

        imageRecords.add({
          'property_id': newPropertyId,
          'storage_path': publicUrl,
          'position': i,
        });
      }

      await supabase.from('property_images').insert(imageRecords);

      if (mounted) {
        showSnackBar(context, 'Listing created! Pending admin approval.');
        Navigator.of(context).pop(true);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        showSnackBar(context, 'Database error: ${e.message}', isError: true);
      }
    } on StorageException catch (e) {
      if (mounted) {
        showSnackBar(context, 'Storage error: ${e.message}', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'An unexpected error occurred: $e',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // --- End of Save/Create/Update Logic ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Listing' : 'Add New Listing'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / 3,
            backgroundColor: Colors.grey[300],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: PageView(
          controller: _pageController,
          onPageChanged: (page) {
            setState(() {
              _currentPage = page;
            });
          },
          children: [
            _buildPage1Details(),
            _buildPage2ImagesAndAmenities(),
            _buildPage3Location(), 
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0).copyWith(
            bottom: MediaQuery.of(context).padding.bottom + 16.0),
        child: Row(
          children: [
            if (_currentPage > 0)
              TextButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: const Text('Back'),
              ),
            const Spacer(),
            if (_currentPage < 2)
              ElevatedButton(
                onPressed: () {
                  if (_currentPage == 0) {
                    if (_formKey.currentState!.validate()) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: const Text('Next'),
              ),
            if (_currentPage == 2)
              ElevatedButton(
                onPressed: _isLoading ? null : _saveListing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEditMode ? 'Save Changes' : 'Create Listing'),
              ),
          ],
        ),
      ),
    );
  }

  // --- Page 1: Details, Type, & Price ---
  Widget _buildPage1Details() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What kind of place will you host?',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _propertyType,
            decoration: const InputDecoration(labelText: 'Property Type'),
            items: AppConstants.propertyTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _propertyType = value;
                });
              }
            },
          ),
          const SizedBox(height: 24),
          Text('Listing Details',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Listing Title'),
            validator: (value) =>
                value == null || value.isEmpty ? 'Title is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 5,
            validator: (value) => value == null || value.isEmpty
                ? 'Description is required'
                : null,
          ),
          const SizedBox(height: 24),
          Text('Guests & Pricing',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                      labelText: 'Price per Night (RM)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Price is required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _maxGuestsController,
                  decoration: const InputDecoration(labelText: 'Max Guests'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cleaningFeeController,
            decoration: const InputDecoration(
                labelText: 'Cleaning Fee (RM)', hintText: '0.00 (Optional)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
          ),
        ],
      ),
    );
  }

  // --- Page 2: Images & Amenities ---
  Widget _buildPage2ImagesAndAmenities() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Property Images',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (!_isEditMode) ...[
            _buildPickImagesButton(),
            const SizedBox(height: 16),
            _buildImagePreview(),
          ] else ...[
            Text(
              'Images cannot be edited after creation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _buildExistingImagesPreview(),
          ],
          const SizedBox(height: 24),
          _AmenitiesSection(
            selectedAmenities: _selectedAmenities,
            onAmenityToggle: _onAmenityToggle,
          ),
        ],
      ),
    );
  }

  // --- PAGE 3: Location (FIXED) ---
  Widget _buildPage3Location() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Address',
              hintText: 'Search or tap on the map',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _updateMapFromAddress,
              ),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'Address is required' : null,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              // --- FIX: This check prevents the map from building
              // until this page is visible. ---
              child: _currentPage == 2
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _initialCameraPosition,
                        zoom: _isEditMode ? 15 : 12,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      onTap: (location) {
                        setState(() {
                          _selectedLocation = location;
                        });
                        _updateAddressFromLatLng(location);
                      },
                      markers: _selectedLocation == null
                          ? {}
                          : {
                              Marker(
                                markerId: const MarkerId('selected-location'),
                                position: _selectedLocation!,
                              )
                            },
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                    )
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading Map...'),
                          ],
                        ),
                      ),
                    ),
              // --- END FIX ---
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets for Page 2 ---
  Widget _buildPickImagesButton() {
    return ElevatedButton.icon(
      onPressed: _pickImages,
      icon: const Icon(Icons.add_a_photo),
      label: const Text('Select Images'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 45),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImages.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
            child: Text('No images selected.',
                style: TextStyle(color: Colors.grey))),
      );
    }
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_selectedImages[index].path),
                width: 150,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExistingImagesPreview() {
    final images = widget.propertyToEdit?.images ?? [];
    if (images.isEmpty) {
      return const Center(child: Text('No images found for this listing.'));
    }

    images.sort((a, b) => a.position.compareTo(b.position));

    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          final image = images[index];
          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                image.storagePath,
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                loadingBuilder: (BuildContext context, Widget child,
                    ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 150,
                    height: 150,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (BuildContext context, Object exception,
                    StackTrace? stackTrace) {
                  return Container(
                    width: 150,
                    height: 150,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

//  _AmenitiesSection helper widget
class _AmenitiesSection extends StatelessWidget {
  const _AmenitiesSection({
    required this.selectedAmenities,
    required this.onAmenityToggle,
  });

  final List<String> selectedAmenities;
  final ValueChanged<String> onAmenityToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amenities',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Select all that apply.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: AppConstants.amenities.map((amenityName) {
            final isSelected = selectedAmenities.contains(amenityName);
            final iconData = AppConstants.amenityIcons[amenityName];

            return FilterChip(
              label: Text(amenityName),
              avatar: iconData != null
                  ? Icon(
                      iconData,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    )
                  : null,
              selected: isSelected,
              onSelected: (selected) {
                onAmenityToggle(amenityName);
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              checkmarkColor: Theme.of(context).colorScheme.onPrimary,
              labelStyle: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}