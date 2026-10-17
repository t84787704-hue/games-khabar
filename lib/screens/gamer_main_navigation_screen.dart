// ===============================================================================
// FULL MULTI-LANGUAGE SERVICE (7 Languages Dynamic Translation Dictionary)
// Supported: English (en), Urdu (ur), Hindi (hi), Arabic (ar), 
//            Bengali (bn), Chinese (zh), Roman (ro)
// ===============================================================================

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

  /// Reactive notifier for active language code
  static final ValueNotifier<String> currentLanguage = ValueNotifier<String>('en');

  static String get selectedLang => currentLanguage.value;
  static bool get isUrdu => currentLanguage.value == 'ur';
  static bool get isArabic => currentLanguage.value == 'ar';
  static bool get isRtl => isUrdu || isArabic;

  /// ✅ Global Translation Function: Jo zuban active hogi uska tarjuma return karega
  static String t(String key) {
    final lang = currentLanguage.value;
    if (lang == 'en') return key;
    return _translations[lang]?[key] ?? key;
  }

  /// 7 زبانوں کی مکمل ڈکشنری
  static final Map<String, Map<String, String>> _translations = {
    // 🇵🇰 اردو (Urdu)
    'ur': {
      'Feed': 'فیڈ',
      'Teams': 'ٹیمز',
      'Messages': 'پیغامات',
      'Rooms': 'رومز',
      'Profile': 'پروفائل',
      'Admin': 'ایڈمن',
      'Gamers ID': 'گیمرز آئی ڈی',
      "What's on your mind?": 'آپ کیا سوچ رہے ہیں؟',
      'Post': 'پوسٹ',
      'Like': 'پسند',
      'Comment': 'تبصرہ',
      'Share': 'شیئر',
      'Search Gamers': 'گیمرز تلاش کریں',
      'comments': 'تبصرے',
      'Comments': 'تبصرے',
      'Write a comment...': 'ایک تبصرہ لکھیں...',
      'Create Team': 'ٹیم بنائیں',
      'Incoming Challenges': 'موصولہ چیلنجز',
      'Live': 'لائیو',
      'No live matches': 'کوئی لائیو میچ نہیں',
      'Search teams by name or tag...': 'نام یا ٹیگ سے تلاش کریں...',
      'Accept': 'قبول کریں',
      'Reject': 'مسترد',
      'CHALLENGE': 'چیلنج',
      'Team DM': 'ٹیم چیٹ',
      'END MATCH': 'میچ ختم کریں',
      'Join': 'شامل ہوں',
      'Requested': 'درخواست بھیجی',
      'Members': 'ارکان',
      'Leader': 'لیڈر',
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
      'Follow Us': 'ہمیں فالو کریں',
    },

    // 🇮🇳 हिंदी (Hindi)
    'hi': {
      'Feed': 'फ़ीड',
      'Teams': 'टीमें',
      'Messages': 'संदेश',
      'Rooms': 'कमरे',
      'Profile': 'प्रोफ़ाइल',
      'Admin': 'व्यवस्थापक',
      'Gamers ID': 'गेमर्स आईडी',
      "What's on your mind?": 'आप क्या सोच रहे हैं?',
      'Post': 'पोस्ट',
      'Like': 'पसंद',
      'Comment': 'टिप्पणी',
      'Share': 'शेयर',
      'Search Gamers': 'गेमर्स खोजें',
      'comments': 'टिप्पणियां',
      'Comments': 'टिप्पणियां',
      'Write a comment...': 'टिप्पणी लिखें...',
      'Create Team': 'टीम बनाएं',
      'Incoming Challenges': 'आने वाली चुनौतियां',
      'Live': 'लाइव',
      'No live matches': 'कोई लाइव मैच नहीं',
      'Search teams by name or tag...': 'नाम या टैग से खोजें...',
      'Accept': 'स्वीकारें',
      'Reject': 'अस्वीकार',
      'CHALLENGE': 'चुनौती',
      'Team DM': 'टीम डीएम',
      'END MATCH': 'मैच समाप्त करें',
      'Join': 'शामिल हों',
      'Requested': 'अनुरोधित',
      'Members': 'सदस्य',
      'Leader': 'लीडर',
      'Create Game Room': 'गेम रूम बनाएं',
      'JOIN MATCH': 'मैच में शामिल हों',
      'ROOM CREDENTIALS': 'कमरे का विवरण',
      'ROOM ID': 'रूम आईडी',
      'PASSWORD': 'पासवर्ड',
      'Rules': 'नियम',
      'PLAYERS': 'खिलाड़ी',
      'Prize Pool': 'इनामी राशि',
      'WINNER': 'विजेता',
      'DEFEATED': 'पराजित',
      'Type a message...': 'संदेश लिखें...',
      'End Match (I Won)': 'मैच समाप्त (मैं जीता)',
      'Proof Submitted ⏳ (Tap to Change)': 'सबूत जमा हुआ ⏳ (बदलें)',
      'Re-upload Proof 🔄': 'फिर से सबूत अपलोड करें 🔄',
      'Follow Us': 'हमें फॉलो करें',
    },

    // 🇸🇦 العربية (Arabic)
    'ar': {
      'Feed': 'المنشورات',
      'Teams': 'الفرق',
      'Messages': 'الرسائل',
      'Rooms': 'الغرف',
      'Profile': 'الملف الشخصي',
      'Admin': 'المشرف',
      'Gamers ID': 'هوية اللاعب',
      "What's on your mind?": 'بماذا تفكر؟',
      'Post': 'نشر',
      'Like': 'إعجاب',
      'Comment': 'تعليق',
      'Share': 'مشاركة',
      'Search Gamers': 'البحث عن لاعبين',
      'comments': 'تعليقات',
      'Comments': 'التعليقات',
      'Write a comment...': 'اكتب تعليقاً...',
      'Create Team': 'إنشاء فريق',
      'Incoming Challenges': 'التحديات الواردة',
      'Live': 'مباشر',
      'No live matches': 'لا توجد مباريات مباشرة',
      'Search teams by name or tag...': 'البحث بالاسم أو الرمز...',
      'Accept': 'قبول',
      'Reject': 'رفض',
      'CHALLENGE': 'تحدي',
      'Team DM': 'دردشة الفريق',
      'END MATCH': 'إنهاء المباراة',
      'Join': 'انضمام',
      'Requested': 'تم الطلب',
      'Members': 'الأعضاء',
      'Leader': 'القائد',
      'Create Game Room': 'إنشاء غرفة لعب',
      'JOIN MATCH': 'الانضمام للمباراة',
      'ROOM CREDENTIALS': 'بيانات الغرفة',
      'ROOM ID': 'معرّف الغرفة',
      'PASSWORD': 'كلمة المرور',
      'Rules': 'القواعد',
      'PLAYERS': 'اللاعبون',
      'Prize Pool': 'مجموع الجوائز',
      'WINNER': 'الفائز',
      'DEFEATED': 'مهزوم',
      'Type a message...': 'اكتب رسالة...',
      'End Match (I Won)': 'إنهاء المباراة (أنا فزت)',
      'Proof Submitted ⏳ (Tap to Change)': 'تم إرسال الإثبات ⏳ (تعديل)',
      'Re-upload Proof 🔄': 'إعادة رفع الإثبات 🔄',
      'Follow Us': 'تابعنا',
    },

    // 🇧🇩 বাংলা (Bengali)
    'bn': {
      'Feed': 'ফিড',
      'Teams': 'দলসমূহ',
      'Messages': 'বার্তাসমূহ',
      'Rooms': 'রুমসমূহ',
      'Profile': 'প্রোফাইল',
      'Admin': 'অ্যাডমিন',
      'Gamers ID': 'গেমার্স আইডি',
      "What's on your mind?": 'আপনার মনে কী আছে?',
      'Post': 'পোস্ট',
      'Like': 'পছন্দ',
      'Comment': 'মন্তব্য',
      'Share': 'শেয়ার',
      'Search Gamers': 'গেমার খুঁজুন',
      'comments': 'মন্তব্য',
      'Comments': 'মন্তব্যসমূহ',
      'Write a comment...': 'একটি মন্তব্য লিখুন...',
      'Create Team': 'দল তৈরি করুন',
      'Incoming Challenges': 'আগত চ্যালেঞ্জ',
      'Live': 'লাইভ',
      'No live matches': 'কোনো লাইভ ম্যাচ নেই',
      'Search teams by name or tag...': 'নাম বা ট্যাগ দিয়ে খুঁজুন...',
      'Accept': 'গ্রহণ করুন',
      'Reject': 'প্রত্যাখ্যান',
      'CHALLENGE': 'চ্যালেঞ্জ',
      'Team DM': 'টিম ডিএম',
      'END MATCH': 'ম্যাচ শেষ করুন',
      'Join': 'যোগ দিন',
      'Requested': 'অনুরোধ করা হয়েছে',
      'Members': 'সদস্যবৃন্দ',
      'Leader': 'দলনেতা',
      'Create Game Room': 'গেম রুম তৈরি করুন',
      'JOIN MATCH': 'ম্যাচে যোগ দিন',
      'ROOM CREDENTIALS': 'রুমের তথ্য',
      'ROOM ID': 'রুম আইডি',
      'PASSWORD': 'পাসওয়ার্ড',
      'Rules': 'নিয়মাবলী',
      'PLAYERS': 'খেলোয়াড়গণ',
      'Prize Pool': 'পুরস্কার তহবিল',
      'WINNER': 'বিজয়ী',
      'DEFEATED': 'পরাজিত',
      'Type a message...': 'একটি বার্তা লিখুন...',
      'End Match (I Won)': 'ম্যাচ শেষ (আমি জিতেছি)',
      'Proof Submitted ⏳ (Tap to Change)': 'প্রমাণ জমা হয়েছে ⏳ (পরিবর্তন)',
      'Re-upload Proof 🔄': 'প্রমাণ পুনরায় আপলোড করুন 🔄',
      'Follow Us': 'আমাদের অনুসরণ করুন',
    },

    // 🇨🇳 中文 (Chinese)
    'zh': {
      'Feed': '动态',
      'Teams': '战队',
      'Messages': '消息',
      'Rooms': '房间',
      'Profile': '个人资料',
      'Admin': '管理员',
      'Gamers ID': '玩家ID',
      "What's on your mind?": '分享你的新鲜事...',
      'Post': '发布',
      'Like': '点赞',
      'Comment': '评论',
      'Share': '分享',
      'Search Gamers': '搜索玩家',
      'comments': '条评论',
      'Comments': '评论列表',
      'Write a comment...': '写下你的评论...',
      'Create Team': '创建战队',
      'Incoming Challenges': '收到挑战',
      'Live': '比赛中',
      'No live matches': '暂无进行中的比赛',
      'Search teams by name or tag...': '搜索战队名称或标签...',
      'Accept': '接受',
      'Reject': '拒绝',
      'CHALLENGE': '发起挑战',
      'Team DM': '战队私信',
      'END MATCH': '结束比赛',
      'Join': '加入',
      'Requested': '已申请',
      'Members': '成员',
      'Leader': '队长',
      'Create Game Room': '创建比赛房间',
      'JOIN MATCH': '加入比赛',
      'ROOM CREDENTIALS': '房间凭据',
      'ROOM ID': '房间号',
      'PASSWORD': '密码',
      'Rules': '规则',
      'PLAYERS': '玩家列表',
      'Prize Pool': '总奖金',
      'WINNER': '获胜者',
      'DEFEATED': '败者',
      'Type a message...': '输入消息...',
      'End Match (I Won)': '结算比赛 (我赢了)',
      'Proof Submitted ⏳ (Tap to Change)': '已提交凭证 ⏳ (点击修改)',
      'Re-upload Proof 🔄': '重新上传凭证 🔄',
      'Follow Us': '关注我们',
    },

    // 🌐 Roman (Urdu/Hindi in English script)
    'ro': {
      'Feed': 'Feed',
      'Teams': 'Teams',
      'Messages': 'Messages',
      'Rooms': 'Rooms',
      'Profile': 'Profile',
      'Admin': 'Admin',
      'Gamers ID': 'Gamers ID',
      "What's on your mind?": 'Aap kya soch rahe hain?',
      'Post': 'Post',
      'Like': 'Like',
      'Comment': 'Comment',
      'Share': 'Share',
      'Search Gamers': 'Gamers talash karein',
      'comments': 'comments',
      'Comments': 'Comments',
      'Write a comment...': 'Ek comment likhein...',
      'Create Team': 'Team Banayein',
      'Incoming Challenges': 'Aye huwe challenges',
      'Live': 'Live',
      'No live matches': 'Koi live match nahi',
      'Search teams by name or tag...': 'Naam ya tag se dhoondein...',
      'Accept': 'Qabool',
      'Reject': 'Reject',
      'CHALLENGE': 'CHALLENGE',
      'Team DM': 'Team DM',
      'END MATCH': 'Match Khatam Karein',
      'Join': 'Join',
      'Requested': 'Requested',
      'Members': 'Members',
      'Leader': 'Leader',
      'Create Game Room': 'Game Room Banayein',
      'JOIN MATCH': 'MATCH JOIN KAREIN',
      'ROOM CREDENTIALS': 'Room Details',
      'ROOM ID': 'Room ID',
      'PASSWORD': 'Password',
      'Rules': 'Rules',
      'PLAYERS': 'Players',
      'Prize Pool': 'Prize Pool',
      'WINNER': 'WINNER',
      'DEFEATED': 'HAR GAYA',
      'Type a message...': 'Message likhein...',
      'End Match (I Won)': 'Match Khatam (Main Jeeta)',
      'Proof Submitted ⏳ (Tap to Change)': 'Proof Bhej Diya ⏳ (Badlein)',
      'Re-upload Proof 🔄': 'Dubara Proof Upload Karein 🔄',
      'Follow Us': 'Hamein Follow Karein',
    },
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
