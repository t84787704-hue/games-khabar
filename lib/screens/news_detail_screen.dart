import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/news_model.dart';
import '../widgets/app_image_view.dart';

class NewsDetailScreen extends StatelessWidget {
  final NewsModel news;

  const NewsDetailScreen({super.key, required this.news});

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color alertRed = Color(0xFFFF4655);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);
  static const Color textLightGray = Color(0xFFD4D4D8);

  bool get hasVideoUrl => news.videoUrl != null && news.videoUrl!.trim().isNotEmpty;

  bool get isYouTubeVideo {
    if (!hasVideoUrl) return false;
    final lower = news.videoUrl!.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  String? get youTubeVideoId {
    if (!isYouTubeVideo) return null;
    final url = news.videoUrl!.trim();
    final converted = YoutubePlayer.convertUrlToId(url);
    if (converted != null && converted.isNotEmpty) return converted;
    final regExp = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/))([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

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
    final directUrl = _extractSourceUrl(news.description);
    final ytId = youTubeVideoId;
    final isOtherVideo = hasVideoUrl && !isYouTubeVideo;

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

                  // News Title (IGN Bold Style)
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

                  // YouTube Player (if YouTube link)
                  if (ytId != null) ...[
                    YouTubePlayerContainer(videoId: ytId),
                    const SizedBox(height: 20),
                  ],

                  // Watch Video Button (if other mp4/video link)
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

class YouTubePlayerContainer extends StatefulWidget {
  final String videoId;

  const YouTubePlayerContainer({super.key, required this.videoId});

  @override
  State<YouTubePlayerContainer> createState() => _YouTubePlayerContainerState();
}

class _YouTubePlayerContainerState extends State<YouTubePlayerContainer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4655).withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: const Color(0xFF00FF88),
          progressColors: const ProgressBarColors(
            playedColor: Color(0xFF00FF88),
            handleColor: Color(0xFF00FF88),
            bufferedColor: Colors.white24,
            backgroundColor: Colors.white10,
          ),
          bottomActions: [
            CurrentPosition(),
            ProgressBar(isExpanded: true),
            RemainingDuration(),
            const PlaybackSpeedButton(),
          ],
        ),
      ),
    );
  }
}
