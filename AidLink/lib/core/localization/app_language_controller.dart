// Purpose: Manages application language selection and localization state.
// File: lib/core/localization/app_language_controller.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageController extends ChangeNotifier {
  AppLanguageController._();

  static final AppLanguageController instance = AppLanguageController._();

  static const String _prefsKey = 'app_language_code';
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isUrdu => _locale.languageCode == 'ur';

  // --- Load saved language from local storage ---
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefsKey);
    if (savedCode == null) return;
    _locale = _normalize(savedCode);
    notifyListeners();
  }

  // --- Persist selected language and notify listeners ---
  Future<void> setLanguageCode(String code) async {
    final normalized = _normalize(code);
    if (_locale == normalized) return;

    _locale = normalized;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalized.languageCode);
  }

  // --- Normalize unsupported codes to English ---
  Locale _normalize(String code) {
    final lower = code.toLowerCase();
    if (lower == 'ur') return const Locale('ur');
    return const Locale('en');
  }
}
