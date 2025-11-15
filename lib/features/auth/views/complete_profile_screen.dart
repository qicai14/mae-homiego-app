import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart'; // To access authNotifierProvider
import 'package:homiego/core/services/supabase_client.dart'; // To access supabase client
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For User

// Re-use the loading provider from login/signup
final authLoadingProvider = StateProvider<bool>((ref) => false);

// --- Use ConsumerStatefulWidget for Controllers ---
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _contactNoController;
  User? _currentUser; // Store current user info

  @override
  void initState() {
    super.initState();
    _currentUser = supabase.auth.currentUser; // Get user on init
    _fullNameController =
        TextEditingController(text: _currentUser?.userMetadata?['full_name'] ?? ''); // Pre-fill if available
    _contactNoController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactNoController.dispose();
    super.dispose();
  }

  // --- SAVE PROFILE FUNCTION ---
  Future<void> _saveProfile() async {
    final fullName = _fullNameController.text.trim();
    final contactNo = _contactNoController.text.trim();

    // Basic validation
    if (fullName.isEmpty) {
      if (mounted) showSnackBar(context, 'Full Name cannot be empty.', isError: true);
      return;
    }

    if (_currentUser == null) {
       if (mounted) showSnackBar(context, 'Error: Not logged in.', isError: true);
       // Optional: Log out user if this happens
       // ref.read(authNotifierProvider.notifier).signOut();
       return;
    }

    ref.read(authLoadingProvider.notifier).state = true;

    try {
      // Update the 'profiles' table
      await supabase.from('profiles').update({
        'full_name': fullName,
        'contact_no': contactNo.isNotEmpty ? contactNo : null, // Store null if empty
      }).eq('id', _currentUser!.id); // Match the logged-in user's ID

      if (mounted) {
        showSnackBar(context, 'Profile updated successfully!');
        // --- CRUCIAL: Invalidate the provider to trigger AuthGate ---
        ref.invalidate(authNotifierProvider);
        // AuthGate will now re-run, see the profile is complete, and navigate
      }

    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to update profile: $e', isError: true);
      }
    } finally {
      if (mounted) {
        ref.read(authLoadingProvider.notifier).state = false;
      }
    }
  }
  // --- END SAVE PROFILE FUNCTION ---


  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false, // Don't show back button
         actions: [ // Optional: Add a logout button here in case user gets stuck
           IconButton(
             icon: const Icon(Icons.logout),
             onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
             tooltip: 'Log Out',
           )
         ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.person_pin_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 24),
                  Text(
                    'Just one last step!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please confirm your details to continue.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Full Name Field
                  TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name*',
                      prefixIcon: Icon(Icons.person_outline)
                      ),
                    textInputAction: TextInputAction.next,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  // Contact No Field
                  TextField(
                    controller: _contactNoController,
                    decoration: const InputDecoration(
                      labelText: 'Contact No (Optional)',
                       prefixIcon: Icon(Icons.phone_outlined)
                       ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    enabled: !isLoading,
                    onSubmitted: (_) {
                      if (!isLoading) _saveProfile();
                    },
                  ),
                  const SizedBox(height: 32),
                  // Save Button
                  ElevatedButton(
                    onPressed: isLoading ? null : _saveProfile,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          )
                        : const Text('Save & Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

