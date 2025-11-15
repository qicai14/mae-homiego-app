import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:homiego/widgets/profile_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _fullNameController;
  late TextEditingController _contactNoController;
  late TextEditingController _shortBioController;

  bool _isEditingName = false;
  bool _isEditingContact = false;
  bool _isEditingBio = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _contactNoController = TextEditingController();
    _shortBioController = TextEditingController();
  }

  void _updateControllersFromProfile(Profile? profile) {
    if (profile != null && !_isEditingName && !_isEditingContact && !_isEditingBio) {
      _fullNameController.text = profile.fullName ?? '';
      _contactNoController.text = profile.contactNo ?? '';
      _shortBioController.text = profile.shortBio ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactNoController.dispose();
    _shortBioController.dispose();
    super.dispose();
  }

  Future<void> _saveField(String field, String value) async {
    final authState = ref.read(authNotifierProvider);
    final user = authState.value?.user;
    
    if (user == null) {
      if (mounted) {
        showSnackBar(context, 'Error: Not logged in.', isError: true);
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await supabase.from('profiles').update({
        field: value.isEmpty ? null : value,
      }).eq('id', user.id);

      if (mounted) {
        showSnackBar(context, 'Profile updated successfully!');
        // Refresh the auth state to get updated profile
        ref.invalidate(authNotifierProvider);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to update profile: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          if (field == 'full_name') _isEditingName = false;
          if (field == 'contact_no') _isEditingContact = false;
          if (field == 'short_bio') _isEditingBio = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(authNotifierProvider.notifier).signOut();
        if (mounted) {
          showSnackBar(context, 'Logged out successfully');
        }
      } catch (e) {
        if (mounted) {
          showSnackBar(context, 'Failed to logout: $e', isError: true);
        }
      }
    }
  }

  Widget _buildEditableField({
    required String label,
    required String field,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onCancel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (!isEditing)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                  iconSize: 20,
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: _isSaving
                          ? null
                          : () => _saveField(field, controller.text),
                      iconSize: 20,
                      color: Colors.green,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSaving ? null : onCancel,
                      iconSize: 20,
                      color: Colors.red,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isEditing)
            TextField(
              controller: controller,
              enabled: !_isSaving,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            )
          else
            Text(
              controller.text.isEmpty ? 'Not set' : controller.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: controller.text.isEmpty
                        ? Colors.grey
                        : null,
                  ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authStateAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: authStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error loading profile: $error'),
        ),
        data: (authState) {
          final profile = authState.profile;
          final userName = profile?.fullName ?? 'User';
          
          // Update controllers when profile data changes (only if not editing)
          _updateControllersFromProfile(profile);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                // Profile Avatar - Centered
                Center(
                  child: ProfileAvatar(
                    size: 100,
                    name: userName,
                  ),
                ),
                const SizedBox(height: 32),
                // Full Name
                _buildEditableField(
                  label: 'Full Name',
                  field: 'full_name',
                  controller: _fullNameController,
                  isEditing: _isEditingName,
                  onEdit: () {
                    setState(() {
                      _isEditingName = true;
                    });
                  },
                  onCancel: () {
                    final authState = ref.read(authNotifierProvider);
                    authState.whenData((state) {
                      _fullNameController.text = state.profile?.fullName ?? '';
                    });
                    setState(() {
                      _isEditingName = false;
                    });
                  },
                ),
                const Divider(color: Colors.grey, indent: 24, endIndent: 24),
                // Contact Number
                _buildEditableField(
                  label: 'Contact Number',
                  field: 'contact_no',
                  controller: _contactNoController,
                  isEditing: _isEditingContact,
                  onEdit: () {
                    setState(() {
                      _isEditingContact = true;
                    });
                  },
                  onCancel: () {
                    final authState = ref.read(authNotifierProvider);
                    authState.whenData((state) {
                      _contactNoController.text = state.profile?.contactNo ?? '';
                    });
                    setState(() {
                      _isEditingContact = false;
                    });
                  },
                ),
                const Divider(color: Colors.grey, indent: 24, endIndent: 24),
                // Short Bio
                _buildEditableField(
                  label: 'Short Bio',
                  field: 'short_bio',
                  controller: _shortBioController,
                  isEditing: _isEditingBio,
                  onEdit: () {
                    setState(() {
                      _isEditingBio = true;
                    });
                  },
                  onCancel: () {
                    final authState = ref.read(authNotifierProvider);
                    authState.whenData((state) {
                      _shortBioController.text = state.profile?.shortBio ?? '';
                    });
                    setState(() {
                      _isEditingBio = false;
                    });
                  },
                ),
                const SizedBox(height: 32),
                // Logout Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

