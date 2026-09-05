import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/gamer_theme.dart';
import '../models/gaming_news_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gaming_news_service.dart';
import '../screens/news_detail_screen.dart';

class NewsPostCard extends StatefulWidget {
  final GamingNewsModel news;

  const NewsPostCard({super.key, required this.news});

  @override
  State<NewsPostCard> createState() => _NewsPostCardState();
}

class _NewsPostCardState extends State<NewsPostCard> {
  final GamingNewsService _newsService = GamingNewsService();
  bool _isLiked = false;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.news.views > 0 ? widget.news.views : 124;
  }

  void _onOpenDetail() {
    _newsService.incrementViews(widget.news.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(news: widget.news),
      ),
    );
  }

  void _onShare() {
    final text = '🎮 ${widget.news.titleEn}\n\n'
        '${widget.news.titleUr.isNotEmpty ? "${widget.news.titleUr}\n\n" : ""}'
        'Read more on Games Khabar: ${widget.news.sourceUrl.isNotEmpty ? widget.news.sourceUrl : "https://gameskhabar.pk"}';
    Share.share(text);
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
      } else {
        _likeCount--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = GamerAuthService().currentUid ?? '';
    final news = widget.news;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262E3D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: GK Logo Avatar + "GAMES KHABAR • Official" + Verified Tick + Category & Time + Trending News Label
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // GK Avatar
                GestureDetector(
                  onTap: _onOpenDetail,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00FF88), Color(0xFF00D2FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FF88).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'GK',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name & Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'GAMES KHABAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '•',
                            style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 10),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Official',
                            style: TextStyle(
                              color: Color(0xFF00D2FF),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF00FF88), // Green Verified Tick
                            size: 15,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          // Category badge e.g. "GRAND THEFT AUTO" / "EA SPORTS"
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
                                  color: Color(0xFF00FF88),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9.5,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 10),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            news.timeAgo,
                            style: const TextStyle(
                              color: Color(0xFF8B9BB4),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Top right label: "Trending News"
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB703).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFFFB703).withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 12,
                        color: Color(0xFFFFB703),
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Trending',
                        style: TextStyle(
                          color: Color(0xFFFFB703),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // English Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text(
              news.titleEn,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
          ),

          // Urdu translated Title in Green #00FF88 below
          if (news.titleUr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              child: Text(
                news.titleUr,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Color(0xFF00FF88),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Body Image: Full width like Facebook post
          if (news.imageUrl.isNotEmpty)
            GestureDetector(
              onTap: _onOpenDetail,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF10141D),
                  child: CachedNetworkImage(
                    imageUrl: news.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFF141923),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00FF88),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF141923),
                      child: Center(
                        child: Icon(
                          Icons.sports_esports_rounded,
                          size: 48,
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Divider before footer
          const Divider(color: Color(0xFF262E3D), height: 1),

          // Footer: Like (views) + Share + Bookmark + Read More
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Like Button
                InkWell(
                  onTap: _toggleLike,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 18,
                          color: _isLiked ? const Color(0xFFFF4757) : const Color(0xFF8B9BB4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_likeCount',
                          style: TextStyle(
                            color: _isLiked ? const Color(0xFFFF4757) : const Color(0xFF8B9BB4),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Share Button
                InkWell(
                  onTap: _onShare,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.share_outlined,
                          size: 17,
                          color: Color(0xFF8B9BB4),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Share',
                          style: TextStyle(
                            color: Color(0xFF8B9BB4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Bookmark Button
                StreamBuilder<bool>(
                  stream: _newsService.isBookmarkedStream(currentUid, news.id),
                  builder: (context, snap) {
                    final isBookmarked = snap.data ?? false;
                    return InkWell(
                      onTap: () async {
                        if (currentUid.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please log in to bookmark news')),
                          );
                          return;
                        }
                        final saved = await _newsService.toggleBookmark(currentUid, news);
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
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Icon(
                          isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                          size: 19,
                          color: isBookmarked ? const Color(0xFF00FF88) : const Color(0xFF8B9BB4),
                        ),
                      ),
                    );
                  },
                ),

                const Spacer(),

                // Read More Button
                ElevatedButton.icon(
                  onTap: _onOpenDetail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text(
                    'Read More',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
