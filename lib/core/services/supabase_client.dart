import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A Riverpod provider that exposes the Supabase client.
///
/// This is the *only* way other providers or widgets should access
/// the Supabase client, adhering to our Riverpod architecture.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// We keep this getter for any potential non-Riverpod utility,
// but providers should be preferred.
SupabaseClient get supabase => Supabase.instance.client;
