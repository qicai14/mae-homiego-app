import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart'; // Ensure correct path
import 'package:homiego/core/providers/auth_providers.dart'; // Import notifier provider
// import 'package:homiego/core/services/supabase_client.dart'; // No longer needed here
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For AuthResponse, User, AuthException

// Re-use loading provider from login
final authLoadingProvider = StateProvider<bool>((ref) => false);
// Provider to hold the selected role
final selectedRoleProvider = StateProvider<UserRole>((ref) => UserRole.tenant);

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- SIGNUP FUNCTION (REVISED V6 - ROLE IN METADATA) ---
  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final UserRole roleChosenByUser = ref.read(selectedRoleProvider);
    debugPrint("SignupScreen: Role selected in Dropdown: ${roleChosenByUser.name}");

    // Basic validation...
    if (email.isEmpty || password.isEmpty) { /* ... */ return; }
    if (password.length < 6) { /* ... */ return; }

    ref.read(authLoadingProvider.notifier).state = true;

    try {
      // Step 1: Sign up user, passing the role in the 'data' map.
      // This data populates auth.users.raw_user_meta_data
      debugPrint("SignupScreen: Attempting auth.signUp for $email with role: ${roleChosenByUser.name}");
      final authResponse = await ref
          .read(authNotifierProvider.notifier)
          .signUpWithEmail(
              email,
              password,
              // --- THIS IS THE KEY CHANGE ---
              data: {'role': roleChosenByUser.name} // Pass role as metadata
          );
      final user = authResponse.user;

      if (user == null) { throw Exception('Signup failed: User object is null'); }
      debugPrint("SignupScreen: auth.signUp successful. User ID: ${user.id}. Trigger will now create profile.");

      // --- REMOVED THE CLIENT-SIDE ROLE UPDATE AND DELAY ---
      // The trigger now handles setting the correct role during profile insertion.

      // Feedback & Navigation Trigger...
      if (mounted) {
        showSnackBar(context, 'Signup successful! Please check your email ($email) to verify.');
        debugPrint("SignupScreen: Invalidating auth provider...");
        ref.invalidate(authNotifierProvider); // Triggers AuthGate -> VerifyEmailScreen
      }

    } on AuthException catch (e) {
      debugPrint("SignupScreen: AuthException: ${e.message}");
       if (mounted) showSnackBar(context, 'Signup failed: ${e.message}', isError: true);
    } catch (e) {
      debugPrint("SignupScreen: Unexpected error: $e");
       if (mounted) showSnackBar(context, 'An unexpected error: $e', isError: true);
    } finally {
      if (mounted) ref.read(authLoadingProvider.notifier).state = false;
    }
  }
  // --- END SIGNUP FUNCTION ---

  // ... (build method remains the same) ...
  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final selectedRole = ref.watch(selectedRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
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
                   Text(
                    'Join Homiego',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Email Field
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email*',
                      prefixIcon: Icon(Icons.email_outlined)
                      ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password*',
                       prefixIcon: const Icon(Icons.lock_outline),
                       hintText: 'Minimum 6 characters',
                       hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 24),
                  // Role Selection Dropdown
                  Text('I want to sign up as a...*', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserRole>(
                    value: selectedRole,
                    decoration: InputDecoration(
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.tenant,
                        child: Text('Tenant (Looking for a place)'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.homeowner,
                        child: Text('Homeowner (Listing a place)'),
                      ),
                    ],
                    onChanged: isLoading ? null : (value) {
                      if (value != null) {
                        ref.read(selectedRoleProvider.notifier).state = value;
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  // Sign Up Button
                  ElevatedButton(
                    onPressed: isLoading ? null : _signUp,
                    child: isLoading
                        ? const SizedBox(
                            height: 24, width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Text('Sign Up'),
                  ),
                  const SizedBox(height: 16),
                  // Back to Login Navigation
                  TextButton(
                     onPressed: isLoading ? null : () => Navigator.pop(context), // Just go back
                    child: const Text('Already have an account? Log In'),
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