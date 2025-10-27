import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/main.dart'; // To access global 'supabase'
import 'package:supabase_flutter/supabase_flutter.dart';

// This provider manages the entire auth state (user, profile, logic)
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AppAuthState>(() {
  return AuthNotifier();
});

// RENAMED to AppAuthState to avoid conflict with Supabase's 'AuthState'
class AppAuthState {
  final User? user;
  final Profile? profile;

  AppAuthState({this.user, this.profile});

  bool get isEmailVerified => user?.emailConfirmedAt != null;
  bool get isProfileComplete => profile?.isProfileComplete ?? false;
}

class AuthNotifier extends AsyncNotifier<AppAuthState> {

  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  Future<AppAuthState> build() async {
    // Listen to Supabase's auth changes
    _authStateSubscription?.cancel();
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      // 'data' is Supabase's AuthState object
      final session = data.session;
      if (session == null) {
        state = AsyncData(AppAuthState(user: null, profile: null));
      } else {
        // User is logged in, now fetch their profile
        try {
          final profileData = await _fetchProfile(session.user.id);
          state = AsyncData(AppAuthState(user: session.user, profile: profileData));
        } catch (e) {
          state = AsyncError(e, StackTrace.current);
        }
      }
    });

    ref.onDispose(() {
      _authStateSubscription?.cancel();
    });

    // Initial check
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      return AppAuthState(user: null, profile: null);
    }

    final profileData = await _fetchProfile(currentUser.id);
    return AppAuthState(user: currentUser, profile: profileData);
  }

  Future<Profile?> _fetchProfile(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return Profile.fromMap(response);
    } catch (e) {
      // This happens if the profile doesn't exist yet after signup
      return null;
    }
  }

  // --- Auth Actions ---

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = supabase.auth.currentUser!;
      final profile = await _fetchProfile(user.id);
      return AppAuthState(user: user, profile: profile);
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cred = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (cred.user == null) {
        throw Exception("Sign up failed");
      }
      
      await supabase.from('profiles').insert({
        'id': cred.user!.id,
        'full_name': fullName,
        'role': role.name,
      });
      
      final profileData = await _fetchProfile(cred.user!.id);
      return AppAuthState(user: cred.user, profile: profileData);
    });
  }
  
  Future<void> sendEmailVerification() async {
     await supabase.auth.resend(
       type: OtpType.signup,
       email: state.value?.user?.email,
     );
  }

  Future<void> completeProfile(String fullName, String contactNo) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = state.value!.user!;
      await supabase.from('profiles').update({
        'full_name': fullName,
        'contact_no': contactNo,
      }).eq('id', user.id);
      
      final profileData = await _fetchProfile(user.id);
      return AppAuthState(user: user, profile: profileData);
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await supabase.auth.signOut();
  }
  
  Future<void> refreshAuth() async {
    state = const AsyncLoading();
    await supabase.auth.refreshSession();
    
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      state = AsyncData(AppAuthState(user: null, profile: null));
      return;
    }
    final profileData = await _fetchProfile(currentUser.id);
    state = AsyncData(AppAuthState(user: currentUser, profile: profileData));
  }
}

