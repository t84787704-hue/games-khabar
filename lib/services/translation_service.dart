import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static final Map<String, String> _cache = {};

  static String _mapAppLang(String appLang) {
    String l = appLang.toLowerCase();
    if (l.contains('hi')) return 'hi';
    if (l.contains('ur')) return 'ur';
    if (l.contains('bn')) return 'bn';
    if (l.contains('ar')) return 'ar';
    if (l.contains('zh')) return 'zh-CN';
    if (l.contains('en')) return 'en';
    return 'en';
  }

  static Future<String> translateSingle(String text, String targetAppLang) async {
    String clean = text.trim();
    if (clean.isEmpty) return clean;

    String to = _mapAppLang(targetAppLang);
    if (to == 'en' || targetAppLang.toLowerCase().contains('roman') || targetAppLang == 'ro') {
      return clean;
    }

    String key = "$to::$clean";
    if (_cache.containsKey(key)) return _cache[key]!;

    // 1st try: MyMemory API (sabse stable)
    try {
      final url = Uri.parse('https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(clean)}&langpair=en|$to');
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String translated = data['responseData']?['translatedText']?? '';
        if (translated.isNotEmpty &&!translated.toLowerCase().contains('mymemory')) {
          _cache[key] = translated;
          return translated;
        }
      }
    } catch (e) {}

    // 2nd try: Google gtx API
    try {
      String code = to;
      final url = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=$code&dt=t&q=${Uri.encodeComponent(clean)}');
      final res = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data!= null && data[0] is List) {
          String translated = (data[0] as List).map((e) => e[0].toString()).join('');
          if (translated.trim().isNotEmpty) {
            _cache[key] = translated;
            return translated;
          }
        }
      }
    } catch (e) {}

    return clean;
  }

  static Future<Map<String, String>> translateTo7Languages(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      return {'roman': '', 'ro': '', 'en': '', 'hi': '', 'ur': '', 'bn': '', 'ar': '', 'zh': '', 'zh-cn': ''};
    }
    Map<String, String> result = {
      'roman': clean, 'ro': clean, 'en': clean,
      'hi': clean, 'ur': clean, 'bn': clean,
      'ar': clean, 'zh': clean, 'zh-cn': clean
    };

    final targets = [
      {'key': 'hi', 'code': 'hi'},
      {'key': 'ur', 'code': 'ur'},
      {'key': 'bn', 'code': 'bn'},
      {'key': 'ar', 'code': 'ar'},
      {'key': 'zh', 'code': 'zh-CN'},
    ];

    await Future.wait(targets.map((t) async {
      String translated = await translateSingle(clean, t['code']!);
      result[t['key']!] = translated;
      if (t['key'] == 'zh') result['zh-cn'] = translated;
    }));

    return result;
  }

  static void clearCache() => _cache.clear();
}