import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../widgets/gamer_avatar.dart';
import 'gamer_profile_screen.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId;
  final String displayName;
  final int initialTabIndex; // 0 = Followers, 1 = Following

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    required this.displayName,
    this.initialTabIndex = 0,
  });

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GamerSocialService _socialService = GamerSocialService();
  final GamerAuthService _authService = GamerAuthService();

  List<GamerUser> _followers = [];
  List<GamerUser> _following = [];
  bool _loadingFollowers = true;
  bool _loadingFollowing = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingFollowers = true;
      _loadingFollowing = true;
    });

    final followers = await _socialService.getFollowers(widget.userId);
    final following = await _socialService.getFollowing(widget.userId);

    if (mounted) {
      setState(() {
        _followers = followers;
        _following = following;
        _loadingFollowers = false;
        _loadingFollowing = false;
      });
    }
  }

  Widget _buildUserList(List<GamerUser> list, bool isLoading, String emptyLabel) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue));
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, color: GamerTheme.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(emptyLabel, style: const TextStyle(color: GamerTheme.textGray, fontSize: 14)),
          ],
        ),
      );
    }

    final currentUid = _authService.currentUid ?? '';

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(color: GamerTheme.borderDark, height: 1),
      itemBuilder: (context, index) {
        final user = list[index];
        final isSelf = user.uid == currentUid;
        final gameColor = GamerTheme.gameColors[user.favoriteGame] ?? GamerTheme.accentBlue;
        final gameEmoji = GamerTheme.gameEmojis[user.favoriteGame] ?? '🎮';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          leading: GamerAvatar(
            photoUrl: user.photoUrl,
            displayName: user.displayName,
            radius: 22,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: user.uid)),
              );
            },
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  user.displayName,
                  style: const TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.check_circle_rounded, color: GamerTheme.accentBlue, size: 14),
            ],
          ),
          subtitle: Row(
            children: [
              Text(
                '@${user.username}',
                style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: gameColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$gameEmoji ${user.favoriteGame}',
                  style: TextStyle(color: gameColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          trailing: isSelf
              ? null
              : StreamBuilder<bool>(
                  stream: _socialService.isFollowingStream(currentUid, user.uid),
                  builder: (context, snap) {
                    final isFollowing = snap.data ?? false;
                    return SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: isFollowing ? GamerTheme.cardElevated : GamerTheme.accentBlue,
                          foregroundColor: isFollowing ? GamerTheme.textGray : GamerTheme.bgDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isFollowing ? GamerTheme.borderLight : Colors.transparent,
                            ),
                          ),
                        ),
                        onPressed: () async {
                          if (isFollowing) {
                            await _socialService.unfollowUser(currentUid: currentUid, targetUid: user.uid);
                          } else {
                            await _socialService.followUser(currentUid: currentUid, targetUid: user.uid);
                          }
                          _loadData();
                        },
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: isFollowing ? GamerTheme.textGray : GamerTheme.bgDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: user.uid)),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        title: Text('${widget.displayName}\'s Network'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: GamerTheme.accentBlue,
          indicatorWeight: 3,
          labelColor: GamerTheme.accentBlue,
          unselectedLabelColor: GamerTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          tabs: [
            Tab(text: 'Followers (${_followers.length})'),
            Tab(text: 'Following (${_following.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(_followers, _loadingFollowers, 'No followers yet'),
          _buildUserList(_following, _loadingFollowing, 'Not following anyone yet'),
        ],
      ),
    );
  }
}
