import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/utils/show_snackbar.dart';

// Local provider to hold the selected role in the UI
final _selectedRoleProvider = StateProvider<UserRole>((ref) => UserRole.tenant);

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final selectedRole = ref.read(_selectedRoleProvider);
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _fullNameController.text.isEmpty) {
      showSnackBar(context, 'Please fill in all fields', isError: true);
      return;
    }

    try {
      await ref.read(authNotifierProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            fullName: _fullNameController.text.trim(),
            role: selectedRole,
          );
      // AuthGate will now see the new user and route to VerifyEmailScreen
      if (context.mounted) {
         showSnackBar(context, 'Success! Please check your email to verify.');
         Navigator.of(context).pop(); // Go back to login screen
      }
    } catch (e) {
      // The listener will show the error snackbar
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = ref.watch(_selectedRoleProvider);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        showSnackBar(context, next.error.toString(), isError: true);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
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
                  TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  Text('I am a...', style: Theme.of(context).textTheme.titleMedium),
                  DropdownButtonFormField<UserRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined)),
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
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(_selectedRoleProvider.notifier).state = value;
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isLoading ? null : _signUp,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Text('Sign Up'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
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

