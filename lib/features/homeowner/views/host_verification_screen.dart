import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:homiego/features/homeowner/views/host_verification_success_screen.dart';

class HostVerificationScreen extends ConsumerStatefulWidget {
  const HostVerificationScreen({super.key});

  @override
  ConsumerState<HostVerificationScreen> createState() =>
      _HostVerificationScreenState();
}

class _HostVerificationScreenState
    extends ConsumerState<HostVerificationScreen> {
  bool _isLoading = false;

  Future<void> _mockVerify() async {
    // Prevent multiple submissions
    if (_isLoading) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Simulate network delay to show loading screen
      await Future.delayed(const Duration(seconds: 2));

      // The "Mock" Logic: Update the profile
      await supabase
          .from('profiles')
          .update({'is_verified': true}).eq('id', userId);

      if (!mounted) return;

      // CRITICAL: Invalidate the auth provider to refresh the account screen
      ref.invalidate(authNotifierProvider);

      // Navigate to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HostVerificationSuccessScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Screen 2: Show loading UI 
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Verifying your account...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait a moment.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Screen 1: Show verification UI 
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Icon(
              Icons.shield_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Verify Your Account',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your IC to verify your identity. This helps build trust with tenants.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Mock "Upload Document" button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Upload & Verify IC (Mock)'),
                  Icon(Icons.upload_file_outlined),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _mockVerify,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Submit & Verify IC'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}