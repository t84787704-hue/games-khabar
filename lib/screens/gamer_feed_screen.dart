import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_post_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';
import 'gamer_profile_screen.dart';

class GamerFeedScreen extends StatefulWidget {
  const GamerFeedScreen({super.key});

  @override
  State<GamerFeedScreen> createState() => _GamerFeedScreenState();
}

class _GamerFeedScreenState extends State<GamerFeedScreen> {
  final GamerAuthService _authService = GamerAuthService();
  final GamerSocialService _socialService = GamerSocialService();

  // Feed Filter: 'all' or 'following'
  String _feedMode = 'all';
  String _selectedGameTag = 'All';

  final List<String> _gameFilters = ['All', 'BGMI', 'PUBG', 'Free Fire', 'COD Mobile', 'Valorant'];

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
            setState(() {});
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
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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

              // Horizontal Game Filter Chips
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
                      final emoji = GamerTheme.gameEmojis[game] ?? '🎮';

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          avatar: game == 'All' ? null : Text(emoji, style: const TextStyle(fontSize: 12)),
                          label: Text(
                            game,
                            style: TextStyle(
                              color: isSelected ? GamerTheme.bgDark : GamerTheme.textWhite,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: GamerTheme.cardDark,
                          selectedColor: GamerTheme.accentBlue,
                          side: BorderSide(
                            color: isSelected ? GamerTheme.accentBlue : GamerTheme.borderDark,
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

              // Posts Stream List
              StreamBuilder<List<GamerPost>>(
                stream: _socialService.getAllPostsStream(
                  gameTag: _selectedGameTag == 'All' ? null : _selectedGameTag,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue)),
                    );
                  }

                  var posts = snapshot.data ?? [];

                  if (_feedMode == 'following') {
                    // Filter by followed users stream
                    return StreamBuilder<List<String>>(
                      stream: _socialService.getFollowingUserIdsStream(currentUid),
                      builder: (context, followingSnap) {
                        final followingIds = followingSnap.data ?? [];
                        final filteredPosts = posts.where((p) => followingIds.contains(p.userId) || p.userId == currentUid).toList();

                        if (filteredPosts.isEmpty) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyFollowingState(),
                          );
                        }

                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => PostCard(post: filteredPosts[index]),
                            childCount: filteredPosts.length,
                          ),
                        );
                      },
                    );
                  }

                  if (posts.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyAllState(),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => PostCard(post: posts[index]),
                      childCount: posts.length,
                    ),
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
