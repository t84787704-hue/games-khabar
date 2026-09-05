import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_post_model.dart';
import '../models/gaming_news_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../services/gaming_news_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/post_card.dart';
import '../widgets/news_post_card.dart';
import 'create_post_screen.dart';
import 'gamer_profile_screen.dart';
import 'gamer_search_screen.dart';
import 'notifications_screen.dart';

class _FeedItem {
  final String postType; // 'user' or 'news'
  final GamerPost? userPost;
  final GamingNewsModel? newsPost;
  final DateTime timestamp;

  _FeedItem.user(this.userPost)
      : postType = 'user',
        newsPost = null,
        timestamp = userPost?.createdAt ?? DateTime.now();

  _FeedItem.news(this.newsPost)
      : postType = 'news',
        userPost = null,
        timestamp = newsPost?.timestamp ?? DateTime.now();
}

class GamerFeedScreen extends StatefulWidget {
  const GamerFeedScreen({super.key});

  @override
  State<GamerFeedScreen> createState() => _GamerFeedScreenState();
}

class _GamerFeedScreenState extends State<GamerFeedScreen> {
  final GamerAuthService _authService = GamerAuthService();
  final GamerSocialService _socialService = GamerSocialService();
  final GamingNewsService _newsService = GamingNewsService();

  // Feed Filter: 'all' or 'following'
  String _feedMode = 'all';
  String _selectedGameTag = 'All';

  final List<String> _gameFilters = [
    'All',
    'News',
    'BGMI',
    'PUBG',
    'Free Fire',
    'COD Mobile',
    'Valorant',
  ];

  List<_FeedItem> _buildMergedList({
    required List<GamerPost> userPosts,
    required List<GamingNewsModel> newsList,
    required String selectedFilter,
    required String feedMode,
    required List<String> followingIds,
    required String currentUid,
  }) {
    // 1. If 'News' filter chip is selected: show ONLY TYPE B news posts
    if (selectedFilter == 'News') {
      return newsList.map((n) => _FeedItem.news(n)).toList();
    }

    // 2. Filter user posts if Following mode is active
    List<GamerPost> filteredUserPosts = userPosts;
    if (feedMode == 'following') {
      filteredUserPosts = userPosts
          .where((p) => followingIds.contains(p.userId) || p.userId == currentUid)
          .toList();
    }

    // 3. Filter if a specific game is selected (e.g. 'BGMI', 'PUBG')
    if (selectedFilter != 'All') {
      final q = selectedFilter.toLowerCase();
      filteredUserPosts = filteredUserPosts
          .where((p) => p.gameTag.toLowerCase() == q)
          .toList();

      final matchingNews = newsList.where((n) {
        return n.category.toLowerCase().contains(q) ||
            n.titleEn.toLowerCase().contains(q) ||
            n.summary.toLowerCase().contains(q) ||
            n.platform.toLowerCase().contains(q);
      }).toList();

      if (matchingNews.isNotEmpty) {
        return _weaveItems(filteredUserPosts, matchingNews);
      }
      return filteredUserPosts.map((p) => _FeedItem.user(p)).toList();
    }

    // 4. In 'All' filter mode:
    // Weave pattern: After every 1 user post, show 2 news posts so feed is never empty!
    // When a user posts something, it appears instantly at top (index 0).
    return _weaveItems(filteredUserPosts, newsList);
  }

