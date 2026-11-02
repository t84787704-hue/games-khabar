import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';
import '../services/translation_service.dart';
import '../models/gaming_news_model.dart';
import '../models/news_model.dart';
import '../data/fallback_images.dart';

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

  late String _title;
  late String _description;
  late String _imageUrl;
  late String _source;
  late String _sourceUrl;
  late String _category;
  late String _gameName;
  late String _timeAgo;

  bool _showUrdu = true;
  String? _urduTitle;
  String? _urduDescription;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _extractData();
    _resolveUrduContent();
  }

  void _extractData() {
    final nd = widget.newsData;
    final gn = widget.gamingNews;
    final nm = widget.newsModel;

    _title = (widget.title ??
            nd?['title'] ??
            gn?.titleEn ??
            nm?.getTitle('en') ??
            nm?.title ??
            '')
        .toString()
        .trim();

    _description = (widget.description ??
            nd?['description'] ??
            nd?['content'] ??
            gn?.contentEn ??
            nm?.getDescription('en') ??
            nm?.description ??
            '')
        .toString()
        .trim();

    // Check pre-translated fields cleanly
    String? preUrduTitle = nd?['title_ur']?.toString();
    if (preUrduTitle == null && nd != null && nd['titleMap'] is Map) {
      preUrduTitle = (nd['titleMap'] as Map)['ur']?.toString();
    }
    preUrduTitle ??= gn?.titleUr ?? nm?.titleMap['ur'];

    if (preUrduTitle != null &&
        preUrduTitle.trim().isNotEmpty &&
        TranslationService.isTextInLanguage(preUrduTitle, 'ur')) {
      _urduTitle = preUrduTitle.trim();
    }

    String? preUrduDesc = nd?['description_ur']?.toString();
    if (preUrduDesc == null && nd != null && nd['descriptionMap'] is Map) {
      preUrduDesc = (nd['descriptionMap'] as Map)['ur']?.toString();
    }
    preUrduDesc ??= gn?.contentUr ?? nm?.descriptionMap['ur'];

    if (preUrduDesc != null &&
        preUrduDesc.trim().isNotEmpty &&
        TranslationService.isTextInLanguage(preUrduDesc, 'ur')) {
      _urduDescription = preUrduDesc.trim();
    }

    _imageUrl = (widget.imageUrl ??
            nd?['image_url'] ??
            nd?['imageUrl'] ??
            gn?.effectiveImageUrl ??
            nm?.imageUrl ??
            '')
        .toString()
        .trim();

    _sourceUrl = (widget.sourceUrl ??
            nd?['source_url'] ??
            nd?['sourceUrl'] ??
            nd?['url'] ??
            gn?.sourceUrl ??
            nm?.sourceUrl ??
            '')
        .toString()
        .trim();

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

    final rawTime = (widget.timeAgo ??
            nd?['created_at'] ??
            nd?['published_at'] ??
            nd?['timeAgo'] ??
            '')
        .toString();

    _timeAgo = _formatTimestamp(rawTime);
  }

  void _resolveUrduContent() {
    // Check if title is already in Urdu
    if (_urduTitle == null) {
      if (TranslationService.isTextInLanguage(_title, 'ur')) {
        _urduTitle = _title;
      } else if (_globalUrduDetailCache.containsKey('t_$_title')) {
        _urduTitle = _globalUrduDetailCache['t_$_title'];
      }
    }

    // Check if description is already in Urdu
    if (_urduDescription == null) {
      if (TranslationService.isTextInLanguage(_description, 'ur')) {
        _urduDescription = _description;
      } else if (_globalUrduDetailCache.containsKey('d_$_description')) {
        _urduDescription = _globalUrduDetailCache['d_$_description'];
      }
    }

    if (_urduTitle != null && _urduDescription != null) {
      return;
    }

    _isTranslating = true;

    Future.wait([
      if (_urduTitle == null && _title.isNotEmpty)
        TranslationService.translateSingle(_title, 'ur').then((res) {
          if (res.isNotEmpty && TranslationService.isTextInLanguage(res, 'ur')) {
            _globalUrduDetailCache['t_$_title'] = res;
            _urduTitle = res;
          }
        }),
      if (_urduDescription == null && _description.isNotEmpty)
        TranslationService.translateArticle(_description, 'ur').then((res) {
          if (res.isNotEmpty && TranslationService.isTextInLanguage(res, 'ur')) {
            _globalUrduDetailCache['d_$_description'] = res;
            _urduDescription = res;
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
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hrs ago';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  void _shareArticle() {
    final activeTitle = (_showUrdu && _urduTitle != null) ? _urduTitle! : _title;
    final activeDesc = (_showUrdu && _urduDescription != null) ? _urduDescription! : _description;

    final shareText = '🎮 $activeTitle\n\n'
        '${activeDesc.length > 200 ? "${activeDesc.substring(0, 200)}..." : activeDesc}\n\n'
        'Read complete story on Games ID app!'
        '${_sourceUrl.isNotEmpty ? "\n\nSource: $_sourceUrl" : ""}';
    Share.share(shareText);
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
          if (_sourceUrl.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, size: 20),
              color: textSec,
              onPressed: _openSourceWebsite,
              tooltip: 'Open in Browser',
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
                          gameFallbackImages['DEFAULT']!,
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
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openSourceWebsite,
                              icon: Icon(
                                Icons.open_in_new_rounded,
                                size: 16,
                                color: accentGreen,
                              ),
                              label: Text(
                                displayUrdu
                                    ? 'اصل ویب سائٹ وزٹ کریں (${_source.replaceAll('.com', '')})'
                                    : 'Visit Source Website (${_source.replaceAll('.com', '')})',
                                style: TextStyle(
                                  color: accentGreen,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: accentGreen.withOpacity(0.6)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
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
  }
}
