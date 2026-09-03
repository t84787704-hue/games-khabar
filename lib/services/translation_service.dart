import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
import 'package:http/http.dart' as http;

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();
  static final Map<String, String> _cache = {};

  static String _mapAppLang(String appLang) {
    String l = appLang.toLowerCase();
    if (l.contains('hi')) return 'hi';
    if (l.contains('ur')) return 'ur';
    if (l.contains('bn') || l.contains('bengla')) return 'bn';
    if (l.contains('ar')) return 'ar';
    if (l.contains('zh') || l.contains('china')) return 'zh-cn';
    if (l.contains('en')) return 'en';
    return 'en'; // roman ke liye
  }

  // UI me news dikhate waqt ye use hoga
  static Future<String> translateSingle(String text, String targetAppLang) async {
    String clean = text.trim();
    if (clean.isEmpty) return clean;
    String to = _mapAppLang(targetAppLang);
    if (to == 'en' || targetAppLang.toLowerCase().contains('roman')) return clean;

    String key = "$to::$clean";
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      var t = await _translator.translate(clean, to: to).timeout(Duration(seconds: 7));
      if (t.text.trim().isNotEmpty) {
        _cache[key] = t.text;
        return t.text;
      }
    } catch (e) {}

    try {
      String code = to == 'zh-cn'? 'zh-CN' : to;
      final url = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=$code&dt=t&q=${Uri.encodeComponent(clean)}');
      final res = await http.get(url).timeout(Duration(seconds: 7));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String translated = (data[0] as List).map((e) => e[0].toString()).join('');
        _cache[key] = translated;
        return translated;
      }
    } catch (e) {}
    return clean;
  }

  // News save karte waqt ye use hota hai
  static Future<Map<String, String>> translateTo7Languages(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return {'roman':'','ro':'','en':'','hi':'','ur':'','bn':'','ar':'','zh':'','zh-cn':''};
    Map<String, String> result = {'roman': clean, 'ro': clean, 'en': clean, 'hi': clean, 'ur': clean, 'bn': clean, 'ar': clean, 'zh': clean, 'zh-cn': clean};
    final targets = [{'key':'hi','code':'hi'},{'key':'ur','code':'ur'},{'key':'bn','code':'bn'},{'key':'ar','code':'ar'},{'key':'zh','code':'zh-cn'}];
    await Future.wait(targets.map((t) async {
      String translated = await translateSingle(clean, t['code']!);
      result[t['key']!] = translated;
      if (t['key'] == 'zh') result['zh-cn'] = translated;
    }));
    return result;
  }
}