import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../foundation/networking/app_network_client.dart';

class VmLocaleController extends ChangeNotifier {
  VmLocaleController._();

  static final VmLocaleController instance = VmLocaleController._();

  static const String _preferenceKey = 'funkey_ui_language_v1';

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  static Locale localeForLanguage(String language) {
    return switch (language.trim().toLowerCase()) {
      'hindi' => const Locale('hi'),
      'telugu' => const Locale('te'),
      _ => const Locale('en'),
    };
  }

  Future<void> restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final language = preferences.getString(_preferenceKey);
      if (language != null && language.trim().isNotEmpty) {
        _apply(localeForLanguage(language));
      }
    } catch (_) {
      // Locale persistence is convenience state. English remains safe fallback.
    }
  }

  Future<void> setLanguage(String language) async {
    final locale = localeForLanguage(language);
    _apply(locale);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_preferenceKey, language.trim());
    } catch (_) {
      // The active locale remains usable even if local persistence fails.
    }
  }

  Future<void> syncFromBackend() async {
    try {
      final response = await AppNetworkRuntime.shared.getMap('/settings/me');
      final settings = response['settings'];
      if (settings is! Map) return;
      final language = settings['language']?.toString().trim();
      if (language == null || language.isEmpty) return;
      await setLanguage(language);
    } catch (_) {
      // Backend settings are non-critical for startup. Keep local preference.
    }
  }

  void _apply(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}
