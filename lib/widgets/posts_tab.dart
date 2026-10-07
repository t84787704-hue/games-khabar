import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_post_model.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/block_service.dart';
import '../services/profile_service.dart';
import '../widgets/post_card.dart';

/// PostsTab displays all posts for a user profile.
class PostsTab extends StatefulWidget {
  final GamerUser user;
  final bool isOwnProfile;

  const PostsTab({
    super.key,
    required this.user,
    required this.isOwnProfile,
  });

  @override
  State<PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<PostsTab>
    with AutomaticKeepAliveClientMixin {
  final _authService = GamerAuthService();
  final _blockService = BlockService();

  Set<String> _blockedIds = {};
  bool _blockedLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBlocked();
  }

  Future<void> _loadBlocked() async {
    final uid = _authService.currentUid ?? '';
    if (uid.isEmpty) {
      if (mounted) setState(() => _blockedLoaded = true);
      return;
    }
    final ids = await _blockService.getBlockedIds(uid);
    if (!mounted) return;
    setState(() {
      _blockedIds = ids;
      _blockedLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_blockedLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: GamerTheme.accentBlue),
      );
    }

    return StreamBuilder<List<ProfileFeedItem>>(
      stream: ProfileService().getUserPostsAndClipsStream(
        userId: widget.user.uid,
        username: widget.user.username,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: GamerTheme.accentBlue),
          );
        }

        final rawItems = snapshot.data ?? [];

        // Filter out blocked users' posts
        final items = rawItems.where((item) {
          final itemUid = item.userId.toString();
          if (widget.isOwnProfile &&
              itemUid == (_authService.currentUid ?? '')) {
            return true;
          }
          return !_blockedIds.contains(itemUid);
        }).toList();

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.post_add_rounded,
                    color: GamerTheme.textMuted, size: 48),
                const SizedBox(height: 10),
                Text(
                  widget.isOwnProfile
                      ? 'You haven\'t posted anything yet.'
                      : '@${widget.user.username} hasn\'t posted yet.',
                  style: const TextStyle(
                      color: GamerTheme.textGray, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Share gameplay updates and squad room codes!',
                  style: TextStyle(
                      color: GamerTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            final item = items[index];

            final post = item.originalPost ??
                GamerPost(
                  postId: item.id,
                  userId: item.userId,
                  username: item.username,
                  displayName: item.displayName,
                  userPhoto: item.userPhoto,
                  text: item.text,
                  gameTag: item.gameTag,
                  likesCount: item.likesCount,
                  commentsCount: item.commentsCount,
                  isVerified: item.isVerified,
                  createdAt: item.createdAt,
                );

            return PostCard(post: post);
          },
        );
      },
    );
  }
}