import 'package:flutter/material.dart';
import '../services/translation_service.dart';
import '../services/theme_service.dart';

class UrduNewsContent extends StatefulWidget {
  final String title;
  final String description;
  final String? titleUr;
  final String? descriptionUr;
  final VoidCallback? onTap;
  final int maxDescriptionLines;

  const UrduNewsContent({
    super.key,
    required this.title,
    required this.description,
    this.titleUr,
    this.descriptionUr,
    this.onTap,
    this.maxDescriptionLines = 3,
  });

  @override
  State<UrduNewsContent> createState() => _UrduNewsContentState();
}

class _UrduNewsContentState extends State<UrduNewsContent> {
  static final Map<String, String> _globalUrduCache = {};

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
    if (oldWidget.title != widget.title || oldWidget.description != widget.description) {
      _resolveTranslations();
    }
  }

  void _resolveTranslations() {
    // 1. Check if pre-translated Urdu title provided
    if (widget.titleUr != null &&
        widget.titleUr!.trim().isNotEmpty &&
        TranslationService.isTextInLanguage(widget.titleUr!, 'ur')) {
      _urduTitle = widget.titleUr;
    } else if (TranslationService.isTextInLanguage(widget.title, 'ur')) {
      _urduTitle = widget.title;
    } else if (_globalUrduCache.containsKey('t_${widget.title}')) {
      _urduTitle = _globalUrduCache['t_${widget.title}'];
    }

    // 2. Check description
    if (widget.descriptionUr != null &&
        widget.descriptionUr!.trim().isNotEmpty &&
        TranslationService.isTextInLanguage(widget.descriptionUr!, 'ur')) {
      _urduDescription = widget.descriptionUr;
    } else if (TranslationService.isTextInLanguage(widget.description, 'ur')) {
      _urduDescription = widget.description;
    } else if (_globalUrduCache.containsKey('d_${widget.description}')) {
      _urduDescription = _globalUrduCache['d_${widget.description}'];
    }

    // If both are resolved, return
    if (_urduTitle != null && _urduDescription != null) {
      return;
    }

    // 3. Otherwise translate asynchronously in background
    _isTranslating = true;
    final titleToTranslate = widget.title.trim();

    // Prepare a clean snippet of description for the feed card
    String descSnippet = widget.description.trim();
    if (descSnippet.length > 300) {
      descSnippet = '${descSnippet.substring(0, 300)}...';
    }

    Future.wait([
      if (_urduTitle == null && titleToTranslate.isNotEmpty)
        TranslationService.translateSingle(titleToTranslate, 'ur').then((res) {
          if (res.isNotEmpty && TranslationService.isTextInLanguage(res, 'ur')) {
            _globalUrduCache['t_$titleToTranslate'] = res;
            _urduTitle = res;
          }
        }),
      if (_urduDescription == null && descSnippet.isNotEmpty)
        TranslationService.translateSingle(descSnippet, 'ur').then((res) {
          if (res.isNotEmpty && TranslationService.isTextInLanguage(res, 'ur')) {
            _globalUrduCache['d_${widget.description}'] = res;
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
    final currentTitle = displayUrdu ? _urduTitle! : widget.title;

    String currentDesc = '';
    if (displayUrdu && _urduDescription != null && _urduDescription!.isNotEmpty) {
      currentDesc = _urduDescription!;
    } else {
      currentDesc = widget.description;
    }

    // Clean up if description repeats title or is almost identical
    final normTitle = currentTitle.replaceAll(RegExp(r'[\s\-_\|\.\u00a0]+'), '').trim().toLowerCase();
    final normDesc = currentDesc.replaceAll(RegExp(r'[\s\-_\|\.\u00a0]+'), '').trim().toLowerCase();
    final bool isRepeated = normTitle == normDesc ||
        normDesc.startsWith(normTitle.substring(0, (normTitle.length * 0.6).toInt().clamp(1, normTitle.length))) ||
        (normTitle.length > 20 && normDesc.contains(normTitle.substring(0, 20)));

    if (isRepeated || currentDesc.trim().length < 160) {
      currentDesc = displayUrdu
          ? 'اس گیم کی تازہ ترین آفیشل اپ ڈیٹ، گیم پلے میں تبدیلیاں، اور تمام نئی تفصیلات جانیے۔ مکمل تفصیلات کے لیے نیچے \'Read Full Story\' پر کلک کریں۔'
          : 'Check out the latest official game patch notes, gameplay balance updates, and upcoming features. Tap \'Read Full Story\' below for full coverage.';
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
