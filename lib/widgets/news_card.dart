import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/news_model.dart';
import '../services/theme_service.dart';
import 'translated_news_title.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: neonGreen.withOpacity(0.15),
          highlightColor: neonGreen.withOpacity(0.08),
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderDark),
            ),
            child: Row(
              children: [
                // Left Thumbnail
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                  child: SizedBox(
                    width: 120,
                    height: double.infinity,
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
                        // Title
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
                        // Views footer
                        Row(
                          children: [
                            Icon(Icons.visibility_outlined, color: textGray, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${news.views}',
                              style: TextStyle(color: textGray, fontSize: 10),
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
    );
  }
}
