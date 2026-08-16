import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Supported app languages. Add new ones here + a matching
/// assets/lang/<code>.json file + a pubspec.yaml entry.
enum AppLanguage { bisaya, tagalog, english }

extension AppLanguageMeta on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.bisaya:
        return 'bis';
      case AppLanguage.tagalog:
        return 'tl';
      case AppLanguage.english:
        return 'en';
    }
  }

  /// Label shown in the UI toggle itself — intentionally NOT translated,
  /// since a language switcher should always show language names in their
  /// own language (so a user can find their language even if the app is
  /// currently showing a language they don't read).
  String get nativeLabel {
    switch (this) {
      case AppLanguage.bisaya:
        return 'Bisaya';
      case AppLanguage.tagalog:
        return 'Tagalog';
      case AppLanguage.english:
        return 'English';
    }
  }
}

/// Single source of truth for theme + language. Lives above [MaterialApp]
/// (see main_example.dart) so changing it rebuilds the whole app, not just
/// one screen.
///
/// Plain ChangeNotifier — no external state management package required.
class AppSettings extends ChangeNotifier {
  bool _isDarkMode = false;
  AppLanguage _language = AppLanguage.bisaya;
  Map<String, String> _translations = {};
  bool _ready = false;

  bool get isDarkMode => _isDarkMode;
  AppLanguage get language => _language;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// True once the first translation file has finished loading. Gate your
  /// app's first frame on this (see main_example.dart) so you never flash
  /// raw translation keys on screen.
  bool get ready => _ready;

  /// Call once at startup, before runApp.
  Future<void> init() async {
    await _loadTranslations(_language);
    _ready = true;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    _persist();
  }

  void toggleDarkMode() => setDarkMode(!_isDarkMode);

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    await _loadTranslations(lang);
    _language = lang;
    notifyListeners();
    _persist();
  }

  Future<void> _loadTranslations(AppLanguage lang) async {
    try {
      final raw = await rootBundle.loadString('assets/lang/${lang.code}.json');
      final Map<String, dynamic> decoded = json.decode(raw) as Map<String, dynamic>;
      _translations = decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e, st) {
      // Fail soft: keep whatever translations we had (or empty), so the UI
      // falls back to showing raw keys instead of crashing.
      debugPrint('AppSettings: failed to load lang/${lang.code}.json: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// Look up a translated string by key, with optional {placeholder}
  /// substitution, e.g. t('age_years', {'age': '68'}).
  String t(String key, [Map<String, String>? args]) {
    var value = _translations[key] ?? key;
    if (args != null) {
      args.forEach((placeholder, replacement) {
        value = value.replaceAll('{$placeholder}', replacement);
      });
    }
    return value;
  }

  void _persist() {
    // Hook persistence here later, e.g. with shared_preferences:
    //   final prefs = await SharedPreferences.getInstance();
    //   await prefs.setBool('isDarkMode', _isDarkMode);
    //   await prefs.setString('language', _language.code);
    // Left as a no-op for now since you're keeping this dependency-free;
    // without it, dark mode / language reset to defaults on app restart.
  }
}