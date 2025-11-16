import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:homiego/core/constants/app_constants.dart'; // <-- CORRECT IMPORT
import 'package:homiego/core/services/supabase_client.dart'; // <-- CORRECT IMPORT
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({super.key});

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxGuestsController = TextEditingController();
  final _cleaningFeeController = TextEditingController();
  final _addressController = TextEditingController();
  
  // Use AppConstants for the default value
  String _propertyType = AppConstants.propertyTypes.first; 
  final List<String> _selectedAmenities = [];

  // Map State
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  final LatLng _initialCameraPosition =
      const LatLng(3.1390, 101.6869); // Kuala Lumpur

  // Image State
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];

  // Loading State
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _maxGuestsController.dispose();
    _cleaningFeeController.dispose();
    _addressController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Toggles an amenity in the [_selectedAmenities] list.
  void _onAmenityToggle(String amenity) {
    setState(() {
      if (_selectedAmenities.contains(amenity)) {
        _selectedAmenities.remove(amenity);
      } else {
        _selectedAmenities.add(amenity);
      }
    });
  }

  /// Uses [geocoding] to get an address from map coordinates and updates
  /// the [_addressController].
  Future<void> _updateAddressFromLatLng(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // Format a readable address
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

  /// Uses [geocoding] to get coordinates from the address text and
  /// animates the map camera to the new location.
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

  /// Uses [image_picker] to allow multi-image selection and updates
  /// the [_selectedImages] list.
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

  /// The main multi-step creation logic.
  /// 1. Inserts property data into 'properties' table.
  /// 2. Uploads selected images to 'property_image' storage bucket.
  /// 3. Inserts image metadata into 'property_images' table.
  Future<void> _createListing() async {
    // 1. Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // 2. Check for location
    if (_selectedLocation == null) {
      showSnackBar(context, 'Please select a location on the map',
          isError: true);
      return;
    }
    // 3. Check for images
    if (_selectedImages.isEmpty) {
      showSnackBar(context, 'Please select at least one image', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // --- FIX 1: Use the Riverpod provider ---
    final supabase = ref.read(supabaseClientProvider);
    final hostId = supabase.auth.currentUser!.id;

    try {
      // --- GATHER DATA ---
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final pricePerNight = double.parse(_priceController.text.trim());
      final maxGuests = int.parse(_maxGuestsController.text.trim());
      final cleaningFee =
          double.tryParse(_cleaningFeeController.text.trim()) ?? 0.0;
      final address = _addressController.text.trim();
      final latitude = _selectedLocation!.latitude;
      final longitude = _selectedLocation!.longitude;

      // --- BUSINESS LOGIC (Feature 1) ---
      final serviceFee = pricePerNight * 0.10; // 10% service fee

      // --- STEP 1: Insert Property Data ---
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
        'status': 'pending', // New listings must be approved by an admin
        'cleaning_fee': cleaningFee,
        'service_fee': serviceFee,
      };

      // Use .select() to get the ID back, as requested
      final result = await supabase
          .from('properties')
          .insert(propertyData)
          .select('id')
          .single();

      final newPropertyId = result['id'] as int;

      // --- STEP 2: Upload Images to Storage ---
      final List<String> storagePaths = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final file = File(image.path);
        final fileExtension = image.path.split('.').last.toLowerCase();
        // Create a unique, organized storage path
        final storagePath = '$newPropertyId/image_$i.$fileExtension';

        await supabase.storage.from('property_image').upload(
              storagePath,
              file,
              fileOptions:
                  FileOptions(contentType: 'image/$fileExtension'),
            );
        storagePaths.add(storagePath);
      }

      // --- STEP 3: Insert Image Records into DB ---
      final imageRecords = storagePaths.map((path) {
        return {
          'property_id': newPropertyId,
          'storage_path': path,
          'position': storagePaths.indexOf(path), // 0-based index
        };
      }).toList();

      await supabase.from('property_images').insert(imageRecords);

      // --- STEP 4: Finalize (Success) ---
      if (mounted) {
        showSnackBar(context, 'Listing created! Pending admin approval.');
        Navigator.of(context).pop();
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
      // --- STEP 4: Finalize (Error) ---
      if (mounted) {
        showSnackBar(context, 'An unexpected error occurred: $e',
            isError: true);
      }
    } finally {
      // --- STEP 4: Finalize (Always) ---
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Listing'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Basic Info Section ---
                Text(
                  'Listing Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 4,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Description is required'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _propertyType,
                  decoration: const InputDecoration(labelText: 'Property Type'),
                  // --- FIX 2: Use AppConstants.propertyTypes ---
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration:
                            const InputDecoration(labelText: 'Price per Night (RM)'),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Price is required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _maxGuestsController,
                        decoration: const InputDecoration(labelText: 'Max Guests'),
                        keyboardType: TextInputType.number,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Max guests required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cleaningFeeController,
                  decoration: const InputDecoration(
                      labelText: 'Cleaning Fee (RM)',
                      hintText: '0.00 (Optional)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const Divider(height: 32),

                // --- Amenities Section ---
                _AmenitiesSection(
                  selectedAmenities: _selectedAmenities,
                  onAmenityToggle: _onAmenityToggle,
                ),
                const Divider(height: 32),

                // --- Location Section (Feature 2) ---
                Text(
                  'Location',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
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
                  validator: (value) => value == null || value.isEmpty
                      ? 'Address is required'
                      : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _initialCameraPosition,
                        zoom: 12,
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
                              ),
                            },
                    ),
                  ),
                ),
                const Divider(height: 32),

                // --- Image Upload Section (Feature 3) ---
                Text(
                  'Photos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Select Images'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  child: _selectedImages.isEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                              child: Text('No images selected.',
                                  style: TextStyle(color: Colors.grey))),
                        )
                      : ListView.builder(
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
                ),
                const Divider(height: 32),

                // --- Submit Button ---
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _createListing,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Save Listing'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A helper widget to display amenity filter chips.
/// State is managed in the parent [_AddListingScreenState].
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
          // --- FIX 3: Iterate over AppConstants.amenities (List<String>) ---
          children: AppConstants.amenities.map((amenityName) {
            final isSelected = selectedAmenities.contains(amenityName);
            // Get the icon from the amenityIcons map
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
                  : null, // No icon if not found
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