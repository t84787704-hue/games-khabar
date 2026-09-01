import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();

  /// 7 Target languages:
  /// - Roman: Original text from admin
  /// - English: 'en'
  /// - Hindi: 'hi'
  /// - Urdu: 'ur'
  /// - Bengali: 'bn'
  /// - Arabic: 'ar'
  /// - Chinese: 'zh-cn' (saved as 'zh' and 'zh-cn')
  static Future<Map<String, String>> translateTo7Languages(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      return {
        'roman': '',
        'ro': '',
        'en': '',
        'hi': '',
        'ur': '',
        'bn': '',
        'ar': '',
        'zh': '',
      };
    }

    final Map<String, String> result = {
      'roman': clean,
      'ro': clean,
      'en': clean,
      'hi': clean,
      'ur': clean,
      'bn': clean,
      'ar': clean,
      'zh': clean,
    };

    // Target definitions for Google Translator
    final targetLanguages = [
      {'key': 'en', 'code': 'en'},
      {'key': 'hi', 'code': 'hi'},
      {'key': 'ur', 'code': 'ur'},
      {'key': 'bn', 'code': 'bn'},
      {'key': 'ar', 'code': 'ar'},
      {'key': 'zh', 'code': 'zh-cn'},
    ];

    await Future.wait(
      targetLanguages.map((target) async {
        final key = target['key']!;
        final code = target['code']!;
        try {
          final translation = await _translator.translate(clean, to: code);
          final translatedText = translation.text.trim();
          if (translatedText.isNotEmpty) {
            result[key] = translatedText;
            if (key == 'zh') {
              result['zh-cn'] = translatedText;
            }
          }
        } catch (e) {
          debugPrint('Translation error for $key ($code): $e');
          // If translation fails (e.g. offline/timeout), keep fallback to clean input
        }
      }),
    );

    return result;
  }
}
