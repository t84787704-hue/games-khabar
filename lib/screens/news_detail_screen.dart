import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_model.dart';
import '../widgets/app_image_view.dart';
import '../services/bookmark_service.dart';
import '../services/firestore_service.dart';

/// Helper function to extract YouTube video ID from various YouTube URL formats or direct ID
String? extractYoutubeId(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  String cleanUrl = url.trim();

  // 1. Direct 11-character video ID
  final directIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  if (directIdRegex.hasMatch(cleanUrl)) {
    return cleanUrl;
  }

  // 2. Remove ?si= or &si= parameter
  if (cleanUrl.contains('?si=') || cleanUrl.contains('&si=')) {
    cleanUrl = cleanUrl.replaceAll(RegExp(r'[?&]si=[^&#]+'), '');
  }

  // 3. Extract ID using RegExp
  final regExp = RegExp(
    r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/|live\/)|(?:v=))([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );
  final match = regExp.firstMatch(cleanUrl);
  if (match != null && match.group(1) != null) {
    return match.group(1);
  }

  final fallbackRegExp = RegExp(
    r'(?:v=|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );
  final fallbackMatch = fallbackRegExp.firstMatch(cleanUrl);
  return fallbackMatch?.group(1);
}

class NewsDetailScreen extends StatelessWidget {
  final NewsModel news;

  const NewsDetailScreen({super.key, required this.news});

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color scaffoldBg = Color(0xFF121318);
  static const Color cardDark = Color(0xFF1E1F28);
  static const Color borderDark = Color(0xFF2E303E);
  static const Color alertRed = Color(0xFFFF3344);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);
  static const Color textLightGray = Color(0xFFD4D4D8);

  bool get hasVideoUrl => news.videoUrl != null && news.videoUrl!.trim().isNotEmpty;

  String? get youTubeVideoId => extractYoutubeId(news.videoUrl);

  String? _extractSourceUrl(String text) {
    if (news.sourceUrl != null && news.sourceUrl!.trim().isNotEmpty) {
      return news.sourceUrl!.trim();
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
      return url;
    }
    return null;
  }

  Future<void> _openYouTubeVideo(BuildContext context, String videoId) async {
    final uri = Uri.parse("https://www.youtube.com/watch?v=$videoId");
    try {
      final canOpen = await canLaunchUrl(uri);
      if (canOpen) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark,
            content: Text('Could not open YouTube', style: TextStyle(color: neonGreen)),
          ),
        );
      }
    }
  }

  Future<void> _launchExternalUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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

    final String shareMessage =
        '🔥 ${news.title}\n\n'
        '${news.description}\n\n'
        '🎮 Read more on Games Khabar App 👇\n'
        '📲 Download Now: $playStoreUrl';

    try {
      await Share.share(
        shareMessage,
        subject: '🎮 ${news.title} - Games Khabar',
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
              side: BorderSide(color: neonGreen, width: 1),
            ),
            content: Row(
              children: const [
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
    final isSaved = await BookmarkService().toggleBookmark(news);
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
                  style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final directUrl = _extractSourceUrl(news.description);
    final ytId = youTubeVideoId;
    final isOtherVideo = hasVideoUrl && ytId == null;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          news.category.isNotEmpty ? news.category : 'Gaming Khabar',
          style: TextStyle(
            color: textWhite,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          // Bookmark Icon Button
          ValueListenableBuilder<Set<String>>(
            valueListenable: BookmarkService.bookmarkedIdsNotifier,
            builder: (context, bookmarkedIds, _) {
              final isSaved = bookmarkedIds.contains(news.id);
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
            icon: Icon(Icons.share_outlined, color: neonGreen, size: 22),
            tooltip: 'Share',
            onPressed: () => _shareArticle(context),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. News Featured Image
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AppImageView(
                    imageUrl: news.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Metadata Bar (Category Badge, Video Tag, Time, Views)
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
                      news.category.toUpperCase(),
                      style: TextStyle(
                        color: neonGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (hasVideoUrl) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: alertRed.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: alertRed, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
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
                  Icon(Icons.access_time_rounded, color: textGray, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    news.timeAgo,
                    style: TextStyle(
                      color: textGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.visibility_outlined, color: textGray, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${news.views} views',
                    style: TextStyle(color: textGray, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. News Title
              Text(
                news.title,
                style: TextStyle(
                  color: textWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),

              // 4. Accent Divider
              Container(
                height: 3,
                width: 44,
                decoration: BoxDecoration(
                  color: neonGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // 5. YouTube Video Preview Card (Click to open YouTube App / Web)
              if (ytId != null) ...[
                GestureDetector(
                  onTap: () => _openYouTubeVideo(context, ytId),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: alertRed.withOpacity(0.7), width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // YouTube Thumbnail (0.jpg standard)
                            CachedNetworkImage(
                              imageUrl: 'https://img.youtube.com/vi/$ytId/0.jpg',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: cardDark,
                                child: Center(
                                  child: CircularProgressIndicator(color: alertRed, strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: cardDark,
                                child: Center(
                                  child: Icon(Icons.movie_rounded, color: textGray, size: 40),
                                ),
                              ),
                            ),
                            // Dark Overlay
                            Container(
                              color: Colors.black.withOpacity(0.35),
                            ),
                            // Centered Red Play Button
                            Center(
                              child: Container(
                                width: 64,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: alertRed,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: alertRed.withOpacity(0.6),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                            // Bottom Action Banner
                            Positioned(
                              bottom: 10,
                              left: 12,
                              right: 12,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.play_circle_fill_rounded, color: alertRed, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Watch on YouTube',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.open_in_new_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 6. Direct Video Link Button (if other direct URL)
              if (isOtherVideo) ...[
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
                    onPressed: () => _launchExternalUrl(context, news.videoUrl!),
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                    label: const Text(
                      'Watch Video',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 7. News Description Text
              Text(
                news.description,
                style: const TextStyle(
                  color: textLightGray,
                  fontSize: 15,
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 28),

              // 8. Source Article Link (if present)
              if (directUrl != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: neonGreen,
                      side: BorderSide(color: neonGreen, width: 1.2),
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

              // 9. Share Button
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
              const SizedBox(height: 16),

              // 10. Related News Section
              _buildRelatedNewsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  List<NewsModel> _getRelatedNews(List<NewsModel> allNews) {
    // 1. Exclude current news itself
    final otherNews = allNews.where((n) => n.id != news.id).toList();

    // 2. Filter by same category (up to 4)
    final List<NewsModel> related = otherNews
        .where((n) => n.category.trim().toLowerCase() == news.category.trim().toLowerCase())
        .take(4)
        .toList();

    // 3. If related count is less than 2, also find news where title contains same keywords
    if (related.length < 2) {
      final words = news.title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 3)
          .toSet();

      final relatedIds = related.map((e) => e.id).toSet();

      for (final item in otherNews) {
        if (related.length >= 4) break;
        if (relatedIds.contains(item.id)) continue;

        final itemTitleLower = item.title.toLowerCase();
        final hasKeyword = words.any((w) => itemTitleLower.contains(w));
        if (hasKeyword) {
          related.add(item);
          relatedIds.add(item.id);
        }
      }
    }

    return related;
  }

  Widget _buildRelatedNewsSection(BuildContext context) {
    return StreamBuilder<List<NewsModel>>(
      stream: FirestoreService().getNewsStream(),
      initialData: FirestoreService().currentNews,
      builder: (context, snapshot) {
        final allNews = snapshot.data ?? [];
        final relatedList = _getRelatedNews(allNews);

        // 5. Hide the whole section if no related news found
        if (relatedList.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Divider(color: borderDark, thickness: 1),
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
                Text(
                  'Related News',
                  style: TextStyle(
                    color: textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: relatedList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = relatedList[index];
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
                          // Thumbnail Image
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
                                        child: Icon(
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
                          // Content Info
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
                                          style: TextStyle(
                                            color: neonGreen,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        item.timeAgo,
                                        style: TextStyle(color: textGray, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textWhite,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.visibility_outlined, color: textGray, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${item.views} views',
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
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
