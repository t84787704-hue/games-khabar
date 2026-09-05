import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/gaming_news_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gaming_news_service.dart';
import 'package:url_launcher/url_launcher.dart';

class GamingNewsCard extends StatelessWidget {
  final GamingNewsModel news;

  const GamingNewsCard({super.key, required this.news});

  void _onShare() {
    final text = '🎮 ${news.titleEn}\n\n'
        '${news.titleUr.isNotEmpty ? "${news.titleUr}\n\n" : ""}'
        'Read more on Games Khabar: ${news.sourceUrl.isNotEmpty ? news.sourceUrl : "https://gameskhabar.pk"}';
    Share.share(text);
  }

  Future<void> _onOpenDetail(BuildContext context) async {
    GamingNewsService().incrementViews(news.id);
    if (news.sourceUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(news.sourceUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('Error launching URL: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = GamerAuthService().currentUid ?? '';
    final gamingNewsService = GamingNewsService();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F29), // Dark #1A1F29 background as specified
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262E3D), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onOpenDetail(context),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: 35% Image
                Expanded(
                  flex: 35,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                    child: news.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: news.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF10141D),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00FF88),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => _build4DotsPlaceholder(),
                          )
                        : _build4DotsPlaceholder(),
                  ),
                ),

                // Right: 65% Content
                Expanded(
                  flex: 65,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top row: Green Category Badge + Timestamp
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Green category badge e.g. "FALL UP", "EA SPORTS", "GRAND THEFT A...", "FPS/SHOOTING"
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FF88).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF00FF88).withOpacity(0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  news.category.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF00FF88), // Neon Green #00FF88
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Timestamp
                            Text(
                              news.timeAgo,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Title in White Bold
                        Text(
                          news.titleEn,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            height: 1.25,
                          ),
                        ),

                        // Urdu translated title in Green #00FF88
                        if (news.titleUr.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            news.titleUr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: Color(0xFF00FF88), // Green #00FF88 as specified
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),

                        // Bottom row: Eye icon + views count + share icon + bookmark icon
                        Row(
                          children: [
                            // Eye icon + views count
                            const Icon(
                              Icons.visibility_outlined,
                              size: 14,
                              color: Color(0xFF8B9BB4),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${news.views}',
                              style: const TextStyle(
                                color: Color(0xFF8B9BB4),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const Spacer(),

                            // Share icon
                            InkWell(
                              onTap: _onShare,
                              borderRadius: BorderRadius.circular(16),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.share_outlined,
                                  size: 17,
                                  color: Color(0xFF8B9BB4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Bookmark icon connected to users/{uid}/saved_news
                            StreamBuilder<bool>(
                              stream: gamingNewsService.isBookmarkedStream(currentUid, news.id),
                              builder: (context, snap) {
                                final isBookmarked = snap.data ?? false;
                                return InkWell(
                                  onTap: () async {
                                    if (currentUid.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please log in to bookmark news'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      return;
                                    }
                                    final saved = await gamingNewsService.toggleBookmark(currentUid, news);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: const Color(0xFF182234),
                                          content: Text(
                                            saved ? 'Article saved to bookmarks' : 'Article removed from bookmarks',
                                            style: const TextStyle(color: Color(0xFF00FF88)),
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                                      size: 18,
                                      color: isBookmarked ? const Color(0xFF00FF88) : const Color(0xFF8B9BB4),
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
    );
  }

  Widget _build4DotsPlaceholder() {
    return Container(
      color: const Color(0xFF10141D),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(),
                const SizedBox(width: 4),
                _dot(),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(),
                const SizedBox(width: 4),
                _dot(),
              ],
            ),
            const SizedBox(height: 6),
            Icon(
              Icons.sports_esports_rounded,
              size: 16,
              color: Colors.white.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot() {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFF00FF88).withOpacity(0.4),
        shape: BoxShape.circle,
      ),
    );
  }
}
