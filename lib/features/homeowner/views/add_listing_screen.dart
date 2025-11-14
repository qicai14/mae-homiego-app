import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/constants/app_constants.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'dashboard_screen.dart' show homeownerProfileProvider;
import 'package:homiego/core/utils/show_snackbar.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({super.key});

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxGuestsController = TextEditingController();
  final _addressController = TextEditingController();

  String? _propertyType;
  Set<String> _selectedAmenities = {};
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _maxGuestsController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_propertyType == null) {
      showSnackBar(context, 'Please select a property type.', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final profile = ref.read(homeownerProfileProvider);
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final maxGuest = int.tryParse(_maxGuestsController.text.trim()) ?? 1;
      final newProp = {
        'host_id': profile.id,
        'created_at': DateTime.now().toIso8601String(),
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'property_type': _propertyType,
        'price_per_night': price,
        'max_guests': maxGuest,
        'address': _addressController.text.trim(),
        'amenities': _selectedAmenities.toList(),
        'status': PropertyStatus.pending.name,
        'verified': false,
        'cleaning_fee': 0.0,
        'service_fee': 0.0,
        // latitude/longitude left blank for now
      };
      await supabase.from('properties').insert(newProp).select().single();
      if (!context.mounted) return;
      showSnackBar(context, 'Listing submitted for review!', isError: false);
      Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showSnackBar(context, 'Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Listing'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description *'),
                minLines: 2,
                maxLines: 5,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: _propertyType,
                items: AppConstants.propertyTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _propertyType = val),
                decoration: const InputDecoration(labelText: 'Property Type *'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price per Night (MYR) *'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty || double.tryParse(v) == null ? 'Enter valid number' : null,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: TextFormField(
                      controller: _maxGuestsController,
                      decoration: const InputDecoration(labelText: 'Max Guests *'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty || int.tryParse(v) == null || int.parse(v) < 1 ? 'Enter valid number' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              Text('Amenities', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.amenityIcons.entries.map((entry) {
                  return FilterChip(
                    avatar: Icon(entry.value, size: 18),
                    label: Text(entry.key),
                    selected: _selectedAmenities.contains(entry.key),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAmenities.add(entry.key);
                        } else {
                          _selectedAmenities.remove(entry.key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submitForm,
                  child: _loading
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      : const Text('Submit Listing'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
