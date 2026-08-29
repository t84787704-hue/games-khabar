import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_model.dart';

class NewsDetailScreen extends StatelessWidget {
  final NewsModel news;

  const NewsDetailScreen({super.key, required this.news});

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color cardDark2 = Color(0xFF15151A);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);
  static const Color textLightGray = Color(0xFFD4D4D8);

  String? _extractUrl(String text) {
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

  Future<void> _launchUrlString(BuildContext context, String url) async {
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

  void _shareArticle(BuildContext context) {
    final textToShare = '${news.title}\n\nRead more on Games Khabar App';
    Clipboard.setData(ClipboardData(text: textToShare));
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
            Text(
              'Article link copied to clipboard!',
              style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final directUrl = _extractUrl(news.description);

    return Scaffold(
      backgroundColor: bgDark,
      body: CustomScrollView(
        slivers: [
          // Sliver Hero Image with Back Button
          SliverAppBar(
            expandedHeight: 300,
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
                  CachedNetworkImage(
                    imageUrl: news.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: cardDark,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(neonGreen),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: cardDark,
                      child: const Icon(Icons.broken_image_rounded, color: textGray, size: 48),
                    ),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge + Time
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

                  // IGN Style Bold Title
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
                  const SizedBox(height: 18),

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
                        onPressed: () => _launchUrlString(context, directUrl),
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

                  // Action Buttons (Share & Source)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
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
                      ),
                    ],
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
