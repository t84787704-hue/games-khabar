import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguageModel {
  final String code;
  final String englishName;
  final String nativeName;
  final String flag;
  final bool isRtl;

  const LanguageModel({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.flag,
    this.isRtl = false,
  });
}

class LanguageService {
  static const String keySelectedLanguage = 'selected_language_code';
  static const String keySelectedLang = 'selectedLang';
  static const String keyHasChosenLanguage = 'has_selected_language_first_launch';

  /// ✅ Ab app hamesha English pe lock hai
  static final ValueNotifier<String> currentLanguage = ValueNotifier<String>('en');

  static String get selectedLang => 'en';
  static bool get isUrdu => false; // Hamesha false taake RTL logic trigger na ho

  /// Global Translation Helper
  static String t(String key, {BuildContext? context, List<String>? args}) {
    try {
      if (context != null) {
        return key.tr(context: context, args: args);
      }
      return key.tr(args: args);
    } catch (_) {
      return key;
    }
  }

  /// Initialize and force English
  static Future<void> init() async {
    currentLanguage.value = 'en';
  }

  /// Change language (Bypassed - Hamesha English)
  static Future<void> setLanguage(String code) async {
    currentLanguage.value = 'en';
  }

  /// Toggle language (Bypassed - Hamesha English)
  static Future<void> toggleLanguage() async {
    currentLanguage.value = 'en';
  }

  /// ✅ Sirf English locale supported hai
  static const List<Locale> supportedLocales = [
    Locale('en'),
  ];

  /// ✅ Sirf English language list mein hai
  static const List<LanguageModel> languages = [
    LanguageModel(code: 'en', englishName: 'English', nativeName: 'English', flag: '🇬🇧', isRtl: false),
  ];

  static LanguageModel getLanguageModel(String code) {
    return languages.first; // Hamesha English return karega
  }

  static bool isRtlLocale(Locale locale) {
    return false; // RTL hamesha off
  }

  static Future<String> getAutoDetectedLanguageCode() async {
    return 'en'; // Auto detect hamesha English
  }

  static Future<bool> shouldShowFirstLaunchPicker() async {
    return false; // Pehli baar language picker nahi khulega
  }

  static Future<void> saveLanguagePreference(String code) async {
    currentLanguage.value = 'en';
  }

  /// Language picker bottom sheet (Ab khali ya bypass)
  static void showLanguageBottomSheet(
    BuildContext context, {
    bool isFirstLaunch = false,
    VoidCallback? onLanguageChanged,
  }) {
    // Ab ye sheet kisi ko show nahi hogi
    return;
  }
}