import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:translator/translator.dart';
import 'package:xml/xml.dart' as xml;
import '../models/gaming_news_model.dart';

class GamingNewsService {
  static final GamingNewsService _instance = GamingNewsService._internal();
  factory GamingNewsService() => _instance;
  GamingNewsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleTranslator _translator = GoogleTranslator();

  static const String collectionName = 'gaming_news';

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  final List<String> _rssFeedUrls = [
    'https://feeds.feedburner.com/ign/games-all',
    'https://www.gamespot.com/feeds/mashup/',
    'https://www.epicgames.com/blog/en-US/feed',
  ];

  /// Stream of all gaming news from Firestore, sorted by timestamp descending
  Stream<List<GamingNewsModel>> getGamingNewsStream() {
    return _firestore
        .collection(collectionName)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        // Trigger background sync if empty
        syncRssNews();
        return _getFallbackSeedArticles();
      }
      return snapshot.docs.map((doc) => GamingNewsModel.fromFirestore(doc)).toList();
    });
  }

  /// Stream of saved news from user subcollection users/{uid}/saved_news
  Stream<List<GamingNewsModel>> getSavedNewsStream(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_news')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GamingNewsModel.fromFirestore(doc)).toList());
  }

  /// Check if a specific news article is bookmarked
  Stream<bool> isBookmarkedStream(String uid, String newsId) {
    if (uid.isEmpty || newsId.isEmpty) return Stream.value(false);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_news')
        .doc(newsId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Toggle bookmark status in user's saved_news subcollection
  Future<bool> toggleBookmark(String uid, GamingNewsModel news) async {
    if (uid.isEmpty || news.id.isEmpty) return false;
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_news')
          .doc(news.id);

      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.delete();
        return false;
      } else {
        await docRef.set(news.toMap());
        return true;
      }
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
      return false;
    }
  }

  /// Increment views on an article
  Future<void> incrementViews(String newsId) async {
    if (newsId.isEmpty) return;
    try {
      await _firestore.collection(collectionName).doc(newsId).update({
        'views': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// Fetch news from RSS, parse, translate, and save to Firestore
  Future<int> syncRssNews() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int totalSaved = 0;

    try {
      // First ensure initial seed articles exist in Firestore so users have instant content
      await _seedInitialNewsIfEmpty();

      for (final feedUrl in _rssFeedUrls) {
        try {
          final articles = await _fetchFromRss(feedUrl);
          for (final item in articles) {
            try {
              // Check if already in Firestore to prevent duplicate translations
              final docRef = _firestore.collection(collectionName).doc(item.id);
              final doc = await docRef.get();
              if (!doc.exists) {
                // Translate title to Urdu using translator package
                String titleUr = item.titleUr;
                if (titleUr.isEmpty && item.titleEn.isNotEmpty) {
                  try {
                    final translation = await _translator.translate(item.titleEn, to: 'ur');
                    titleUr = translation.text;
                  } catch (e) {
                    titleUr = _generateUrduFallback(item.titleEn);
                  }
                }

                final completeItem = item.copyWith(titleUr: titleUr);
                await docRef.set(completeItem.toMap());
                totalSaved++;
              }
            } catch (e) {
              debugPrint('Error saving article ${item.id}: $e');
            }
          }
        } catch (e) {
          debugPrint('Error processing feed $feedUrl: $e');
        }
      }
    } catch (e) {
      debugPrint('Global sync error: $e');
    } finally {
      _isSyncing = false;
    }

    return totalSaved;
  }

  /// Fetch from rss2json or fallback direct XML
  Future<List<GamingNewsModel>> _fetchFromRss(String feedUrl) async {
    List<GamingNewsModel> results = [];

    // Attempt 1: Using api.rss2json.com
    try {
      final apiUrl = Uri.parse(
          'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(feedUrl)}');
      final response = await http.get(apiUrl).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok' && data['items'] is List) {
          final items = data['items'] as List;
          for (final item in items) {
            final title = (item['title'] ?? '').toString().trim();
            if (title.isEmpty) continue;

            final link = (item['link'] ?? '').toString();
            final id = _generateDocId(link.isNotEmpty ? link : title);
            final description = (item['description'] ?? item['content'] ?? '').toString();
            final cleanSummary = _cleanHtmlText(description);
            final fullText = _cleanHtmlFullText((item['content'] ?? item['description'] ?? '').toString());

            // Extract image
            String imageUrl = (item['thumbnail'] ?? '').toString();
            if (imageUrl.isEmpty && item['enclosure'] is Map) {
              imageUrl = (item['enclosure']['link'] ?? '').toString();
            }
            if (imageUrl.isEmpty) {
              imageUrl = _extractImageFromHtml(description);
            }

            DateTime pubDate = DateTime.now();
            if (item['pubDate'] != null) {
              pubDate = DateTime.tryParse(item['pubDate'].toString()) ?? DateTime.now();
            }

            final category = _categorizeNews(title, description);
            final platform = _detectPlatform(title, description);

            results.add(GamingNewsModel(
              id: id,
              titleEn: title,
              titleUr: '', // Will be translated before saving
              category: category,
              platform: platform,
              imageUrl: imageUrl,
              summary: cleanSummary,
              fullContent: fullText.isNotEmpty ? fullText : cleanSummary,
              sourceUrl: link,
              timestamp: pubDate,
              views: 120 + (title.hashCode.abs() % 1450),
            ));
          }
          if (results.isNotEmpty) return results;
        }
      }
    } catch (e) {
      debugPrint('rss2json failed for $feedUrl: $e. Falling back to direct XML parse.');
    }

    // Attempt 2: Direct RSS XML download
    try {
      final response = await http.get(Uri.parse(feedUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final items = document.findAllElements('item');

        for (final item in items) {
          final title = item.findElements('title').firstOrNull?.innerText.trim() ?? '';
          if (title.isEmpty) continue;

          final link = item.findElements('link').firstOrNull?.innerText.trim() ?? '';
          final id = _generateDocId(link.isNotEmpty ? link : title);
          final desc = item.findElements('description').firstOrNull?.innerText.trim() ?? '';
          final cleanSummary = _cleanHtmlText(desc);

          String imageUrl = '';
          final enclosure = item.findElements('enclosure').firstOrNull;
          if (enclosure != null) {
            imageUrl = enclosure.getAttribute('url') ?? '';
          }
          if (imageUrl.isEmpty) {
            final mediaContent = item.findElements('media:content').firstOrNull;
            if (mediaContent != null) {
              imageUrl = mediaContent.getAttribute('url') ?? '';
            }
          }
          if (imageUrl.isEmpty) {
            final mediaThumbnail = item.findElements('media:thumbnail').firstOrNull;
            if (mediaThumbnail != null) {
              imageUrl = mediaThumbnail.getAttribute('url') ?? '';
            }
          }
          if (imageUrl.isEmpty) {
            imageUrl = _extractImageFromHtml(desc);
          }

          final pubDateStr = item.findElements('pubDate').firstOrNull?.innerText.trim();
          DateTime pubDate = DateTime.now();
          if (pubDateStr != null) {
            pubDate = DateTime.tryParse(pubDateStr) ?? DateTime.now();
          }

          final category = _categorizeNews(title, desc);
          final platform = _detectPlatform(title, desc);
          final contentEncoded = item.findElements('content:encoded').firstOrNull?.innerText.trim() ?? '';
          final fullText = _cleanHtmlFullText(contentEncoded.isNotEmpty ? contentEncoded : desc);

          results.add(GamingNewsModel(
            id: id,
            titleEn: title,
            titleUr: '',
            category: category,
            platform: platform,
            imageUrl: imageUrl,
            summary: cleanSummary,
            fullContent: fullText.isNotEmpty ? fullText : cleanSummary,
            sourceUrl: link,
            timestamp: pubDate,
            views: 90 + (title.hashCode.abs() % 1300),
          ));
        }
      }
    } catch (e) {
      debugPrint('Direct XML parse failed for $feedUrl: $e');
    }

    return results;
  }

  /// Infer gaming category from title and content
  String _categorizeNews(String title, String content) {
    final combined = '$title $content'.toUpperCase();
    if (combined.contains('GTA') || combined.contains('GRAND THEFT AUTO')) {
      return 'GRAND THEFT AUTO';
    }
    if (combined.contains('FIFA') || combined.contains('EA SPORTS') || combined.contains('FC 24') || combined.contains('FC 25')) {
      return 'EA SPORTS';
    }
    if (combined.contains('FALLOUT') || combined.contains('FALL GUYS')) {
      return 'FALL UP';
    }
    if (combined.contains('CALL OF DUTY') || combined.contains('COD') || combined.contains('BATTLEFIELD') || combined.contains('VALORANT') || combined.contains('FPS')) {
      return 'FPS/SHOOTING';
    }
    if (combined.contains('BATTLE ROYALE') || combined.contains('PUBG') || combined.contains('BGMI') || combined.contains('FREE FIRE') || combined.contains('WARZONE')) {
      return 'BATTLE ROYALE';
    }
    if (combined.contains('FORZA') || combined.contains('NEED FOR SPEED') || combined.contains('NFS') || combined.contains('RACING') || combined.contains('GT7') || combined.contains('GRAN TURISMO')) {
      return 'RACING GAMES';
    }
    if (combined.contains('OPEN WORLD') || combined.contains('CYBERPUNK') || combined.contains('ELDER SCROLLS') || combined.contains('WITCHER')) {
      return 'OPEN WORLD';
    }
    if (combined.contains('EPIC GAMES') || combined.contains('STEAM') || combined.contains('FREE GAME')) {
      return 'FREE GAMES';
    }
    return 'FEATURED';
  }

  /// Detect platform tag
  String _detectPlatform(String title, String content) {
    final combined = '$title $content'.toUpperCase();
    if (combined.contains('PS5') || combined.contains('PLAYSTATION 5') || combined.contains('PS4')) {
      return 'PS5';
    }
    if (combined.contains('XBOX') || combined.contains('SERIES X') || combined.contains('GAME PASS')) {
      return 'Xbox';
    }
    if (combined.contains('SWITCH') || combined.contains('NINTENDO')) {
      return 'Switch';
    }
    if (combined.contains('PC') || combined.contains('STEAM') || combined.contains('RTX') || combined.contains('NVIDIA')) {
      return 'PC';
    }
    if (combined.contains('DRIVING') || combined.contains('RACING')) {
      return 'Driving Games';
    }
    if (combined.contains('OPEN WORLD')) {
      return 'Open World';
    }
    return 'Multiplatform';
  }

  String _cleanHtmlText(String html) {
    String text = html.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > 400) {
      text = '${text.substring(0, 397)}...';
    }
    return text;
  }

  String _cleanHtmlFullText(String html) {
    String text = html.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _extractImageFromHtml(String html) {
    final match = RegExp(r'<img[^>]+src="([^">]+)"', caseSensitive: false).firstMatch(html);
    if (match != null && match.groupCount >= 1) {
      return match.group(1) ?? '';
    }
    return '';
  }

  String _generateDocId(String input) {
    return input.hashCode.abs().toString();
  }

  String _generateUrduFallback(String englishTitle) {
    // Intelligent fallback in case translation is offline
    return 'گیمنگ نیوز: $englishTitle';
  }

  /// Seed high-quality initial articles to Firestore if collection is empty
  Future<void> _seedInitialNewsIfEmpty() async {
    try {
      final snap = await _firestore.collection(collectionName).limit(3).get();
      if (snap.docs.isEmpty) {
        final seedArticles = _getFallbackSeedArticles();
        final batch = _firestore.batch();
        for (final article in seedArticles) {
          final ref = _firestore.collection(collectionName).doc(article.id);
          batch.set(ref, article.toMap());
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error seeding initial gaming news: $e');
    }
  }

  List<GamingNewsModel> _getFallbackSeedArticles() {
    return [
      GamingNewsModel(
        id: 'gn_1',
        titleEn: 'Grand Theft Auto VI New Gameplay Leaks and Vice City Map Size Revealed',
        titleUr: 'گرینڈ تھیفٹ آٹو 6: نئے گیم پلے لیکس اور وائس سٹی میپ کا سائز سامنے آگیا',
        category: 'GRAND THEFT AUTO',
        platform: 'PS5',
        imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=800&q=80',
        summary: 'Rockstar Games insider details the expanded Vice City state of Leonida with unprecedented graphical fidelity and realistic physics engine upgrades.',
        fullContent: 'Rockstar Games insider details the expanded Vice City state of Leonida with unprecedented graphical fidelity and realistic physics engine upgrades. The upcoming Grand Theft Auto VI is set in the fictional state of Leonida, which is inspired by Florida, and features the neon-soaked streets of Vice City and surrounding bayous, wetlands, and small towns. Leaks indicate dynamic weather systems, volumetric clouds, AI-driven pedestrian routines, advanced water physics, and unprecedented vehicular customization. Both protagonists, Lucia and Jason, bring a cinematic storyline focused on heist planning, illicit syndicates, and high-stakes criminal warfare.',
        sourceUrl: 'https://www.ign.com/games/grand-theft-auto-vi',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        views: 1840,
      ),
      GamingNewsModel(
        id: 'gn_2',
        titleEn: 'EA Sports FC 25 Ultimate Team New Heroes, Tactics & Career Mode Overhaul',
        titleUr: 'ای اے اسپورٹس ایف سی 25: الٹیمیٹ ٹیم کے نئے ہیروز اور کیریئر موڈ کی تبدیلیاں',
        category: 'EA SPORTS',
        platform: 'PS5',
        imageUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=800&q=80',
        summary: 'Electronic Arts has revealed revolutionary FC IQ tactical systems with 50+ new player roles and revamped manager career mode.',
        fullContent: 'Electronic Arts has revealed revolutionary FC IQ tactical systems with 50+ new player roles and revamped manager career mode. Powered by real-world data from top football matches, FC IQ fundamentally overhauls how players position themselves on the pitch. New 5v5 Rush mode replaces Volta, bringing fast-paced competitive gameplay with friends. Career mode adds Live Start Points that reflect real-season points tables, injuries, and manager sackings in real time.',
        sourceUrl: 'https://www.gamespot.com/articles/ea-sports-fc-25/',
        timestamp: DateTime.now().subtract(const Duration(minutes: 48)),
        views: 932,
      ),
      GamingNewsModel(
        id: 'gn_3',
        titleEn: 'Call of Duty Black Ops 6 Warzone Season Reveal: Return of Classic Maps',
        titleUr: 'کال آف ڈیوٹی بلیک آپس 6: وارزون سیزن میں کلاسک نقشوں کی شاندار واپسی',
        category: 'FPS/SHOOTING',
        platform: 'PC',
        imageUrl: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=800&q=80',
        summary: 'Treyarch introduces omnimovement mechanics allowing players to sprint, slide, and dive in any direction seamlessly in combat.',
        fullContent: 'Treyarch introduces omnimovement mechanics allowing players to sprint, slide, and dive in any direction seamlessly in combat. Black Ops 6 brings a gripping spy thriller campaign set in the early 1990s, round-based Zombies on two brand-new maps at launch, and 16 multiplayer maps including 12 core 6v6 maps and 4 Strike maps. Dedicated servers and refreshed perk systems guarantee competitive integrity across all platforms.',
        sourceUrl: 'https://www.gamespot.com/games/call-of-duty-black-ops-6/',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 12)),
        views: 1250,
      ),
      GamingNewsModel(
        id: 'gn_4',
        titleEn: 'Epic Games Store Free Mystery Games Lineup for PC Gamers This Week',
        titleUr: 'ایپک گیمز اسٹور: پی سی پلیئرز کے لیے اس ہفتے کے مفت مسٹری گیمز کا اعلان',
        category: 'FEATURED',
        platform: 'PC',
        imageUrl: 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=800&q=80',
        summary: 'Claim top rated AAA and indie titles completely free on Epic Games Store this weekend with lifetime library ownership.',
        fullContent: 'Claim top rated AAA and indie titles completely free on Epic Games Store this weekend with lifetime library ownership. PC gamers can log in to their Epic Games account to claim rotating weekly giveaways with zero subscription fees. Once claimed during the promotional window, the titles remain permanently in the player’s personal library with cloud saves and achievement tracking enabled.',
        sourceUrl: 'https://www.epicgames.com/store/free-games',
        timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 5)),
        views: 890,
      ),
      GamingNewsModel(
        id: 'gn_5',
        titleEn: 'Forza Horizon 6 Japan Map Setting Teased by Playground Games Developers',
        titleUr: 'فورزا ہورائزن 6: جاپان کا نقشہ اور شاندار ریسنگ روٹس کی پہلی جھلک',
        category: 'RACING GAMES',
        platform: 'Xbox',
        imageUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=800&q=80',
        summary: 'Next generation open world driving with dynamic weather, neon Tokyo cityscapes, and mountain drift passes announced for Xbox Series X.',
        fullContent: 'Next generation open world driving with dynamic weather, neon Tokyo cityscapes, and mountain drift passes announced for Xbox Series X and PC. Playground Games developers have teased the most requested fan location featuring authentic Japanese touge passes, cherry blossom highways, urban expressway loops like the Shuto Expressway, and photorealistic ray tracing in both gameplay and Photo Mode.',
        sourceUrl: 'https://www.ign.com/articles/forza-horizon-next-news',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        views: 2150,
      ),
      GamingNewsModel(
        id: 'gn_6',
        titleEn: 'Nintendo Switch 2 Hardware Specs Leak Reveals 4K DLSS Support & Battery Boost',
        titleUr: 'نینٹینڈو سوئچ 2: 4K ڈی ایل ایس ایس سپورٹ اور بڑی بیٹری کے ساتھ تفصیلات لیک',
        category: 'FEATURED',
        platform: 'Switch',
        imageUrl: 'https://images.unsplash.com/photo-1578301978693-85fa9c0320b9?auto=format&fit=crop&w=800&q=80',
        summary: 'Custom Nvidia silicon promises ray tracing and enhanced handheld efficiency for the highly anticipated Nintendo next generation console.',
        fullContent: 'Custom Nvidia silicon promises ray tracing and enhanced handheld efficiency for the highly anticipated Nintendo next generation console. Developers briefing notes suggest NVIDIA custom DLSS upscaling to output crisp 4K visual resolution when docked to modern televisions, while maintaining exceptional battery life and thermal stability during portable play.',
        sourceUrl: 'https://www.gamespot.com/articles/switch-successor-spec-leaks/',
        timestamp: DateTime.now().subtract(const Duration(hours: 4, minutes: 30)),
        views: 1420,
      ),
      GamingNewsModel(
        id: 'gn_7',
        titleEn: 'Fallout 5 and New Vegas Remastered Status Update from Bethesda Game Studios',
        titleUr: 'فال آؤٹ 5 اور نیو ویگاس ری ماسٹرڈ پر بیتیسڈا اسٹوڈیوز کا بڑا بیان',
        category: 'FALL UP',
        platform: 'Xbox',
        imageUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?auto=format&fit=crop&w=800&q=80',
        summary: 'Following the smash hit television series, Bethesda confirms full pre-production ramp-up for the next mainline post-apocalyptic RPG.',
        fullContent: 'Following the smash hit television series, Bethesda confirms full pre-production ramp-up for the next mainline post-apocalyptic RPG. Todd Howard shared insights into the studio roadmap, highlighting next-generation Creation Engine 2 enhancements, expanded faction dialogues, modular base engineering, and immersive wasteland survival mechanics.',
        sourceUrl: 'https://www.ign.com/articles/fallout-franchise-future',
        timestamp: DateTime.now().subtract(const Duration(hours: 6)),
        views: 1675,
      ),
      GamingNewsModel(
        id: 'gn_8',
        titleEn: 'Cyberpunk 2077 Project Orion Sequel Enters Full Production in Boston',
        titleUr: 'سائبر پنک 2077 کا نیا سیکوئل: پروجیکٹ اورین پر فل اسکیل ڈیولپمنٹ شروع',
        category: 'OPEN WORLD',
        platform: 'PC',
        imageUrl: 'https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?auto=format&fit=crop&w=800&q=80',
        summary: 'CD Projekt Red expands its North American studio to create an even deeper, more reactive open world dystopian Night City.',
        fullContent: 'CD Projekt Red expands its North American studio to create an even deeper, more reactive open world dystopian Night City. Built on Unreal Engine 5, Project Orion brings next-generation crowds, vertical multi-tiered megastructures, deeper branching cyberware abilities, and expanded underground black-market syndicates.',
        sourceUrl: 'https://www.gamespot.com/articles/cyberpunk-sequel-update/',
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        views: 1105,
      ),
    ];
  }
}
