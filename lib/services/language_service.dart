import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'theme_service.dart';

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

  /// Reactive notifier for current language
  static final ValueNotifier<String> currentLanguage = ValueNotifier<String>('en');

  static String get selectedLang => currentLanguage.value;
  static bool get isUrdu => currentLanguage.value == 'ur';

  /// ✅ Global Translation Helper Function
  /// Kisi bhi screen par Text(LanguageService.t('Teams')) likhein
  static String t(String key) {
    if (!isUrdu) return key;
    return _urduDictionary[key] ?? key;
  }

  /// App ke saare alfaz ki Dictionary
  static final Map<String, String> _urduDictionary = {
    // Bottom Nav & Titles
    'Feed': 'فیڈ',
    'Teams': 'ٹیمز',
    'Messages': 'پیغامات',
    'Rooms': 'رومز',
    'Profile': 'پروفائل',
    'Admin': 'ایڈمن',
    'Gamers ID': 'گیمرز آئی ڈی',

    // Feed Screen
    "What's on your mind?": 'آپ کے ذہن میں کیا ہے؟',
    'Post': 'پوسٹ',
    'Like': 'پسند',
    'Comment': 'تبصرہ',
    'Share': 'شیئر',
    'Search Gamers': 'گیمرز تلاش کریں',
    'comments': 'تبصرے',
    'Comments': 'تبصرے',
    'Write a comment...': 'ایک تبصرہ لکھیں...',
    'Just now': 'ابھی',
    'Report Post': 'پوسٹ رپورٹ کریں',
    'Delete Post': 'پوسٹ ڈیلیٹ کریں',

    // Teams Screen
    'Create Team': 'ٹیم بنائیں',
    'Incoming Challenges': 'موصولہ چیلنجز',
    'Live': 'لائیو',
    'No live matches': 'کوئی لائیو میچ نہیں',
    'Search teams by name or tag...': 'نام یا ٹیگ سے تلاش کریں...',
    'Accept': 'قبول کریں',
    'Reject': 'مسترد',
    'CHALLENGE': 'چیلنج',
    'Challenge': 'چیلنج',
    'Team DM': 'ٹیم چیٹ',
    'END MATCH': 'میچ ختم کریں',
    'Join': 'شامل ہوں',
    'Requested': 'درخواست بھیجی',
    'Members': 'ارکان',
    'Leader': 'لیڈر',

    // Rooms Screen
    'Create Game Room': 'گیم روم بنائیں',
    'JOIN MATCH': 'میچ میں شامل ہوں',
    'ROOM CREDENTIALS': 'روم کی تفصیلات',
    'ROOM ID': 'روم آئی ڈی',
    'PASSWORD': 'پاس ورڈ',
    'Rules': 'قوانین',
    'PLAYERS': 'کھلاڑی',
    'Prize Pool': 'انعام',
    'WINNER': 'فاتح',
    'DEFEATED': 'شکست',
    'Type a message...': 'پیغام لکھیں...',
    'End Match (I Won)': 'میچ ختم (میں جیت گیا)',
    'Proof Submitted ⏳ (Tap to Change)': 'ثبوت جمع ہوگیا ⏳ (تبدیل کریں)',
    'Re-upload Proof 🔄': 'دوبارہ ثبوت اپلوڈ کریں 🔄',
  };

  /// Initialize and load saved language preference
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(keySelectedLanguage) ?? prefs.getString(keySelectedLang);
      if (savedLang != null && savedLang.isNotEmpty) {
        currentLanguage.value = savedLang;
      } else {
        currentLanguage.value = 'en';
      }
    } catch (_) {
      currentLanguage.value = 'en';
    }
  }

  /// Change active language and persist in SharedPreferences
  static Future<void> setLanguage(String code) async {
    currentLanguage.value = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keySelectedLang, code);
      await prefs.setString(keySelectedLanguage, code);
      await prefs.setBool(keyHasChosenLanguage, true);
    } catch (_) {}
  }

  /// Quick toggle between 'en' and 'ur'
  static Future<void> toggleLanguage() async {
    final next = currentLanguage.value == 'ur' ? 'en' : 'ur';
    await setLanguage(next);
  }

  static const List<Locale> supportedLocales = [
    Locale('ro'),
    Locale('en'),
    Locale('hi'),
    Locale('ur'),
    Locale('bn'),
    Locale('ar'),
    Locale('zh'),
  ];

  static const List<LanguageModel> languages = [
    LanguageModel(code: 'ro', englishName: 'Roman', nativeName: 'Roman', flag: '🌐', isRtl: false),
    LanguageModel(code: 'en', englishName: 'English', nativeName: 'English', flag: '🇬🇧', isRtl: false),
    LanguageModel(code: 'hi', englishName: 'Hindi', nativeName: 'हिंदी', flag: '🇮🇳', isRtl: false),
    LanguageModel(code: 'ur', englishName: 'Urdu', nativeName: 'اردو', flag: '🇵🇰', isRtl: true),
    LanguageModel(code: 'bn', englishName: 'Bengali', nativeName: 'বাংলা', flag: '🇧🇩', isRtl: false),
    LanguageModel(code: 'ar', englishName: 'Arabic', nativeName: 'العربية', flag: '🇸🇦', isRtl: true),
    LanguageModel(code: 'zh', englishName: 'Chinese', nativeName: '中文', flag: '🇨🇳', isRtl: false),
  ];

  static LanguageModel getLanguageModel(String code) {
    return languages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => languages[1],
    );
  }

  static bool isRtlLocale(Locale locale) {
    return locale.languageCode == 'ar' || locale.languageCode == 'ur';
  }

  static Future<String> getAutoDetectedLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(keySelectedLanguage);
    if (savedCode != null && savedCode.isNotEmpty) {
      return savedCode;
    }

    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final countryCode = (locale.countryCode ?? '').toUpperCase();
      final langCode = (locale.languageCode).toLowerCase();

      if (countryCode == 'PK' || langCode == 'ur') {
        return 'ur';
      } else if (countryCode == 'IN' || langCode == 'hi') {
        return 'hi';
      } else if (countryCode == 'BD' || langCode == 'bn') {
        return 'bn';
      } else if (['SA', 'AE', 'EG', 'KW', 'QA', 'OM', 'BH', 'IQ', 'JO', 'LB'].contains(countryCode) || langCode == 'ar') {
        return 'ar';
      } else if (['CN', 'TW', 'HK', 'MO', 'SG'].contains(countryCode) || langCode == 'zh') {
        return 'zh';
      }
    } catch (_) {}

    return 'en';
  }

  static Future<bool> shouldShowFirstLaunchPicker() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(keyHasChosenLanguage) ?? false);
  }

  static Future<void> saveLanguagePreference(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keySelectedLanguage, code);
    await prefs.setString(keySelectedLang, code);
    await prefs.setBool(keyHasChosenLanguage, true);
    currentLanguage.value = code;
  }

  /// Shows the 7-language bottom sheet
  static void showLanguageBottomSheet(
    BuildContext context, {
    bool isFirstLaunch = false,
    VoidCallback? onLanguageChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !isFirstLaunch,
      enableDrag: !isFirstLaunch,
      builder: (modalContext) {
        String currentLocaleCode = 'en';
        try {
          currentLocaleCode = context.locale.languageCode;
        } catch (_) {
          currentLocaleCode = LanguageService.currentLanguage.value;
        }

        final isDark = ThemeService.isDarkMode;
        final bg = isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);
        final card = isDark ? const Color(0xFF1E242C) : const Color(0xFFF3F4F6);
        final border = isDark ? const Color(0xFF2D3748) : const Color(0xFFE5E7EB);
        final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
        final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
        final neonGreen = ThemeService.primaryGreen;

        String selectedCode = currentLocaleCode;

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return PopScope(
              canPop: !isFirstLaunch,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: neonGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.language_rounded, color: neonGreen, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Language',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Choose your preferred language',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isFirstLaunch)
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: textSecondary),
                              onPressed: () => Navigator.pop(modalContext),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: languages.map((lang) {
                          final isSelected = selectedCode == lang.code;

                          return InkWell(
                            onTap: () async {
                              setSheetState(() {
                                selectedCode = lang.code;
                              });

                              await saveLanguagePreference(lang.code);

                              if (modalContext.mounted) {
                                Navigator.pop(modalContext);
                              }

                              try {
                                if (context.mounted) {
                                  await context.setLocale(Locale(lang.code));
                                }
                              } catch (_) {}

                              onLanguageChanged?.call();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: (MediaQuery.of(context).size.width - 60) / 2,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected ? neonGreen.withOpacity(0.15) : card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? neonGreen : border,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: neonGreen.withOpacity(0.2),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    lang.flag,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          lang.nativeName,
                                          style: TextStyle(
                                            color: isSelected ? neonGreen : textPrimary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (lang.code != 'en' && lang.code != 'ro')
                                          Text(
                                            lang.englishName,
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 10,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle_rounded, color: neonGreen, size: 18),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
