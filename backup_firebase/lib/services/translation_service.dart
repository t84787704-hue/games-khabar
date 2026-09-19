import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
import 'package:http/http.dart' as http;
import '../models/news_model.dart';
import 'firestore_service.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();
  static final Map<String, String> _cache = {};

  /// Clean Steam BBCode tags, HTML tags, and HTML entities into clean readable text
  static String cleanBbCodeAndHtml(String text) {
    if (text.isEmpty) return '';
    String t = text;

    // 1. Strip Steam image BBCode: [img]...[/img]
    t = t.replaceAll(RegExp(r'\[img\][\s\S]*?\[\/img\]', caseSensitive: false), '');

    // 2. Unwrap URL tags: [url=...]text[/url] -> text
    t = t.replaceAllMapped(
      RegExp(r'\[url=[^\]]*\]([\s\S]*?)\[\/url\]', caseSensitive: false),
      (m) => m.group(1) ?? '',
    );

    // 3. Headings and paragraphs to double newlines
    t = t.replaceAll(RegExp(r'\[\/?h[1-6]\]', caseSensitive: false), '\n\n');
    t = t.replaceAll(RegExp(r'\[\/?p\]', caseSensitive: false), '\n\n');

    // 4. Bullet points
    t = t.replaceAll(RegExp(r'\[\*\]', caseSensitive: false), '\n• ');

    // 5. Remove other BBCode tags
    t = t.replaceAll(
      RegExp(
        r'\[\/?(?:list|olist|b|i|u|s|strike|code|pre|quote|previewyoutube|youtube|video|spoiler|table|tr|td|th|hr)[^\]]*\]',
        caseSensitive: false,
      ),
      '',
    );
    t = t.replaceAll(
      RegExp(r'\[\/?(?:color|size|align|font|img)[^\]]*\]', caseSensitive: false),
      '',
    );

    // 6. HTML breaks and paragraphs
    t = t.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n');
    t = t.replaceAll(RegExp(r'<\/?p>', caseSensitive: false), '\n\n');
    t = t.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // 7. HTML entities
    t = t
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&hellip;', '...')
        .replaceAll('&ndash;', '-')
        .replaceAll('&mdash;', '—');

    // 8. Normalize spacing and multiple line breaks
    t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t.trim();
  }

  /// Check if the given text matches the script of the target language
  static bool isTextInLanguage(String text, String targetLang) {
    if (text.trim().isEmpty) return false;
    final lang = targetLang.toLowerCase();
    if (lang == 'ur' || lang == 'ar') {
      // Arabic / Urdu Unicode range
      return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    } else if (lang == 'hi') {
      // Devanagari Unicode range
      return RegExp(r'[\u0900-\u097F]').hasMatch(text);
    } else if (lang == 'bn') {
      // Bengali Unicode range
      return RegExp(r'[\u0980-\u09FF]').hasMatch(text);
    } else if (lang == 'zh' || lang == 'zh-cn') {
      // CJK ideographs
      return RegExp(r'[\u4E00-\u9FFF]').hasMatch(text);
    }
    // For English or Roman script
    return true;
  }

  static String _mapAppLang(String appLang) {
    String l = appLang.toLowerCase();
    if (l == 'ur') return 'ur';
    if (l == 'hi') return 'hi';
    if (l == 'bn' || l.contains('bengla')) return 'bn';
    if (l == 'ar') return 'ar';
    if (l == 'zh' || l == 'zh-cn' || l.contains('china')) return 'zh-cn';
    if (l == 'en') return 'en';
    if (l == 'ro' || l.contains('roman')) return 'ro';
    return l;
  }

  /// Translate a single sentence or short text (e.g. title) with multiple fallbacks
  static Future<String> translateSingle(String text, String targetAppLang) async {
    String clean = cleanBbCodeAndHtml(text);
    if (clean.isEmpty) return clean;

    final targetCode = _mapAppLang(targetAppLang);
    if (targetCode == 'en' || targetCode == 'ro' || targetAppLang.toLowerCase().contains('roman')) {
      return clean;
    }

    // If already in target language script, return immediately
    if (isTextInLanguage(clean, targetCode)) {
      return clean;
    }

    final key = "$targetCode::$clean";
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final String googleCode = targetCode == 'zh-cn' ? 'zh-CN' : targetCode;

    // 1. Google Translate Direct API (client=dict-chrome-ex, fast, no 429 captcha)
    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=dict-chrome-ex&sl=auto&tl=$googleCode&dt=t&q=${Uri.encodeComponent(clean)}',
      );
      final res = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        if (parsed is List && parsed.isNotEmpty && parsed[0] is List) {
          final buffer = StringBuffer();
          for (final item in parsed[0]) {
            if (item is List && item.isNotEmpty && item[0] != null) {
              buffer.write(item[0].toString());
            }
          }
          final translated = buffer.toString().trim();
          if (translated.isNotEmpty && isTextInLanguage(translated, targetCode)) {
            _cache[key] = translated;
            return translated;
          }
        }
      }
    } catch (_) {}

    // 2. Google Mobile Web Translate fallback
    try {
      final uri = Uri.parse(
        'https://translate.google.com/m?sl=auto&tl=$googleCode&q=${Uri.encodeComponent(clean)}',
      );
      final res = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final match = RegExp(r'class="result-container">([\s\S]*?)<\/div>', caseSensitive: false).firstMatch(res.body);
        if (match != null && match.group(1) != null) {
          final translated = cleanBbCodeAndHtml(match.group(1)!);
          if (translated.isNotEmpty && isTextInLanguage(translated, targetCode)) {
            _cache[key] = translated;
            return translated;
          }
        }
      }
    } catch (_) {}

    // 3. MyMemory API fallback
    try {
      final queryText = clean.length > 500 ? clean.substring(0, 500) : clean;
      final myMemoryUri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(queryText)}&langpair=auto|$googleCode',
      );
      final res = await http.get(myMemoryUri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final translated = json['responseData']?['translatedText'] as String?;
        if (translated != null &&
            translated.trim().isNotEmpty &&
            !translated.startsWith('MYMEMORY WARNING')) {
          final decoded = cleanBbCodeAndHtml(translated);
          if (decoded.isNotEmpty && isTextInLanguage(decoded, targetCode)) {
            _cache[key] = decoded;
            return decoded;
          }
        }
      }
    } catch (_) {}

    // 4. GoogleTranslator package fallback
    try {
      final t = await _translator.translate(clean, to: googleCode).timeout(const Duration(seconds: 4));
      final translated = t.text.trim();
      if (translated.isNotEmpty && isTextInLanguage(translated, targetCode)) {
        _cache[key] = translated;
        return translated;
      }
    } catch (_) {}

    return clean;
  }

  /// Translate full multi-paragraph articles chunk by chunk in parallel preserving structure
  static Future<String> translateArticle(String fullText, String targetAppLang) async {
    final clean = cleanBbCodeAndHtml(fullText);
    if (clean.isEmpty) return clean;

    final targetCode = _mapAppLang(targetAppLang);
    if (targetCode == 'en' || targetCode == 'ro' || targetAppLang.toLowerCase().contains('roman')) {
      return clean;
    }

    if (isTextInLanguage(clean, targetCode)) {
      return clean;
    }

    final key = "article::$targetCode::$clean";
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    // Split text into paragraphs
    final paragraphs = clean
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) return clean;

    // Translate all paragraphs in parallel for instant loading
    final translatedParagraphs = await Future.wait(
      paragraphs.map((p) async {
        if (p.length <= 1500) {
          return await translateSingle(p, targetCode);
        } else {
          // Sub-chunk long paragraph by sentences
          final sentences = p.split(RegExp(r'(?<=[.!?\n])\s+'));
          String currentChunk = '';
          final chunkTranslations = <String>[];
          for (final s in sentences) {
            if ((currentChunk.length + s.length) < 800) {
              currentChunk += (currentChunk.isEmpty ? '' : ' ') + s;
            } else {
              if (currentChunk.isNotEmpty) {
                final ct = await translateSingle(currentChunk, targetCode);
                chunkTranslations.add(ct);
              }
              currentChunk = s;
            }
          }
          if (currentChunk.isNotEmpty) {
            final ct = await translateSingle(currentChunk, targetCode);
            chunkTranslations.add(ct);
          }
          return chunkTranslations.join(' ');
        }
      }),
    );

    final result = translatedParagraphs.join('\n\n');
    if (result.isNotEmpty && isTextInLanguage(result, targetCode)) {
      _cache[key] = result;
    }
    return result;
  }

  /// Ensure both title and description of a NewsModel are translated to target language
  static Future<void> ensureNewsItemTranslated(NewsModel news, String targetLang) async {
    final lang = _mapAppLang(targetLang);
    if (lang == 'en' || lang == 'ro' || targetLang.toLowerCase().contains('roman')) {
      return;
    }

    final currentTitle = news.getTitle(lang);
    final currentDesc = news.getDescription(lang);

    final titleNeeds = !isTextInLanguage(currentTitle, lang);
    final descNeeds = !isTextInLanguage(currentDesc, lang);

    if (!titleNeeds && !descNeeds) return;

    final tasks = <Future>[];

    if (titleNeeds) {
      final baseTitle = news.titleMap['en'] ?? currentTitle;
      tasks.add(translateSingle(baseTitle, lang).then((t) {
        if (t.isNotEmpty && isTextInLanguage(t, lang)) {
          news.titleMap[lang] = t;
        }
      }));
    }

    if (descNeeds) {
      final baseDesc = news.descriptionMap['en'] ?? currentDesc;
      tasks.add(translateArticle(baseDesc, lang).then((d) {
        if (d.isNotEmpty && isTextInLanguage(d, lang)) {
          news.descriptionMap[lang] = d;
        }
      }));
    }

    await Future.wait(tasks);

    // Also persist translation back to Firestore if document exists
    if (news.id.isNotEmpty && !news.id.startsWith('local-')) {
      final updatedTitle = news.titleMap[lang];
      final updatedDesc = news.descriptionMap[lang];
      if (updatedTitle != null || updatedDesc != null) {
        FirestoreService().updateNewsTranslation(
          news.id,
          lang,
          updatedTitle ?? currentTitle,
          updatedDesc ?? currentDesc,
        );
      }
    }
  }

  /// News save karte waqt ye use hota hai
  static Future<Map<String, String>> translateTo7Languages(String text) async {
    final clean = cleanBbCodeAndHtml(text);
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
        'zh-cn': '',
      };
    }
    Map<String, String> result = {
      'roman': clean,
      'ro': clean,
      'en': clean,
      'hi': clean,
      'ur': clean,
      'bn': clean,
      'ar': clean,
      'zh': clean,
      'zh-cn': clean,
    };
    final targets = [
      {'key': 'hi', 'code': 'hi'},
      {'key': 'ur', 'code': 'ur'},
      {'key': 'bn', 'code': 'bn'},
      {'key': 'ar', 'code': 'ar'},
      {'key': 'zh', 'code': 'zh-cn'},
    ];
    await Future.wait(targets.map((t) async {
      String translated = await translateSingle(clean, t['code']!);
      result[t['key']!] = translated;
      if (t['key'] == 'zh') result['zh-cn'] = translated;
    }));
    return result;
  }
}
