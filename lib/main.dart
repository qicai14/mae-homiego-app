import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/theme/app_theme.dart';
import 'package:homiego/features/auth/views/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  runApp(
    // ProviderScope is what "activates" Riverpod for the app
    const ProviderScope(
      child: HomiegoApp(),
    ),
  );
}

// Global helper to access the Supabase client easily
final supabase = Supabase.instance.client;

class HomiegoApp extends StatelessWidget {
  const HomiegoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Homiego',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false, // Hides the debug banner
      home: const AuthGate(), // The new entry point for our app
    );
  }
}

