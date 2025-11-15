import 'dart:async'; // Required for TimeoutException
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'core/theme/app_theme.dart';
import 'features/auth/views/auth_gate.dart';

// DO NOT define the global supabase client here anymore. Access it via:
// import 'package:homiego/core/services/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  debugPrint('main: before dotenv.load'); 
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('main: dotenv loaded'); 
    // Quick check if keys were loaded (optional but helpful)
    if (dotenv.env['SUPABASE_URL'] == null || dotenv.env['SUPABASE_ANON_KEY'] == null) {
       throw Exception('.env file missing SUPABASE_URL or SUPABASE_ANON_KEY');
    }
  } catch (e) {
     debugPrint('main: Failed to load .env file: $e');
     // Handle error appropriately, maybe show an error screen
     // For now, we'll just print and continue, Supabase init will likely fail
  }


  // Initialize Supabase
  try {
    debugPrint('main: before Supabase.initialize'); // ChatGPT Suggestion
    await Supabase.initialize( // <-- Error should disappear here
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      debug: true, // Enable Supabase SDK logging
    ).timeout(const Duration(seconds: 15), onTimeout: () { // ChatGPT Suggestion
      // If initialization takes longer than 15 seconds, throw an error.
      throw TimeoutException('Supabase.initialize() timed out after 15 seconds');
    });
    debugPrint('main: Supabase initialized successfully'); // ChatGPT Suggestion

  } on TimeoutException catch (e) {
      debugPrint('main: Supabase init error (Timeout): $e');
      // TODO: Show an error message to the user (e.g., check internet)
      // For now, we proceed, but the app might not work correctly.
  } catch (e, st) {
    // Catch any other initialization errors (wrong URL/Key, network issues)
    debugPrint('main: Supabase init error (Other): $e\n$st'); // ChatGPT Suggestion
    // TODO: Show an error message to the user
  }

  // Run the app
  runApp(
    const ProviderScope(
      child: HomiegoApp(),
    ),
  );
}

// Global helper access is now handled by lib/core/services/supabase_client.dart

class HomiegoApp extends StatelessWidget {
  const HomiegoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Homiego',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

