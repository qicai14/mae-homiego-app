import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart'; // To access auth state and methods
import 'package:homiego/core/services/supabase_client.dart'; // <-- ADDED: To access supabase client for resend
import 'package:homiego/core/utils/show_snackbar.dart'; // Use our custom snackbar
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- ADDED: For OtpType

// Provider for the refresh loading state
final _verifyEmailLoadingProvider = StateProvider<bool>((ref) => false);

class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  // --- REFRESH FUNCTION ---
  Future<void> _checkVerificationStatus(BuildContext context, WidgetRef ref) async {
    // Prevent multiple clicks while loading
    if (ref.read(_verifyEmailLoadingProvider)) return;

    ref.read(_verifyEmailLoadingProvider.notifier).state = true;
    try {
      debugPrint("VerifyEmailScreen: Refreshing user state...");
      ref.invalidate(authNotifierProvider);

      await Future.delayed(const Duration(seconds: 1)); // Adjust delay if needed

      // Read latest state after invalidation
      // Use .future to await the potentially async recalculation
      final refreshedAuthState = await ref.read(authNotifierProvider.future);

      debugPrint("VerifyEmailScreen: State after refresh: $refreshedAuthState");

      // Check verification status in the refreshed state
      // Use 'context.mounted' here as it's passed into the function
      if (refreshedAuthState.isEmailVerified && context.mounted) {
        debugPrint("VerifyEmailScreen: Email verified after refresh!");
        showSnackBar(context, 'Email verified successfully! Redirecting...');
      } else if (context.mounted){
         debugPrint("VerifyEmailScreen: Email still not verified after refresh.");
         showSnackBar(context, 'Email not verified yet. Please check your inbox/spam folder and click the link.');
      }

    } catch (e, st) {
       debugPrint("VerifyEmailScreen: Error checking status: $e\n$st");
       // Use 'context.mounted' here
      if (context.mounted) {
        showSnackBar(context, 'Error checking verification status: $e', isError: true);
      }
    } finally {
       // Reset loading state
       // Need to check mounted status AFTER async gap if context is used
       // Safest check is often just reading the provider state again if needed,
       // but resetting the loading provider itself is generally safe.
       // We'll rely on Riverpod to handle provider disposal correctly.
       ref.read(_verifyEmailLoadingProvider.notifier).state = false;
    }
  }
   // --- END REFRESH FUNCTION ---

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authNotifierProvider);
    final userEmail = authStateAsync.value?.user?.email ?? 'your email address';
    final isLoading = ref.watch(_verifyEmailLoadingProvider);

    // Handle potential errors loading the auth state
    // Use whenOrNull to avoid showing UI during loading
     authStateAsync.whenOrNull(
       error: (err, st) {
          // Schedule the snackbar to show after the build completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // REMOVED 'mounted' check here - context should be valid if build is running
             showSnackBar(context, 'Error loading user data: $err', isError: true);
          });
       }
     );


    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: isLoading ? null : () => ref.read(authNotifierProvider.notifier).signOut(),
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
                  const Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 24),
                  Text(
                    'Check Your Inbox',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'We\'ve sent a verification link to:\n$userEmail',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                   const SizedBox(height: 8),
                   Text(
                    'Click the link in the email to activate your account. Then tap the button below.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Refresh Button
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : () => _checkVerificationStatus(context, ref),
                     icon: isLoading
                         ? Container(
                             width: 20, height: 20, padding: const EdgeInsets.all(2.0),
                             child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                           )
                         : const Icon(Icons.refresh),
                    label: const Text('I Clicked the Link / Check Status'),
                  ),
                  const SizedBox(height: 16),
                  // Log Out Button
                  TextButton(
                    onPressed: isLoading ? null : () => ref.read(authNotifierProvider.notifier).signOut(),
                    child: const Text('Log Out'),
                  ),
                   const SizedBox(height: 24),
                   // Resend Email Section
                   Text(
                    'Didn\'t receive the email? Check your spam folder or wait a minute.',
                     style: Theme.of(context).textTheme.bodySmall?.copyWith( color: Colors.grey[600]),
                     textAlign: TextAlign.center,
                   ),
                   TextButton(
                     onPressed: isLoading ? null : () async {
                       // Get user safely - Use read here as it's inside a callback
                       final user = ref.read(authNotifierProvider).value?.user;
                       if (user == null || user.email == null) {
                          // REMOVED 'mounted' check - context should be valid
                          showSnackBar(context, 'Cannot resend: User email not found.');
                          return;
                       }
                       try {
                         // Use the imported 'supabase' client getter
                         await supabase.auth.resend(type: OtpType.signup, email: user.email!);
                         // REMOVED 'mounted' check
                         showSnackBar(context, 'Verification email resent to ${user.email}.');
                       } catch (e) {
                          // REMOVED 'mounted' check
                          showSnackBar(context, 'Error resending email: $e', isError: true);
                       }
                     },
                     child: const Text('Resend Verification Email'),
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

