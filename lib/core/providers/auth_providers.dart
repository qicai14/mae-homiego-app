import 'dart:async';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart'; // Import the Profile model
import 'package:homiego/core/services/supabase_client.dart'; // Import the supabase client getter
import 'package:homiego/core/services/booking_service.dart'; // For booking synchronization
import 'package:homiego/features/general/views/notification_screen.dart' as notification_screen;
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth state (user + profile)
@immutable
class AppAuthState {
  final User? user;
  final Profile? profile;

  // Constructor
  const AppAuthState({this.user, this.profile});

  // Helper getters
  bool get isLoggedIn => user != null;
  bool get isEmailVerified => user?.emailConfirmedAt != null;
  bool get isProfileComplete => profile?.fullName?.isNotEmpty ?? false;

  // Copy with updates
  AppAuthState copyWith({
    User? user,
    Profile? profile,
  }) {
    return AppAuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
    );
  }

   @override
   String toString() => 'AppAuthState(user: ${user?.id}, profile: ${profile?.id}, verified: $isEmailVerified, complete: $isProfileComplete)';

   // Equality comparison
   @override
   bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppAuthState && other.user == user && other.profile == profile;
   }

   @override
   int get hashCode => user.hashCode ^ profile.hashCode;
}

// Auth state manager
class AuthNotifier extends AsyncNotifier<AppAuthState> {
  StreamSubscription<AuthState>? _authStateSubscription;

  // Initialize state and listeners
  @override
  Future<AppAuthState> build() async {
    debugPrint("AuthNotifier: Build started");

    // Get initial user and profile
    final initialUser = supabase.auth.currentUser;
    Profile? initialProfile;

    if (initialUser != null) {
      debugPrint("AuthNotifier: Initial user found (${initialUser.id}), fetching profile...");
      initialProfile = await _fetchProfile(initialUser.id);
      debugPrint("AuthNotifier: Initial profile fetched: ${initialProfile?.id}");
      
      // Sync bookings on initial load
      _synchronizeBookingsOnLogin();
    } else {
       debugPrint("AuthNotifier: No initial user.");
    }

    // Listen to auth changes
    _listenToAuthStateChanges();

    // Cleanup on dispose
    ref.onDispose(() {
      debugPrint("AuthNotifier: Disposing auth state listener");
      _authStateSubscription?.cancel();
    });

     debugPrint("AuthNotifier: Build finished. Initial State: User=${initialUser?.id}, Profile=${initialProfile?.id}");
    return AppAuthState(user: initialUser, profile: initialProfile);
  }


  // Listen to auth state changes
  void _listenToAuthStateChanges() {
    _authStateSubscription?.cancel();
    _authStateSubscription = supabase.auth.onAuthStateChange.listen(
      (data) async {
        try {
          final Session? session = data.session;
          final user = session?.user;
          debugPrint("AuthNotifier: Auth state changed. New User: ${user?.id}");

          if (user == null) {
            // User logged out
            try {
              state = AsyncData(const AppAuthState(user: null, profile: null));
            } catch (e) {
              debugPrint("AuthNotifier: Error updating state (logged out): $e");
            }
            debugPrint("AuthNotifier: User logged out.");
          } else {
            // User logged in, fetch profile
            debugPrint("AuthNotifier: User logged in/refreshed (${user.id}), fetching profile...");
            final profile = await _fetchProfile(user.id);
            debugPrint("AuthNotifier: Profile fetched: ${profile?.id}");
            
            // Update state
            try {
              state = AsyncData(AppAuthState(user: user, profile: profile));
            } catch (e) {
              debugPrint("AuthNotifier: Error updating state (logged in): $e");
              return;
            }
            
            // Sync bookings after state update
            _synchronizeBookingsOnLogin();
          }
        } catch (e, stackTrace) {
          debugPrint("AuthNotifier: Error in auth state change handler: $e");
          debugPrint("AuthNotifier: Stack trace: $stackTrace");
          try {
            state = AsyncError(e, stackTrace);
          } catch (_) {
            // Ignore if disposed
          }
        }
      },
      onError: (error) {
         debugPrint("AuthNotifier: Error in auth state stream: $error");
        try {
          state = AsyncError(error, StackTrace.current);
        } catch (_) {
          // Ignore if disposed
        }
      },
    );
  }

