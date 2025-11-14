import 'dart:async';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart'; // Import the Profile model
import 'package:homiego/core/services/supabase_client.dart'; // Import the supabase client getter
import 'package:supabase_flutter/supabase_flutter.dart';

// --- State Class Definition ---
// Holds the combined authentication state (Supabase user + our Profile data)
@immutable // Makes the class immutable, good practice for state
class AppAuthState {
  final User? user;
  final Profile? profile; // <-- USE 'Profile' NOT 'AppProfile'

  // Constructor
  const AppAuthState({this.user, this.profile});

  // Helper getters derived from the state
  bool get isLoggedIn => user != null;
  bool get isEmailVerified => user?.emailConfirmedAt != null;
  // Profile is complete if it exists and the full name is not empty
  bool get isProfileComplete => profile?.fullName?.isNotEmpty ?? false;

  // Method to create a copy with updated values (for immutability)
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

   // Optional: For easy comparison if needed
   @override
   bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppAuthState && other.user == user && other.profile == profile;
   }

   @override
   int get hashCode => user.hashCode ^ profile.hashCode;
}

// --- AsyncNotifier Definition ---
// Manages fetching and updating the AppAuthState
class AuthNotifier extends AsyncNotifier<AppAuthState> {
  StreamSubscription<AuthState>? _authStateSubscription;

  // --- BUILD METHOD ---
  // Called initially and whenever dependencies change (but we have none here)
  // Sets up the initial state and listeners
  @override
  Future<AppAuthState> build() async {
    debugPrint("AuthNotifier: Build started");

    // Get initial Supabase user (might be null if not logged in)
    final initialUser = supabase.auth.currentUser;
    Profile? initialProfile;

    // If logged in initially, try to fetch profile
    if (initialUser != null) {
      debugPrint("AuthNotifier: Initial user found (${initialUser.id}), fetching profile...");
      initialProfile = await _fetchProfile(initialUser.id);
      debugPrint("AuthNotifier: Initial profile fetched: ${initialProfile?.id}");
    } else {
       debugPrint("AuthNotifier: No initial user.");
    }

    // Set up listener for Supabase auth changes (login, logout)
    _listenToAuthStateChanges();

    // Clean up the listener when the provider is disposed
    ref.onDispose(() {
      debugPrint("AuthNotifier: Disposing auth state listener");
      _authStateSubscription?.cancel();
    });

     debugPrint("AuthNotifier: Build finished. Initial State: User=${initialUser?.id}, Profile=${initialProfile?.id}");
    // Return the initial combined state
    return AppAuthState(user: initialUser, profile: initialProfile);
  }
  // --- END BUILD METHOD ---


  // --- Helper to listen to Supabase auth state ---
  void _listenToAuthStateChanges() {
    // Cancel any existing listener first
    _authStateSubscription?.cancel();
    // Listen to Supabase's stream
    _authStateSubscription = supabase.auth.onAuthStateChange.listen(
      (data) async {
        final Session? session = data.session;
        final user = session?.user;
        debugPrint("AuthNotifier: Auth state changed. New User: ${user?.id}");

        if (user == null) {
          // User logged out, update state with null user and profile
          state = AsyncData(const AppAuthState(user: null, profile: null));
           debugPrint("AuthNotifier: User logged out.");
        } else {
          // User logged in or token refreshed, fetch their profile
          debugPrint("AuthNotifier: User logged in/refreshed (${user.id}), fetching profile...");
          final profile = await _fetchProfile(user.id);
          debugPrint("AuthNotifier: Profile fetched: ${profile?.id}");
          // Update state with the new user and profile
          state = AsyncData(AppAuthState(user: user, profile: profile));
        }
      },
      onError: (error) {
         debugPrint("AuthNotifier: Error in auth state stream: $error");
        // Update state with error if the stream fails
        state = AsyncError(error, StackTrace.current);
      },
    );
  }

