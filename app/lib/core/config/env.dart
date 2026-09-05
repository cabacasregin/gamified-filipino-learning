/// Build-time configuration, supplied via `--dart-define` (see README for
/// the exact `flutter run` / `flutter build` invocations). Keeping secrets
/// out of source control: the Supabase anon key is safe to ship in a client
/// (it's public by design, protected by RLS), but is still not hardcoded
/// here so different environments (dev/staging/prod projects) can swap it.
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
