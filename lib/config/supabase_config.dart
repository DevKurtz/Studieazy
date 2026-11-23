/// Supabase's project URL is public; the publishable key is also designed for
/// client apps. Database passwords and service-role keys must never go here.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url =
      'https://tqvpgvoxjmvmykzmakdj.supabase.co';
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => publishableKey.isNotEmpty;
}
