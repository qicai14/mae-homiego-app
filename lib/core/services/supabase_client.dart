import 'package:supabase_flutter/supabase_flutter.dart'; // <-- ADD THIS LINE

// Use a getter so the client is only accessed after Supabase is initialized.
// This single file is now the ONLY place other parts of the app
// should get the Supabase client from.
SupabaseClient get supabase => Supabase.instance.client;
