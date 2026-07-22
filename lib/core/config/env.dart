/// Environment configuration for roger.
///
/// Values are injected at build time via --dart-define flags:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// R2 credentials are intentionally absent: clients upload/download via
/// short-lived presigned URLs minted by an Edge Function (step 11), so R2
/// access keys never live in the client binary or env.
class Env {
  // Supabase (needed for step 3: auth & onboarding)
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
