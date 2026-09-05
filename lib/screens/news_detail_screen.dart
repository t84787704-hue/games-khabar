import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'dart:ui' as ui;
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_model.dart';
import '../services/bookmark_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../services/streak_service.dart';
import '../services/coin_reward_service.dart';
import '../widgets/app_image_view.dart';
import '../widgets/translated_news_title.dart';
import '../widgets/price_graph_widget.dart';
import '../widgets/game_countdown_widget.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsModel news;
  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  bool _isExpanded = false;
  final BookmarkService _bookmarkService = BookmarkService();

  @override
  void initState() {
    super.initState();
    // Daily task: reading articles contributes to streak
    StreakService().recordArticleRead(widget.news.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CoinRewardService().onNewsRead(context);
    });
  }

  Color get bgDark => ThemeService.bg;
  Color get cardDark => ThemeService.card;
  Color get borderDark => ThemeService.border;
  Color get neonGreen => ThemeService.primaryGreen;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;

  String _getTitleSafe(String langCode) {
    String t = widget.news.getTitle(langCode);
    if (t.trim().isEmpty) t = widget.news.getTitle('en');
    if (t.trim().isEmpty) t = widget.news.title;
    return t;
  }

  String _cleanHtml(String text) {
    if (text.isEmpty) return text;
    String t = text;
    // Strip BBCode tags like [p], [/p], [b], [url], {STEAM_CLAN_IMAGE}
    t = t.replaceAll(RegExp(r'\[\/?p\]', caseSensitive: false), '\n\n');
    t = t.replaceAll(RegExp(r'\[img[^\]]*\][\s\S]*?\[\/img\]', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\{STEAM_CLAN_IMAGE\}[^\s"<>]+', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\[url=[^\]]+\][\s\S]*?\[\/url\]', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\[\/?(b|i|u|h[1-6]|strong|em|url|strike|sub|sup)[^\]]*\]', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\[[^\]]+\]'), ' ');
    t = t.replaceAll(RegExp(r'<[^>]*>'), ' ');
    t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t.trim();
  }

  String _fixLinks(String text) {
    if (text.isEmpty) return text;
    String cleaned = text;

    // 1. Replace duplicate schemes like 'https:// https://' or regex 'https:\s*//\s*https:\s*//' -> 'https://'
    cleaned = cleaned.replaceAll(RegExp(r'(?:https?:\s*//\s*)+https?:\s*//', caseSensitive: false), 'https://');

    // 2. Replace 'https:// ' and 'http:// ' spaces after scheme -> 'https://'
    cleaned = cleaned.replaceAll(RegExp(r'(https?://)\s+', caseSensitive: false), r'$1');

    // 3. Fix spaces before domain or in domain: 'https:// www.ea.com' -> 'https://www.ea.com'
    cleaned = cleaned.replaceAll(RegExp(r'https?://\s+', caseSensitive: false), 'https://');

    // 4. Fix double slash before ID: '/app//2488620' -> '/app/2488620' (while keeping 'https://')
    cleaned = cleaned.replaceAllMapped(RegExp(r'(https?://[^\s]+)', caseSensitive: false), (match) {
      final fullUrl = match.group(1)!;
      final parts = fullUrl.split('://');
      if (parts.length == 2) {
        final scheme = parts[0];
        final path = parts[1].replaceAll(RegExp(r'/+'), '/');
        return '$scheme://$path';
      }
      return fullUrl;
    });

    return cleaned;
  }

  String _getDescSafe(String langCode) {
    String d = widget.news.getDescription(langCode);
    if (d.trim().isEmpty) d = widget.news.getDescription('en');
    if (d.trim().isEmpty) d = widget.news.description;
    return _fixLinks(_cleanHtml(d));
  }

  String _getReadMoreText(String langCode) {
    if (langCode == 'ur') return 'مزید پڑھیں';
    if (langCode == 'ro') return 'Citește mai mult';
    return 'Read more';
  }

  String _getShowLessText(String langCode) {
    if (langCode == 'ur') return 'کم دکھائیں';
    if (langCode == 'ro') return 'Arată mai puțin';
    return 'Show less';
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final isRtl = LanguageService.isRtlLocale(context.locale);
    final titleSafe = _getTitleSafe(langCode);
    final descSafe = _getDescSafe(langCode);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.news.category,
          style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: neonGreen, size: 20),
            onPressed: () {},
          ),
          ValueListenableBuilder(
            valueListenable: BookmarkService.bookmarksListNotifier,
            builder: (context, List<NewsModel> list, _) {
              final isSaved = list.any((e) => e.id == widget.news.id);
              return IconButton(
                icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: neonGreen, size: 20),
                onPressed: () => _bookmarkService.toggleBookmark(widget.news),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.translate_rounded, color: textGray, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('views ${widget.news.views} ', style: TextStyle(color: textGray, fontSize: 12)),
                  Icon(Icons.remove_red_eye_outlined, color: textGray, size: 14),
                  const Spacer(),
                  Text(widget.news.timeAgo, style: TextStyle(color: textGray, fontSize: 12)),
                  const SizedBox(width: 4),
                  Icon(Icons.access_time, color: textGray, size: 14),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: neonGreen, width: 1),
                        borderRadius: BorderRadius.circular(6),
                        color: neonGreen.withOpacity(0.1),
                      ),
                      child: Text(
                        (widget.news.gameName != null && widget.news.gameName!.trim().isNotEmpty
                                ? widget.news.gameName!
                                : widget.news.category)
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: neonGreen, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                titleSafe,
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                style: TextStyle(color: textWhite, fontSize: 22, fontWeight: FontWeight.w900, height: 1.4),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: borderDark)),
              child: AppImageView(imageUrl: widget.news.imageUrl, fit: BoxFit.cover),
            ),
            // Live Countdown Module (if upcoming game with release date)
            if (widget.news.effectiveReleaseDate != null)
              GameCountdownWidget(
                targetDate: widget.news.effectiveReleaseDate!,
                gameName: widget.news.gameName ?? widget.news.category,
                subtitle: widget.news.category,
              ),
            // Price Tracker Module (Price Graph + Set Alert button)
            PriceGraphWidget(news: widget.news),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Linkify(
                    onOpen: (link) async {
                      final uri = Uri.tryParse(link.url);
                      if (uri != null) {
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {
                          await launchUrl(uri);
                        }
                      }
                    },
                    text: _isExpanded
                        ? descSafe
                        : descSafe.length > 400
                            ? '${descSafe.substring(0, 400)}...'
                            : descSafe,
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                    style: TextStyle(color: textWhite, fontSize: 14, height: 1.8),
                    linkStyle: TextStyle(
                      color: neonGreen,
                      fontSize: 14,
                      height: 1.8,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (descSafe.length > 400)
                    Align(
                      alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Text(
                            _isExpanded ? _getShowLessText(langCode) : _getReadMoreText(langCode),
                            style: TextStyle(color: neonGreen, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}