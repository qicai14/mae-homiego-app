import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart'; // To call login method
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:homiego/features/auth/views/signup_screen.dart';
// Note: We don't import supabase_client directly here, we use the notifier

// Re-use the loading provider from signup screen
final authLoadingProvider = StateProvider<bool>((ref) => false);

// --- Use ConsumerStatefulWidget for Controllers ---
class LoginScreen extends ConsumerStatefulWidget {
  // --- ADD 'message' parameter back ---
  final String? message;
  const LoginScreen({super.key, this.message});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();

    // --- ADD WidgetsBinding to show message ---
    // Use WidgetsBinding to show SnackBar after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.message != null && widget.message!.isNotEmpty && mounted) {
        showSnackBar(context, widget.message!, isError: true);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIN FUNCTION ---
  Future<void> login() async {
    // Basic validation
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      if (mounted) showSnackBar(context, 'Please fill in all fields', isError: true);
      return;
    }

    // Set loading state
    ref.read(authLoadingProvider.notifier).state = true;

    try {
      // Call the login method from the AuthNotifier
      await ref.read(authNotifierProvider.notifier).signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
      // AuthGate will handle navigation on successful login via state change

    } catch (e) {
       if (mounted) {
         showSnackBar(context, 'Login Failed: ${e.toString()}', isError: true);
       }
    } finally {
      // Ensure loading state is reset even if login fails or widget is disposed
      if (mounted) {
        ref.read(authLoadingProvider.notifier).state = false;
      }
    }
  }
  // --- END LOGIN FUNCTION ---


  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Homiego Logo
                  Image.asset(
                    'lib/assets/HOMIEGO LOGO.png',
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.home,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome Back to Homiego',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log in to find your perfect stay',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Email Field
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined)
                      ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !isLoading, // Disable when loading
                  ),
                  const SizedBox(height: 16),
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                       prefixIcon: Icon(Icons.lock_outline)
                       ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    enabled: !isLoading, // Disable when loading
                    onSubmitted: (_) { // Allow login on keyboard done action
                      if (!isLoading) login();
                    },
                  ),
                  const SizedBox(height: 32),
                  // Login Button
                  ElevatedButton(
                    onPressed: isLoading ? null : login, // Disable button when loading
                    child: isLoading
                        ? const SizedBox( // Show loading indicator inside button
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3,
                            ),
                          )
                        : const Text('Log In'),
                  ),
                  const SizedBox(height: 16),
                   // Optional: Forgot Password Button
                   // TextButton(
                   //   onPressed: isLoading ? null : () { /* TODO: Navigate to Forgot Password */ },
                   //   child: const Text('Forgot Password?'),
                   // ),
                  const SizedBox(height: 16),
                  // Sign Up Navigation
                  TextButton(
                    onPressed: isLoading ? null : () { // Disable when loading
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignupScreen()),
                      );
                    },
                    child: const Text('Don\'t have an account? Sign Up'),
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

