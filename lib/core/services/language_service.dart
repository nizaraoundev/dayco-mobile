import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends GetxService {
  static const String _languageKey = 'selected_language';
  static const String _languageSelectedKey = 'language_already_selected';

  // Default language is French
  static const String defaultLanguage = 'fr';

  // Available languages
  static const Map<String, Map<String, String>> supportedLanguages = {
    'fr': {
      'name': 'Français',
      'nativeName': 'Français',
      'flag': '🇫🇷',
    },
    'ar': {
      'name': 'Arabic',
      'nativeName': 'العربية',
      'flag': '🇹🇳',
    },
    'en': {
      'name': 'English',
      'nativeName': 'English',
      'flag': '🇺🇸',
    },
  };

  late SharedPreferences _prefs;
  final RxString currentLanguage = defaultLanguage.obs;
  final RxBool isLanguageSelected = false.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initPreferences();
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();

    // Load saved language or use default
    final savedLanguage = _prefs.getString(_languageKey) ?? defaultLanguage;
    currentLanguage.value = savedLanguage;

    // Check if language was already selected
    isLanguageSelected.value = _prefs.getBool(_languageSelectedKey) ?? false;

    // Update app locale
    Get.updateLocale(Locale(savedLanguage));
  }

  /// Check if user has already selected a language
  bool hasSelectedLanguage() {
    return _prefs.getBool(_languageSelectedKey) ?? false;
  }

  /// Get current saved language
  String getCurrentLanguage() {
    return _prefs.getString(_languageKey) ?? defaultLanguage;
  }

  /// Set language and save to preferences
  Future<void> setLanguage(String languageCode) async {
    if (supportedLanguages.containsKey(languageCode)) {
      currentLanguage.value = languageCode;
      await _prefs.setString(_languageKey, languageCode);
      await _prefs.setBool(_languageSelectedKey, true);
      isLanguageSelected.value = true;

      // Update app locale
      Get.updateLocale(Locale(languageCode));
    }
  }

  /// Reset language selection (useful for testing)
  Future<void> resetLanguageSelection() async {
    await _prefs.remove(_languageSelectedKey);
    isLanguageSelected.value = false;
  }

  /// Get language display name
  String getLanguageName(String languageCode) {
    return supportedLanguages[languageCode]?['name'] ?? 'Unknown';
  }

  /// Get language native name
  String getLanguageNativeName(String languageCode) {
    return supportedLanguages[languageCode]?['nativeName'] ?? 'Unknown';
  }

  /// Get language flag
  String getLanguageFlag(String languageCode) {
    return supportedLanguages[languageCode]?['flag'] ?? '🏳️';
  }

  /// Get all supported languages as a list
  List<MapEntry<String, Map<String, String>>> getSupportedLanguages() {
    return supportedLanguages.entries.toList();
  }
}
