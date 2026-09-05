import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/news_model.dart';
import '../services/theme_service.dart';
import '../services/bookmark_service.dart';
import 'translated_news_title.dart';
import 'urdu_summary_text.dart';

class NewsCard extends StatelessWidget {
  final NewsModel news;
  final VoidCallback onTap;
  final String langCode;
  final bool isRtl;

  const NewsCard({
    super.key,
    required this.news,
    required this.onTap,
    this.langCode = 'en',
    this.isRtl = false,
  });

  void _toggleBookmark(BuildContext context) async {
    final isSaved = await BookmarkService().toggleBookmark(news);
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ThemeService.card,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSaved ? ThemeService.primaryGreen : ThemeService.border,
              width: 1.2,
            ),
          ),
          content: Row(
            children: [
              Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: isSaved ? ThemeService.primaryGreen : ThemeService.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSaved
                      ? 'Saved to Bookmarks! 🔖 (Local)'
                      : 'Removed from Bookmarks',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _shareArticle() {
    final shareUrl = (news.sourceUrl != null && news.sourceUrl!.trim().isNotEmpty)
        ? news.sourceUrl!.trim()
        : 'https://gameskhabar.pk';
    final shareText = '🎮 ${news.title}\n\nRead more on Games Khabar:\n$shareUrl';
    Share.share(shareText, subject: news.title);
  }

  @override
  Widget build(BuildContext context) {
    final neonGreen = ThemeService.primaryGreen;
    final cardDark = ThemeService.card;
    final borderDark = ThemeService.border;
    final textWhite = ThemeService.textPrimary;
    final textGray = ThemeService.textSecondary;

    final badgeText = (news.gameName != null && news.gameName!.trim().isNotEmpty)
        ? news.gameName!.trim()
        : news.category;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: neonGreen.withOpacity(0.15),
          highlightColor: neonGreen.withOpacity(0.08),
          child: Container(
            constraints: const BoxConstraints(minHeight: 125),
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderDark),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Thumbnail (120px)
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                    child: SizedBox(
                      width: 120,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: news.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF1E1E24),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF1E1E24),
                              child: const Center(
                                child: Icon(Icons.games, color: Color(0xFF9E9EA7), size: 28),
                              ),
                            ),
                          ),
                          if (news.videoUrl != null && news.videoUrl!.isNotEmpty)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Color(0xFFFF4655),
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Right Details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top row: Game Name Badge & Time
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: neonGreen.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: neonGreen.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    badgeText.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: neonGreen,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                news.timeAgo,
                                style: TextStyle(color: textGray, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // English Title
                          TranslatedNewsTitle(
                            news: news,
                            langCode: langCode,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: isRtl ? TextAlign.right : TextAlign.left,
                            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                            style: TextStyle(
                              color: textWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),

                          // Short 2-line Urdu summary under title
                          UrduSummaryText(
                            news: news,
                            maxLines: 2,
                          ),

                          const SizedBox(height: 6),

                          // Bottom Row: Views, Share & Bookmark Buttons
                          Row(
                            children: [
                              Icon(Icons.visibility_outlined, color: textGray, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${news.views}',
                                style: TextStyle(color: textGray, fontSize: 10),
                              ),
                              const Spacer(),

                              // Share Button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _shareArticle,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.share_outlined,
                                      color: textGray,
                                      size: 17,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Bookmark Icon (Save to local)
                              ValueListenableBuilder<Set<String>>(
                                valueListenable: BookmarkService.bookmarkedIdsNotifier,
                                builder: (context, ids, _) {
                                  final isSaved = ids.contains(news.id);
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _toggleBookmark(context),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Icon(
                                          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                          color: isSaved ? neonGreen : textGray,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
        ),
      ),
    );
  }
}
