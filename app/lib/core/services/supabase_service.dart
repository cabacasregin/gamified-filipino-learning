import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Thin wrapper around the Supabase singleton so the rest of the app never
/// touches `Supabase.instance` directly (keeps a single seam for testing).
class SupabaseService {
  SupabaseService._();

  static Future<void> init() async {
    await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
