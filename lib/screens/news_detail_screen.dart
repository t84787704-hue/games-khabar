import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../models/news_model.dart';
import '../widgets/app_image_view.dart';
import '../widgets/native_ad_widget.dart';
import '../services/bookmark_service.dart';
import '../services/firestore_service.dart';
import '../services/ad_free_service.dart';
import '../services/translation_service.dart';
import '../services/language_service.dart';

/// Robust YouTube ID extractor matching standard, embed, shorts, and youtu.be URLs
String? extractYoutubeId(String? url) {
  if (url == null) return null;
  final cleanUrl = url.trim();
  if (cleanUrl.isEmpty) return null;
  if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanUrl)) {
    return cleanUrl;
  }
  final reg = RegExp(r'(?:v=|\/embed\/|\/shorts\/|youtu\.be\/)([a-zA-Z0-9_-]{11})');
  return reg.firstMatch(cleanUrl)?.group(1);
}

/// Backward compatibility alias
String? getYoutubeId(String? url) => extractYoutubeId(url);

class NewsDetailScreen extends StatefulWidget {
  final NewsModel news;

  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  String? youtubeId;
  String? get videoId => youtubeId;
  YoutubePlayerController? _youtubeController;
  bool _hasVideoError = false;

  String? _translatedTitle;
  String? _translatedDescription;
  bool _isTranslating = false;
  String? _currentLoadedLang;

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color scaffoldBg = Color(0xFF121318);
  static const Color cardDark = Color(0xFF1E1F28);
  static const Color borderDark = Color(0xFF2E303E);
  static const Color alertRed = Color(0xFFFF3344);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);
  static const Color textLightGray = Color(0xFFD4D4D8);

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final langCode = context.locale.languageCode;
    if (_currentLoadedLang != langCode) {
      _currentLoadedLang = langCode;
      _triggerTranslationIfNeeded(langCode);
    }
  }

  Future<void> _triggerTranslationIfNeeded(String langCode) async {
    final baseTitle = TranslationService.cleanBbCodeAndHtml(widget.news.getTitle(langCode));
    final baseDesc = TranslationService.cleanBbCodeAndHtml(widget.news.getDescription(langCode));

    final isTargetLatin = (langCode == 'en' || langCode == 'ro' || langCode == 'roman');
    final titleOk = isTargetLatin || TranslationService.isTextInLanguage(baseTitle, langCode);
    final descOk = isTargetLatin || TranslationService.isTextInLanguage(baseDesc, langCode);

    if (titleOk && descOk) {
      setState(() {
        _translatedTitle = baseTitle;
        _translatedDescription = baseDesc;
        _isTranslating = false;
      });
      return;
    }

    // Set fallback immediately while translating
    setState(() {
      _translatedTitle = baseTitle;
      _translatedDescription = baseDesc;
      _isTranslating = true;
    });

    try {
      final titleSrc = widget.news.titleMap['en'] ?? baseTitle;
      final descSrc = widget.news.descriptionMap['en'] ?? baseDesc;

      final tFuture = titleOk
          ? Future.value(baseTitle)
          : TranslationService.translateSingle(titleSrc, langCode);

      final dFuture = descOk
          ? Future.value(baseDesc)
          : TranslationService.translateArticle(descSrc, langCode);

      final results = await Future.wait([tFuture, dFuture]);
      final newTitle = results[0];
      final newDesc = results[1];

      if (mounted && _currentLoadedLang == langCode) {
        setState(() {
          if (newTitle.isNotEmpty && (isTargetLatin || TranslationService.isTextInLanguage(newTitle, langCode))) {
            _translatedTitle = newTitle;
            widget.news.titleMap[langCode] = newTitle;
          }
          if (newDesc.isNotEmpty && (isTargetLatin || TranslationService.isTextInLanguage(newDesc, langCode))) {
            _translatedDescription = newDesc;
            widget.news.descriptionMap[langCode] = newDesc;
          }
          _isTranslating = false;
        });

        // Persist to Firestore in background
        if (widget.news.id.isNotEmpty && !widget.news.id.startsWith('local-')) {
          FirestoreService().updateNewsTranslation(
            widget.news.id,
            langCode,
            _translatedTitle ?? baseTitle,
            _translatedDescription ?? baseDesc,
          );
        }
      }
    } catch (_) {
      if (mounted && _currentLoadedLang == langCode) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  void _initVideoPlayer() {
    final rawVideoUrl = widget.news.videoUrl;
    final String? candidateUrl = (rawVideoUrl != null && rawVideoUrl.trim().isNotEmpty)
        ? rawVideoUrl.trim()
        : (widget.news.youtubeId?.isNotEmpty == true
            ? 'https://www.youtube.com/watch?v=${widget.news.youtubeId}'
            : widget.news.sourceUrl);

    final bool videoDeclared = (rawVideoUrl != null && rawVideoUrl.trim().isNotEmpty) ||
        (widget.news.youtubeId != null && widget.news.youtubeId!.trim().isNotEmpty);

    final extracted = extractYoutubeId(candidateUrl);

    if (videoDeclared && (extracted == null || extracted.isEmpty)) {
      _hasVideoError = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: alertRed,
              content: Text('Invalid video URL', style: TextStyle(color: textWhite)),
            ),
          );
        }
      });
    } else if (extracted != null && extracted.isNotEmpty) {
      youtubeId = extracted;
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: youtubeId!,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          mute: false,
          showControls: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
  }

  String? _extractSourceUrl(String text) {
    if (widget.news.sourceUrl != null && widget.news.sourceUrl!.trim().isNotEmpty) {
      final sUrl = widget.news.sourceUrl!.trim();
      if (getYoutubeId(sUrl) == null) {
        return sUrl;
      }
    }
    final urlRegExp = RegExp(
      r'((https?:\/\/)|(www\.))[^\s]+',
      caseSensitive: false,
    );
    final match = urlRegExp.firstMatch(text);
    if (match != null) {
      String url = match.group(0)!;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      if (getYoutubeId(url) == null) {
        return url;
      }
    }
    return null;
  }

  String _cleanContentText(String text) {
    String cleaned = TranslationService.cleanBbCodeAndHtml(text);
    if (youtubeId != null) {
      cleaned = cleaned
          .replaceAll(
            RegExp(r'https?:\/\/(?:www\.)?(?:youtube\.com\/[^\s]+|youtu\.be\/[^\s]+)'),
            '',
          )
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    }
    return cleaned.trim();
  }

  Future<void> _launchExternalUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: cardDark,
            content: Text('Could not open link', style: TextStyle(color: neonGreen)),
          ),
        );
      }
    }
  }

  void _shareArticle(BuildContext context) async {
    const String packageName = 'com.gameskhabar.games_khabar';
    final String playStoreUrl =
        'https://play.google.com/store/apps/details?id=$packageName';

    final langCode = context.locale.languageCode;
    final displayTitle = _translatedTitle ??
        TranslationService.cleanBbCodeAndHtml(widget.news.getTitle(langCode));
    final displayDescription = _translatedDescription ??
        TranslationService.cleanBbCodeAndHtml(widget.news.getDescription(langCode));

    final String shareMessage =
        '🔥 $displayTitle\n\n'
        '$displayDescription\n\n'
        '🎮 Read more on Games Khabar App 👇\n'
        '📲 Download Now: $playStoreUrl';

    try {
      await Share.share(
        shareMessage,
        subject: '🎮 $displayTitle - Games Khabar',
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareMessage));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: neonGreen, width: 1),
            ),
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: neonGreen, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Article link copied to clipboard!',
                    style: TextStyle(
                      color: textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  void _toggleBookmark(BuildContext context) async {
    final isSaved = await BookmarkService().toggleBookmark(widget.news);
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cardDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isSaved ? neonGreen : borderDark, width: 1.2),
          ),
          content: Row(
            children: [
              Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: isSaved ? neonGreen : textGray,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSaved
                      ? 'Saved to Bookmarks! 🔖'
                      : 'Removed from Bookmarks',
                  style: const TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  List<NewsModel> _getRelatedNews(List<NewsModel> allNews, String langCode) {
    final otherNews = allNews.where((n) => n.id != widget.news.id).toList();
    final List<NewsModel> related = otherNews
        .where((n) => n.category.trim().toLowerCase() == widget.news.category.trim().toLowerCase())
        .take(4)
        .toList();

    if (related.length < 2) {
      final currentTitle = widget.news.getTitle(langCode);
      final words = currentTitle
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 3)
          .toSet();

      final relatedIds = related.map((e) => e.id).toSet();

      for (final item in otherNews) {
        if (related.length >= 4) break;
        if (relatedIds.contains(item.id)) continue;

        final itemTitleLower = item.getTitle(langCode).toLowerCase();
        final hasKeyword = words.any((w) => itemTitleLower.contains(w));
        if (hasKeyword) {
          related.add(item);
          relatedIds.add(item.id);
        }
      }
    }

    return related;
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final isRtl = LanguageService.isRtlLocale(context.locale);
    final displayTitle = _translatedTitle ??
        TranslationService.cleanBbCodeAndHtml(widget.news.getTitle(langCode));
    final rawDescription = _translatedDescription ??
        TranslationService.cleanBbCodeAndHtml(widget.news.getDescription(langCode));
    final displayDescription = _cleanContentText(rawDescription);
    final directUrl = _extractSourceUrl(rawDescription);
    final hasVideo = youtubeId != null || (widget.news.videoUrl != null && widget.news.videoUrl!.isNotEmpty);

    final paragraphs = displayDescription
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final firstParagraph = paragraphs.isNotEmpty ? paragraphs.first : displayDescription;
    final remainingParagraphs = paragraphs.length > 1 ? paragraphs.sublist(1) : <String>[];

    return Scaffold(
        backgroundColor: scaffoldBg,
        extendBody: false,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: cardDark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textWhite, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.news.category.isNotEmpty ? widget.news.category : 'Gaming Khabar',
            style: const TextStyle(
              color: textWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: false,
          actions: [
            // Language Switcher Button
            IconButton(
              icon: const Icon(Icons.language_rounded, color: textWhite, size: 22),
              tooltip: 'Change Language',
              onPressed: () => LanguageService.showLanguageBottomSheet(context),
            ),
            // Bookmark Icon Button
            ValueListenableBuilder<Set<String>>(
              valueListenable: BookmarkService.bookmarkedIdsNotifier,
              builder: (context, bookmarkedIds, _) {
                final isSaved = bookmarkedIds.contains(widget.news.id);
                return IconButton(
                  icon: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isSaved ? neonGreen : textWhite,
                    size: 22,
                  ),
                  tooltip: 'Bookmark',
                  onPressed: () => _toggleBookmark(context),
                );
              },
            ),
            // Share Icon Button
            IconButton(
              icon: const Icon(Icons.share_outlined, color: neonGreen, size: 22),
              tooltip: 'Share',
              onPressed: () => _shareArticle(context),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Metadata Bar (Category Badge, Video Tag, Time, Views)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: neonGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: neonGreen, width: 1),
                      ),
                      child: Text(
                        widget.news.category.toUpperCase(),
                        style: const TextStyle(
                          color: neonGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (hasVideo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: alertRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: alertRed, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: alertRed, size: 14),
                            SizedBox(width: 2),
                            Text(
                              'VIDEO',
                              style: TextStyle(
                                color: alertRed,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    const Icon(Icons.access_time_rounded, color: textGray, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      widget.news.timeAgo,
                      style: const TextStyle(
                        color: textGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.visibility_outlined, color: textGray, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.news.views} views',
                      style: const TextStyle(color: textGray, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. News Title
                Text(
                  displayTitle,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  style: const TextStyle(
                    color: textWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Accent Divider & Translation Status
                Row(
                  children: [
                    Container(
                      height: 3,
                      width: 44,
                      decoration: BoxDecoration(
                        color: neonGreen,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isTranslating)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: neonGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: neonGreen.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: neonGreen,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Translating (${LanguageService.getLanguageModel(langCode).nativeName})...',
                              style: const TextStyle(
                                color: neonGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (langCode != 'en' && langCode != 'ro' && langCode != 'roman')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderDark, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.translate_rounded, color: neonGreen, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              LanguageService.getLanguageModel(langCode).nativeName,
                              style: const TextStyle(
                                color: textLightGray,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Video / Media Area
                if (_youtubeController != null || _hasVideoError) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: _hasVideoError
                          ? Container(
                              color: cardDark,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.error_outline_rounded, color: alertRed, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'Invalid video URL',
                                      style: TextStyle(
                                        color: textWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : YoutubePlayer(
                              controller: _youtubeController!,
                              aspectRatio: 16 / 9,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        final rawUrl = (widget.news.videoUrl != null && widget.news.videoUrl!.trim().isNotEmpty)
                            ? widget.news.videoUrl!.trim()
                            : (youtubeId != null ? 'https://www.youtube.com/watch?v=$youtubeId' : '');
                        if (rawUrl.isNotEmpty) {
                          _launchExternalUrl(context, rawUrl);
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 14, color: textGray),
                      label: const Text(
                        'Watch in YouTube App',
                        style: TextStyle(color: textGray, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AppImageView(
                        imageUrl: widget.news.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Direct Video Link Button (for non-YouTube direct MP4/stream video links only)
                if (widget.news.videoUrl != null && widget.news.videoUrl!.isNotEmpty && youtubeId == null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alertRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _launchExternalUrl(context, widget.news.videoUrl!),
                      icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                      label: const Text(
                        'Watch Video',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 6. News Description - First Paragraph
                if (firstParagraph.isNotEmpty) ...[
                  Text(
                    firstParagraph,
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      color: textLightGray,
                      fontSize: 15,
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 7. Native Ad Inside Scroll Content (After 1st paragraph) - Isolated via StatefulBuilder
                StatefulBuilder(
                  builder: (context, setAdState) {
                    return ValueListenableBuilder<DateTime?>(
                      valueListenable: AdFreeService.adFreeUntilNotifier,
                      builder: (context, adFreeUntil, _) {
                        if (AdFreeService().isAdFree) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(
                            top: 10,
                            bottom: 18,
                          ),
                          child: const NativeAdWidget(
                            margin: EdgeInsets.zero,
                          ),
                        );
                      },
                    );
                  },
                ),

                // 8. Remaining Paragraphs
                if (remainingParagraphs.isNotEmpty) ...[
                  ...remainingParagraphs.map(
                    (para) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        para,
                        textAlign: isRtl ? TextAlign.right : TextAlign.left,
                        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                        style: const TextStyle(
                          color: textLightGray,
                          fontSize: 15,
                          height: 1.6,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

              // 9. Source Article Link (Non-YouTube external source only)
              if (directUrl != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: neonGreen,
                      side: const BorderSide(color: neonGreen, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _launchExternalUrl(context, directUrl),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text(
                      'Read Full Source Article',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 10. Share Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonGreen,
                    foregroundColor: const Color(0xFF05080D),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _shareArticle(context),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'Share Article',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 11. Related News Section
              StreamBuilder<List<NewsModel>>(
                stream: FirestoreService().getNewsStream(),
                initialData: FirestoreService().currentNews,
                builder: (context, snapshot) {
                  final allNews = snapshot.data ?? [];
                  final relatedList = _getRelatedNews(allNews, langCode);

                  if (relatedList.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      const Divider(color: borderDark, thickness: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: neonGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Related News',
                            style: TextStyle(
                              color: textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: relatedList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = relatedList[index];
                          final itemTitle = item.getTitle(langCode);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NewsDetailScreen(news: item),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              splashColor: neonGreen.withOpacity(0.15),
                              highlightColor: neonGreen.withOpacity(0.08),
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: cardDark,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderDark),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                                      child: SizedBox(
                                        width: 110,
                                        height: double.infinity,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            AppImageView(
                                              imageUrl: item.imageUrl,
                                              fit: BoxFit.cover,
                                            ),
                                            if (item.videoUrl != null && item.videoUrl!.isNotEmpty)
                                              Center(
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.65),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: alertRed, width: 1.2),
                                                  ),
                                                  child: const Icon(
                                                    Icons.play_arrow_rounded,
                                                    color: alertRed,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: neonGreen.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: neonGreen.withOpacity(0.5)),
                                                  ),
                                                  child: Text(
                                                    item.category.toUpperCase(),
                                                    style: const TextStyle(
                                                      color: neonGreen,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  item.timeAgo,
                                                  style: const TextStyle(color: textGray, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              itemTitle,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: textWhite,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                height: 1.25,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                const Icon(Icons.visibility_outlined, color: textGray, size: 12),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${item.views} views',
                                                  style: const TextStyle(color: textGray, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