  List<_FeedItem> _weaveItems(
    List<GamerPost> userPosts,
    List<GamingNewsModel> newsList,
  ) {
    final List<_FeedItem> result = [];
    int userIdx = 0;
    int newsIdx = 0;

    // If there are no user posts, show all news articles
    if (userPosts.isEmpty) {
      return newsList.map((n) => _FeedItem.news(n)).toList();
    }

    while (userIdx < userPosts.length || newsIdx < newsList.length) {
      // 1 User post
      if (userIdx < userPosts.length) {
        result.add(_FeedItem.user(userPosts[userIdx++]));
      }

      // 2 News posts
      if (newsIdx < newsList.length) {
        result.add(_FeedItem.news(newsList[newsIdx++]));
      }
      if (newsIdx < newsList.length) {
        result.add(_FeedItem.news(newsList[newsIdx++]));
      }

      // If user posts exhausted, append all remaining news
      if (userIdx >= userPosts.length) {
        while (newsIdx < newsList.length) {
          result.add(_FeedItem.news(newsList[newsIdx++]));
        }
        break;
      }

      // If news exhausted, append all remaining user posts
      if (newsIdx >= newsList.length) {
        while (userIdx < userPosts.length) {
          result.add(_FeedItem.user(userPosts[userIdx++]));
        }
        break;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? '';
    final gamer = _authService.currentGamer;

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: GamerTheme.blueOrangeGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => GamerTheme.blueOrangeGradient.createShader(bounds),
              child: const Text(
                'GAMERS ID',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: GamerTheme.textWhite, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GamerSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_rounded, color: GamerTheme.textWhite, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: GamerAvatar(
              photoUrl: gamer?.photoUrl ?? '',
              displayName: gamer?.displayName ?? 'Gamer',
              radius: 18,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GamerProfileScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: GamerTheme.accentBlue,
          backgroundColor: GamerTheme.cardDark,
          onRefresh: () async {
            await _newsService.syncRssNews();
            if (mounted) setState(() {});
          },
          child: CustomScrollView(
            slivers: [
              // Facebook-Style "What's on your mind" Quick Create Bar
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: GamerTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GamerTheme.borderDark),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        GamerAvatar(
                          photoUrl: gamer?.photoUrl ?? '',
                          displayName: gamer?.displayName ?? 'Gamer',
                          radius: 18,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "What's on your mind, Gamer?",
                            style: TextStyle(
                              color: GamerTheme.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: GamerTheme.blueOrangeGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Post',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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

              // Filter Toggle: All vs Following
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      // All Posts Toggle
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _feedMode = 'all'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _feedMode == 'all' ? GamerTheme.accentBlue : GamerTheme.cardDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _feedMode == 'all' ? GamerTheme.accentBlue : GamerTheme.borderDark,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.public_rounded,
                                    size: 16,
                                    color: _feedMode == 'all' ? GamerTheme.bgDark : GamerTheme.textGray,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'All Gamers',
                                    style: TextStyle(
                                      color: _feedMode == 'all' ? GamerTheme.bgDark : GamerTheme.textGray,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Following Toggle
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _feedMode = 'following'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _feedMode == 'following' ? GamerTheme.accentOrange : GamerTheme.cardDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _feedMode == 'following' ? GamerTheme.accentOrange : GamerTheme.borderDark,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    size: 16,
                                    color: _feedMode == 'following' ? Colors.white : GamerTheme.textGray,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Following',
                                    style: TextStyle(
                                      color: _feedMode == 'following' ? Colors.white : GamerTheme.textGray,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Horizontal Game Filter Chips (including 'News')
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: _gameFilters.length,
                    itemBuilder: (context, index) {
                      final game = _gameFilters[index];
                      final isSelected = _selectedGameTag == game;
                      final isNews = game == 'News';

                      String? emoji;
                      if (game == 'All') {
                        emoji = null;
                      } else if (isNews) {
                        emoji = '📰';
                      } else {
                        emoji = GamerTheme.gameEmojis[game] ?? '🎮';
                      }

                      final activeColor = isNews ? const Color(0xFF00FF88) : GamerTheme.accentBlue;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          avatar: emoji == null
                              ? null
                              : Text(emoji, style: const TextStyle(fontSize: 12)),
                          label: Text(
                            game,
                            style: TextStyle(
                              color: isSelected
                                  ? (isNews ? Colors.black : GamerTheme.bgDark)
                                  : (isNews ? const Color(0xFF00FF88) : GamerTheme.textWhite),
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: isNews
                              ? const Color(0xFF00FF88).withOpacity(0.08)
                              : GamerTheme.cardDark,
                          selectedColor: activeColor,
                          side: BorderSide(
                            color: isSelected
                                ? activeColor
                                : (isNews
                                    ? const Color(0xFF00FF88).withOpacity(0.3)
                                    : GamerTheme.borderDark),
                          ),
                          onSelected: (_) {
                            setState(() => _selectedGameTag = game);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Combined Stream List: Collection "posts" + Collection "gaming_news"
              StreamBuilder<List<GamerPost>>(
                stream: _socialService.getAllPostsStream(
                  gameTag: _selectedGameTag == 'All' || _selectedGameTag == 'News'
                      ? null
                      : _selectedGameTag,
                ),
                builder: (context, postsSnapshot) {
                  return StreamBuilder<List<GamingNewsModel>>(
                    stream: _newsService.getGamingNewsStream(),
                    builder: (context, newsSnapshot) {
                      if (postsSnapshot.connectionState == ConnectionState.waiting &&
                          newsSnapshot.connectionState == ConnectionState.waiting) {
                        return const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(color: GamerTheme.accentBlue),
                          ),
                        );
                      }

                      final userPosts = postsSnapshot.data ?? [];
                      final newsList = newsSnapshot.data ?? [];

                      if (_feedMode == 'following') {
                        // Following filter stream
                        return StreamBuilder<List<String>>(
                          stream: _socialService.getFollowingUserIdsStream(currentUid),
                          builder: (context, followingSnap) {
                            final followingIds = followingSnap.data ?? [];
                            final mergedItems = _buildMergedList(
                              userPosts: userPosts,
                              newsList: newsList,
                              selectedFilter: _selectedGameTag,
                              feedMode: _feedMode,
                              followingIds: followingIds,
                              currentUid: currentUid,
                            );

                            if (mergedItems.isEmpty) {
                              return SliverFillRemaining(
                                hasScrollBody: false,
                                child: _buildEmptyFollowingState(),
                              );
                            }

                            return SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = mergedItems[index];
                                  if (item.postType == 'news' && item.newsPost != null) {
                                    return NewsPostCard(
                                      key: ValueKey('news_${item.newsPost!.id}'),
                                      news: item.newsPost!,
                                    );
                                  } else if (item.userPost != null) {
                                    return PostCard(
                                      key: ValueKey('post_${item.userPost!.postId}'),
                                      post: item.userPost!,
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                                childCount: mergedItems.length,
                              ),
                            );
                          },
                        );
                      }

                      // All Feed Mode
                      final mergedItems = _buildMergedList(
                        userPosts: userPosts,
                        newsList: newsList,
                        selectedFilter: _selectedGameTag,
                        feedMode: _feedMode,
                        followingIds: const [],
                        currentUid: currentUid,
                      );

                      if (mergedItems.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyAllState(),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = mergedItems[index];
                            if (item.postType == 'news' && item.newsPost != null) {
                              return NewsPostCard(
                                key: ValueKey('news_${item.newsPost!.id}'),
                                news: item.newsPost!,
                              );
                            } else if (item.userPost != null) {
                              return PostCard(
                                key: ValueKey('post_${item.userPost!.postId}'),
                                post: item.userPost!,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          childCount: mergedItems.length,
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyAllState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: GamerTheme.cardElevated,
                shape: BoxShape.circle,
                border: Border.all(color: GamerTheme.borderDark),
              ),
              child: const Icon(Icons.sports_esports_rounded, color: GamerTheme.accentBlue, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'No posts in this feed yet',
              style: TextStyle(color: GamerTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Be the first player to share your gameplay status, clutch moment or recruit squad members!',
              textAlign: TextAlign.center,
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.accentBlue,
                foregroundColor: GamerTheme.bgDark,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create First Post', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFollowingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add_rounded, color: GamerTheme.accentOrange, size: 54),
            const SizedBox(height: 14),
            const Text(
              'Follow Gamers to See Their Feed',
              style: TextStyle(color: GamerTheme.textWhite, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Discover and follow fellow BGMI, PUBG, Free Fire, COD and Valorant players to populate this feed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.accentOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                setState(() => _feedMode = 'all');
              },
              child: const Text('Explore All Gamers', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

