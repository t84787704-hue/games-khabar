import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/fallback_images.dart';
import '../services/translation_service.dart';
import '../services/supabase_store_service.dart';

class RssSource {
  final String id;
  final String name;
  final String url;
  final String categoryHint;
  final String searchVolumeDesc;
  bool isEnabled;

  RssSource({
    required this.id,
    required this.name,
    required this.url,
    required this.categoryHint,
    this.searchVolumeDesc = '',
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'category': categoryHint,
        'categoryHint': categoryHint,
        'searchVolumeDesc': searchVolumeDesc,
        'isEnabled': isEnabled,
      };

  factory RssSource.fromJson(Map<String, dynamic> json, [String? id]) => RssSource(
        id: id ?? json['id'] as String? ?? UniqueKey().toString(),
        name: json['name'] as String? ?? 'Gaming Feed',
        url: json['url'] as String? ?? '',
        categoryHint: (json['category'] ?? json['categoryHint']) as String? ?? 'Gaming News',
        searchVolumeDesc: json['searchVolumeDesc'] as String? ?? '',
        isEnabled: json['isEnabled'] as bool? ?? true,
      );
}

class AutoNewsScraper {
  static const String collectionName = 'scraper_sources';
  static final AutoNewsScraper _instance = AutoNewsScraper._internal();
  factory AutoNewsScraper() => _instance;

  Timer? _scraperTimer;
  bool _isScraping = false;
  DateTime? _lastScrapeTime;
  int _lastScrapedCount = 0;
  String _statusMessage = 'Idle';

  // ValueNotifier so UI in Admin Panel updates live
  final ValueNotifier<bool> isScrapingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> statusNotifier = ValueNotifier<String>('Idle');
  final ValueNotifier<DateTime?> lastScrapeTimeNotifier = ValueNotifier<DateTime?>(null);
  final ValueNotifier<int> lastScrapedCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<RssSource>> sourcesNotifier = ValueNotifier<List<RssSource>>([]);

  // Top 10 High Search Volume Sources
  static final List<Map<String, dynamic>> defaultRssSources = [
    {
      'id': 'source_1_sportskeeda',
      'name': 'Sportskeeda',
      'url': 'https://www.sportskeeda.com/esports/feed',
      'category': 'BGMI / Free Fire',
      'isEnabled': true,
      'order': 1,
    },
    {
      'id': 'source_2_freefiremania',
      'name': 'FreeFireMania',
      'url': 'https://www.freefiremania.com/feed',
      'category': 'Free Fire',
      'isEnabled': true,
      'order': 2,
    },
    {
      'id': 'source_3_afkgaming',
      'name': 'AFK Gaming',
      'url': 'https://afkgaming.com/esports/feed',
      'category': 'BGMI / Valorant',
      'isEnabled': true,
      'order': 3,
    },
    {
      'id': 'source_4_talkesport',
      'name': 'TalkEsport',
      'url': 'https://www.talkesport.com/feed',
      'category': 'BGMI / Free Fire',
      'isEnabled': true,
      'order': 4,
    },
    {
      'id': 'source_5_gamerant',
      'name': 'Gamerant',
      'url': 'https://gamerant.com/feed/',
      'category': 'GTA / PUBG',
      'isEnabled': true,
      'order': 5,
    },
    {
      'id': 'source_6_ign',
      'name': 'IGN',
      'url': 'https://www.ign.com/rss/articles/feed',
      'category': 'GTA / COD',
      'isEnabled': true,
      'order': 6,
    },
    {
      'id': 'source_7_gamespot',
      'name': 'Gamespot',
      'url': 'https://www.gamespot.com/feeds/mashup/',
      'category': 'GTA / Minecraft',
      'isEnabled': true,
      'order': 7,
    },
    {
      'id': 'source_8_gamingonphone',
      'name': 'GamingOnPhone',
      'url': 'https://www.gamingonphone.com/feed/',
      'category': 'Free Fire / COD Mobile',
      'isEnabled': true,
      'order': 8,
    },
    {
      'id': 'source_9_pocketgamer',
      'name': 'PocketGamer',
      'url': 'https://www.pocketgamer.com/feed/',
      'category': 'Mobile Gaming',
      'isEnabled': true,
      'order': 9,
    },
    {
      'id': 'source_10_dexerto',
      'name': 'Dexerto',
      'url': 'https://www.dexerto.com/feed/',
      'category': 'GTA 6 Leaks',
      'isEnabled': true,
      'order': 10,
    },
  ];

