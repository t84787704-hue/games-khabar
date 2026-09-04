import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'dart:ui' as ui;
import '../models/news_model.dart';
import '../services/bookmark_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../widgets/app_image_view.dart';
import '../widgets/translated_news_title.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsModel news;
  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  bool _isExpanded = false;
  final BookmarkService _bookmarkService = BookmarkService();

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

  String _getDescSafe(String langCode) {
    String d = widget.news.getDescription(langCode);
    if (d.trim().isEmpty) d = widget.news.getDescription('en');
    if (d.trim().isEmpty) d = widget.news.description;
    return d;
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: neonGreen, width: 1),
                      borderRadius: BorderRadius.circular(6),
                      color: neonGreen.withOpacity(0.1),
                    ),
                    child: Text(
                      widget.news.category.toUpperCase(),
                      style: TextStyle(color: neonGreen, fontSize: 11, fontWeight: FontWeight.w900),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    _isExpanded
                        ? descSafe
                        : descSafe.length > 400
                            ? '${descSafe.substring(0, 400)}...'
                            : descSafe,
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                    style: TextStyle(color: textWhite, fontSize: 14, height: 1.8),
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
                            _isExpanded ? 'کم دکھائیں' : 'مزید پڑھیں',
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