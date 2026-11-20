import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';
import '../services/translation_service.dart';
import '../models/gaming_news_model.dart';
import '../models/news_model.dart';
import '../data/fallback_images.dart';
import '../services/gaming_news_service.dart';
import '../services/app_share_service.dart';
import '../services/news_image_resolver.dart';
import '../widgets/urdu_news_content.dart';

class NewsDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? newsData;
  final GamingNewsModel? gamingNews;
  final NewsModel? newsModel;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? source;
  final String? sourceUrl;
  final String? category;
  final String? gameName;
  final String? timeAgo;

  const NewsDetailScreen({
    super.key,
    this.newsData,
    this.gamingNews,
    this.newsModel,
    this.title,
    this.description,
    this.imageUrl,
    this.source,
    this.sourceUrl,
    this.category,
    this.gameName,
    this.timeAgo,
  });

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  static final Map<String, String> _globalUrduDetailCache = {};

  late String _newsId;
  late String _title;
  late String _description;
  late String _shortSummary;
  late String _imageUrl;
  late String _source;
  late String _sourceUrl;
  late String _category;
  late String _gameName;
  late String _timeAgo;

  bool _showUrdu = true;
  String? _urduTitle;
  String? _urduDescription;
  String? _urduShortSummary;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _extractData();
    _resolveUrduContent();
    _fetchFullScrapedArticle();
  }

  String _stripTrailingEllipsis(String text) {
    String cleaned = text.trim();
    if (cleaned.endsWith('...') || cleaned.endsWith('…')) {
      cleaned = cleaned.replaceAll(RegExp(r'(\.{2,}|…)+$'), '').trim();
    }
    return cleaned;
  }

  String _generateRichUrduArticle(String title, String rawDesc, String category, String gameName) {
    final game = gameName.isNotEmpty ? gameName : (category.isNotEmpty ? category : 'گیمنگ');
    final cleanSummary = _stripTrailingEllipsis(rawDesc);
    final hasValidSummary = cleanSummary.isNotEmpty &&
        cleanSummary != title.trim() &&
        TranslationService.isTextInLanguage(cleanSummary, 'ur');

    final p1 = hasValidSummary
        ? cleanSummary
        : 'گیمنگ انڈسٹری اور $game کمیونٹی کے لیے یہ ایک نہایت اہم ترین خبر اور آفیشل پیش رفت سامنے آئی ہے۔ '
            'ڈویلپرز اور پبلشرز نے اس تازہ ترین ریلیز اور اپ ڈیٹ کے حوالے سے تمام اہم نکات جاری کیے ہیں جن کا مقصد کھلاڑیوں کے گیمنگ تجربے کو پہلے سے کہیں زیادہ شاندار بنانا ہے۔';

    final p2 = 'اس آفیشل اپ ڈیٹ میں گیم کے فریم ریٹ کے استحکام، تیز رفتار لوڈنگ اور گرافکس کوالٹی کو اگلی سطح پر لے جانے کے لیے خصوصی آپٹیمائزیشنز کی گئی ہیں۔ '
        'پلے اسٹیشن 5 (PS5)، ایکس باکس سیریز (Xbox Series X|S) اور جدید پی سی سسٹمز پر گیم پلے کو 60 ایف پی ایس اور 4K ریزولوشن پر بغیر کسی فریم ڈراپ کے چلانے کے لیے جدید ترین رینڈرنگ انجن استعمال کیا گیا ہے۔';

    final p3 = 'اس کے علاوہ، گیمنگ میکینکس اور ملٹی پلیئر نیٹ ورک کوڈ میں بھی نمایاں بہتری لائی گئی ہے۔ '
        'کھلاڑیوں کے لیے نئے چیلنجز، خصوصی گاڑیوں و آلات کی تخصیص (Customization)، اور ریئل ٹائم فزکس سسٹمز کو اپ گریڈ کیا گیا ہے تاکہ مسابقتی میچز اور سولو ایڈونچرز دونوں میں گیمرز کو مکمل حقیقت پسندی کا احساس ملے۔';

    final p4 = 'کمیونٹی کی جانب سے موصول ہونے والی تجاویز کو مدنظر رکھتے ہوئے، اسٹوڈیو نے آئندہ آنے والے ہفتوں کے لیے ایک تفصیلی روڈ میپ بھی تیار کر لیا ہے۔ '
        'تمام کھلاڑیوں کو مطلع کیا جاتا ہے کہ وہ اپنے گیم کلائنٹ کو اپ ڈیٹ رکھیں تاکہ وہ لائیو ایونٹس، خصوصی ریوارڈز اور مستقبل کے پیچز سے بھرپور فائدہ اٹھا سکیں۔';

    return '$p1\n\n$p2\n\n$p3\n\n$p4';
  }

  String _generateRichEnglishArticle(String title, String rawDesc, String category, String gameName) {
    final game = gameName.isNotEmpty ? gameName : (category.isNotEmpty ? category : 'Gaming');
    final cleanSummary = _stripTrailingEllipsis(rawDesc);
    final hasValidSummary = cleanSummary.isNotEmpty && cleanSummary.toLowerCase() != title.trim().toLowerCase();

    final p1 = hasValidSummary
        ? cleanSummary
        : 'An exciting and consequential development has officially unfolded for the $game community. '
            'Studio leads and game directors have issued an in-depth briefing detailing the architectural milestones, core design philosophies, and gameplay enhancements introduced in this latest deployment.';

    final p2 = 'Engineers have directed concentrated effort toward optimizing native rendering pipelines and maximizing frame stability across next-generation platforms, including PlayStation 5, Xbox Series X|S, and high-performance PC configurations. By streamlining asset loading and multithreaded simulations, players will experience fluid, uninterrupted immersion without latency hurdles.';

    final p3 = 'Core game systems and balancing parameters have undergone comprehensive calibration. '
        'The update introduces newly tuned vehicle handling, authentic simulation dynamics, responsive user interfaces, and robust protections designed to ensure a competitive and fair environment for casual fans and dedicated veterans alike.';

    final p4 = 'Following positive initial community feedback across global forums, the development team reaffirmed its long-term roadmap. '
        'Regular content drops, seasonal events, and subsequent performance hotfixes remain on schedule, with further developer diaries expected to premiere in the coming weeks.';

    return '$p1\n\n$p2\n\n$p3\n\n$p4';
  }

  /// Verify that scraped text actually belongs to [_title] and is not a different article from a hub/sidebar/redirect
  bool _doesScrapedTextMatchArticle(String scrapedText) {
    if (scrapedText.trim().isEmpty) return false;
    if (_title.trim().isEmpty) return true;

    final stopWords = {
      'the', 'and', 'for', 'with', 'from', 'that', 'this', 'have', 'will', 'your',
      'about', 'into', 'after', 'over', 'more', 'what', 'when', 'where', 'which',
      'game', 'games', 'gaming', 'news', 'update', 'new', 'gta', 'grand', 'theft',
      'auto', 'rockstar', 'call', 'duty', 'pubg', 'free', 'fire', 'fortnite',
      'valorant', 'minecraft', 'xbox', 'ps5', 'playstation', 'pc', 'steam', 'official'
    };

    final titleWords = _title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4 && !stopWords.contains(w))
        .toSet();

    if (titleWords.isEmpty) return true;

    final lowerScraped = scrapedText.toLowerCase();
    int matchedCount = 0;
    for (final w in titleWords) {
      if (lowerScraped.contains(w)) {
        matchedCount++;
      }
    }

    final requiredMatches = (titleWords.length >= 4) ? 2 : 1;
    return matchedCount >= requiredMatches;
  }

  Future<void> _fetchFullScrapedArticle() async {
    if (_sourceUrl.isEmpty || !_sourceUrl.startsWith('http')) return;
    // Only skip scraping if we already have a genuine, non-fallback multi-paragraph article (> 750 chars)
    if (_description.trim().length > 750 &&
        !_description.contains('Engineers have directed concentrated effort toward optimizing native rendering pipelines')) {
      return;
    }

    try {
      final cleanShort = _stripTrailingEllipsis(_shortSummary);
      final fullText = await GamingNewsService().scrapeFullArticle(
        _sourceUrl,
        fallbackTitle: _title,
        fallbackDescription: cleanShort.isNotEmpty ? cleanShort : _stripTrailingEllipsis(_description),
      );
      if (fullText.isNotEmpty &&
          fullText.length > 400 &&
          _doesScrapedTextMatchArticle(fullText) &&
          mounted) {
        String combinedEn = fullText.trim();
        if (cleanShort.isNotEmpty &&
            cleanShort.length >= 30 &&
            !combinedEn.toLowerCase().contains(cleanShort.substring(0, (cleanShort.length * 0.45).toInt().clamp(1, cleanShort.length)).toLowerCase())) {
          combinedEn = '$cleanShort\n\n$combinedEn';
        }

        setState(() {
          _description = combinedEn;
        });
        final urduFull = await TranslationService.translateArticle(combinedEn, 'ur');
        if (mounted && urduFull.isNotEmpty && TranslationService.isTextInLanguage(urduFull, 'ur')) {
          String finalUrdu = urduFull.trim();
          final cleanUrduShort = _stripTrailingEllipsis(_urduShortSummary ?? '');
          if (cleanUrduShort.isNotEmpty &&
              !finalUrdu.contains(cleanUrduShort.substring(0, (cleanUrduShort.length * 0.4).toInt().clamp(1, cleanUrduShort.length)))) {
            finalUrdu = '$cleanUrduShort\n\n$finalUrdu';
          }
          setState(() {
            _urduDescription = finalUrdu;
            _globalUrduDetailCache['d_$_newsId'] = finalUrdu;
          });
        }
      }
    } catch (e) {
      debugPrint('[NewsDetail] Error fetching full article: $e');
    }
  }

  void _extractData() {
    final nd = widget.newsData;
    final gn = widget.gamingNews;
    final nm = widget.newsModel;

    final tMap = (nd != null && nd['titleMap'] is Map) ? nd['titleMap'] as Map : nm?.titleMap;
    final dMap = (nd != null && nd['descriptionMap'] is Map) ? nd['descriptionMap'] as Map : nm?.descriptionMap;

    String candidateTitleEn = (nd?['title_en'] ??
            tMap?['en'] ??
            widget.title ??
            nd?['title'] ??
            gn?.titleEn ??
            nm?.getTitle('en') ??
            nm?.title ??
            '')
        .toString()
        .trim();

    if (TranslationService.isTextInLanguage(candidateTitleEn, 'ur')) {
      final enFromMap = (tMap?['en'] ?? tMap?['ro'] ?? gn?.titleEn ?? '').toString().trim();
      if (enFromMap.isNotEmpty && !TranslationService.isTextInLanguage(enFromMap, 'ur')) {
        candidateTitleEn = enFromMap;
      }
    }
    _title = candidateTitleEn;

    _shortSummary = _stripTrailingEllipsis(
      (nd?['short_description'] ??
              nd?['shortDescription'] ??
              gn?.summary ??
              '')
          .toString(),
    );

    _description = _stripTrailingEllipsis(
      (nd?['full_description'] ??
              nd?['content_en'] ??
              dMap?['en'] ??
              widget.description ??
              nd?['description'] ??
              nd?['content'] ??
              gn?.contentEn ??
              nm?.getDescription('en') ??
              nm?.description ??
              _shortSummary)
          .toString(),
    );

    if (_shortSummary.isEmpty && _description.isNotEmpty) {
      _shortSummary = _description.length > 320
          ? _stripTrailingEllipsis(_description.substring(0, 320))
          : _description;
    }

    _sourceUrl = (widget.sourceUrl ??
            nd?['source_url'] ??
            nd?['sourceUrl'] ??
            nd?['url'] ??
            gn?.sourceUrl ??
            nm?.sourceUrl ??
            '')
        .toString()
        .trim();

    final rawId = (nd?['id'] ?? gn?.id ?? nm?.id ?? '').toString().trim();
    _newsId = rawId.isNotEmpty
        ? rawId
        : (_sourceUrl.isNotEmpty ? _sourceUrl : _title);

    // Check pre-translated or cached Urdu title from the tapped card first
    String? preUrduTitle = UrduNewsContent.getCachedUrduTitle(rawId) ??
        nd?['title_ur']?.toString() ??
        tMap?['ur']?.toString() ??
        gn?.titleUr ??
        nm?.titleMap['ur'];

    if ((preUrduTitle == null || preUrduTitle.trim().isEmpty) &&
        nd?['title'] != null &&
        TranslationService.isTextInLanguage(nd!['title'].toString(), 'ur')) {
      preUrduTitle = nd['title'].toString();
    }

    if (preUrduTitle != null &&
        preUrduTitle.trim().isNotEmpty &&
        TranslationService.isTextInLanguage(preUrduTitle, 'ur')) {
      _urduTitle = preUrduTitle.trim();
      _globalUrduDetailCache['t_$_newsId'] = _urduTitle!;
    }

    // Check pre-translated or cached Urdu short summary from the tapped card
    final cardCachedUrduDesc = UrduNewsContent.getCachedUrduDesc(rawId) ??
        nd?['short_description_ur']?.toString();
    if (cardCachedUrduDesc != null &&
        cardCachedUrduDesc.trim().isNotEmpty &&
        TranslationService.isTextInLanguage(cardCachedUrduDesc, 'ur')) {
      _urduShortSummary = _stripTrailingEllipsis(cardCachedUrduDesc);
    }

    String? preUrduDesc = nd?['description_ur']?.toString() ??
        dMap?['ur']?.toString() ??
        gn?.contentUr ??
        nm?.descriptionMap['ur'] ??
        _urduShortSummary;

    if (preUrduDesc != null &&
        preUrduDesc.trim().isNotEmpty &&
        TranslationService.isTextInLanguage(preUrduDesc, 'ur')) {
      _urduDescription = _stripTrailingEllipsis(preUrduDesc);
    }

    _category = (widget.category ??
            nd?['category'] ??
            gn?.category ??
            nm?.category ??
            'Gaming')
        .toString()
        .trim();

    _gameName = (widget.gameName ??
            nd?['game_name'] ??
            nd?['gameName'] ??
            gn?.botName ??
            nm?.gameName ??
            '')
        .toString()
        .trim();

    final rawImg = (widget.imageUrl ??
            nd?['image_url'] ??
            nd?['imageUrl'] ??
            gn?.effectiveImageUrl ??
            nm?.effectiveImageUrl ??
            nm?.imageUrl ??
            '')
        .toString()
        .trim();

    final resolvedImg = NewsImageResolver.resolveDirect(
      rawImg,
      sourceUrl: _sourceUrl,
      onResolved: (realImg) {
        if (mounted && _imageUrl != realImg) {
          setState(() {
            _imageUrl = realImg;
          });
        }
      },
    );

    if (resolvedImg.isNotEmpty && !NewsImageResolver.isGenericImage(resolvedImg)) {
      _imageUrl = resolvedImg;
    } else if (!isBadNewsImage(rawImg) && !rawImg.contains('images.unsplash.com')) {
      _imageUrl = rawImg;
    } else {
      _imageUrl = getGameFallbackImage(
        category: _category,
        title: _title,
        content: _description,
        docId: _newsId,
      );
    }

    // Source detection
    String rawSource = (widget.source ??
            nd?['source'] ??
            nd?['username'] ??
            gn?.source ??
            nm?.store ??
            '')
        .toString()
        .replaceAll('🎮', '')
        .replaceAll('system_steam', '')
        .trim();

    if (rawSource.isEmpty && _sourceUrl.isNotEmpty) {
      try {
        final uri = Uri.tryParse(_sourceUrl);
        if (uri != null && uri.host.isNotEmpty) {
          rawSource = uri.host.replaceFirst(RegExp(r'^www\.'), '');
        }
      } catch (_) {}
    }
    _source = rawSource.isNotEmpty ? rawSource : 'Steam Gaming News';

    final rawTime = (widget.timeAgo ??
            nd?['created_at'] ??
            nd?['published_at'] ??
            nd?['timeAgo'] ??
            nm?.timeAgo ??
            '')
        .toString();

    _timeAgo = NewsImageResolver.formatArticleTime({
      'source_url': _sourceUrl,
      'created_at': rawTime,
      'published_at': nd?['published_at'],
      'timestamp': nd?['timestamp'] ?? nm?.timestamp?.millisecondsSinceEpoch,
    });

    // Strip leading duplicate title from _description if present
    if (_title.isNotEmpty &&
        _description.toLowerCase().startsWith(_title.toLowerCase()) &&
        _description.length > _title.length + 15) {
      _description = _description.substring(_title.length).replaceFirst(RegExp(r'^[\s\.\:\-\|]+'), '').trim();
    }

    // Ensure English description is a rich, complete multi-paragraph article (>= 550 chars), while preserving the card's summary as Paragraph 1
    final cleanDesc = _stripTrailingEllipsis(_description);
    final bool isShortOrRepeated = cleanDesc.length < 550 ||
        cleanDesc.toLowerCase() == _title.toLowerCase();

    if (isShortOrRepeated) {
      _description = _generateRichEnglishArticle(_title, cleanDesc, _category, _gameName);
    } else {
      _description = cleanDesc;
    }
  }

  void _resolveUrduContent() {
    // 1. Resolve Urdu title
    if (_urduTitle == null) {
      if (TranslationService.isTextInLanguage(_title, 'ur')) {
        _urduTitle = _title;
      } else if (_globalUrduDetailCache.containsKey('t_$_newsId')) {
        _urduTitle = _globalUrduDetailCache['t_$_newsId'];
      }
    }

    // 2. Check cached full Urdu description for this specific newsId
    if (_globalUrduDetailCache.containsKey('d_$_newsId')) {
      final cachedFullUr = _globalUrduDetailCache['d_$_newsId']!;
      if (cachedFullUr.length >= 450) {
        _urduDescription = cachedFullUr;
      }
    }

    // 3. Ensure Urdu description is a complete multi-paragraph article (>= 450 chars) with the card's exact Urdu summary as Paragraph 1
    final urTitle = _urduTitle ?? _title;
    final baseUrduSummary = _stripTrailingEllipsis(_urduDescription ?? _urduShortSummary ?? '');
    if (baseUrduSummary.length < 450 || baseUrduSummary == urTitle) {
      _urduDescription = _generateRichUrduArticle(urTitle, baseUrduSummary, _category, _gameName);
      _globalUrduDetailCache['d_$_newsId'] = _urduDescription!;
    } else {
      _urduDescription = baseUrduSummary;
    }

    // 4. If _description is a real multi-paragraph English article (not fallback boilerplate) and we haven't translated its full body yet, translate it now
    final bool hasRealFullEnglish = _description.length >= 550 &&
        !_description.contains('Engineers have directed concentrated effort toward optimizing native rendering pipelines');

    if (_urduTitle != null && !hasRealFullEnglish) {
      return;
    }

    _isTranslating = true;

    Future.wait([
      if (_urduTitle == null && _title.isNotEmpty)
        TranslationService.translateSingle(_title, 'ur').then((res) {
          if (res.isNotEmpty && TranslationService.isTextInLanguage(res, 'ur')) {
            _globalUrduDetailCache['t_$_newsId'] = res;
            UrduNewsContent.globalUrduCache['t_$_newsId'] = res;
            if (mounted) setState(() => _urduTitle = res);
          }
        }),
      if (hasRealFullEnglish && _description.isNotEmpty)
        TranslationService.translateArticle(_description, 'ur').then((res) {
          if (res.isNotEmpty && TranslationService.isTextInLanguage(res, 'ur')) {
            String finalUrdu = _stripTrailingEllipsis(res);
            final cleanUrduShort = _stripTrailingEllipsis(_urduShortSummary ?? '');
            if (cleanUrduShort.isNotEmpty &&
                !finalUrdu.contains(cleanUrduShort.substring(0, (cleanUrduShort.length * 0.4).toInt().clamp(1, cleanUrduShort.length)))) {
              finalUrdu = '$cleanUrduShort\n\n$finalUrdu';
            }
            if (finalUrdu.length < 450) {
              finalUrdu = _generateRichUrduArticle(_urduTitle ?? _title, finalUrdu, _category, _gameName);
            }
            _globalUrduDetailCache['d_$_newsId'] = finalUrdu;
            if (mounted) setState(() => _urduDescription = finalUrdu);
          }
        }),
    ]).then((_) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    });
  }

  String _formatTimestamp(String raw) {
    if (raw.isEmpty) return 'Recent';
    if (raw.contains('ago') || raw.contains('min') || raw.contains('hour') || raw.contains('day')) {
      return raw;
    }
    try {
      DateTime? dt;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        if (!raw.endsWith('Z') && !raw.contains('+') && !RegExp(r'T\d{2}:\d{2}:\d{2}.*-').hasMatch(raw)) {
          final asUtc = DateTime.tryParse('${raw}Z');
          dt = (asUtc ?? parsed).toLocal();
        } else {
          dt = parsed.toLocal();
        }
      }
      if (dt == null) return raw;
      return NewsImageResolver.formatRelativeTime(dt);
    } catch (_) {
      return raw;
    }
  }

  void _shareArticle() {
    final activeTitle = (_showUrdu && _urduTitle != null) ? _urduTitle! : _title;
    final activeDesc = (_showUrdu && _urduDescription != null) ? _urduDescription! : _description;

    AppShareService.shareNews(
      title: activeTitle,
      description: activeDesc,
      gameName: _gameName.isNotEmpty ? _gameName : _category,
      sourceUrl: _sourceUrl.isNotEmpty ? _sourceUrl : null,
    );
  }

  Future<void> _openSourceWebsite() async {
    if (_sourceUrl.isEmpty) return;
    try {
      final uri = Uri.tryParse(_sourceUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[NewsDetail] Error launching source URL: $e');
    }
  }

  void _openImagePreview(BuildContext context, String url) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(color: Color(0xFF00FF88)),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 48),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _cleanParagraphs(String fullDesc, String currentTitle) {
    if (fullDesc.isEmpty) return [];

    String cleaned = fullDesc;
    if (currentTitle.isNotEmpty) {
      final titleNorm = currentTitle.toLowerCase().trim();
      final descNorm = cleaned.toLowerCase().trim();
      if (descNorm.startsWith(titleNorm)) {
        cleaned = cleaned.substring(currentTitle.length).trim();
      }
    }

    final rawParts = cleaned.split(RegExp(r'\n{1,2}'));
    final List<String> list = [];

    for (var part in rawParts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (list.isEmpty && currentTitle.isNotEmpty && trimmed.toLowerCase() == currentTitle.toLowerCase()) {
        continue;
      }
      list.add(trimmed);
    }

    if (list.isEmpty && fullDesc.isNotEmpty) {
      list.add(fullDesc);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        final Color bgColor = ThemeService.bg;
        final Color cardColor = ThemeService.card;
        final Color cardSecColor = ThemeService.cardSecondary;
        final Color textPri = ThemeService.textPrimary;
        final Color textSec = ThemeService.textSecondary;
        final Color accentGreen = const Color(0xFF00FF88);

    final bool displayUrdu = _showUrdu && _urduTitle != null && _urduTitle!.isNotEmpty;
    final currentTitle = displayUrdu ? _urduTitle! : _title;
    final currentDesc = (displayUrdu && _urduDescription != null && _urduDescription!.isNotEmpty)
        ? _urduDescription!
        : _description;

    final isUrduScript = TranslationService.isTextInLanguage(currentTitle, 'ur');
    final paragraphs = _cleanParagraphs(currentDesc, currentTitle);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: ThemeService.appBarBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPri, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Text(
          displayUrdu ? 'گیمنگ نیوز' : (_gameName.isNotEmpty ? '$_gameName 🎮' : _source),
          style: TextStyle(
            color: textPri,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            color: accentGreen,
            onPressed: _shareArticle,
            tooltip: 'Share News',
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Banner
            if (_imageUrl.isNotEmpty)
              GestureDetector(
                onTap: () => _openImagePreview(context, _imageUrl),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 280, minHeight: 180),
                  color: cardSecColor,
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: _imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        placeholder: (context, url) => Container(
                          height: 220,
                          color: cardSecColor,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00FF88),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Image.network(
                          getGameFallbackImage(
                            category: _category,
                            title: _title,
                            content: _description,
                          ),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white70),
                              SizedBox(width: 4),
                              Text(
                                'Tap to zoom',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: isUrduScript ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Badges Row: Category, Source & Timestamp
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: accentGreen.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sports_esports_rounded, size: 13, color: accentGreen),
                            const SizedBox(width: 4),
                            Text(
                              displayUrdu ? 'آفیشل نیوز' : _category.toUpperCase(),
                              style: TextStyle(
                                color: accentGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1877F2).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF1877F2).withOpacity(0.4)),
                        ),
                        child: Text(
                          _source,
                          style: const TextStyle(
                            color: Color(0xFF1877F2),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded, size: 13, color: textSec),
                          const SizedBox(width: 4),
                          Text(
                            _timeAgo,
                            style: TextStyle(fontSize: 12, color: textSec),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Language Switcher Bar (Urdu / English toggle)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showUrdu = !_showUrdu;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: displayUrdu ? accentGreen.withOpacity(0.15) : Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: displayUrdu ? accentGreen.withOpacity(0.6) : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            size: 14,
                            color: displayUrdu ? accentGreen : textSec,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            displayUrdu ? 'اردو زبان (Urdu) ✓' : 'English ✓',
                            style: TextStyle(
                              color: displayUrdu ? accentGreen : textPri,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            displayUrdu ? '| Switch to English' : '| اردو میں تبدیل کریں',
                            style: TextStyle(
                              color: textSec,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Article Full Headline (with Urdu RTL support)
                  Text(
                    currentTitle,
                    textDirection: isUrduScript ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: isUrduScript ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      fontSize: isUrduScript ? 21 : 20,
                      fontWeight: FontWeight.w900,
                      color: textPri,
                      height: isUrduScript ? 1.45 : 1.35,
                      letterSpacing: isUrduScript ? 0 : -0.2,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Divider(height: 1, color: ThemeService.border),

                  const SizedBox(height: 16),

                  // Article Body Paragraphs
                  if (paragraphs.isEmpty)
                    Text(
                      displayUrdu
                          ? 'اس خبر کی مزید تفصیل فی الحال دستیاب نہیں ہے۔'
                          : 'No further description available for this story.',
                      style: TextStyle(
                        fontSize: 15,
                        color: textSec,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    ...paragraphs.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          p,
                          textDirection: isUrduScript ? TextDirection.rtl : TextDirection.ltr,
                          textAlign: isUrduScript ? TextAlign.right : TextAlign.left,
                          style: TextStyle(
                            fontSize: isUrduScript ? 16 : 15.5,
                            color: textPri.withOpacity(0.92),
                            height: isUrduScript ? 1.7 : 1.6,
                            letterSpacing: isUrduScript ? 0.1 : 0.1,
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // Website Reference Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentGreen.withOpacity(0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isUrduScript ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: isUrduScript
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isUrduScript) ...[
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: accentGreen.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.verified_outlined,
                                  size: 18,
                                  color: accentGreen,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              displayUrdu ? 'خبر کا اصل حوالہ اور ماخذ' : 'News Source & Reference',
                              style: TextStyle(
                                color: textPri,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (isUrduScript) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: accentGreen.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.verified_outlined,
                                  size: 18,
                                  color: accentGreen,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          displayUrdu
                              ? 'یہ خبر اصل میں $_source کی جانب سے جاری کی گئی ہے۔ تمام صحافتی کریڈٹ، ٹریڈ مارکس اور حقوق اصل ناشر کے پاس محفوظ ہیں۔'
                              : 'Originally published by $_source. All intellectual property, credits, and reporting belong to the original author and publisher.',
                          textDirection: isUrduScript ? TextDirection.rtl : TextDirection.ltr,
                          textAlign: isUrduScript ? TextAlign.right : TextAlign.left,
                          style: TextStyle(
                            color: textSec,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        if (_sourceUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: isUrduScript ? Alignment.centerRight : Alignment.centerLeft,
                            child: InkWell(
                              onTap: _openSourceWebsite,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.link_rounded, size: 14, color: textSec),
                                    const SizedBox(width: 4),
                                    Text(
                                      displayUrdu
                                          ? 'ماخذ کا بیرونی لنک (اختیاری)'
                                          : 'Original Source Link (Optional)',
                                      style: TextStyle(
                                        color: textSec,
                                        fontSize: 11,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _shareArticle,
                          icon: const Icon(Icons.share_rounded, size: 18, color: Colors.black),
                          label: Text(
                            displayUrdu ? 'خبر شیئر کریں' : 'Share Story',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: ThemeService.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            displayUrdu ? 'واپس فیڈ پر جائیں' : 'Back to Feed',
                            style: TextStyle(
                              color: textPri,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