  // --- Helper to fetch profile data from 'profiles' table ---
  Future<Profile?> _fetchProfile(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single(); // Use .single() as ID should be unique

      // If data is returned, parse it into a Profile object
      return Profile.fromMap(response);
    } catch (e) {
      // Handle errors (e.g., profile not found, network error)
      debugPrint("AuthNotifier: Error fetching profile for user $userId: $e");
      return null; // Return null if profile fetch fails
    }
  }

  // --- Public methods to interact with Auth ---

  // Sign In
  Future<void> signInWithEmail(String email, String password) async {
    // No need to set loading state here, AsyncNotifier handles it
    try {
      debugPrint("AuthNotifier: Attempting sign in for $email");
      await supabase.auth.signInWithPassword(email: email, password: password);
      // Listener will update the state automatically on success
      debugPrint("AuthNotifier: Sign in successful (state update pending listener)");
    } catch (e) {
        debugPrint("AuthNotifier: Sign in failed: $e");
      // Rethrow the error so the UI can catch it and show a message
      rethrow;
    }
  }

    // Sign Up (REVISED to accept data parameter)
    Future<AuthResponse> signUpWithEmail(String email, String password, {Map<String, dynamic>? data}) async { // <-- ADDED data parameter
      try {
        debugPrint("AuthNotifier: Attempting sign up for $email with data: $data");
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
          data: data, // <-- PASS data to Supabase Auth
        );
        debugPrint("AuthNotifier: Sign up successful (auth part). User: ${response.user?.id}");
        // Profile creation is handled by the DB trigger using the metadata.
        return response;
      } catch (e) {
        debugPrint("AuthNotifier: Sign up failed: $e");
        rethrow;
      }
    }

  // Sign Out
  Future<void> signOut() async {
    try {
      debugPrint("AuthNotifier: Attempting sign out");
      await supabase.auth.signOut();
      // Listener will set state to null user/profile
      debugPrint("AuthNotifier: Sign out successful (state update pending listener)");
    } catch (e) {
       debugPrint("AuthNotifier: Sign out failed: $e");
      // Optionally update state to error or rethrow
      rethrow;
    }
  }

  // Send Password Reset Email
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

  // Refresh user data (e.g., after email verification)
  Future<void> refreshUser() async {
     final user = state.value?.user; // Get current user from state
     if (user != null) {
        try {
          debugPrint("AuthNotifier: Refreshing user data for ${user.id}");
          // Note: Supabase Flutter SDK might handle some refresh automatically,
          // but explicit refresh can be useful after manual actions like verification.
          // await user.update() // or other relevant methods if needed
          // For now, simply re-triggering the auth listener might be enough
          // or re-fetch profile if only profile data changed.
          // Let's just invalidate for now to re-run build and fetch everything.
          ref.invalidateSelf(); // Re-run the build method
          debugPrint("AuthNotifier: User refresh triggered by invalidation.");
        } catch (e) {
          debugPrint("AuthNotifier: User refresh failed: $e");
          // Handle error appropriately
        }
     } else {
        debugPrint("AuthNotifier: Cannot refresh, no user logged in.");
     }
  }



  /// Updates the user's profile in the 'profiles' table and refreshes the state.
  Future<void>   updateProfile(Map<String, dynamic> data) async {
    final profileId = state.value?.profile?.id;
    if (profileId == null) {
      throw Exception('User is not logged in. Cannot update profile.');
    }

    try {
      debugPrint("AuthNotifier: Updating profile for $profileId with data: $data");
      // 1. Update the database
      await supabase.from('profiles').update(data).eq('id', profileId);

      // 2. Refetch the profile to get fresh data
      debugPrint("AuthNotifier: Update successful, refetching profile...");
      final newProfile = await _fetchProfile(profileId);

      // 3. Update the local Riverpod state
      if (newProfile != null) {
        state = AsyncData(state.value!.copyWith(profile: newProfile));
        debugPrint("AuthNotifier: State updated with new profile.");
      } else {
        // This case is unlikely if the update succeeded, but good to handle
        throw Exception('Failed to refetch profile after update.');
      }
    } catch (e) {
      debugPrint("AuthNotifier: updateProfile failed: $e");
      rethrow; // Rethrow to be caught by the UI
    }
  }
}

// --- Provider Definition ---
// Exposes the AuthNotifier and its state (AppAuthState) to the app
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AppAuthState>(() {
  return AuthNotifier();
});

