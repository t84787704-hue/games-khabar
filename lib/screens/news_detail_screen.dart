import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
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

String? extractYoutubeId(String? url) {
  if (url == null) return null;
  final cleanUrl = url.trim();
  if (cleanUrl.isEmpty) return null;
  if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanUrl)) return cleanUrl;
  final reg = RegExp(r'(?:v=|\/embed\/|\/shorts\/|youtu\.be\/)([a-zA-Z0-9_-]{11})');
  return reg.firstMatch(cleanUrl)?.group(1);
}
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
    setState(() {
      _translatedTitle = baseTitle;
      _translatedDescription = descOk ? baseDesc : null;
      _isTranslating = true;
    });
    try {
      final titleSrc = widget.news.titleMap['en']?.isNotEmpty == true ? widget.news.titleMap['en']! : baseTitle;
      final descSrc = widget.news.descriptionMap['en']?.isNotEmpty == true ? widget.news.descriptionMap['en']! : baseDesc;
      final cleanTitleSrc = TranslationService.cleanBbCodeAndHtml(titleSrc);
      final cleanDescSrc = TranslationService.cleanBbCodeAndHtml(descSrc);
      final tFuture = titleOk ? Future.value(baseTitle) : TranslationService.translateSingle(cleanTitleSrc, langCode);
      final dFuture = descOk ? Future.value(baseDesc) : TranslationService.translateArticle(cleanDescSrc, langCode);
      final results = await Future.wait([tFuture, dFuture]);
      if (mounted && _currentLoadedLang == langCode) {
        setState(() {
          _translatedTitle = results[0].isNotEmpty ? results[0] : baseTitle;
          _translatedDescription = results[1].isNotEmpty ? results[1] : baseDesc;
          _isTranslating = false;
        });
        if (widget.news.id.isNotEmpty && !widget.news.id.startsWith('local-')) {
          FirestoreService().updateNewsTranslation(widget.news.id, langCode, _translatedTitle ?? baseTitle, _translatedDescription ?? baseDesc);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _translatedDescription ??= baseDesc;
          _isTranslating = false;
        });
      }
    }
  }

  void _initVideoPlayer() {
    final rawVideoUrl = widget.news.videoUrl;
    final String? candidateUrl = (rawVideoUrl != null && rawVideoUrl.trim().isNotEmpty) ? rawVideoUrl.trim() : (widget.news.youtubeId?.isNotEmpty == true ? 'https://www.youtube.com/watch?v=${widget.news.youtubeId}' : null);
    final extracted = extractYoutubeId(candidateUrl);
    if (extracted != null && extracted.isNotEmpty) {
      youtubeId = extracted;
      _youtubeController = YoutubePlayerController.fromVideoId(videoId: youtubeId!, autoPlay: false, params: const YoutubePlayerParams(showFullscreenButton: true, mute: false, showControls: true));
    }
  }

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
  }

  String _cleanContentText(String text) {
    String cleaned = TranslationService.cleanBbCodeAndHtml(text);
    // Bahar ke links hata do - full content app me hi dikhana hai
    cleaned = cleaned.replaceAll(RegExp(r'https?:\/\/[^\s]+'), '').replaceAll(RegExp(r'www\.[^\s]+'), '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (youtubeId != null) {
      cleaned = cleaned.replaceAll(RegExp(r'https?:\/\/(?:www\.)?(?:youtube\.com\/[^\s]+|youtu\.be\/[^\s]+)'), '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    }
    return cleaned.trim();
  }

  void _shareArticle(BuildContext context) async {
    const String packageName = 'com.gameskhabar.games_khabar';
    final String playStoreUrl = 'https://play.google.com/store/apps/details?id=$packageName';
    final langCode = context.locale.languageCode;
    final displayTitle = _translatedTitle ?? widget.news.getTitle(langCode);
    final displayDescription = _translatedDescription ?? widget.news.getDescription(langCode);
    final String shareMessage = '🔥 $displayTitle\n\n$displayDescription\n\n🎮 Read more on Games Khabar App 👇\n📲 Download Now: $playStoreUrl';
    try {
      await Share.share(shareMessage, subject: '🎮 $displayTitle - Games Khabar');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareMessage));
    }
  }

  void _toggleBookmark(BuildContext context) async {
    final isSaved = await BookmarkService().toggleBookmark(widget.news);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: cardDark, content: Text(isSaved ? 'Saved to Bookmarks! 🔖' : 'Removed from Bookmarks', style: const TextStyle(color: textWhite))));
    }
  }

  List<NewsModel> _getRelatedNews(List<NewsModel> allNews, String langCode) {
    final otherNews = allNews.where((n) => n.id != widget.news.id).toList();
    return otherNews.where((n) => n.category.trim().toLowerCase() == widget.news.category.trim().toLowerCase()).take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final isRtl = LanguageService.isRtlLocale(context.locale);
    final displayTitle = _translatedTitle ?? TranslationService.cleanBbCodeAndHtml(widget.news.getTitle(langCode));
    final rawDescription = _translatedDescription ?? TranslationService.cleanBbCodeAndHtml(widget.news.getDescription(langCode));
    final displayDescription = _cleanContentText(rawDescription);
    final hasVideo = youtubeId != null || (widget.news.videoUrl != null && widget.news.videoUrl!.isNotEmpty);
    final paragraphs = displayDescription.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final firstParagraph = paragraphs.isNotEmpty ? paragraphs.first : displayDescription;
    final remainingParagraphs = paragraphs.length > 1 ? paragraphs.sublist(1) : <String>[];

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textWhite, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text(widget.news.category.isNotEmpty ? widget.news.category : 'Gaming Khabar', style: const TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.language_rounded, color: textWhite, size: 22), onPressed: () => LanguageService.showLanguageBottomSheet(context)),
          ValueListenableBuilder<Set<String>>(valueListenable: BookmarkService.bookmarkedIdsNotifier, builder: (context, ids, _) {
            final isSaved = ids.contains(widget.news.id);
            return IconButton(icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: isSaved ? neonGreen : textWhite, size: 22), onPressed: () => _toggleBookmark(context));
          }),
          IconButton(icon: const Icon(Icons.share_outlined, color: neonGreen, size: 22), onPressed: () => _shareArticle(context)),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).padding.bottom + 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: neonGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: neonGreen, width: 1)), child: Text(widget.news.category.toUpperCase(), style: const TextStyle(color: neonGreen, fontSize: 11, fontWeight: FontWeight.w900))),
                const SizedBox(width: 10),
                const Icon(Icons.access_time_rounded, color: textGray, size: 14),
                const SizedBox(width: 4),
                Text(widget.news.timeAgo, style: const TextStyle(color: textGray, fontSize: 12)),
                const Spacer(),
                const Icon(Icons.visibility_outlined, color: textGray, size: 14),
                const SizedBox(width: 4),
                Text('${widget.news.views} views', style: const TextStyle(color: textGray, fontSize: 12)),
              ]),
              const SizedBox(height: 14),
              Text(displayTitle, textAlign: isRtl ? TextAlign.right : TextAlign.left, textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr, style: const TextStyle(color: textWhite, fontSize: 22, fontWeight: FontWeight.w900, height: 1.3)),
              const SizedBox(height: 12),
              Container(height: 3, width: 44, decoration: BoxDecoration(color: neonGreen, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              if (_youtubeController != null) ...[
                ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(height: 220, width: double.infinity, child: YoutubePlayer(controller: _youtubeController!, aspectRatio: 16 / 9))),
                const SizedBox(height: 16),
              ] else ...[
                ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: 16 / 9, child: AppImageView(imageUrl: widget.news.imageUrl, fit: BoxFit.cover))),
                const SizedBox(height: 16),
              ],
              if (firstParagraph.isNotEmpty) ...[
                Text(firstParagraph, textAlign: isRtl ? TextAlign.right : TextAlign.left, textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr, style: const TextStyle(color: textLightGray, fontSize: 15, height: 1.7, letterSpacing: 0.2)),
                const SizedBox(height: 14),
              ],
              ValueListenableBuilder<DateTime?>(valueListenable: AdFreeService.adFreeUntilNotifier, builder: (context, _, __) {
                if (AdFreeService().isAdFree) return const SizedBox.shrink();
                return Container(margin: const EdgeInsets.only(top: 10, bottom: 18), child: const NativeAdWidget(margin: EdgeInsets.zero));
              }),
              ...remainingParagraphs.map((para) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(para, textAlign: isRtl ? TextAlign.right : TextAlign.left, textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr, style: const TextStyle(color: textLightGray, fontSize: 15, height: 1.7)))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: neonGreen, foregroundColor: const Color(0xFF05080D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _shareArticle(context), icon: const Icon(Icons.share_rounded, size: 18), label: const Text('Share Article', style: TextStyle(fontWeight: FontWeight.w900)))),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}