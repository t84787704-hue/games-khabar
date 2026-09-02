import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/news_model.dart';
import '../widgets/app_image_view.dart';
import '../widgets/native_ad_widget.dart';
import '../services/bookmark_service.dart';
import '../services/firestore_service.dart';
import '../services/ad_free_service.dart';

/// Helper function to extract 11-char YouTube video ID from various YouTube URL formats, direct ID, or content text
String? extractYoutubeId(String? urlOrText) {
  if (urlOrText == null || urlOrText.trim().isEmpty) return null;
  String clean = urlOrText.trim();

  // 1. Direct 11-character video ID
  final directIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  if (directIdRegex.hasMatch(clean)) {
    return clean;
  }

  // 2. Try YoutubePlayer.convertUrlToId
  try {
    final converted = YoutubePlayer.convertUrlToId(clean);
    if (converted != null && converted.trim().length == 11) {
      return converted.trim();
    }
  } catch (_) {}

  // 3. Clean tracking query parameters
  if (clean.contains('?si=') || clean.contains('&si=')) {
    clean = clean.replaceAll(RegExp(r'[?&]si=[^&#\s]+'), '');
  }

  // 4. Extract ID using regex matching youtube.com or youtu.be
  final regExp = RegExp(
    r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/|live\/)|(?:v=))([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );
  final match = regExp.firstMatch(clean);
  if (match != null && match.group(1) != null) {
    return match.group(1);
  }

  final fallbackRegExp = RegExp(
    r'(?:v=|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );
  final fallbackMatch = fallbackRegExp.firstMatch(clean);
  return fallbackMatch?.group(1);
}

/// Helper to detect if a given URL is a YouTube URL
bool isYouTubeUrl(String? url) {
  if (url == null || url.trim().isEmpty) return false;
  final lower = url.trim().toLowerCase();
  return lower.contains('youtube.com') ||
      lower.contains('youtu.be') ||
      extractYoutubeId(url) != null;
}

class NewsDetailScreen extends StatefulWidget {
  final NewsModel news;

  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  YoutubePlayerController? _youtubeController;
  String? _detectedVideoId;
  bool _isPlaying = false;

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color scaffoldBg = Color(0xFF121318);
  static const Color cardDark = Color(0xFF1E1F28);
  static const Color borderDark = Color(0xFF2E303E);
  static const Color alertRed = Color(0xFFFF3344);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);
  static const Color textLightGray = Color(0xFFD4D4D8);

  @override
  void initState() {
    super.initState();
    _initYoutubePlayer();
  }

  void _initYoutubePlayer() {
    _detectedVideoId = _findYouTubeVideoId(widget.news);
    if (_detectedVideoId != null && _detectedVideoId!.isNotEmpty) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: _detectedVideoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: false,
          enableCaption: true,
          showLiveFullscreenButton: false,
        ),
      );
    }
  }

  String? _findYouTubeVideoId(NewsModel news) {
    // 1. Check videoUrl field
    if (news.videoUrl != null && news.videoUrl!.trim().isNotEmpty) {
      final id = extractYoutubeId(news.videoUrl);
      if (id != null) return id;
    }

    // 2. Check sourceUrl field
    if (news.sourceUrl != null && news.sourceUrl!.trim().isNotEmpty) {
      final id = extractYoutubeId(news.sourceUrl);
      if (id != null) return id;
    }

    // 3. Check all translated descriptions in descriptionMap
    for (final desc in news.descriptionMap.values) {
      final id = extractYoutubeId(desc);
      if (id != null) return id;
    }

    // 4. Check raw description / title
    final rawDescId = extractYoutubeId(news.description);
    if (rawDescId != null) return rawDescId;

    final rawTitleId = extractYoutubeId(news.title);
    if (rawTitleId != null) return rawTitleId;

    return null;
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  bool get hasOtherNonYoutubeVideo =>
      widget.news.videoUrl != null &&
      widget.news.videoUrl!.trim().isNotEmpty &&
      _detectedVideoId == null &&
      !isYouTubeUrl(widget.news.videoUrl);

  String? _extractSourceUrl(String text) {
    if (widget.news.sourceUrl != null && widget.news.sourceUrl!.trim().isNotEmpty) {
      final sUrl = widget.news.sourceUrl!.trim();
      // Remove clickable action if it's a YouTube URL since player is embedded
      if (!isYouTubeUrl(sUrl)) {
        return sUrl;
      }
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
      // If it's a YouTube URL, suppress clickable external link
      if (!isYouTubeUrl(url)) {
        return url;
      }
    }
    return null;
  }

  String _cleanContentText(String text) {
    // If YouTube video is present, remove raw YouTube URLs to keep content readable
    if (_detectedVideoId != null) {
      return text
          .replaceAll(
            RegExp(r'https?:\/\/(?:www\.)?(?:youtube\.com\/[^\s]+|youtu\.be\/[^\s]+)'),
            '',
          )
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    }
    return text.trim();
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

    final langCode = context.locale.languageCode;
    final displayTitle = widget.news.getTitle(langCode);
    final displayDescription = widget.news.getDescription(langCode);

    final String shareMessage =
        '🔥 $displayTitle\n\n'
        '$displayDescription\n\n'
        '🎮 Read more on Games Khabar App 👇\n'
        '📲 Download Now: $playStoreUrl';

    try {
      await Share.share(
        shareMessage,
        subject: '🎮 $displayTitle - Games Khabar',
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
    final isSaved = await BookmarkService().toggleBookmark(widget.news);
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
    if (_detectedVideoId != null && _youtubeController != null) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: neonGreen,
          progressColors: const ProgressBarColors(
            playedColor: neonGreen,
            handleColor: neonGreen,
            bufferedColor: Colors.grey,
            backgroundColor: Colors.black26,
          ),
          topActions: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _youtubeController!.metadata.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
        builder: (context, player) {
          return _buildScaffoldContent(context, playerWidget: player);
        },
      );
    }

    return _buildScaffoldContent(context);
  }

  Widget _buildScaffoldContent(BuildContext context, {Widget? playerWidget}) {
    final langCode = context.locale.languageCode;
    final displayTitle = widget.news.getTitle(langCode);
    final rawDescription = widget.news.getDescription(langCode);
    final displayDescription = _cleanContentText(rawDescription);
    final directUrl = _extractSourceUrl(rawDescription);
    final hasVideo = _detectedVideoId != null || hasOtherNonYoutubeVideo;

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
          widget.news.category.isNotEmpty ? widget.news.category : 'Gaming Khabar',
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
              final isSaved = bookmarkedIds.contains(widget.news.id);
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
              // 1. Metadata Bar (Category Badge, Video Tag, Time, Views)
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
                      widget.news.category.toUpperCase(),
                      style: TextStyle(
                        color: neonGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (hasVideo) ...[
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
                    widget.news.timeAgo,
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
                    '${widget.news.views} views',
                    style: TextStyle(color: textGray, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. News Title
              Text(
                displayTitle,
                style: TextStyle(
                  color: textWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),

              // 3. Accent Divider
              Container(
                height: 3,
                width: 44,
                decoration: BoxDecoration(
                  color: neonGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Video / Featured Media Area
              if (_detectedVideoId != null && _youtubeController != null) ...[
                if (_isPlaying && playerWidget != null) ...[
                  // Active embedded YouTube player
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: alertRed.withOpacity(0.5), width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: playerWidget,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(Icons.verified_user_outlined, color: textGray, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Video Credit: Official Channel',
                        style: TextStyle(
                          color: textGray,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Thumbnail with Play Icon & Click-to-Play GestureDetector
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _isPlaying = true;
                      });
                      _youtubeController?.play();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderDark, width: 1.2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Thumbnail Image
                              AppImageView(
                                imageUrl: widget.news.imageUrl.isNotEmpty
                                    ? widget.news.imageUrl
                                    : 'https://img.youtube.com/vi/$_detectedVideoId/hqdefault.jpg',
                                fit: BoxFit.cover,
                              ),
                              // Dark Overlay for Contrast
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.2),
                                      Colors.black.withOpacity(0.65),
                                    ],
                                  ),
                                ),
                              ),
                              // Glowing Center Play Button
                              Center(
                                child: Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    color: alertRed,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: alertRed.withOpacity(0.6),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                              ),
                              // Play pill hint
                              Positioned(
                                bottom: 12,
                                left: 12,
                                right: 12,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: alertRed.withOpacity(0.7), width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.play_circle_fill_rounded, color: alertRed, size: 14),
                                          SizedBox(width: 5),
                                          Text(
                                            'Tap to Play Video',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
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
                    const SizedBox(height: 6),
                    Row(
                      children: const [
                        Icon(Icons.verified_user_outlined, color: textGray, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Video Credit: Official Channel',
                          style: TextStyle(
                            color: textGray,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ] else ...[
                // Featured Image (No video)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: AppImageView(
                      imageUrl: widget.news.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Direct Video Link Button (for non-YouTube direct MP4/stream video links only)
              if (hasOtherNonYoutubeVideo) ...[
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
                    onPressed: () => _launchExternalUrl(context, widget.news.videoUrl!),
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                    label: const Text(
                      'Watch Video',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 6. News Description Text (Cleaned from raw YouTube URLs)
              Text(
                displayDescription,
                style: const TextStyle(
                  color: textLightGray,
                  fontSize: 15,
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 24),

              // 7. Source Article Link (Non-YouTube external source only)
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

              // 8. Share Button
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
              const SizedBox(height: 20),

              // 9. AdMob Ad Section (Separated by >= 12px gap from player & content for YouTube + AdMob compliance)
              ValueListenableBuilder<DateTime?>(
                valueListenable: AdFreeService.adFreeUntilNotifier,
                builder: (context, adFreeUntil, _) {
                  if (AdFreeService().isAdFree) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: const [
                      SizedBox(height: 12), // Explicit 12px+ buffer
                      NativeAdWidget(),
                      SizedBox(height: 12),
                    ],
                  );
                },
              ),

              // 10. Related News Section
              _buildRelatedNewsSection(context, langCode),
            ],
          ),
        ),
      ),
    );
  }

  List<NewsModel> _getRelatedNews(List<NewsModel> allNews, String langCode) {
    // 1. Exclude current news itself
    final otherNews = allNews.where((n) => n.id != widget.news.id).toList();

    // 2. Filter by same category (up to 4)
    final List<NewsModel> related = otherNews
        .where((n) => n.category.trim().toLowerCase() == widget.news.category.trim().toLowerCase())
        .take(4)
        .toList();

    // 3. If related count is less than 2, also find news where title contains same keywords
    if (related.length < 2) {
      final currentTitle = widget.news.getTitle(langCode);
      final words = currentTitle
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 3)
          .toSet();

      final relatedIds = related.map((e) => e.id).toSet();

      for (final item in otherNews) {
        if (related.length >= 4) break;
        if (relatedIds.contains(item.id)) continue;

        final itemTitleLower = item.getTitle(langCode).toLowerCase();
        final hasKeyword = words.any((w) => itemTitleLower.contains(w));
        if (hasKeyword) {
          related.add(item);
          relatedIds.add(item.id);
        }
      }
    }

    return related;
  }

  Widget _buildRelatedNewsSection(BuildContext context, String langCode) {
    return StreamBuilder<List<NewsModel>>(
      stream: FirestoreService().getNewsStream(),
      initialData: FirestoreService().currentNews,
      builder: (context, snapshot) {
        final allNews = snapshot.data ?? [];
        final relatedList = _getRelatedNews(allNews, langCode);

        // Hide the whole section if no related news found
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
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: relatedList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = relatedList[index];
                final itemTitle = item.getTitle(langCode);
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
                                    itemTitle,
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
