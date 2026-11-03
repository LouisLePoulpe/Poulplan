/// Poulapp cloud settings, injected at build time from the local `.env`
/// (`flutter run --dart-define-from-file=.env`). Empty in public builds
/// (F-Droid): the app then works locally only.
abstract final class CloudConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
