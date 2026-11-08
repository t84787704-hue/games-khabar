import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/fallback_images.dart';

/// NewsImageResolver dynamically extracts and caches the genuine article hero image
/// from news source websites (via OpenGraph og:image, twitter:image, meta tags),
/// ensuring that news articles never show generic Unsplash placeholder images.
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

  // Active in-flight requests to avoid duplicate fetches
  static final Map<String, Future<String?>> _inFlight = {};

  // Change notifier for feed cards to rebuild when real image is resolved
  static final ValueNotifier<int> onImageResolved = ValueNotifier<int>(0);

  static void _initPreSeeded() {
    if (_cache.isNotEmpty) return;
    _cache.addAll(_preSeededImages);
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
    'https://attackofthefanboy.com/social-media/a-woman-says-a-heart-attack-at-24-sent-her-hunting-for-medical-history-and-a-dna-test-exposed-the-cheating-secret-her-grandmother-hid-for-55-years/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/dna-tiktok.jpg',
    'https://attackofthefanboy.com/social-media/a-nanny-says-she-was-called-late-for-arriving-at-801-am-then-quit-after-the-mom-asked-her-to-wipe-the-babys-face-once-the-other-nanny-kissed-her/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/nanny-tiktok.jpg',
    'https://news.xbox.com/en-us/2026/11/05/ea-play-november/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/EAP_MySimsBundle_PlayListDrop_Social_1920x1080-e793e531979efc252673.jpg',
    'https://news.xbox.com/en-us/2026/11/05/a-faster-simpler-xbox-experience-is-coming-to-pc-web-and-cloud/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/XBOXWire_Bastion_Image1_Header_110526-bb33470068546f1dc696-1024x576.png',
    'https://news.xbox.com/en-us/2026/11/05/free-play-days-11-04-2026/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/11/FY26-Social-FPD_11-06-2026_1920x1080-JPG-f061ae62490042855b20.jpg',
    'https://attackofthefanboy.com/politics/trump-reportedly-told-aides-that-stephen-miller-had-gone-too-far-with-deportations-after-melania-made-a-private-complaint/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/Donald-Trump-and-staff-on-Air-Force-One_1793904338504.jpg',
    'https://attackofthefanboy.com/social-media/dylan-sprouse-reunited-with-mr-moseby-actor-phill-lewis-then-revealed-the-only-suite-life-residual-check-he-ever-got-was-5-cents/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/Young-Dylan-Sprouse-and-Cole-Sprouse-sitting-on-sofas-and-close-up-of-a-man.jpg',
    'https://attackofthefanboy.com/social-media/a-22-year-old-woman-went-to-bed-feeling-fine-and-woke-with-half-her-face-drooping-then-five-days-later-she-could-no-longer-walk-or-speak/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/A-woman-on-a-hospital-bed-and-close-up-of-a-woman.jpg',
    'https://attackofthefanboy.com/social-media/a-new-jersey-shopper-walked-into-walmart-and-found-the-clothing-aisles-blocked-off-because-selling-them-that-day-is-illegal/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/1_1794053588459.jpg',
    'https://news.xbox.com/en-us/2026/10/30/terrible-lizards-movement-is-your-weapon/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/TitledHeroArt_1920x1080-6061668f5e0d4550d3e7.jpg',
    'https://news.xbox.com/en-us/2026/10/29/metro-redux-next-gen-update/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/10/METRO-Redux-1-81be11dfea4d5d8f97e7.jpg',
    'https://attackofthefanboy.com/social-media/an-arizona-dad-hauled-his-dead-86-inch-lg-tv-back-to-costco-expecting-a-refund-then-walked-out-paying-full-price-for-a-new-one/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/Costco-logo-on-a-building-and-a-man-with-a-TV.jpg',
    'https://attackofthefanboy.com/entertainment/justin-timberlake-says-michael-jackson-called-him-about-an-nsync-song-but-he-thought-it-was-a-prank-and-cursed-him-out/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/Justin-Timberlake-28485093605_1794054104267.jpg',
    'https://news.xbox.com/en-us/2026/11/06/gears-of-war-e-day-season-2-20th-anniversary/':
        'https://xboxwire.thesourcemediaassets.com/sites/2/2026/11/GoW_EDAY_20th_Lancer-027826f9d544349f4546.jpg',
    'https://attackofthefanboy.com/sports/a-woman-says-a-former-mlb-pitcher-flew-her-first-class-to-away-games-for-eight-months-then-her-aunt-revealed-he-was-engaged/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/image_1794053888919.jpg',
    'https://attackofthefanboy.com/true-crime/police-say-a-48-year-old-drunk-passenger-exposed-himself-at-a-florida-airport-gate-then-urinated-on-a-mom-and-her-7-year-old-son/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/Photo-by-Margo-Evardson_1793964155488.jpg',
    'https://attackofthefanboy.com/news/an-airbnb-host-who-rewashes-guests-dishes-and-skips-a-separate-cleaning-fee-says-the-general-public-is-not-sympathizing-with-us/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/an-airbnb-logo-a-restuarant-with-the-common-clean-table-and-chairs-and-some-food-on-the-table.jpg',
    'https://attackofthefanboy.com/true-crime/a-12-year-old-testified-that-her-mom-confessed-to-killing-the-teacher-she-was-cheating-with-and-the-next-day-her-mom-and-stepdad-pleaded-guilty/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/Screenshot-2026-11-06-121742_1793963902474.jpg',
    'https://attackofthefanboy.com/true-crime/police-at-a-peruvian-airport-searched-three-travelers-luggage-and-found-more-than-3000-live-tarantulas-stuffed-inside-socks/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/Photo-by-Soly-Moses_1793965739973.jpg',
    'https://attackofthefanboy.com/social-media/a-city-worker-was-emptying-trash-cans-at-a-california-park-when-they-found-a-live-4-foot-python-curled-up-in-one-and-no-one-knows-who-put-it-there/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/A-trash-can-and-a-python.jpg',
    'https://attackofthefanboy.com/entertainment/an-arkansas-pilot-flew-in-a-strange-pattern-for-over-eight-hours-then-his-completed-flight-path-revealed-a-tribute-to-gta-6/':
        'https://attackofthefanboy.com/wp-content/uploads/2026/11/Untitled-1_1794074339975.jpg',
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

  /// Synchronous fast resolver:
  /// 1. If [currentImg] is already a genuine article image, returns it.
  /// 2. If [sourceUrl] is known in cache/pre-seeded, returns the real image immediately.
  /// 3. Otherwise returns [currentImg] while scheduling an asynchronous resolution in the background.
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

  /// Queues asynchronous image resolution from article page
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

  /// Asynchronously fetches article webpage and extracts real og:image or twitter:image
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

      // 1. Meta tags: og:image, twitter:image, secure_url
      final metaElements = document.getElementsByTagName('meta');
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
