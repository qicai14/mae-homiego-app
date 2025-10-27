import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/utils/show_snackbar.dart';

class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authNotifierProvider).value?.user?.email ?? 'your email';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),
                Text(
                  'Verify Your Email',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'We\'ve sent a verification link to:\n$email\n\nPlease check your inbox and click the link to continue.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () async {
                    // This tells the app to re-check the auth state
                    // The user should click this AFTER clicking the email link
                    await ref.read(authNotifierProvider.notifier).refreshAuth();
                  },
                  child: const Text('I\'ve Verified! Continue'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    try {
                      await ref.read(authNotifierProvider.notifier).sendEmailVerification();
                      showSnackBar(context, 'Verification email sent!');
                    } catch(e) {
                      showSnackBar(context, e.toString(), isError: true);
                    }
                  },
                  child: const Text('Resend Verification Email'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await ref.read(authNotifierProvider.notifier).signOut();
                  },
                  child: Text(
                    'Log Out',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

