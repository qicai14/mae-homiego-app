import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/utils/show_snackbar.dart';

class EditHomeownerProfileScreen extends ConsumerStatefulWidget {
  const EditHomeownerProfileScreen({super.key});

  @override
  ConsumerState<EditHomeownerProfileScreen> createState() =>
      _EditHomeownerProfileScreenState();
}

class _EditHomeownerProfileScreenState
    extends ConsumerState<EditHomeownerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _contactNoController;
  String? _selectedGender;
  bool _isLoading = false;

  // List of gender options for the dropdown
  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];


  @override
  void initState() {
    super.initState();
    // Pre-fill controllers with current profile data
    final profile = ref.read(authNotifierProvider).value?.profile;
    _fullNameController =
        TextEditingController(text: profile?.fullName ?? '');
    _contactNoController =
        TextEditingController(text: profile?.contactNo ?? '');
    _selectedGender = profile?.gender;

    // Ensure _selectedGender is one of the valid options, or null
    if (_selectedGender != null && !_genderOptions.contains(_selectedGender)) {
       _selectedGender = null;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactNoController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    // 1. Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // 2. Prepare data map
    final data = {
      'full_name': _fullNameController.text.trim(),
      'contact_no': _contactNoController.text.trim().isNotEmpty
          ? _contactNoController.text.trim()
          : null,
      'gender': _selectedGender,
    };

    try {
      // 3. Call the notifier method
      await ref.read(authNotifierProvider.notifier).updateProfile(data);

      if (mounted) {
        // 4. Show success and pop screen
        showSnackBar(context, 'Profile saved successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      // 5. Show error
      if (mounted) {
        showSnackBar(context, 'Failed to save profile: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Full Name
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Full Name cannot be empty';
                  }
                  return null;
                },
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),
              // Contact No
              TextFormField(
                controller: _contactNoController,
                decoration: const InputDecoration(
                  labelText: 'Contact No',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),
              // Gender Dropdown
              DropdownButtonFormField<String>(
                value: _selectedGender,
                items: _genderOptions
                    .map((gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        ))
                    .toList(),
                onChanged: _isLoading
                    ? null
                    : (value) => setState(() => _selectedGender = value),
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_outlined),
                ),
              ),
              const SizedBox(height: 36),
              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}