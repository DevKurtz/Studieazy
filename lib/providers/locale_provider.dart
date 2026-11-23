import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  static const String _key = 'app_language_code';
  bool _hasManualSelection = false;

  static const List<AppLanguage> supportedLanguages = [
    AppLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English (US)',
      flag: '🇺🇸',
    ),
    AppLanguage(
      code: 'fil',
      name: 'Filipino',
      nativeName: 'Wikang Filipino',
      flag: '🇵🇭',
    ),
    AppLanguage(
      code: 'ceb',
      name: 'Cebuano',
      nativeName: 'Binisaya',
      flag: '🇵🇭',
    ),
    AppLanguage(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
    ),
  ];

  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_key);
      if (!_hasManualSelection && savedCode != null && _isSupported(savedCode)) {
        state = Locale(savedCode);
      }
    } catch (_) {}
  }

  Future<void> setLocale(String languageCode) async {
    if (!_isSupported(languageCode)) return;
    _hasManualSelection = true;
    state = Locale(languageCode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, languageCode);
    } catch (_) {}
  }

  bool _isSupported(String code) {
    return supportedLanguages.any((lang) => lang.code == code);
  }

  static AppLanguage getLanguage(String code) {
    return supportedLanguages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => supportedLanguages.first,
    );
  }
}
