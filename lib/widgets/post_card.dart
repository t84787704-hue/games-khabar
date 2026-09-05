import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_post_model.dart';
import '../models/post_comment_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../widgets/gamer_avatar.dart';
import '../screens/gamer_profile_screen.dart';

class PostCard extends StatefulWidget {
  final GamerPost post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final GamerSocialService _socialService = GamerSocialService();
  final GamerAuthService _authService = GamerAuthService();

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamerProfileScreen(userId: widget.post.userId),
      ),
    );
  }

  void _sharePost() {
    final text = '🎮 ${widget.post.displayName} (@${widget.post.username}) on Gamers ID:\n\n'
        '${widget.post.text}\n\n'
        'Game: ${widget.post.gameTag}\n'
        'Join Gamers ID: The Mini Facebook for Gamers!';
    Share.share(text);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardElevated,
        title: const Text('Delete Post', style: TextStyle(color: GamerTheme.textWhite)),
        content: const Text('Are you sure you want to delete this post?', style: TextStyle(color: GamerTheme.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _socialService.deletePost(
                postId: widget.post.postId,
                userId: widget.post.userId,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post deleted'), backgroundColor: GamerTheme.cardHover),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(post: widget.post),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'just now';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? '';
    final isAuthor = currentUid == widget.post.userId;
    final gameColor = GamerTheme.gameColors[widget.post.gameTag] ?? GamerTheme.accentBlue;
    final gameEmoji = GamerTheme.gameEmojis[widget.post.gameTag] ?? '🎮';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, @username, Game Tag & Menu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GamerAvatar(
                  photoUrl: widget.post.userPhoto,
                  displayName: widget.post.displayName,
                  radius: 20,
                  onTap: _openProfile,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _openProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.post.displayName,
                                style: const TextStyle(
                                  color: GamerTheme.textWhite,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.check_circle_rounded, color: GamerTheme.accentBlue, size: 14),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '@${widget.post.username}',
                              style: const TextStyle(
                                color: GamerTheme.accentOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10)),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(widget.post.createdAt),
                              style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Game Tag Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: gameColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gameColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(gameEmoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        widget.post.gameTag,
                        style: TextStyle(
                          color: gameColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                if (isAuthor) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: GamerTheme.textMuted, size: 20),
                    color: GamerTheme.cardElevated,
                    onSelected: (val) {
                      if (val == 'delete') _confirmDelete();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: GamerTheme.redAccent, size: 18),
                            SizedBox(width: 8),
                            Text('Delete Post', style: TextStyle(color: GamerTheme.redAccent, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Post Text Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              widget.post.text,
              style: const TextStyle(
                color: GamerTheme.textWhite,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: GamerTheme.borderDark, height: 1),

          // Bottom Action Bar: Like, Comment, Share
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Like Button
                StreamBuilder<bool>(
                  stream: _socialService.isPostLikedStream(widget.post.postId, currentUid),
                  builder: (context, snapshot) {
                    final isLiked = snapshot.data ?? false;
                    return InkWell(
                      onTap: () {
                        if (currentUid.isEmpty) return;
                        _socialService.toggleLike(
                          postId: widget.post.postId,
                          userId: currentUid,
                          postAuthorId: widget.post.userId,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isLiked ? GamerTheme.redAccent : GamerTheme.textGray,
                              size: 19,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.post.likesCount}',
                              style: TextStyle(
                                color: isLiked ? GamerTheme.redAccent : GamerTheme.textGray,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Comment Button
                InkWell(
                  onTap: _showCommentsSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: GamerTheme.textGray,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.post.commentsCount}',
                          style: const TextStyle(
                            color: GamerTheme.textGray,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Share Button
                InkWell(
                  onTap: _sharePost,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.share_outlined,
                          color: GamerTheme.textGray,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Share',
                          style: TextStyle(
                            color: GamerTheme.textGray,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final GamerPost post;

  const _CommentsSheet({required this.post});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();
  final _socialService = GamerSocialService();
  final _authService = GamerAuthService();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final gamer = _authService.currentGamer;
    final uid = _authService.currentUid;
    if (uid == null || gamer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in and create your Gamer ID to comment')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await _socialService.addComment(
        postId: widget.post.postId,
        postAuthorId: widget.post.userId,
        userId: uid,
        username: gamer.username,
        displayName: gamer.displayName,
        userPhoto: gamer.photoUrl,
        text: text,
      );
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error commenting: $e'), backgroundColor: GamerTheme.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Handle pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GamerTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gamer Discussion',
              style: TextStyle(
                color: GamerTheme.textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: GamerTheme.borderDark, height: 1),

            // Comments List
            Expanded(
              child: StreamBuilder<List<PostComment>>(
                stream: _socialService.getCommentsStream(widget.post.postId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue));
                  }

                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.chat_bubble_outline_rounded, color: GamerTheme.textMuted, size: 36),
                          SizedBox(height: 8),
                          Text('No comments yet.', style: TextStyle(color: GamerTheme.textMuted, fontSize: 13)),
                          Text('Drop your gamer tip or GG below!', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: comments.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final c = comments[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GamerAvatar(
                              photoUrl: c.userPhoto,
                              displayName: c.displayName,
                              radius: 16,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => GamerProfileScreen(userId: c.userId),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: GamerTheme.cardElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: GamerTheme.borderDark),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          c.displayName,
                                          style: const TextStyle(
                                            color: GamerTheme.textWhite,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '@${c.username}',
                                          style: const TextStyle(
                                            color: GamerTheme.accentOrange,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.text,
                                      style: const TextStyle(
                                        color: GamerTheme.textWhite,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(color: GamerTheme.borderDark, height: 1),
            const SizedBox(height: 8),

            // Input Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: GamerTheme.textWhite, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Add a gaming comment...',
                      filled: true,
                      fillColor: GamerTheme.cardElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: GamerTheme.borderDark),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _submitComment,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: GamerTheme.accentBlue),
                        )
                      : const Icon(Icons.send_rounded, color: GamerTheme.accentBlue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
