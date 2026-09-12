import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_post_model.dart';
import '../models/gamer_user_model.dart';
import '../services/profile_service.dart';
import '../widgets/post_card.dart';

/// PostsTab displays all posts for a user profile.
class PostsTab extends StatelessWidget {
  final GamerUser user;
  final bool isOwnProfile;

  const PostsTab({
    super.key,
    required this.user,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProfileFeedItem>>(
      stream: ProfileService().getUserPostsAndClipsStream(
        userId: user.uid,
        username: user.username,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: GamerTheme.accentBlue),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
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
                  'Share gameplay updates and squad room codes!',
                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
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
