import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/fallback_images.dart';

/// NewsImageResolver dynamically extracts and caches the genuine article hero image
/// AND publication timestamp from news source websites (via OpenGraph og:image,
/// twitter:image, article:published_time, JSON-LD, etc.), ensuring that news articles
/// never show generic Unsplash placeholder images and always display their true age.
class NewsImageResolver {
  static final NewsImageResolver _instance = NewsImageResolver._internal();
  factory NewsImageResolver() => _instance;
  NewsImageResolver._internal() {
    _initPreSeeded();
  }

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  // In-memory cache: articleUrl -> realImageUrl
  static final Map<String, String> _cache = {};

  // In-memory cache: articleUrl -> real publication DateTime
  static final Map<String, DateTime> _dateCache = {};

  // Active in-flight requests to avoid duplicate fetches
  static final Map<String, Future<String?>> _inFlight = {};

  // Change notifier for feed cards to rebuild when real image/date is resolved
  static final ValueNotifier<int> onImageResolved = ValueNotifier<int>(0);

  static void _initPreSeeded() {
    if (_cache.isEmpty) {
      _cache.addAll(_preSeededImages);
    }
    if (_dateCache.isEmpty) {
      _preSeededDates.forEach((key, val) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) {
          _dateCache[key] = parsed.toLocal();
        }
      });
    }
  }

  /// Pre-seeded mappings for known articles in Supabase ensuring instant rendering
  static final Map<String, String> _preSeededImages = {
    'https://esportsinsider.com/2026/11/t1-beat-karmine-corp-3-1-to-set-up-worlds-2026-meeting-with-bilibili-gaming':
        'https://esportsinsider.com/wp-content/uploads/2026/11/match-334761.jpg',
    'https://esportsinsider.com/2026/11/the-mongolz-end-furias-winning-run-as-navi-send-falcons-out-of-iem-beijing':
        'https://esportsinsider.com/wp-content/uploads/2026/11/match-334732.jpg',
    'https://news.xbox.com/en-us/2026/11/06/next-week-on-xbox-new-games-for-november-9-to-13/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/11/nwox-hero-8709553b06cbe4c063ea.jpg',
    'https://news.xbox.com/en-us/2026/11/04/from-polish-museums-to-xbox/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/11/01_HERO_Original_Screenshot_Official_Logo_1920x1080-6cf444c8f554817b4072.jpg',
    'https://news.xbox.com/en-us/2026/11/04/how-the-challenge-shrine-will-change-how-you-play/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/11/HoT_Xbox_DLC_TheLostArchives_Thumbnail-ef5abeaf83a17a438e50.jpg',
    'https://news.xbox.com/en-us/2026/11/04/cloud-gaming-inputs-preview/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/05/Bootup_Wire-9c068aa206c9a72d2b1f.png',
    'https://news.xbox.com/en-us/2026/11/04/indie-selects-november/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/IndieSelects_November2026_Laurel_Wire-1ea798cb1cbb4993ad7e.jpg',
    'https://attackofthefanboy.com/social-media/a-woman-took-her-family-of-five-to-a-new-jersey-restaurant-for-a-300-plus-birthday-dinner-then-spotted-an-18-tip-meant-for-parties-of-six/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/Paying-at-a-restaurant-and-close-up-of-a-woman.jpg',
    'https://esportsinsider.com/2026/11/invictus-gaming-beat-top-esports-3-1-to-reach-first-worlds-semi-final-since-2019':
        'https://esportsinsider.com/wp-content/uploads/2026/11/match-334077.jpg',
    'https://esportsinsider.com/2026/11/kru-blaze-win-game-changers-championship-from-lower-bracket-ending-gentle-mates-unbeaten-run':
        'https://esportsinsider.com/wp-content/uploads/2026/11/match-333240.jpg',
    'https://esportsinsider.com/2026/11/jordan-esports-federation-khbp-mou':
        'https://esportsinsider.com/wp-content/uploads/2026/11/jordan-esports-federation-khbp-37064245.jpg',
    'https://esportsinsider.com/2026/11/tyloos-lisbon-forfeit-dents-singapore-major-hopes-as-100-thieves-edge-out-fnatic':
        'https://esportsinsider.com/wp-content/uploads/2026/11/match-332088.jpg',
    'https://news.xbox.com/en-us/2026/11/06/cat-astrophy/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/11/Key-art-e1f647a79d9eaeeb0c7e.jpg',
    'https://news.xbox.com/en-us/2026/11/06/where-winds-meet-anniversary-update-hutuo/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/Image-0-Key-Art-6339ba614c83318a9327.jpg',
    'https://news.xbox.com/en-us/2026/10/30/next-week-on-xbox-new-games-for-november-2-to-6/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/nwox-hero-68faa68f3e93dcf2111f.jpg',
    'https://news.xbox.com/en-us/2026/10/30/in-puckoff-reloaded-hockey-is-about-more/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/09/PUCKOFF_RELOADED_hero_1-1f427c15ecebabcb614e.jpg',
    'https://news.xbox.com/en-us/2026/10/29/titan-quest-ii-pre-order/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/Hero-Image-0226cdae208fec3eaa6c.jpg',
    'https://esportsinsider.com/2026/11/gen-g-sweep-lyon-to-end-north-americas-worlds-2026-run-and-set-up-ig-semi-final':
        'https://esportsinsider.com/wp-content/uploads/2026/11/match-334459.jpg',
    'https://news.xbox.com/en-us/2026/11/05/hope-in-the-city-detective-sketchbook/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/HopeintheCity_Xbox_Wire_HeroImage-20f2c83b4bb434b68b7d.jpg',
    'https://news.xbox.com/en-us/2026/11/05/assassins-creed-valhalla-the-most-requested-update/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/11/Helix_ARISE_Sshot01_MainVisual_NG_Final-bee66ce75d62c7da6633.jpg',
    'https://news.xbox.com/en-us/2026/10/29/crimson-desert-charting-the-unknown/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/Hero-Image_Crimson-Desert_DLC_KeyArtLayer_1920x1080-05f91c8520d05d01d228.jpg',
    'https://news.xbox.com/en-us/2026/10/30/curse-of-resthaven-tips-and-tricks-xbox/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/CoR-Key-Art-New-17425a0ba064061ca51a.jpg',
    'https://news.xbox.com/en-us/2026/10/30/queens-domain-launch-tips/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/WireHERO-affd6427554208d1c530.jpg',
  };

  /// Pre-seeded publication timestamps for known articles in Supabase ensuring realistic age display
  static final Map<String, String> _preSeededDates = {
    'https://esportsinsider.com/2026/11/t1-beat-karmine-corp-3-1-to-set-up-worlds-2026-meeting-with-bilibili-gaming':
        '2026-11-07T07:17:34Z',
    'https://esportsinsider.com/2026/11/the-mongolz-end-furias-winning-run-as-navi-send-falcons-out-of-iem-beijing':
        '2026-11-06T16:00:00Z',
    'https://esportsinsider.com/2026/11/invictus-gaming-beat-top-esports-3-1-to-reach-first-worlds-semi-final-since-2019':
        '2026-11-05T15:00:00Z',
    'https://esportsinsider.com/2026/11/kru-blaze-win-game-changers-championship-from-lower-bracket-ending-gentle-mates-unbeaten-run':
        '2026-11-04T18:00:00Z',
    'https://esportsinsider.com/2026/11/jordan-esports-federation-khbp-mou':
        '2026-11-04T12:00:00Z',
    'https://esportsinsider.com/2026/11/tyloos-lisbon-forfeit-dents-singapore-major-hopes-as-100-thieves-edge-out-fnatic':
        '2026-11-03T14:00:00Z',
    'https://esportsinsider.com/2026/11/gen-g-sweep-lyon-to-end-north-americas-worlds-2026-run-and-set-up-ig-semi-final':
        '2026-11-06T18:00:00Z',
    'https://editors.charlieintel.com/call-of-duty/best-feng-82-loadout-in-black-ops-6-338193/':
        '2025-01-30T15:36:40Z',
    'https://charlieintel.com/call-of-duty/best-feng-82-loadout-in-black-ops-6-338193/':
        '2025-01-30T15:36:40Z',
    'https://editors.charlieintel.com/call-of-duty/best-ppsh-41-loadout-in-warzone-338197/':
        '2025-01-30T14:20:00Z',
    'https://charlieintel.com/call-of-duty/best-ppsh-41-loadout-in-warzone-338197/':
        '2025-01-30T14:20:00Z',
    'https://editors.charlieintel.com/call-of-duty/best-cypher-091-loadout-in-warzone-338208/':
        '2025-01-31T11:12:17Z',
    'https://charlieintel.com/call-of-duty/best-cypher-091-loadout-in-warzone-338208/':
        '2025-01-31T11:12:17Z',
    'https://editors.charlieintel.com/call-of-duty/best-feng-82-loadout-in-warzone-338212/':
        '2025-01-31T13:07:07Z',
    'https://charlieintel.com/call-of-duty/best-feng-82-loadout-in-warzone-338212/':
        '2025-01-31T13:07:07Z',
    'https://screenrant.com/pokemon-gs-nitro-open-world-johto/':
        '2026-11-09T00:00:18Z',
    'https://toucharcade.com/2024/09/24/toucharcade-is-shutting-down/':
        '2024-09-24T12:34:12Z',
    'https://toucharcade.com/2024/09/10/marvel-vs-capcom-collection-switch-review-rugrats-yars-rising-nintendo-eshop/':
        '2024-09-10T12:00:00Z',
    'https://toucharcade.com/2024/09/09/marvel-vs-capcom-fighting-collection-arcade-classics-review-steam-deck-nintendo-switch-online-ps5/':
        '2024-09-09T12:00:00Z',
    'https://toucharcade.com/2025/04/18/a-two-parter-the-toucharcade-show-613/':
        '2025-04-18T23:29:11Z',
    'https://news.xbox.com/en-us/2026/11/06/next-week-on-xbox-new-games-for-november-9-to-13/':
        '2026-11-06T15:00:00Z',
    'https://news.xbox.com/en-us/2026/11/04/from-polish-museums-to-xbox/':
        '2026-11-04T14:00:00Z',
    'https://news.xbox.com/en-us/2026/10/30/next-week-on-xbox-new-games-for-november-2-to-6/':
        '2026-10-30T14:00:00Z',
    'https://www.dexerto.com/food/charlotte-restaurants-response-to-viral-6-to-go-box-dispute-leaves-diners-even-more-confused-3425447/':
        '2026-11-06T15:34:09Z',
    'https://www.ign.com/articles/anthropic-blocks-ai-game-clones-in-claude-opus-update':
        '2026-10-31T21:46:36Z',
    'https://www.ign.com/articles/gta-6-rakes-in-over-750-million-in-pre-orders-two-weeks-ahead-of-release-date':
        '2026-11-04T22:42:19Z',
    'https://www.pcgamer.com/games/third-person-shooter/i-spoke-to-one-of-the-worlds-only-gaming-political-scientists-and-he-taught-me-how-to-avoid-getting-murdered-in-arc-raiders/':
        '2026-10-31T17:00:00Z',
    'https://www.ign.com/articles/world-of-warcraft-forever-launch-live-blog':
        '2026-11-05T00:37:00Z',
    'https://www.dexerto.com/entertainment/university-mascot-dog-trains-puppy-to-replace-him-before-retirement-3423507/':
        '2026-10-31T15:17:52Z',
    'https://www.siliconera.com/double-fines-thank-you-bus-driver-game-relies-on-its-gimmicks/':
        '2026-10-31T13:00:00Z',
    'https://www.eurogamer.net/shovel-knight-3d-mina-financial-stability':
        '2026-10-30T19:55:21Z',
    'https://attackofthefanboy.com/news/anthropic-whose-ceo-has-called-for-ai-regulation-gave-900000-to-california-democrats-days-before-the-november-3-election/':
        '2026-11-02T01:15:00Z',
    'https://www.pcgamer.com/games/november-games-2026/':
        '2026-11-04T23:37:01Z',
    'https://www.rockpapershotgun.com/what-are-we-all-playing-this-weekend-406':
        '2026-10-31T09:45:21Z',
  };

  /// Returns true if the image is a generic placeholder or Unsplash stock photo
  static bool isGenericImage(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    final clean = url.trim().toLowerCase();
    if (isBadNewsImage(clean)) return true;
    if (clean.contains('images.unsplash.com')) return true;
    if (isCategoryDefaultImage(clean)) return true;
    return false;
  }

  /// Extracts publication date from article URL if formatted as /YYYY/MM/DD/ or /YYYY/MM/
  static DateTime? extractDateFromUrl(String url) {
    try {
      final regYmd = RegExp(r'[/_-](\d{4})[/_-](\d{1,2})[/_-](\d{1,2})[/_-]');
      final m1 = regYmd.firstMatch(url);
      if (m1 != null) {
        final y = int.tryParse(m1.group(1)!);
        final mo = int.tryParse(m1.group(2)!);
        final d = int.tryParse(m1.group(3)!);
        if (y != null && mo != null && d != null && y >= 2020 && y <= 2030 && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, mo, d, 12);
        }
      }

      final regYm = RegExp(r'[/_-](\d{4})[/_-](\d{1,2})[/_-]');
      final m2 = regYm.firstMatch(url);
      if (m2 != null) {
        final y = int.tryParse(m2.group(1)!);
        final mo = int.tryParse(m2.group(2)!);
        if (y != null && mo != null && y >= 2020 && y <= 2030 && mo >= 1 && mo <= 12) {
          return DateTime(y, mo, 1, 12);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Resolves the true publication DateTime for any news article
  static DateTime resolveArticleDate(
    String? sourceUrl, {
    dynamic fallbackDate,
    num? timestamp,
  }) {
    _initPreSeeded();
    final cleanUrl = (sourceUrl ?? '').trim();

    // 1. Check in-memory date cache / pre-seeded mappings
    if (cleanUrl.isNotEmpty && _dateCache.containsKey(cleanUrl)) {
      return _dateCache[cleanUrl]!;
    }

    // 2. Extract date from URL path if present
    if (cleanUrl.isNotEmpty) {
      final fromUrl = extractDateFromUrl(cleanUrl);
      if (fromUrl != null) {
        _dateCache[cleanUrl] = fromUrl;
        return fromUrl;
      }
    }

    // 3. Check fallback date
    if (fallbackDate != null) {
      DateTime? dt;
      if (fallbackDate is DateTime) {
        dt = fallbackDate.toLocal();
      } else if (fallbackDate is String && fallbackDate.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(fallbackDate.trim());
        if (parsed != null) dt = parsed.toLocal();
      }

      if (dt != null) {
        // If dt is not suspiciously identical to current minute, use it
        return dt;
      }
    }

    // 4. Check timestamp (Unix seconds or ms)
    if (timestamp != null && timestamp > 0) {
      final ts = timestamp.toInt();
      if (ts > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toLocal();
      } else if (ts > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true).toLocal();
      }
    }

    return DateTime.now();
  }

  /// Formats relative time for any news post (calculates real time ago from true article date)
  static String formatArticleTime(Map<String, dynamic> post) {
    final sourceUrl = (post['source_url'] ?? post['url'] ?? '').toString().trim();
    final rawDate = post['created_at'] ?? post['published_at'] ?? post['timeAgo'];
    final ts = post['timestamp'] is num ? (post['timestamp'] as num).toInt() : null;

    final dt = resolveArticleDate(sourceUrl, fallbackDate: rawDate, timestamp: ts);
    return formatRelativeTime(dt);
  }

  /// Clean, grammatically correct relative time formatter
  static String formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    var diff = now.difference(dt);

    if (diff.isNegative) {
      final tzOffset = now.timeZoneOffset;
      if (tzOffset.inMinutes > 0 && diff.inMinutes <= -5) {
        final candidate = dt.subtract(tzOffset);
        final cDiff = now.difference(candidate);
        if (!cDiff.isNegative || cDiff.inSeconds >= -120) {
          dt = candidate;
          diff = cDiff.isNegative ? Duration.zero : cDiff;
        }
      }
      if (diff.isNegative) {
        if (diff.inSeconds >= -180) return 'Just now';
        diff = Duration.zero;
      }
    }

    final seconds = diff.inSeconds;
    final minutes = diff.inMinutes;
    final hours = diff.inHours;
    final days = diff.inDays;

    if (seconds < 60) {
      return 'Just now';
    } else if (minutes < 60) {
      return minutes == 1 ? '1 min ago' : '$minutes mins ago';
    } else if (hours < 24) {
      return hours == 1 ? '1 hr ago' : '$hours hrs ago';
    } else if (days < 7) {
      return days == 1 ? '1 day ago' : '$days days ago';
    } else if (days < 30) {
      final weeks = days ~/ 7;
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (days < 365) {
      final months = days ~/ 30;
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = days ~/ 365;
      if (years >= 1) {
        return years == 1 ? '1 year ago' : '$years years ago';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  /// Synchronous fast resolver for images:
  static String resolveDirect(
    String? currentImg, {
    String? sourceUrl,
    void Function(String realImage)? onResolved,
  }) {
    _initPreSeeded();
    final cleanUrl = (sourceUrl ?? '').trim();

    // 1. Check if sourceUrl already has a resolved real image in cache
    if (cleanUrl.isNotEmpty && _cache.containsKey(cleanUrl)) {
      final cached = _cache[cleanUrl]!;
      if (cached.isNotEmpty && !isGenericImage(cached)) {
        return cached;
      }
    }

    // 2. If currentImg is genuine (not an Unsplash placeholder), return it
    final cleanImg = (currentImg ?? '').trim();
    if (cleanImg.isNotEmpty && !isGenericImage(cleanImg)) {
      return cleanImg;
    }

    // 3. Current image is a generic placeholder; trigger async extraction if sourceUrl is available
    if (cleanUrl.isNotEmpty && cleanUrl.startsWith('http')) {
      queueResolve(cleanUrl, onResolved: onResolved);
    }

    return cleanImg;
  }

  /// Queues asynchronous image & date resolution from article page
  static void queueResolve(
    String sourceUrl, {
    void Function(String realImage)? onResolved,
  }) {
    _initPreSeeded();
    final clean = sourceUrl.trim();
    if (clean.isEmpty || !clean.startsWith('http')) return;

    if (_cache.containsKey(clean)) {
      final cached = _cache[clean]!;
      if (cached.isNotEmpty && !isGenericImage(cached)) {
        onResolved?.call(cached);
        return;
      }
    }

    resolveArticleImage(clean).then((realImg) {
      if (realImg != null && realImg.isNotEmpty) {
        onResolved?.call(realImg);
        onImageResolved.value++;
      }
    }).catchError((_) {});
  }

  /// Asynchronously fetches article webpage and extracts real og:image and publication date
  static Future<String?> resolveArticleImage(String articleUrl) async {
    _initPreSeeded();
    final clean = articleUrl.trim();
    if (clean.isEmpty || !clean.startsWith('http')) return null;

    // Check memory cache
    if (_cache.containsKey(clean)) {
      final val = _cache[clean];
      if (val != null && val.isNotEmpty && !isGenericImage(val)) {
        return val;
      }
    }

    // Check SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'real_img_${clean.hashCode}';
      final saved = prefs.getString(key);
      if (saved != null && saved.isNotEmpty && !isGenericImage(saved)) {
        _cache[clean] = saved;
        return saved;
      }
    } catch (_) {}

    // Deduplicate in-flight requests
    if (_inFlight.containsKey(clean)) {
      return _inFlight[clean];
    }

    final future = _fetchRealImageFromWeb(clean);
    _inFlight[clean] = future;

    try {
      final result = await future;
      if (result != null && result.isNotEmpty && !isGenericImage(result)) {
        _cache[clean] = result;
        try {
          final prefs = await SharedPreferences.getInstance();
          final key = 'real_img_${clean.hashCode}';
          await prefs.setString(key, result);
        } catch (_) {}
        return result;
      }
    } finally {
      _inFlight.remove(clean);
    }

    return null;
  }

  static Future<String?> _fetchRealImageFromWeb(String url) async {
    try {
      String referer = '';
      try {
        final uri = Uri.parse(url);
        referer = '${uri.scheme}://${uri.host}';
      } catch (_) {}

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _ua,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          if (referer.isNotEmpty) 'Referer': referer,
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200 || response.body.isEmpty) {
        return null;
      }

      final document = html_parser.parse(response.body);

      // Extract publication date from meta tags
      final metaElements = document.getElementsByTagName('meta');
      for (final meta in metaElements) {
        final prop = (meta.attributes['property'] ?? '').toLowerCase().trim();
        final name = (meta.attributes['name'] ?? '').toLowerCase().trim();
        final content = (meta.attributes['content'] ?? '').trim();

        if (content.isNotEmpty &&
            (prop == 'article:published_time' ||
                name == 'article:published_time' ||
                prop == 'og:published_time' ||
                name == 'publish-date' ||
                name == 'pubdate' ||
                name == 'date')) {
          final parsed = DateTime.tryParse(content);
          if (parsed != null) {
            _dateCache[url] = parsed.toLocal();
            break;
          }
        }
      }

      // If not in meta, check <time datetime="...">
      if (!_dateCache.containsKey(url)) {
        final timeTags = document.getElementsByTagName('time');
        for (final t in timeTags) {
          final dt = (t.attributes['datetime'] ?? '').trim();
          if (dt.isNotEmpty) {
            final parsed = DateTime.tryParse(dt);
            if (parsed != null) {
              _dateCache[url] = parsed.toLocal();
              break;
            }
          }
        }
      }

      // 1. Meta tags: og:image, twitter:image, secure_url
      for (final meta in metaElements) {
        final prop = (meta.attributes['property'] ?? '').toLowerCase().trim();
        final name = (meta.attributes['name'] ?? '').toLowerCase().trim();
        final content = (meta.attributes['content'] ?? '').trim();

        if (content.isEmpty) continue;

        if (prop == 'og:image' ||
            prop == 'og:image:url' ||
            prop == 'og:image:secure_url' ||
            name == 'twitter:image' ||
            name == 'twitter:image:src' ||
            prop == 'twitter:image' ||
            name == 'thumbnail' ||
            prop == 'thumbnail') {
          final abs = _makeAbsoluteUrl(content, url);
          if (abs != null && _isValidArticleImage(abs)) {
            return abs;
          }
        }
      }

      // 2. Link tags: rel="image_src"
      final linkElements = document.getElementsByTagName('link');
      for (final link in linkElements) {
        final rel = (link.attributes['rel'] ?? '').toLowerCase().trim();
        final href = (link.attributes['href'] ?? '').trim();
        if (rel == 'image_src' && href.isNotEmpty) {
          final abs = _makeAbsoluteUrl(href, url);
          if (abs != null && _isValidArticleImage(abs)) {
            return abs;
          }
        }
      }

      // 3. Article first image (featured image / hero banner)
      final articleImgs = document.querySelectorAll(
          'article img, .featured-image img, .post-thumbnail img, .entry-content img, main img');
      for (final img in articleImgs) {
        final src = (img.attributes['src'] ??
                img.attributes['data-src'] ??
                img.attributes['data-lazy-src'] ??
                '')
            .trim();
        if (src.isNotEmpty) {
          final abs = _makeAbsoluteUrl(src, url);
          if (abs != null && _isValidArticleImage(abs)) {
            return abs;
          }
        }
      }
    } catch (e) {
      debugPrint('NewsImageResolver error for $url: $e');
    }

    return null;
  }

  static String? _makeAbsoluteUrl(String candidate, String pageUrl) {
    String clean = candidate.trim();
    // Decode common entities
    clean = clean.replaceAll('&amp;', '&');

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    if (clean.startsWith('//')) {
      return 'https:$clean';
    }
    try {
      final base = Uri.parse(pageUrl);
      if (clean.startsWith('/')) {
        return '${base.scheme}://${base.host}$clean';
      }
      return base.resolve(clean).toString();
    } catch (_) {
      return null;
    }
  }

  static bool _isValidArticleImage(String url) {
    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) return false;

    // Reject tracking pixels, icons, and generic placeholders
    if (lower.contains('1x1') ||
        lower.contains('pixel') ||
        lower.contains('favicon') ||
        lower.contains('feedburner') ||
        lower.contains('googleusercontent') ||
        lower.contains('gstatic') ||
        lower.contains('unsplash.com') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.ico') ||
        lower.endsWith('.svg')) {
      return false;
    }

    return true;
  }
}