  static List<RssSource> get defaultSources => defaultRssSources
      .map((s) => RssSource(
            id: s['id'] as String,
            name: s['name'] as String,
            url: s['url'] as String,
            categoryHint: s['category'] as String,
            searchVolumeDesc: s['category'] as String,
            isEnabled: s['isEnabled'] as bool? ?? true,
          ))
      .toList();

  AutoNewsScraper._internal();

  /// Seed 10 default sources to Supabase 'scraper_sources' and 'rss_sources' collections if empty
  static Future<void> seedDefaultSourcesIfEmpty() async {
    try {
      final snap = await SupabaseService.client
          .from('scraper_sources')
          .select('id')
          .limit(1);
      if (snap.isEmpty) {
        for (int i = 0; i < defaultRssSources.length; i++) {
          final s = defaultRssSources[i];
          final data = {
            'id': s['id'],
            'name': s['name'],
            'url': s['url'],
            'category': s['category'],
            'categoryHint': s['category'],
            'isActive': true,
            'isEnabled': true,
            'order': s['order'] ?? (i + 1),
            'createdAt': DateTime.now().toIso8601String(),
          };
          await SupabaseService.client.from('scraper_sources').upsert(data);
          try {
            await SupabaseService.client.from('rss_sources').upsert(data);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error seeding default sources: $e');
    }
  }

  /// Reset to 10 default sources in Supabase
  static Future<void> resetDefaultSources() async {
    try {
      try {
        await SupabaseService.client.from('scraper_sources').delete().neq('id', '___');
        await SupabaseService.client.from('rss_sources').delete().neq('id', '___');
      } catch (_) {}
      for (int i = 0; i < defaultRssSources.length; i++) {
        final s = defaultRssSources[i];
        final data = {
          'id': s['id'],
          'name': s['name'],
          'url': s['url'],
          'category': s['category'],
          'categoryHint': s['category'],
          'isActive': true,
          'isEnabled': true,
          'order': s['order'] ?? (i + 1),
          'createdAt': DateTime.now().toIso8601String(),
        };
        await SupabaseService.client.from('scraper_sources').upsert(data);
        try {
          await SupabaseService.client.from('rss_sources').upsert(data);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error resetting default sources: $e');
    }
  }

  /// Add a source to Supabase 'rss_sources' and 'scraper_sources'
  static Future<void> addSource({
    required String name,
    required String url,
    required String category,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;

    try {
      final docId = 'source_${DateTime.now().millisecondsSinceEpoch}';
      final data = {
        'id': docId,
        'name': name.trim().isEmpty ? 'Custom RSS Feed' : name.trim(),
        'url': cleanUrl,
        'category': category.trim().isEmpty ? 'Gaming News' : category.trim(),
        'categoryHint': category.trim().isEmpty ? 'Gaming News' : category.trim(),
        'isActive': true,
        'isEnabled': true,
        'order': DateTime.now().millisecondsSinceEpoch,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await SupabaseService.client.from('scraper_sources').upsert(data);
      try {
        await SupabaseService.client.from('rss_sources').upsert(data);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error adding source: $e');
    }
  }

  /// Delete a source from Supabase
  static Future<void> deleteSource(String docId) async {
    try {
      await SupabaseService.client.from('scraper_sources').delete().or('id.eq.$docId');
      try {
        await SupabaseService.client.from('rss_sources').delete().or('id.eq.$docId');
      } catch (_) {}
    } catch (e) {
      debugPrint('Error deleting source: $e');
    }
  }

  /// Toggle source enabled state in Supabase
  static Future<void> toggleSource(String docId, bool isEnabled) async {
    try {
      await SupabaseService.client.from('scraper_sources').update({
        'isActive': isEnabled,
        'isEnabled': isEnabled,
      }).or('id.eq.$docId');
      try {
        await SupabaseService.client.from('rss_sources').update({
          'isActive': isEnabled,
          'isEnabled': isEnabled,
        }).or('id.eq.$docId');
      } catch (_) {}
    } catch (e) {
      debugPrint('Error toggling source: $e');
    }
  }

  /// Initialize scraper with stored or default sources and start 30-minute interval
  Future<void> init() async {
    await seedDefaultSourcesIfEmpty();
    await _loadSources();
    startPeriodicScraping();
  }

  Future<void> _loadSources() async {
    try {
      await seedDefaultSourcesIfEmpty();
      final snap = await SupabaseService.client.from(collectionName).select();
      if (snap.isNotEmpty) {
        final list = snap.map((d) => RssSource.fromJson(d, (d['id'] ?? '').toString())).toList();
        sourcesNotifier.value = list;
        return;
      }
    } catch (_) {}
    sourcesNotifier.value = List.from(defaultSources);
  }

  Future<void> addSource({
    required String name,
    required String url,
    required String categoryHint,
    String searchVolumeDesc = '',
  }) async {
    await addSource(name: name, url: url, category: categoryHint);
    await _loadSources();
  }

  Future<void> toggleSourceInstance(String id, bool enabled) async {
    await toggleSource(id, enabled);
    await _loadSources();
  }

  Future<void> deleteSourceInstance(String id) async {
    await deleteSource(id);
    await _loadSources();
  }

  Future<void> resetToDefaultSources() async {
    await resetDefaultSources();
    await _loadSources();
  }

  /// Start background timer every 30 minutes
  void startPeriodicScraping() {
    _scraperTimer?.cancel();
    _scraperTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      runScraper();
    });
  }

  void stopPeriodicScraping() {
    _scraperTimer?.cancel();
    _scraperTimer = null;
  }

  /// Manual or scheduled trigger to run the RSS scraper across all active sources
  Future<int> runScraper() async {
    if (_isScraping) return 0;

    _isScraping = true;
    isScrapingNotifier.value = true;
    _statusMessage = 'Scraping RSS sources...';
    statusNotifier.value = _statusMessage;

    int totalAdded = 0;
    final activeSources =
        sourcesNotifier.value.where((s) => s.isEnabled && s.url.isNotEmpty).toList();

    try {
      final prefs = await SharedPreferences.getInstance();
      final seenUrls = (prefs.getStringList('seen_source_urls') ?? []).toSet();

      for (final source in activeSources) {
        try {
          _statusMessage = 'Fetching ${source.name}...';
          statusNotifier.value = _statusMessage;

          final items = await _fetchFeedItems(source.url);
          for (final item in items) {
            final sourceUrl = item['sourceUrl'] as String? ?? '';
            if (sourceUrl.isEmpty) continue;

            // 1. Quick Local Duplicate Check
            if (seenUrls.contains(sourceUrl)) {
              continue;
            }

            // 2. Database Duplicate Check
            final isDuplicate = await _checkDuplicate(sourceUrl);
            if (isDuplicate) {
              seenUrls.add(sourceUrl);
              continue;
            }

            // 3. Auto Categorization
            final rawTitle = item['title'] as String? ?? '';
            final rawContent = item['description'] as String? ?? '';
            final category = _detectCategory('$rawTitle $rawContent', source.categoryHint);

            // 4. Roman Urdu / Hinglish Translation
            final titleMap = await _createTranslatedTitleMap(rawTitle);
            final descMap = await TranslationService.translateTo7Languages(rawContent);

            // 5. Image & Video resolution (OG image extraction + per-article unique fallback)
            final imageUrl = await _resolveImageUrl(
              item['imageUrl'] as String?,
              category,
              title: rawTitle,
              content: rawContent,
              sourceUrl: sourceUrl,
            );

            // 6. Save to Database with isAuto: true
            final added = await _saveNews(
              titleMap: titleMap,
              descriptionMap: descMap,
              category: category,
              imageUrl: imageUrl,
              sourceUrl: sourceUrl,
              videoUrl: item['videoUrl'] as String?,
            );

            if (added) {
              totalAdded++;
              seenUrls.add(sourceUrl);
              // Limit seen URLs cache size to prevent memory bloat
              if (seenUrls.length > 500) {
                seenUrls.removeAll(seenUrls.take(100).toList());
              }
            }
          }
        } catch (e) {
          debugPrint('Error scraping ${source.name}: $e');
        }
      }

      await prefs.setStringList('seen_source_urls', seenUrls.toList());
      _lastScrapeTime = DateTime.now();
      _lastScrapedCount = totalAdded;
      lastScrapeTimeNotifier.value = _lastScrapeTime;
      lastScrapedCountNotifier.value = _lastScrapedCount;

      _statusMessage = totalAdded > 0
          ? 'Added $totalAdded new articles'
          : 'Feeds checked. All up to date';
      statusNotifier.value = _statusMessage;
    } catch (e) {
      _statusMessage = 'Scraping error: $e';
      statusNotifier.value = _statusMessage;
    } finally {
      _isScraping = false;
      isScrapingNotifier.value = false;
    }

    return totalAdded;
  }

  /// Categorization logic for Free Fire, BGMI, PUBG, GTA, MINECRAFT, ESPORTS
  String _detectCategory(String fullText, String hint) {
    final lower = fullText.toLowerCase();

    // 1. Free Fire
    if (lower.contains('free fire') ||
        lower.contains('freefire') ||
        lower.contains('ff max') ||
        lower.contains('ffmax') ||
        lower.contains('garena') ||
        lower.contains('free fire max') ||
        lower.contains('alok') ||
        lower.contains('chrono') ||
        lower.contains('bermuda max')) {
      return 'Free Fire';
    }

    // 2. BGMI
    if (lower.contains('bgmi') ||
        lower.contains('battlegrounds mobile india') ||
        lower.contains('bgis') ||
        lower.contains('bmps') ||
        lower.contains('bmsl') ||
        lower.contains('bgmi update') ||
        lower.contains('bgmi 3.') ||
        lower.contains('krafton india')) {
      return 'BGMI';
    }

    // 3. PUBG
    if (lower.contains('pubg') ||
        lower.contains('pubgm') ||
        lower.contains('pubg mobile') ||
        lower.contains('playerunknown') ||
        lower.contains('erangel') ||
        lower.contains('san hok') ||
        lower.contains('miramar')) {
      return 'PUBG';
    }

    // 4. GTA
    if (lower.contains('gta') ||
        lower.contains('gta 6') ||
        lower.contains('gta vi') ||
        lower.contains('gta 5') ||
        lower.contains('gta v') ||
        lower.contains('grand theft auto') ||
        lower.contains('rockstar games') ||
        lower.contains('vice city') ||
        lower.contains('lucia') ||
        lower.contains('leonida')) {
      return 'GTA';
    }

    // 5. MINECRAFT
    if (lower.contains('minecraft') ||
        lower.contains('mojang') ||
        lower.contains('bedrock edition') ||
        lower.contains('java edition') ||
        lower.contains('creeper') ||
        lower.contains('netherite') ||
        lower.contains('redstone')) {
      return 'MINECRAFT';
    }

    // 6. ESPORTS
    if (lower.contains('esports') ||
        lower.contains('e-sports') ||
        lower.contains('tournament') ||
        lower.contains('championship') ||
        lower.contains('valorant') ||
        lower.contains('vct') ||
        lower.contains('cs:go') ||
        lower.contains('cs2') ||
        lower.contains('counter-strike') ||
        lower.contains('call of duty') ||
        lower.contains('cod') ||
        lower.contains('warzone') ||
        lower.contains('codm') ||
        lower.contains('fortnite') ||
        lower.contains('league of legends') ||
        lower.contains('dota') ||
        lower.contains('mobile legends')) {
      return 'ESPORTS';
    }

    // Use hint if valid category
    final upperHint = hint.toUpperCase();
    if (upperHint.contains('FREE FIRE')) return 'Free Fire';
    if (upperHint.contains('BGMI')) return 'BGMI';
    if (upperHint.contains('PUBG')) return 'PUBG';
    if (upperHint.contains('GTA')) return 'GTA';
    if (upperHint.contains('MINECRAFT')) return 'MINECRAFT';
    if (upperHint.contains('ESPORTS')) return 'ESPORTS';

    return 'Gaming News';
  }

  /// Translate Title and generate Roman Urdu / Hinglish style
  Future<Map<String, String>> _createTranslatedTitleMap(String englishTitle) async {
    final base7Map = await TranslationService.translateTo7Languages(englishTitle);
    
    // Create catchy Roman Urdu / Hinglish version
    final romanUrdu = _convertToRomanUrdu(englishTitle, base7Map['hi'] ?? '', base7Map['ur'] ?? '');
    base7Map['roman'] = romanUrdu;
    base7Map['ro'] = romanUrdu;

    return base7Map;
  }

  String _convertToRomanUrdu(String title, String hindiText, String urduText) {
    String clean = title.trim();

    // Smart replacement of frequent gaming headlines to Roman Urdu / Hinglish
    final Map<RegExp, String> romanUrduPatterns = {
      RegExp(r'\bhow to download\b', caseSensitive: false): 'Kaise Download Karein',
      RegExp(r'\bhow to get\b', caseSensitive: false): 'Kaise Hasil Karein',
      RegExp(r'\brelease date\b', caseSensitive: false): 'Release Date & Launch Info',
      RegExp(r'\bnew update\b', caseSensitive: false): 'Naya Big Update',
      RegExp(r'\bpatch notes\b', caseSensitive: false): 'Patch Notes Aur Badlao',
      RegExp(r'\breward code\b', caseSensitive: false): 'Reward Code Aur Free Perks',
      RegExp(r'\bleaks\b', caseSensitive: false): 'Leaked Details Aur Khabar',
      RegExp(r'\bfeatures\b', caseSensitive: false): 'Naye Features',
      RegExp(r'\beverything you need to know\b', caseSensitive: false): 'Puri Tafseel Aur Details',
      RegExp(r'\bguide\b', caseSensitive: false): 'Complete Guide & Tips',
      RegExp(r'\bexplained\b', caseSensitive: false): 'Puri Jankari',
    };

    String result = clean;
    romanUrduPatterns.forEach((pattern, replacement) {
      result = result.replaceAll(pattern, replacement);
    });

    return result.trim().isNotEmpty ? result : clean;
  }

  /// Duplicate check in Supabase
  Future<bool> _checkDuplicate(String sourceUrl) async {
    try {
      final query = await SupabaseService.client
          .from('news')
          .select('id')
          .or('sourceUrl.eq.$sourceUrl,source_url.eq.$sourceUrl')
          .limit(1)
          .timeout(const Duration(seconds: 4));

      return query.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Fetch OG Image from article link: Use http.get(articleLink) and parse meta property="og:image"
  static Future<String?> fetchOgImage(String articleLink) async {
    if (articleLink.trim().isEmpty || !articleLink.startsWith('http')) return null;
    try {
      final res = await http.get(
        Uri.parse(articleLink),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final doc = html_parser.parse(res.body);
        final metaTags = doc.getElementsByTagName('meta');
        for (final meta in metaTags) {
          final prop = meta.attributes['property']?.toLowerCase() ?? '';
          final name = meta.attributes['name']?.toLowerCase() ?? '';
          final content = meta.attributes['content']?.trim() ?? '';

          if ((prop == 'og:image' ||
                  prop == 'og:image:url' ||
                  name == 'twitter:image' ||
                  name == 'twitter:image:src') &&
              content.isNotEmpty &&
              content.startsWith('http') &&
              !content.contains('icon') &&
              !content.contains('pixel') &&
              !content.contains('1x1')) {
            return content;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Resolve High Quality Category Fallback Images with Uniqueness
  Future<String> _resolveImageUrl(
    String? extractedUrl,
    String category, {
    String? title,
    String? content,
    String? sourceUrl,
    String? docId,
  }) async {
    // 1st-3rd tries: If valid unique image already found
    if (extractedUrl != null &&
        extractedUrl.trim().isNotEmpty &&
        !extractedUrl.contains('picsum.photos') &&
        !isCategoryDefaultImage(extractedUrl) &&
        (extractedUrl.startsWith('http://') || extractedUrl.startsWith('https://'))) {
      return extractedUrl.trim();
    }

    // 4th try: Fetch OG Image from article link (meta property="og:image")
    if (sourceUrl != null && sourceUrl.trim().isNotEmpty && sourceUrl.startsWith('http')) {
      final og = await fetchOgImage(sourceUrl.trim());
      if (og != null && og.isNotEmpty) {
        return og;
      }
    }

    // 5th fallback only if all fail: Diverse per-category pool (deterministic by docId / title)
    return getGameFallbackImage(
      category: category,
      title: title,
      content: content,
      docId: docId ?? sourceUrl ?? title,
    );
  }

  /// One-time migration function that updates existing news documents in Supabase
  /// where imageUrl is empty or matches category default image.
  Future<int> fixOldNewsImages() async {
    int updatedCount = 0;
    try {
      final snap = await SupabaseService.client.from('news').select();
      for (final data in snap) {
        final docId = (data['id'] ?? '').toString();
        final rawImg = (data['imageUrl'] ?? '').toString().trim();
        final sourceUrl = (data['sourceUrl'] ?? '').toString().trim();
        final category = (data['category'] ?? 'Gaming News').toString();
        final title = (data['title'] is Map ? data['title']['en'] ?? data['title']['hi'] : data['title'])?.toString() ?? '';
        final content = (data['content'] is Map ? data['content']['en'] : data['content'])?.toString() ?? '';

        if (isCategoryDefaultImage(rawImg) || rawImg.isEmpty || rawImg.contains('picsum.photos')) {
          String newImg = '';

          // 1. Try OG image
          if (sourceUrl.isNotEmpty && sourceUrl.startsWith('http')) {
            final og = await fetchOgImage(sourceUrl);
            if (og != null && og.isNotEmpty) {
              newImg = og;
            }
          }

          // 2. Fallback to unique pool image
          if (newImg.isEmpty || isCategoryDefaultImage(newImg)) {
            newImg = getGameFallbackImage(
              category: category,
              title: title,
              content: content,
              docId: docId,
            );
          }

          if (newImg.isNotEmpty && newImg != rawImg) {
            await SupabaseService.client.from('news').update({'imageUrl': newImg}).or('id.eq.$docId');
            updatedCount++;
            debugPrint('AutoNewsScraper: Fixed image for news doc $docId ($category): $newImg');
          }
        }
      }
    } catch (e) {
      debugPrint('AutoNewsScraper fixOldNewsImages error: $e');
    }
    return updatedCount;
  }

  /// Parse XML RSS & Atom feed items
  Future<List<Map<String, String?>>> _fetchFeedItems(String feedUrl) async {
    final List<Map<String, String?>> results = [];
    try {
      final response = await http.get(
        Uri.parse(feedUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return results;

      final xml = response.body;

      // Extract items or entries
      final itemRegExp = RegExp(r'<item[\s\S]*?<\/item>|<entry[\s\S]*?<\/entry>', caseSensitive: false);
      final matches = itemRegExp.allMatches(xml);

      for (final match in matches.take(15)) {
        final itemBlock = match.group(0) ?? '';
        if (itemBlock.isEmpty) continue;

        final title = _extractXmlTag(itemBlock, 'title');
        String link = _extractXmlTag(itemBlock, 'link');
        if (link.isEmpty) {
          final linkHrefMatch = RegExp(r'''<link[^>]+href=["']([^"']+)["']''', caseSensitive: false)
              .firstMatch(itemBlock);
          if (linkHrefMatch != null) {
            link = linkHrefMatch.group(1) ?? '';
          }
        }
        if (link.isEmpty) {
          link = _extractXmlTag(itemBlock, 'guid');
        }

        String description = _extractXmlTag(itemBlock, 'content:encoded');
        if (description.isEmpty) {
          description = _extractXmlTag(itemBlock, 'description');
        }
        if (description.isEmpty) {
          description = _extractXmlTag(itemBlock, 'summary');
        }

        // Clean HTML tags from description
        description = _stripHtml(description);

        // Extract image according to priority order:
        // 1. rssItem.enclosure?.url
        // 2. rssItem.media?.thumbnails?.first?.url
        // 3. <img> tag in content/description
        String? imageUrl;
        final enclosureMatch = RegExp(r'''<enclosure[^>]+url=["']([^"']+)["']''', caseSensitive: false)
            .firstMatch(itemBlock);
        if (enclosureMatch != null) {
          imageUrl = enclosureMatch.group(1);
        }

        if (imageUrl == null) {
          final mediaMatch = RegExp(r'''<media:(?:content|thumbnail)[^>]+url=["']([^"']+)["']''', caseSensitive: false)
              .firstMatch(itemBlock);
          if (mediaMatch != null) {
            imageUrl = mediaMatch.group(1);
          }
        }

        if (imageUrl == null) {
          final rawContent = _extractXmlTag(itemBlock, 'content:encoded') + ' ' + _extractXmlTag(itemBlock, 'description');
          final imgMatch = RegExp(r'''<img[^>]+src=["'](https?://[^"']+)["']''', caseSensitive: false)
              .firstMatch(rawContent.isNotEmpty ? rawContent : itemBlock);
          if (imgMatch != null) {
            final src = imgMatch.group(1)?.trim();
            if (src != null && !src.contains('icon') && !src.contains('pixel')) {
              imageUrl = src;
            }
          }
        }

        if (title.isNotEmpty && link.isNotEmpty) {
          results.add({
            'title': _cleanXmlText(title),
            'sourceUrl': link.trim(),
            'description': description.isNotEmpty ? description : _cleanXmlText(title),
            'imageUrl': imageUrl,
          });
        }
      }
    } catch (e) {
      debugPrint('Feed parse exception for $feedUrl: $e');
    }

    if (results.isEmpty) {
      try {
        final apiUrl = 'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(feedUrl)}';
        final jsonRes = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 15));
        if (jsonRes.statusCode == 200) {
          final jsonData = json.decode(jsonRes.body);
          if (jsonData['status'] == 'ok') {
            final List items = jsonData['items'] ?? [];
            for (final item in items.take(15)) {
              final title = (item['title'] ?? '').toString().trim();
              final link = (item['link'] ?? '').toString().trim();
              final desc = (item['description'] ?? '').toString().trim();
              String? img;
              if (item['enclosure'] != null && item['enclosure'] is Map && item['enclosure']['link'] != null) {
                img = item['enclosure']['link'].toString();
              } else if (item['thumbnail'] != null) {
                img = item['thumbnail'].toString();
              }
              if (title.isNotEmpty && link.isNotEmpty) {
                results.add({
                  'title': _cleanXmlText(title),
                  'sourceUrl': link,
                  'description': _stripHtml(desc),
                  'imageUrl': img,
                });
              }
            }
          }
        }
      } catch (e2) {
        debugPrint('rss2json fallback error for $feedUrl in AutoNewsScraper: $e2');
      }
    }

    return results;
  }

  String _extractXmlTag(String xmlBlock, String tagName) {
    final cdataRegex = RegExp('<$tagName[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]><\\/$tagName>', caseSensitive: false);
    final cdataMatch = cdataRegex.firstMatch(xmlBlock);
    if (cdataMatch != null && cdataMatch.group(1) != null) {
      return cdataMatch.group(1)!.trim();
    }

    final standardRegex = RegExp('<$tagName[^>]*>([\\s\\S]*?)<\\/$tagName>', caseSensitive: false);
    final match = standardRegex.firstMatch(xmlBlock);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }

    return '';
  }

  String _cleanXmlText(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8216;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&#8211;', '-')
        .replaceAll('&#8212;', '-')
        .trim();
  }

  String _stripHtml(String html) {
    final unescaped = _cleanXmlText(html);
    final noTags = unescaped.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return noTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Save to Supabase with isAuto: true
  Future<bool> _saveNews({
    required Map<String, String> titleMap,
    required Map<String, String> descriptionMap,
    required String category,
    required String imageUrl,
    required String sourceUrl,
    String? videoUrl,
  }) async {
    try {
      final newId = 'news_${DateTime.now().millisecondsSinceEpoch}_${sourceUrl.hashCode.abs()}';
      final nowStr = DateTime.now().toIso8601String();
      await SupabaseService.client.from('news').upsert({
        'id': newId,
        'title': titleMap,
        'content': descriptionMap,
        'description': descriptionMap,
        'category': category,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl ?? '',
        'timestamp': nowStr,
        'created_at': nowStr,
        'isPublished': true,
        'isAuto': true,
        'views': 0,
        'isFree': false,
        'isFeatured': false,
        'timeAgo': 'Just now',
        'sourceUrl': sourceUrl,
      }).timeout(const Duration(seconds: 4));

      // Also trigger refresh in SupabaseStoreService so live stream reflects new Khabar immediately
      SupabaseStoreService().refreshNews();
      return true;
    } catch (e) {
      debugPrint('Failed to save scraped news to Supabase: $e');
      return false;
    }
  }
}
