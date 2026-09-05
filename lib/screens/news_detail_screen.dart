import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/gaming_news_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gaming_news_service.dart';

class NewsDetailScreen extends StatefulWidget {
  final GamingNewsModel news;

  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final GamingNewsService _gamingNewsService = GamingNewsService();

  void _shareNews() {
    final text = '🎮 ${widget.news.titleEn}\n\n'
        '${widget.news.titleUr.isNotEmpty ? "${widget.news.titleUr}\n\n" : ""}'
        'Read more: ${widget.news.sourceUrl.isNotEmpty ? widget.news.sourceUrl : "https://gameskhabar.pk"}';
    Share.share(text);
  }

  Future<void> _openSourceUrl() async {
    final urlStr = widget.news.sourceUrl;
    if (urlStr.isEmpty) return;
    final uri = Uri.tryParse(urlStr);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = GamerAuthService().currentUid ?? '';
    final news = widget.news;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14), // Dark #0B0F14 theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF141923),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
              ),
              child: Text(
                news.category.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF00FF88),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF00D2FF), size: 20),
            onPressed: _shareNews,
          ),
          StreamBuilder<bool>(
            stream: _gamingNewsService.isBookmarkedStream(currentUid, news.id),
            builder: (context, snap) {
              final isBookmarked = snap.data ?? false;
              return IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isBookmarked ? const Color(0xFF00FF88) : Colors.white,
                  size: 22,
                ),
                onPressed: () async {
                  if (currentUid.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please log in to bookmark news')),
                    );
                    return;
                  }
                  final saved = await _gamingNewsService.toggleBookmark(currentUid, news);
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
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full Image Header
            if (news.imageUrl.isNotEmpty)
              Hero(
                tag: 'news_img_${news.id}',
                child: Container(
                  width: double.infinity,
                  height: 240,
                  color: const Color(0xFF1A1F29),
                  child: CachedNetworkImage(
                    imageUrl: news.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFF141923),
                      child: const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF141923),
                      child: const Center(
                        child: Icon(Icons.sports_esports_rounded, size: 60, color: Color(0xFF283244)),
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta Row: Platform, Timestamp, Views
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2FF).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.4)),
                        ),
                        child: Text(
                          news.platform,
                          style: const TextStyle(
                            color: Color(0xFF00D2FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF8B9BB4)),
                      const SizedBox(width: 4),
                      Text(
                        news.timeAgo,
                        style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12),
                      ),
                      const Spacer(),
                      const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF8B9BB4)),
                      const SizedBox(width: 4),
                      Text(
                        '${news.views} views',
                        style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title in English (Bold White)
                  Text(
                    news.titleEn,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Urdu translated title in Green #00FF88
                  if (news.titleUr.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.25)),
                      ),
                      child: Text(
                        news.titleUr,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Divider
                  Container(
                    height: 1,
                    color: const Color(0xFF262E3D),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  const SizedBox(height: 8),

                  // Summary Text
                  Text(
                    news.summary.isNotEmpty ? news.summary : 'No summary available for this story.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 14.5,
                      height: 1.65,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Read More Button
                  if (news.sourceUrl.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF88),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text(
                          'Read More on Source Website',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: _openSourceUrl,
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
