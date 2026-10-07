import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class LocalizationHelper {
  static Map<String, String> _localizedStrings = {};

  static Future<void> loadLocalization() async {
    String languageCode = Get.locale?.languageCode ?? 'en';
    String countryCode = Get.locale?.countryCode ?? 'US';

    String jsonString;
    try {
      jsonString = await rootBundle
          .loadString('lib/localization/${languageCode}_${countryCode}.json');
    } catch (e) {
      // Fallback to English if the localization file doesn't exist
      jsonString = await rootBundle.loadString('lib/localization/en_US.json');
    }

    Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings =
        jsonMap.map((key, value) => MapEntry(key, value.toString()));
  }

  static String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}
