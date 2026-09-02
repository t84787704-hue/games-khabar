import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/translation_service.dart';
import '../services/firestore_service.dart';

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
  static final List<Map<String, dynamic>> defaultFirestoreSources = [
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

  static List<RssSource> get defaultSources => defaultFirestoreSources
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

  /// Seed 10 default sources to Firestore 'scraper_sources' collection if empty
  static Future<void> seedDefaultSourcesIfEmpty() async {
    try {
      final snap = await FirebaseFirestore.instance.collection(collectionName).limit(1).get();
      if (snap.docs.isEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (int i = 0; i < defaultFirestoreSources.length; i++) {
          final s = defaultFirestoreSources[i];
          final docRef = FirebaseFirestore.instance.collection(collectionName).doc(s['id'] as String);
          batch.set(docRef, {
            'name': s['name'],
            'url': s['url'],
            'category': s['category'],
            'categoryHint': s['category'],
            'isEnabled': true,
            'order': s['order'] ?? (i + 1),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error seeding default sources: $e');
    }
  }

  /// Reset to 10 default sources in Firestore
  static Future<void> resetDefaultSources() async {
    try {
      final snap = await FirebaseFirestore.instance.collection(collectionName).get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      for (int i = 0; i < defaultFirestoreSources.length; i++) {
        final s = defaultFirestoreSources[i];
        final docRef = FirebaseFirestore.instance.collection(collectionName).doc(s['id'] as String);
        batch.set(docRef, {
          'name': s['name'],
          'url': s['url'],
          'category': s['category'],
          'categoryHint': s['category'],
          'isEnabled': true,
          'order': s['order'] ?? (i + 1),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error resetting default sources: $e');
    }
  }

  /// Add a source to Firestore 'scraper_sources'
  static Future<void> addFirestoreSource({
    required String name,
    required String url,
    required String category,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection(collectionName).add({
        'name': name.trim().isEmpty ? 'Custom RSS Feed' : name.trim(),
        'url': cleanUrl,
        'category': category.trim().isEmpty ? 'Gaming News' : category.trim(),
        'categoryHint': category.trim().isEmpty ? 'Gaming News' : category.trim(),
        'isEnabled': true,
        'order': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding source: $e');
    }
  }

  /// Delete a source from Firestore 'scraper_sources'
  static Future<void> deleteFirestoreSource(String docId) async {
    try {
      await FirebaseFirestore.instance.collection(collectionName).doc(docId).delete();
    } catch (e) {
      debugPrint('Error deleting source: $e');
    }
  }

  /// Toggle source enabled state in Firestore
  static Future<void> toggleFirestoreSource(String docId, bool isEnabled) async {
    try {
      await FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
        'isEnabled': isEnabled,
      });
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
      final snap = await FirebaseFirestore.instance.collection(collectionName).get();
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((d) => RssSource.fromJson(d.data(), d.id)).toList();
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
    await addFirestoreSource(name: name, url: url, category: categoryHint);
    await _loadSources();
  }

  Future<void> toggleSource(String id, bool enabled) async {
    await toggleFirestoreSource(id, enabled);
    await _loadSources();
  }

  Future<void> deleteSource(String id) async {
    await deleteFirestoreSource(id);
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

            // 2. Firestore Duplicate Check
            final isDuplicate = await _checkFirestoreDuplicate(sourceUrl);
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

            // 5. Image & Video resolution
            final imageUrl = _resolveImageUrl(
              item['imageUrl'] as String?,
              category,
            );

            // 6. Save to Firestore with isAuto: true
            final added = await _saveToFirestore(
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
      RegExp(r'\bredeem code\b', caseSensitive: false): 'Redeem Code Aur Free Rewards',
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

  /// Duplicate check in Firestore
  Future<bool> _checkFirestoreDuplicate(String sourceUrl) async {
    try {
      final db = FirebaseFirestore.instance;
      final query = await db
          .collection('news')
          .where('sourceUrl', isEqualTo: sourceUrl)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));

      return query.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Resolve High Quality Category Fallback Images
  String _resolveImageUrl(String? extractedUrl, String category) {
    if (extractedUrl != null &&
        extractedUrl.trim().isNotEmpty &&
        !extractedUrl.contains('picsum.photos') &&
        (extractedUrl.startsWith('http://') || extractedUrl.startsWith('https://'))) {
      return extractedUrl.trim();
    }

    switch (category) {
      case 'Free Fire':
        return 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80';
      case 'BGMI':
      case 'PUBG':
        return 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1200&q=80';
      case 'GTA':
        return 'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80';
      case 'MINECRAFT':
        return 'https://images.unsplash.com/photo-1627856014754-2907e2055704?auto=format&fit=crop&w=1200&q=80';
      case 'ESPORTS':
        return 'https://images.unsplash.com/photo-1542751110-97427bbecf20?auto=format&fit=crop&w=1200&q=80';
      default:
        return 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1200&q=80';
    }
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

        // Extract image
        String? imageUrl;
        final mediaMatch = RegExp(r'''<media:(?:content|thumbnail)[^>]+url=["']([^"']+)["']''', caseSensitive: false)
            .firstMatch(itemBlock);
        if (mediaMatch != null) {
          imageUrl = mediaMatch.group(1);
        }

        if (imageUrl == null) {
          final enclosureMatch = RegExp(r'''<enclosure[^>]+url=["']([^"']+)["']''', caseSensitive: false)
              .firstMatch(itemBlock);
          if (enclosureMatch != null) {
            imageUrl = enclosureMatch.group(1);
          }
        }

        if (imageUrl == null) {
          final imgMatch = RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false)
              .firstMatch(itemBlock);
          if (imgMatch != null) {
            imageUrl = imgMatch.group(1);
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

  /// Save to Firestore with isAuto: true
  Future<bool> _saveToFirestore({
    required Map<String, String> titleMap,
    required Map<String, String> descriptionMap,
    required String category,
    required String imageUrl,
    required String sourceUrl,
    String? videoUrl,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      await db.collection('news').add({
        'title': titleMap,
        'content': descriptionMap,
        'description': descriptionMap,
        'category': category,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'isPublished': true,
        'isAuto': true,
        'views': 0,
        'isFree': false,
        'isFeatured': false,
        'timeAgo': 'Just now',
        'sourceUrl': sourceUrl,
      }).timeout(const Duration(seconds: 4));

      // Also trigger refresh in FirestoreService so live stream reflects new Khabar immediately
      FirestoreService().refreshNews();
      return true;
    } catch (e) {
      debugPrint('Failed to save scraped news to Firestore: $e');
      return false;
    }
  }
}
