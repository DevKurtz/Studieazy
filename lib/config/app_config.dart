/// Central configuration for the app.
/// Keep API keys here — do NOT commit to public repos.
class AppConfig {
  AppConfig._();

  /// The Gemini key is stored only as a Supabase Edge Function secret.
  static const String geminiModel = 'gemini-3.8-flash';

  /// Maximum file size the AI generator will accept (10 MB).
  static const int maxUploadBytes = 10 * 1024 * 1024;
}