  // Fetch profile from database
  Future<Profile?> _fetchProfile(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return Profile.fromMap(response);
    } catch (e) {
      debugPrint("AuthNotifier: Error fetching profile for user $userId: $e");
      return null;
    }
  }

  // Sync bookings in background
  void _synchronizeBookingsOnLogin() {
    Future.microtask(() async {
      try {
        debugPrint("AuthNotifier: Starting booking synchronization...");
        final currentUser = supabase.auth.currentUser;
        final updatedCount = await BookingService.synchronizeBookings();
        if (updatedCount > 0) {
          debugPrint("AuthNotifier: Synchronized $updatedCount booking(s) - declined/refunded pending bookings past check-in");
          
          // Refresh notifications after delay
          if (currentUser != null) {
            Future.delayed(const Duration(milliseconds: 100), () {
              try {
                if (ref.exists(notification_screen.notificationsProvider(currentUser.id))) {
                  ref.invalidate(notification_screen.notificationsProvider(currentUser.id));
                  debugPrint("AuthNotifier: Invalidated notification provider after synchronization");
                }
              } catch (e) {
                debugPrint("AuthNotifier: Error invalidating notification provider: $e");
              }
            });
          }
        } else {
          debugPrint("AuthNotifier: Booking synchronization completed - no bookings to update");
        }
      } catch (e, stackTrace) {
        debugPrint("AuthNotifier: Error during booking synchronization: $e");
        debugPrint("AuthNotifier: Stack trace: $stackTrace");
        // Background sync, don't throw
      }
    });
  }

  // Sign in
  Future<void> signInWithEmail(String email, String password) async {
    try {
      debugPrint("AuthNotifier: Attempting sign in for $email");
      await supabase.auth.signInWithPassword(email: email, password: password);
      debugPrint("AuthNotifier: Sign in successful (state update pending listener)");
    } catch (e) {
       debugPrint("AuthNotifier: Sign in failed: $e");
      rethrow;
    }
  }

    // Sign up
    Future<AuthResponse> signUpWithEmail(String email, String password, {Map<String, dynamic>? data}) async {
      try {
        debugPrint("AuthNotifier: Attempting sign up for $email with data: $data");
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
          data: data,
        );
        debugPrint("AuthNotifier: Sign up successful (auth part). User: ${response.user?.id}");
        return response;
      } catch (e) {
        debugPrint("AuthNotifier: Sign up failed: $e");
        rethrow;
      }
    }

  // Sign out
  Future<void> signOut() async {
    try {
      debugPrint("AuthNotifier: Attempting sign out");
      await supabase.auth.signOut();
      debugPrint("AuthNotifier: Sign out successful (state update pending listener)");
    } catch (e) {
       debugPrint("AuthNotifier: Sign out failed: $e");
      rethrow;
    }
  }

  // Send password reset email
  Future<void> sendPasswordReset(String email) async {
     try {
      debugPrint("AuthNotifier: Sending password reset for $email");
       await supabase.auth.resetPasswordForEmail(email);
        debugPrint("AuthNotifier: Password reset email sent.");
     } catch (e) {
        debugPrint("AuthNotifier: Password reset failed: $e");
       rethrow;
     }
  }

  // Refresh user data
  Future<void> refreshUser() async {
     final user = state.value?.user;
     if (user != null) {
        try {
          debugPrint("AuthNotifier: Refreshing user data for ${user.id}");
          ref.invalidateSelf();
          debugPrint("AuthNotifier: User refresh triggered by invalidation.");
        } catch (e) {
          debugPrint("AuthNotifier: User refresh failed: $e");
        }
     } else {
        debugPrint("AuthNotifier: Cannot refresh, no user logged in.");
     }
  }



  /// Update profile and refresh state
  Future<void>   updateProfile(Map<String, dynamic> data) async {
    final profileId = state.value?.profile?.id;
    if (profileId == null) {
      throw Exception('User is not logged in. Cannot update profile.');
    }

    try {
      debugPrint("AuthNotifier: Updating profile for $profileId with data: $data");
      await supabase.from('profiles').update(data).eq('id', profileId);

      debugPrint("AuthNotifier: Update successful, refetching profile...");
      final newProfile = await _fetchProfile(profileId);

      if (newProfile != null) {
        state = AsyncData(state.value!.copyWith(profile: newProfile));
        debugPrint("AuthNotifier: State updated with new profile.");
      } else {
        throw Exception('Failed to refetch profile after update.');
      }
    } catch (e) {
      debugPrint("AuthNotifier: updateProfile failed: $e");
      rethrow;
    }
  }
}

// Auth provider
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AppAuthState>(() {
  return AuthNotifier();
});

