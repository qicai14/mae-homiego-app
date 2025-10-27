import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/features/admin/views/admin_dashboard_screen.dart';
import 'package:homiego/features/auth/views/complete_profile_screen.dart';
import 'package:homiego/features/auth/views/login_screen.dart';
import 'package:homiego/features/auth/views/verify_email_screen.dart';
import 'package:homiego/features/homeowner/views/homeowner_main_screen.dart';
import 'package:homiego/features/tenant/views/tenant_main_screen.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authNotifierProvider);

    return authStateAsync.when(
      loading: () {
        debugPrint("AuthGate: Loading auth state...");
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stackTrace) {
        debugPrint("AuthGate: Error loading auth state: $error");
        // Use LoginScreen for errors, but *without* a message
        // to prevent snackbar loops.
        return const LoginScreen();
      },
      data: (authState) {
        final User? user = authState.user;
        final Profile? profileData = authState.profile;

        debugPrint(
            "AuthGate: State received. User: ${user?.id}, Profile: ${profileData?.id}, Verified: ${authState.isEmailVerified}, Complete: ${authState.isProfileComplete}");

        // --- Case 1: User Not Logged In ---
        if (user == null) {
          debugPrint("AuthGate: Case 1 -> LoginScreen");
          return const LoginScreen();
        }

        // --- Case 2: User Logged In, Email Not Verified ---
        if (!authState.isEmailVerified) {
          debugPrint("AuthGate: Case 2 -> VerifyEmailScreen");
          return const VerifyEmailScreen();
        }

        // --- Case 3: User Logged In, Verified, Profile Missing (Safety Net) ---
        if (profileData == null) {
          debugPrint("AuthGate: Case 3 -> Profile MISSING! Forcing logout.");
          // This *shouldn't* happen with the trigger, but it's a good safety catch.
          Future.microtask(
              () => ref.read(authNotifierProvider.notifier).signOut());
              
          // *** THIS IS THE FIX ***
          // Return a clean LoginScreen, NOT one with a message.
          // This stops the snackbar bug.
          return const LoginScreen();
        }

        // --- Case 4: User Logged In, Verified, Profile Not Complete ---
        if (!authState.isProfileComplete) {
          debugPrint("AuthGate: Case 4 -> CompleteProfileScreen");
          // The trigger made the profile, but 'full_name' is still NULL.
          // Send them to the screen to fill it in.
          return const CompleteProfileScreen();
        }

        // --- Case 5: User Logged In, Verified, Profile Complete ---
        debugPrint("AuthGate: Case 5 -> Role Routing (${profileData.role})");
        switch (profileData.role) {
          case UserRole.tenant:
            return const TenantMainScreen(); // TODO: Create this screen
          case UserRole.homeowner:
            return const HomeownerMainScreen();
          case UserRole.admin:
            return const AdminDashboardScreen(); // TODO: Create this screen
        }
      },
    );
  }
}