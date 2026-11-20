import 'package:flutter/material.dart';
import '../services/translation_service.dart';
import '../services/theme_service.dart';

class UrduNewsContent extends StatefulWidget {
  final String? newsId;
  final String title;
  final String description;
  final String? titleUr;
  final String? descriptionUr;
  final VoidCallback? onTap;
  final int maxDescriptionLines;

  const UrduNewsContent({
    super.key,
    this.newsId,
    required this.title,
    required this.description,
    this.titleUr,
    this.descriptionUr,
    this.onTap,
    this.maxDescriptionLines = 3,
  });

  static final Map<String, String> globalUrduCache = {};

  static String? getCachedUrduTitle(String? newsId) {
    if (newsId == null) return null;
    return globalUrduCache['t_$newsId'];
  }

  static String? getCachedUrduDesc(String? newsId) {
    if (newsId == null) return null;
    return globalUrduCache['d_$newsId'];
  }

  @override
  State<UrduNewsContent> createState() => _UrduNewsContentState();
}

class _UrduNewsContentState extends State<UrduNewsContent> {
  bool _showUrdu = true;
  String? _urduTitle;
  String? _urduDescription;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _resolveTranslations();
  }

  @override
  void didUpdateWidget(covariant UrduNewsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.newsId != widget.newsId || oldWidget.title != widget.title || oldWidget.description != widget.description) {
      _resolveTranslations();
    }
  }

  String _cleanText(String raw) {
    if (raw.trim().isEmpty) return '';
    String cleaned = raw
        .replaceAll('notif_gaming_news_fallback', '')
        .replaceAll('notif_gaming_fallback', '')
        .replaceAll('notif_latest_news_fallback', '')
        .replaceAll('notif_read_full_story', '')
        .trim();

    final lines = cleaned.split(RegExp(r'\n{1,2}'));
    final kept = <String>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final lower = t.toLowerCase();
      if (lower.contains('an exciting and consequential development has officially unfolded for the') ||
          lower.contains('engineers have directed concentrated effort toward optimizing native rendering pipelines') ||
          lower.contains('industry analysts and game studio leads report that state-of-the-art engineering') ||
          lower.contains('this official game update brings key performance improvements, bug fixes, balance tweaks') ||
          lower.contains("tap 'read full story' to explore complete release notes, visual highlights") ||
          t.contains('کمیونٹی کے لیے یہ ایک نہایت اہم ترین خبر اور آفیشل پیش رفت سامنے آئی ہے') ||
          t.contains('اس آفیشل اپ ڈیٹ میں گیم کے فریم ریٹ کے استحکام، تیز رفتار لوڈنگ اور گرافکس کوالٹی')) {
        continue;
      }
      kept.add(t);
    }
    return kept.join('\n\n').trim();
  }

  void _resolveTranslations() {
    final cleanTitleEn = _cleanText(widget.title);
    final cleanDescEn = _cleanText(widget.description);

    final cacheKey = (widget.newsId != null && widget.newsId!.trim().isNotEmpty)
        ? widget.newsId!.trim()
        : cleanTitleEn;

    final cleanTitleUr = widget.titleUr != null ? _cleanText(widget.titleUr!) : '';
    final cleanDescUr = widget.descriptionUr != null ? _cleanText(widget.descriptionUr!) : '';

    // 1. Check if pre-translated Urdu title provided
    if (cleanTitleUr.isNotEmpty &&
        TranslationService.isTextInLanguage(cleanTitleUr, 'ur')) {
      _urduTitle = cleanTitleUr;
      UrduNewsContent.globalUrduCache['t_$cacheKey'] = _urduTitle!;
    } else if (TranslationService.isTextInLanguage(cleanTitleEn, 'ur')) {
      _urduTitle = cleanTitleEn;
      UrduNewsContent.globalUrduCache['t_$cacheKey'] = _urduTitle!;
    } else if (UrduNewsContent.globalUrduCache.containsKey('t_$cacheKey')) {
      _urduTitle = _cleanText(UrduNewsContent.globalUrduCache['t_$cacheKey'] ?? '');
    } else {
      _urduTitle = null;
    }

    // 2. Check description
    if (cleanDescUr.isNotEmpty &&
        TranslationService.isTextInLanguage(cleanDescUr, 'ur')) {
      _urduDescription = cleanDescUr;
      UrduNewsContent.globalUrduCache['d_$cacheKey'] = _urduDescription!;
    } else if (TranslationService.isTextInLanguage(cleanDescEn, 'ur')) {
      _urduDescription = cleanDescEn;
      UrduNewsContent.globalUrduCache['d_$cacheKey'] = _urduDescription!;
    } else if (UrduNewsContent.globalUrduCache.containsKey('d_$cacheKey')) {
      final cachedD = _cleanText(UrduNewsContent.globalUrduCache['d_$cacheKey'] ?? '');
      _urduDescription = cachedD.isNotEmpty ? cachedD : null;
    } else {
      _urduDescription = null;
    }

    // If both are resolved, return
    if (_urduTitle != null && (_urduDescription != null || cleanDescEn.isEmpty)) {
      return;
    }

    // 3. Otherwise translate asynchronously in background
    _isTranslating = true;
    final titleToTranslate = cleanTitleEn;

    // Prepare a clean snippet of description for the feed card
    String descSnippet = cleanDescEn;
    if (descSnippet.length > 350) {
      descSnippet = '${descSnippet.substring(0, 350)}...';
    }

    Future.wait([
      if (_urduTitle == null && titleToTranslate.isNotEmpty)
        TranslationService.translateSingle(titleToTranslate, 'ur').then((res) {
          final cleanedRes = _cleanText(res);
          if (cleanedRes.isNotEmpty && TranslationService.isTextInLanguage(cleanedRes, 'ur')) {
            UrduNewsContent.globalUrduCache['t_$cacheKey'] = cleanedRes;
            if (mounted && ((widget.newsId?.trim() ?? _cleanText(widget.title)) == cacheKey)) {
              setState(() => _urduTitle = cleanedRes);
            }
          }
        }),
      if (_urduDescription == null && descSnippet.isNotEmpty)
        TranslationService.translateSingle(descSnippet, 'ur').then((res) {
          final cleanedRes = _cleanText(res);
          if (cleanedRes.isNotEmpty && TranslationService.isTextInLanguage(cleanedRes, 'ur')) {
            UrduNewsContent.globalUrduCache['d_$cacheKey'] = cleanedRes;
            if (mounted && ((widget.newsId?.trim() ?? _cleanText(widget.title)) == cacheKey)) {
              setState(() => _urduDescription = cleanedRes);
            }
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

  void _toggleLanguage() {
    setState(() {
      _showUrdu = !_showUrdu;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = ThemeService.textPrimary;
    final textSecondary = ThemeService.textSecondary;
    final accentGreen = const Color(0xFF00FF88);

    // Current displayed title & description
    final bool displayUrdu = _showUrdu && _urduTitle != null && _urduTitle!.isNotEmpty;
    final currentTitle = displayUrdu ? _urduTitle! : _cleanText(widget.title);

    String currentDesc = '';
    if (displayUrdu && _urduDescription != null && _urduDescription!.isNotEmpty) {
      currentDesc = _urduDescription!;
    } else {
      currentDesc = _cleanText(widget.description);
    }

    // If description starts with the exact title, strip the leading duplicate title
    if (currentDesc.trim().toLowerCase().startsWith(currentTitle.trim().toLowerCase()) &&
        currentDesc.trim().length > currentTitle.trim().length + 10) {
      currentDesc = currentDesc.trim().substring(currentTitle.trim().length).replaceFirst(RegExp(r'^[\s\.\:\-\|]+'), '').trim();
    }

    // If description is identical to title, omit duplicate text rather than injecting a generic template
    final normTitle = currentTitle.replaceAll(RegExp(r'[\s\-_\|\.\u00a0]+'), '').trim().toLowerCase();
    final normDesc = currentDesc.replaceAll(RegExp(r'[\s\-_\|\.\u00a0]+'), '').trim().toLowerCase();
    if (normDesc.isEmpty || normTitle == normDesc) {
      currentDesc = '';
    }

    final isUrduScript = TranslationService.isTextInLanguage(currentTitle, 'ur');

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: isUrduScript ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Urdu Language Indicator & Quick Toggle
            Row(
              mainAxisAlignment: isUrduScript ? MainAxisAlignment.spaceBetween : MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: displayUrdu ? accentGreen.withOpacity(0.15) : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: displayUrdu ? accentGreen.withOpacity(0.4) : Colors.white24,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        size: 11,
                        color: displayUrdu ? accentGreen : textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        displayUrdu ? 'اردو خبریں' : 'ENGLISH',
                        style: TextStyle(
                          color: displayUrdu ? accentGreen : textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle Button
                InkWell(
                  onTap: _toggleLanguage,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _showUrdu ? 'English میں دیکھیں' : 'اردو میں پڑھیں',
                          style: TextStyle(
                            color: accentGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 14,
                          color: accentGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Headline Title
            Text(
              currentTitle,
              textDirection: isUrduScript ? TextDirection.rtl : TextDirection.ltr,
              textAlign: isUrduScript ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontSize: isUrduScript ? 17 : 16,
                fontWeight: FontWeight.w900,
                color: textPrimary,
                height: isUrduScript ? 1.45 : 1.3,
                letterSpacing: isUrduScript ? 0 : -0.2,
              ),
            ),

            // Description Snippet
            if (currentDesc.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                currentDesc,
                maxLines: widget.maxDescriptionLines,
                overflow: TextOverflow.ellipsis,
                textDirection: isUrduScript ? TextDirection.rtl : TextDirection.ltr,
                textAlign: isUrduScript ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  fontSize: isUrduScript ? 14.5 : 14,
                  color: textPrimary.withOpacity(0.9),
                  height: isUrduScript ? 1.6 : 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
