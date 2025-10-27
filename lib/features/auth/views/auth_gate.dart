import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/features/admin/views/admin_dashboard_screen.dart';
import 'package:homiego/features/auth/views/complete_profile_screen.dart';
import 'package:homiego/features/auth/views/login_screen.dart';
import 'package:homiego/features/auth/views/verify_email_screen.dart';
import 'package:homiego/features/homeowner/views/homeowner_main_screen.dart';
import 'package:homiego/features/tenant/views/tenant_main_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return authState.when(
      data: (state) {
        if (state.user == null) {
          // 1. User is not logged in
          return const LoginScreen();
        }

        if (!state.isEmailVerified) {
          // 2. User is logged in but email is not verified
          return const VerifyEmailScreen();
        }

        if (state.profile == null || !state.isProfileComplete) {
          // 3. User is verified but profile is not complete
          return const CompleteProfileScreen();
        }
        
        // 4. User is logged in, verified, and profile is complete
        // Redirect based on role
        switch (state.profile!.role) {
          case UserRole.tenant:
            return const TenantMainScreen();
          case UserRole.homeowner:
            return const HomeownerMainScreen();
          case UserRole.admin:
            return const AdminDashboardScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: $error'),
          ),
        ),
      ),
    );
  }
}

