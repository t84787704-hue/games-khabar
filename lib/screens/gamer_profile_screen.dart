import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../models/gamer_post_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/post_card.dart';
import 'create_gamer_id_screen.dart';
import 'followers_following_screen.dart';
import 'gamer_auth_screen.dart';

class GamerProfileScreen extends StatefulWidget {
  final String? userId; // If null, displays currently logged in user's profile

  const GamerProfileScreen({super.key, this.userId});

  @override
  State<GamerProfileScreen> createState() => _GamerProfileScreenState();
}

class _GamerProfileScreenState extends State<GamerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GamerAuthService _authService = GamerAuthService();
  final GamerSocialService _socialService = GamerSocialService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shareProfile(GamerUser user) {
    final text = '🎮 Check out ${user.displayName}\'s Gamer ID on Gamers ID!\n\n'
        'Handle: @${user.username}\n'
        'Game: ${user.favoriteGame} | Rank: ${user.rank}\n'
        'Bio: ${user.bio}\n\n'
        'Join the Mini Facebook for Gamers!';
    Share.share(text);
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardElevated,
        title: const Text('Log Out', style: TextStyle(color: GamerTheme.textWhite)),
        content: const Text('Are you sure you want to log out of Gamers ID?', style: TextStyle(color: GamerTheme.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const GamerAuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String count, String label, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Text(
              count,
              style: const TextStyle(
                color: GamerTheme.textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: GamerTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? '';
    final targetUid = widget.userId ?? currentUid;
    final isOwnProfile = currentUid == targetUid;

    return StreamBuilder<GamerUser?>(
      stream: _authService.userProfileStream(targetUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: GamerTheme.bgDark,
            body: Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue)),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return Scaffold(
            backgroundColor: GamerTheme.bgDark,
            appBar: AppBar(title: const Text('Gamer Profile')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sentiment_dissatisfied_rounded, color: GamerTheme.textMuted, size: 54),
                  const SizedBox(height: 12),
                  const Text('Gamer ID not found or not set up yet.', style: TextStyle(color: GamerTheme.textWhite)),
                  const SizedBox(height: 16),
                  if (isOwnProfile)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.accentBlue),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateGamerIdScreen()),
                        );
                      },
                      child: const Text('Create Your Gamer ID', style: TextStyle(color: GamerTheme.bgDark, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          );
        }

        final gameColor = GamerTheme.gameColors[user.favoriteGame] ?? GamerTheme.accentBlue;
        final gameEmoji = GamerTheme.gameEmojis[user.favoriteGame] ?? '🎮';

        return Scaffold(
          backgroundColor: GamerTheme.bgDark,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: GamerTheme.cardDark,
                  title: Text(
                    isOwnProfile ? 'My Gamer ID' : '@${user.username}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: GamerTheme.accentBlue),
                      onPressed: () => _shareProfile(user),
                    ),
                    if (isOwnProfile)
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: GamerTheme.redAccent),
                        onPressed: _confirmSignOut,
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Facebook-Style Cover Art Placeholder / Gradient
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0F2027),
                                const Color(0xFF203A43),
                                gameColor.withOpacity(0.4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -20,
                                top: -20,
                                child: Icon(
                                  Icons.sports_esports_rounded,
                                  size: 160,
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                top: 50,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(gameEmoji, style: const TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'GAMERS ID NETWORK',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Facebook-Style Circular Profile Photo
                        Positioned(
                          top: 105,
                          left: 20,
                          child: GamerAvatar(
                            photoUrl: user.photoUrl,
                            displayName: user.displayName,
                            radius: 46,
                            hasGlow: true,
                            borderColor: gameColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // User Info & Badges Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display Name + Verified Badge
                        Row(
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                color: GamerTheme.textWhite,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: GamerTheme.accentBlue, size: 20),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // @username
                        Text(
                          '@${user.username}',
                          style: const TextStyle(
                            color: GamerTheme.accentOrange,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        // Bio
                        if (user.bio.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            user.bio,
                            style: const TextStyle(
                              color: GamerTheme.textWhite,
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Favorite Game Badge & Rank Chip
                        Row(
                          children: [
                            // Favorite Game Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: gameColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: gameColor.withOpacity(0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(gameEmoji, style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text(
                                    user.favoriteGame,
                                    style: TextStyle(
                                      color: gameColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Rank Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: GamerTheme.cardElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: GamerTheme.borderLight),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.military_tech_rounded, color: GamerTheme.flameOrange, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.rank,
                                    style: const TextStyle(
                                      color: GamerTheme.flameOrange,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Followers / Following / Posts Counts
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: GamerTheme.cardDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GamerTheme.borderDark),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn('${user.postsCount}', 'Posts', () {
                                _tabController.animateTo(0);
                              }),
                              Container(height: 24, width: 1, color: GamerTheme.borderDark),
                              _buildStatColumn('${user.followersCount}', 'Followers', () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FollowersFollowingScreen(
                                      userId: user.uid,
                                      displayName: user.displayName,
                                      initialTabIndex: 0,
                                    ),
                                  ),
                                );
                              }),
                              Container(height: 24, width: 1, color: GamerTheme.borderDark),
                              _buildStatColumn('${user.followingCount}', 'Following', () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FollowersFollowingScreen(
                                      userId: user.uid,
                                      displayName: user.displayName,
                                      initialTabIndex: 1,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Action Buttons: Edit / Follow / Share
                        Row(
                          children: [
                            if (isOwnProfile) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GamerTheme.accentBlue,
                                    foregroundColor: GamerTheme.bgDark,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CreateGamerIdScreen(isEditing: true, existingUser: user),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: GamerTheme.borderLight),
                                  foregroundColor: GamerTheme.textWhite,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 18, color: GamerTheme.accentOrange),
                                label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () => _shareProfile(user),
                              ),
                            ] else ...[
                              // Follow / Unfollow Button
                              Expanded(
                                child: StreamBuilder<bool>(
                                  stream: _socialService.isFollowingStream(currentUid, user.uid),
                                  builder: (context, snap) {
                                    final isFollowing = snap.data ?? false;
                                    return ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing ? GamerTheme.cardElevated : GamerTheme.accentBlue,
                                        foregroundColor: isFollowing ? GamerTheme.textWhite : GamerTheme.bgDark,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(color: isFollowing ? GamerTheme.borderLight : Colors.transparent),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: 0,
                                      ),
                                      icon: Icon(
                                        isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
                                        size: 18,
                                        color: isFollowing ? GamerTheme.neonGreen : GamerTheme.bgDark,
                                      ),
                                      label: Text(
                                        isFollowing ? 'Following' : 'Follow Gamer',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: isFollowing ? GamerTheme.textWhite : GamerTheme.bgDark,
                                        ),
                                      ),
                                      onPressed: () async {
                                        if (currentUid.isEmpty) return;
                                        if (isFollowing) {
                                          await _socialService.unfollowUser(currentUid: currentUid, targetUid: user.uid);
                                        } else {
                                          await _socialService.followUser(currentUid: currentUid, targetUid: user.uid);
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: GamerTheme.borderLight),
                                  foregroundColor: GamerTheme.textWhite,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 18, color: GamerTheme.accentOrange),
                                label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () => _shareProfile(user),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Facebook-Style Tabs: Posts | About
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: GamerTheme.accentBlue,
                      indicatorWeight: 3,
                      labelColor: GamerTheme.accentBlue,
                      unselectedLabelColor: GamerTheme.textMuted,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: 'Posts'),
                        Tab(icon: Icon(Icons.info_outline_rounded, size: 18), text: 'About'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Posts Tab
                StreamBuilder<List<GamerPost>>(
                  stream: _socialService.getUserPostsStream(user.uid),
                  builder: (context, postSnap) {
                    if (postSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue));
                    }

                    final posts = postSnap.data ?? [];
                    if (posts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.post_add_rounded, color: GamerTheme.textMuted, size: 48),
                            const SizedBox(height: 10),
                            Text(
                              isOwnProfile
                                  ? 'You haven\'t posted anything yet.'
                                  : '@${user.username} hasn\'t posted yet.',
                              style: const TextStyle(color: GamerTheme.textGray, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Share gameplay updates, squad room codes & tips!',
                              style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: posts.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        return PostCard(post: posts[index]);
                      },
                    );
                  },
                ),

                // Tab 2: About Tab (Facebook-style info card)
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAboutCard(
                        icon: Icons.badge_outlined,
                        title: 'Official Gamer Handle',
                        value: '@${user.username}',
                        color: GamerTheme.accentOrange,
                      ),
                      const SizedBox(height: 12),
                      _buildAboutCard(
                        icon: Icons.sports_esports_outlined,
                        title: 'Main Game',
                        value: '$gameEmoji ${user.favoriteGame}',
                        color: gameColor,
                      ),
                      const SizedBox(height: 12),
                      _buildAboutCard(
                        icon: Icons.military_tech_outlined,
                        title: 'Competitive Tier',
                        value: user.rank,
                        color: GamerTheme.flameOrange,
                      ),
                      const SizedBox(height: 12),
                      _buildAboutCard(
                        icon: Icons.calendar_today_outlined,
                        title: 'Member Since',
                        value: user.createdAt != null
                            ? DateFormat('MMMM yyyy').format(user.createdAt!)
                            : '2026',
                        color: GamerTheme.accentBlue,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: GamerTheme.cardGradient,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GamerTheme.borderDark),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: GamerTheme.accentBlue.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_user_outlined, color: GamerTheme.accentBlue, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Verified Gamer ID',
                                    style: TextStyle(
                                      color: GamerTheme.textWhite,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'This Gamer ID is uniquely registered on the Firebase network.',
                                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: GamerTheme.textWhite, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: GamerTheme.bgDark,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
