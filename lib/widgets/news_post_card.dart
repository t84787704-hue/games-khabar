import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/gamer_theme.dart';
import '../data/fallback_images.dart';
import '../models/gaming_news_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gaming_news_service.dart';
import '../services/language_service.dart';
import '../services/translation_service.dart';

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
  bool _isExpanded = false;

  String? _cachedUrduTitle;
  String? _cachedUrduContent;
  bool _translating = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.news.views >= 100 ? widget.news.views : 1840;
  }

  void _ensureUrduContent(GamingNewsModel news) {
    if (LanguageService.isUrdu) {
      final needsTitle = news.titleUr.isEmpty && _cachedUrduTitle == null && news.titleEn.isNotEmpty;
      final needsContent = news.contentUr.isEmpty && _cachedUrduContent == null;

      if ((needsTitle || needsContent) && !_translating) {
        _translating = true;
        Future.wait([
          if (needsTitle)
            TranslationService.translateSingle(news.titleEn, 'ur').then((res) {
              if (mounted && res.isNotEmpty) {
                setState(() => _cachedUrduTitle = res);
              }
            }).catchError((_) {}),
          if (needsContent)
            TranslationService.translateArticle(news.contentEn.isNotEmpty ? news.contentEn : news.summary, 'ur').then((res) {
              if (mounted && res.isNotEmpty) {
                setState(() => _cachedUrduContent = res);
              }
            }).catchError((_) {}),
        ]).whenComplete(() {
          _translating = false;
        });
      }
    }
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _newsService.incrementViews(widget.news.id);
      }
    });
  }

  void _onShare(String title, String content, String sourceUrl) {
    final text = '🎮 $title\n\n'
        '$content\n\n'
        'Source: ${sourceUrl.isNotEmpty ? sourceUrl : "https://gameskhabar.pk"}';
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

    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguage,
      builder: (context, langCode, _) {
        final isUrdu = langCode == 'ur';
        _ensureUrduContent(news);

        final displayTitle = isUrdu
            ? (_cachedUrduTitle ?? (news.titleUr.isNotEmpty ? news.titleUr : news.titleEn))
            : (news.titleEn.isNotEmpty ? news.titleEn : (_cachedUrduTitle ?? news.titleUr));

        final displayContent = isUrdu
            ? (_cachedUrduContent ?? (news.contentUr.isNotEmpty ? news.contentUr : news.getContent('ur')))
            : (news.contentEn.isNotEmpty ? news.contentEn : news.getContent('en'));

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded ? const Color(0xFF00FF88).withOpacity(0.4) : const Color(0xFF262E3D),
        ),
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
          // HEADER: Bot Avatar, Bot Name + Grey BOT badge, Category, and Timestamp
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bot Avatar
                _buildBotAvatar(news),
                const SizedBox(width: 10),

                // Name & Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              news.effectiveBotName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Grey BOT badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF242C38),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF475569),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              news.effectiveBotBadge,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.smart_toy_rounded,
                            color: Color(0xFF64748B),
                            size: 13,
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
                          if (news.platform.isNotEmpty && news.platform != 'Multiplatform') ...[
                            const SizedBox(width: 6),
                            const Text(
                              '•',
                              style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 10),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              news.platform,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Top right label: "Trending" / "ٹرینڈنگ"
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 12,
                        color: Color(0xFFFFB703),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isUrdu ? 'ٹرینڈنگ' : 'Trending',
                        style: const TextStyle(
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

          // Main Title: ONLY single selected language in big white text (NO green Urdu box)
          GestureDetector(
            onTap: _toggleExpand,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Text(
                displayTitle,
                textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: isUrdu ? 15.5 : 14.5,
                  height: 1.4,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Body Image: Always shown with ClipRRect 12, height 200, full width, and fallback
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: _toggleExpand,
                child: Image.network(
                  news.effectiveImageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: const Color(0xFF141923),
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: const Color(0xFF00FF88),
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Image.network(
                    GamingNewsModel.getCategoryFallbackImage(
                      news.category,
                      title: news.titleEn,
                      content: news.contentEn,
                    ),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Image.network(
                      gameFallbackImages['DEFAULT']!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c2, e2, s2) => _buildHeroFallbackBanner(news),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // INLINE EXPANDED CONTENT
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(news, displayContent, isUrdu),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 280),
          ),

          // Divider before footer
          const Divider(color: Color(0xFF262E3D), height: 1),

          // Footer: Like (views) + Share + Bookmark + Read More / Show Less
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
                  onTap: () => _onShare(displayTitle, displayContent, news.sourceUrl),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.share_outlined,
                          size: 17,
                          color: Color(0xFF8B9BB4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isUrdu ? 'شیئر' : 'Share',
                          style: const TextStyle(
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

                // Expand / Collapse Action Button
                ElevatedButton.icon(
                  onPressed: _toggleExpand,
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
                  icon: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _isExpanded
                        ? (isUrdu ? 'کم دکھائیں' : 'Show Less')
                        : (isUrdu ? 'مزید پڑھیں' : 'Read More'),
                    style: const TextStyle(
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
      },
    );
  }

  Widget _buildExpandedContent(GamingNewsModel news, String content, bool isUrdu) {
    final sourceName = news.displaySource;

    // Split paragraphs to render a comfortable, editorial reading experience
    final rawParagraphs = content.split(RegExp(r'\n{2,}|\n'));
    final paragraphs = rawParagraphs
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      color: const Color(0xFF131924),
      child: Column(
        crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Full News Content in selected language - 4-5 paragraphs, white text, line height 1.6
          if (paragraphs.isNotEmpty)
            ...paragraphs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SelectableText(
                  p,
                  textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                  textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: const Color(0xFFE2E8F0),
                    fontSize: isUrdu ? 14.5 : 14,
                    height: 1.65,
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            )
          else
            SelectableText(
              content,
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
              textAlign: isUrdu ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: const Color(0xFFE2E8F0),
                fontSize: isUrdu ? 14.5 : 14,
                height: 1.65,
                letterSpacing: 0.2,
              ),
            ),

          // Divider line before source label
          const Divider(
            color: Color(0xFF263244),
            height: 20,
            thickness: 1,
          ),

          // Small pill label: "ذریعہ: IGN" - Non-clickable, just text credit
          Align(
            alignment: isUrdu ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2838),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2E3E56),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.newspaper_rounded,
                    size: 13,
                    color: Color(0xFF00FF88),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isUrdu ? 'ذریعہ: $sourceName' : 'Source: $sourceName',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.2,
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

  Widget _buildBotAvatar(GamingNewsModel news) {
    String avatarUrl = news.effectiveBotAvatar;
    if (avatarUrl.contains('.dicebear.com') && avatarUrl.contains('/svg?')) {
      avatarUrl = avatarUrl.replaceAll('/svg?', '/png?');
    }

    final botInitials = news.effectiveBotName.isNotEmpty
        ? news.effectiveBotName.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join()
        : 'BOT';

    return GestureDetector(
      onTap: _toggleExpand,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF161C27),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00FF88).withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.network(
            avatarUrl,
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: const Color(0xFF161C27),
                child: const Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFF00FF88),
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF1A2230),
              child: Center(
                child: Text(
                  botInitials.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroFallbackBanner(GamingNewsModel news) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0D121B),
            Color(0xFF182232),
            Color(0xFF0B0F15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Cyber grid background pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00FF88), width: 1.5),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      news.category.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF00FF88),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    news.titleEn,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        news.effectiveBotName,
                        style: const TextStyle(
                          color: Color(0xFF8B9BB4),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      if (news.platform.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 10)),
                        const SizedBox(width: 6),
                        Text(
                          news.platform,
                          style: const TextStyle(
                            color: Color(0xFF00D2FF),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
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
