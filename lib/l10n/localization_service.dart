import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Manages app localization and language selection
/// Uses JSON files for translations to make it versatile for the team
class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  static const String _defaultLanguage = 'ca'; // Default to Catalan

  late SharedPreferences _prefs;
  Locale _currentLocale = const Locale('ca');
  Map<String, String> _translations = {};

  LocalizationService() {
    _initializeLanguage();
  }

  Future<void> _initializeLanguage() async {
    _prefs = await SharedPreferences.getInstance();
    final savedLanguage = _prefs.getString(_languageKey) ?? _defaultLanguage;
    _currentLocale = Locale(savedLanguage);
    Intl.defaultLocale = savedLanguage;
    await _loadTranslations(savedLanguage);
    notifyListeners();
  }

  /// Loads translation JSON file for the given language
  Future<void> _loadTranslations(String languageCode) async {
    try {
      final filePath = 'lib/l10n/translations_$languageCode.json';
      final jsonString = await rootBundle.loadString(filePath);
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      _translations = jsonMap.cast<String, String>();
    } catch (e) {
      print('Error loading translations for $languageCode: $e');
      // Fallback to English if there's an error
      if (languageCode != 'en') {
        await _loadTranslations('en');
      }
    }
  }

  Locale get currentLocale => _currentLocale;

  String get currentLanguageCode => _currentLocale.languageCode;

  bool get isCatalan => _currentLocale.languageCode == 'ca';

  bool get isEnglish => _currentLocale.languageCode == 'en';

  /// Changes the app language and saves preference
  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'ca' && languageCode != 'en') {
      return;
    }

    _currentLocale = Locale(languageCode);
    Intl.defaultLocale = languageCode;
    await _loadTranslations(languageCode);
    await _prefs.setString(_languageKey, languageCode);
    notifyListeners();
  }

  /// Toggle between Catalan and English
  Future<void> toggleLanguage() async {
    final newLanguage = isCatalan ? 'en' : 'ca';
    await setLanguage(newLanguage);
  }

  /// Get localized string using translation key
  /// Returns the key if translation not found (fallback)
  String translate(String key) {
    return _translations[key] ?? key;
  }

  /// Get all translations for exporting/viewing (useful for team)
  Map<String, String> getAllTranslations() => Map.unmodifiable(_translations);
}
