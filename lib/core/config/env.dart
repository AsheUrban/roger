/// Environment configuration for roger.
///
/// Values are injected at build time via --dart-define flags:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ... \
///     --dart-define=R2_ENDPOINT=https://xxx.r2.cloudflarestorage.com \
///     --dart-define=R2_BUCKET=roger-media \
///     --dart-define=R2_ACCESS_KEY_ID=xxx \
///     --dart-define=R2_SECRET_ACCESS_KEY=xxx
class Env {
  // Supabase (needed for step 3: auth & onboarding)
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Cloudflare R2 (needed for step 11: R2 pipeline)
  static const r2Endpoint = String.fromEnvironment('R2_ENDPOINT');
  static const r2Bucket = String.fromEnvironment('R2_BUCKET');
  static const r2AccessKeyId = String.fromEnvironment('R2_ACCESS_KEY_ID');
  static const r2SecretAccessKey = String.fromEnvironment('R2_SECRET_ACCESS_KEY');
}
