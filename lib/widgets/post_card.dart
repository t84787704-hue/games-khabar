import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_post_model.dart';
import '../models/post_comment_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../widgets/gamer_avatar.dart';
import '../screens/gamer_profile_screen.dart';
import '../services/verification_service.dart';
import '../widgets/rank_badge_widget.dart';
import '../widgets/blue_tick_badge.dart';

class PostCard extends StatefulWidget {
  final dynamic post;
  final VoidCallback? onDeleteTap;

  const PostCard({
    super.key,
    required this.post,
    this.onDeleteTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final GamerSocialService _socialService = GamerSocialService();
  final GamerAuthService _authService = GamerAuthService();
  bool _isAuthorVerified = false;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _isPlayingVideo = false;

  // Safe field getters whether post is GamerPost or Map
  String get postId => (widget.post is GamerPost) ? (widget.post as GamerPost).postId : (widget.post?.id ?? widget.post?.postId ?? '').toString();
  String get userId => (widget.post is GamerPost) ? (widget.post as GamerPost).userId : (widget.post?.userId ?? '').toString();
  String get username => (widget.post is GamerPost) ? (widget.post as GamerPost).username : (widget.post?.username ?? '').toString();
  String get displayName => (widget.post is GamerPost) ? (widget.post as GamerPost).displayName : (widget.post?.displayName ?? username).toString();
  String get userPhoto => (widget.post is GamerPost) ? (widget.post as GamerPost).userPhoto : (widget.post?.userPhoto ?? '').toString();
  String get postText => (widget.post is GamerPost) ? (widget.post as GamerPost).text : (widget.post?.text ?? widget.post?.caption ?? '').toString();
  String get gameTag => (widget.post is GamerPost) ? (widget.post as GamerPost).gameTag : (widget.post?.gameTag ?? widget.post?.game ?? 'Gaming').toString();
  String? get imageUrl => (widget.post is GamerPost) ? (widget.post as GamerPost).imageUrl : widget.post?.imageUrl?.toString();
  String? get videoUrl => (widget.post is GamerPost)
      ? (widget.post as GamerPost).videoUrl
      : (widget.post?.videoUrl ?? widget.post?.cloudinaryUrl ?? widget.post?.video)?.toString();
  int get likesCount => (widget.post is GamerPost) ? (widget.post as GamerPost).likesCount : (widget.post?.likesCount ?? 0);
  int get commentsCount => (widget.post is GamerPost) ? (widget.post as GamerPost).commentsCount : (widget.post?.commentsCount ?? 0);
  DateTime? get createdAt => (widget.post is GamerPost) ? (widget.post as GamerPost).createdAt : widget.post?.createdAt;

  @override
  void initState() {
    super.initState();
    _isAuthorVerified = (widget.post is GamerPost && (widget.post as GamerPost).isVerified) ||
        VerificationService.isVerifiedCached(userId);
    _checkVerification();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _checkVerification();
    }
  }

  Future<void> _checkVerification() async {
    if (userId.isEmpty) return;
    final verified = await VerificationService.isUserVerified(userId);
    if (mounted && verified != _isAuthorVerified) {
      setState(() => _isAuthorVerified = verified);
    }
  }

  Future<void> _startInlineVideo() async {
    final url = videoUrl;
    if (url == null || url.isEmpty) return;

    setState(() => _isPlayingVideo = true);

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        aspectRatio: _videoController!.value.aspectRatio > 0 ? _videoController!.value.aspectRatio : 16 / 9,
      );
      if (mounted) {
        setState(() => _isVideoInitialized = true);
      }
    } catch (e) {
      debugPrint("Error initializing video in post card: $e");
    }
  }

  Future<void> _stopAndDisposeVideo() async {
    try {
      await _videoController?.pause();
      await _chewieController?.pause();
      await _videoController?.dispose();
      _chewieController?.dispose();
      _videoController = null;
      _chewieController = null;
      _isVideoInitialized = false;
    } catch (_) {}
  }

  void _openProfile() {
    _stopAndDisposeVideo();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamerProfileScreen(userId: userId),
      ),
    );
  }

  // Share post with game info, direct video link for WhatsApp preview, and deep link
  Future<void> _sharePost() async {
    const appLink = 'https://play.google.com/store/apps/details?id=com.gamersid.app';
    final deepLink = postId.isNotEmpty ? 'https://gamersid.com/post/$postId' : '';

    final buffer = StringBuffer();
    if (username.isNotEmpty) buffer.writeln('🎮 $displayName (@$username) on Gamers ID');
    if (postText.isNotEmpty) buffer.writeln(postText);
    if (gameTag.isNotEmpty) buffer.writeln('Game: $gameTag');

    final vUrl = videoUrl;
    if (vUrl != null && vUrl.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(vUrl);
    }
    buffer.writeln();
    buffer.writeln('Get the app: $appLink');
    if (deepLink.isNotEmpty) buffer.writeln('View post: $deepLink');

    await Share.share(buffer.toString().trim());
  }

  // Audio cleanup before deleting post
  Future<void> _confirmDelete() async {
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
              // 1. Immediately pause and dispose audio / video
              await _stopAndDisposeVideo();

              // 2. Call custom onDeleteTap or standard Firestore deletion
              if (widget.onDeleteTap != null) {
                widget.onDeleteTap!();
              } else {
                await _socialService.deletePost(
                  postId: postId,
                  userId: userId,
                );
              }

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
      builder: (_) => _CommentsSheet(postId: postId, postAuthorId: userId),
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
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? '';
    final isAuthor = currentUid == userId;
    final gameColor = GamerTheme.gameColors[gameTag] ?? GamerTheme.accentBlue;
    final gameEmoji = GamerTheme.gameEmojis[gameTag] ?? '🎮';
    final vUrl = videoUrl;

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
                  photoUrl: userPhoto,
                  displayName: displayName,
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
                                displayName,
                                style: const TextStyle(
                                  color: GamerTheme.textWhite,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.post is GamerPost)
                              RankBadgeWidget(
                                badge: (widget.post as GamerPost).getRankBadge(),
                                size: 13,
                                showLabel: false,
                              ),
                            UserBlueTickBadge(userId: userId, size: 15),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '@$username',
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
                              _formatTime(createdAt),
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
                        gameTag,
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
          if (postText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                postText,
                style: const TextStyle(
                  color: GamerTheme.textWhite,
                  fontSize: 14.5,
                  height: 1.45,
                ),
              ),
            ),

          // Image Preview
          if (imageUrl != null && imageUrl!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 200,
                    color: GamerTheme.cardElevated,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: GamerTheme.accentBlue),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],

          // Video Player / Thumbnail Preview
          if (vUrl != null && vUrl.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isPlayingVideo && _chewieController != null && _isVideoInitialized
                    ? Container(
                        height: 220,
                        width: double.infinity,
                        color: Colors.black,
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio > 0
                              ? _videoController!.value.aspectRatio
                              : 16 / 9,
                          child: Chewie(controller: _chewieController!),
                        ),
                      )
                    : InkWell(
                        onTap: _startInlineVideo,
                        child: Container(
                          height: 210,
                          width: double.infinity,
                          color: GamerTheme.cardElevated,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Video preview thumbnail
                              CachedNetworkImage(
                                imageUrl: vUrl.endsWith('.mp4')
                                    ? vUrl.replaceAll('.mp4', '.jpg')
                                    : '$vUrl.jpg',
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [GamerTheme.surfaceDark, GamerTheme.cardElevated],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.videogame_asset_rounded, color: GamerTheme.textMuted, size: 48),
                                  ),
                                ),
                              ),
                              // Dark gradient overlay
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.7),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              // Center Play Button
                              Center(
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: GamerTheme.blueOrangeGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: GamerTheme.accentBlue.withOpacity(0.5),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                                ),
                              ),
                              // Top badge: Gaming Clip
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.5)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt_rounded, color: GamerTheme.neonGreen, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'GAMING CLIP • 720P',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Bottom badge: Tap to Play
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tap to Play',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],

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
                  stream: _socialService.isPostLikedStream(postId, currentUid),
                  builder: (context, snapshot) {
                    final isLiked = snapshot.data ?? false;
                    return InkWell(
                      onTap: () {
                        if (currentUid.isEmpty) return;
                        _socialService.toggleLike(
                          postId: postId,
                          userId: currentUid,
                          postAuthorId: userId,
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
                              '$likesCount',
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
                          '$commentsCount',
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
  final String postId;
  final String postAuthorId;

  const _CommentsSheet({
    required this.postId,
    required this.postAuthorId,
  });

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
        postId: widget.postId,
        postAuthorId: widget.postAuthorId,
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

            Expanded(
              child: StreamBuilder<List<PostComment>>(
                stream: _socialService.getCommentsStream(widget.postId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue));
                  }

                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
                                        UserBlueTickBadge(userId: c.userId, size: 13),
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
