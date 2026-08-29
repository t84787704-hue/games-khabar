import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_model.dart';
import '../widgets/app_image_view.dart';

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
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color alertRed = Color(0xFFFF0000);
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
      // Fallback copy to clipboard if share intent fails
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
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: neonGreen, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Article & App link copied to clipboard!',
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

  @override
  Widget build(BuildContext context) {
    final directUrl = _extractSourceUrl(news.description);
    final ytId = youTubeVideoId;
    final isOtherVideo = hasVideoUrl && ytId == null;

    return Scaffold(
      backgroundColor: bgDark,
      body: CustomScrollView(
        slivers: [
          // Hero Cover Image (SliverAppBar with base64 / network image support)
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: bgDark,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.65),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: textWhite, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.65),
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined, color: neonGreen, size: 20),
                    onPressed: () => _shareArticle(context),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppImageView(
                    imageUrl: news.imageUrl,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          bgDark.withOpacity(0.9),
                          bgDark,
                        ],
                        stops: const [0.0, 0.4, 0.85, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge + Video Indicator + Time + Views
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: neonGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: neonGreen, width: 1),
                        ),
                        child: Text(
                          news.category.toUpperCase(),
                          style: const TextStyle(
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
                            borderRadius: BorderRadius.circular(4),
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
                      const Icon(Icons.access_time_rounded, color: textGray, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        news.timeAgo,
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
                        '${news.views} views',
                        style: const TextStyle(color: textGray, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // News Title
                  Text(
                    news.title,
                    style: const TextStyle(
                      color: textWhite,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Divider Accent
                  Container(
                    height: 2,
                    width: 50,
                    decoration: BoxDecoration(
                      color: neonGreen,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // YouTube Thumbnail Player Preview (Opens directly in YouTube App)
                  if (ytId != null) ...[
                    YouTubeThumbnailCard(
                      videoId: ytId,
                      onTap: () => _openYouTubeVideo(context, ytId),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Watch Video Button (if other direct mp4/video link)
                  if (isOtherVideo) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: alertRed,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _launchExternalUrl(context, news.videoUrl!),
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 22, color: Colors.white),
                        label: const Text(
                          'Watch Video',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Description Body Text
                  Text(
                    news.description,
                    style: const TextStyle(
                      color: textLightGray,
                      fontSize: 15,
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Optional "Read Full Article" / URL button
                  if (directUrl != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cardDark,
                          foregroundColor: neonGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: neonGreen, width: 1.2),
                          ),
                        ),
                        onPressed: () => _launchExternalUrl(context, directUrl),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text(
                          'Read Full Article / Source Link',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Action Button (Share)
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
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text(
                        'Share Article',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom YouTube Thumbnail Card with big red play button and black overlay
class YouTubeThumbnailCard extends StatelessWidget {
  final String videoId;
  final VoidCallback onTap;

  const YouTubeThumbnailCard({
    super.key,
    required this.videoId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxResUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
    final hqDefaultUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF15151A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF0000).withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF0000).withOpacity(0.2),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // YouTube High Quality Thumbnail Image
                Image.network(
                  maxResUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      hqDefaultUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF15151A),
                        child: const Center(
                          child: Icon(Icons.movie_rounded, color: Colors.white24, size: 48),
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFF15151A),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF0000),
                          strokeWidth: 2.5,
                        ),
                      ),
                    );
                  },
                ),

                // Semi-transparent Black Overlay
                Container(
                  color: Colors.black.withOpacity(0.35),
                ),

                // Subtle vignette gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),

                // Big Red YouTube Play Button in Center
                Center(
                  child: Container(
                    width: 68,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0000).withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),

                // Bottom Banner: "Watch on YouTube"
                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.play_circle_filled_rounded, color: Color(0xFFFF0000), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Watch on YouTube',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.open_in_new_rounded,
                          color: Colors.white70,
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
    );
  }
}

