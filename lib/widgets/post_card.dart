// ═══════════════════════════════════════════════════════════════════════════════
// EXACT DIFF — Fix 5 compile errors in post_card.dart
// -------------------------------------------------------------------------------
// File: lib/widgets/post_card.dart
// Widget: PostCard -> _PostCardState -> build()
//
// PROBLEM:
// Line 340 had `ValueListenableBuilder<GamerUser?>`.
// 1. 'GamerUser' was not imported or defined in this file.
// 2. Dart treated `currentGamer` as generic `Object`, failing `.uid`, `.username`,
//    and `.photoUrl`.
//
// FIX:
// Removed invalid `<GamerUser?>` annotation and used the existing `userPhoto`
// getter inside `ValueListenableBuilder` which already safely reads
// `_authService.currentGamer.photoUrl` reactively.
//
// NO OTHER CODE CHANGED — byte-by-byte same
// ═══════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../constants/gamer_theme.dart';
import '../services/theme_service.dart';
import '../models/gamer_post_model.dart';
import '../models/post_comment_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../widgets/gamer_avatar.dart';
import '../screens/gamer_profile_screen.dart';
import '../services/verification_service.dart';
import '../widgets/rank_badge_widget.dart';
import '../widgets/blue_tick_badge.dart';
import '../services/app_share_service.dart';
import '../services/supabase_service.dart';

class PostCard extends StatefulWidget {
  final dynamic post;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onRepostTap;
  final String? currentUserId;

  const PostCard({
    super.key,
    required this.post,
    this.onDeleteTap,
    this.onCommentTap,
    this.onRepostTap,
    this.currentUserId,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final GamerSocialService _socialService = GamerSocialService();
  final GamerAuthService _authService = GamerAuthService();
  bool _isAuthorVerified = false;
  bool _isRepostedByMe = false;
  int _repostsCountDelta = 0;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _isPlayingVideo = false;

  // Safe field getters whether post is GamerPost, Map, or custom object
  String get postId => (widget.post is GamerPost)
      ? (widget.post as GamerPost).postId
      : (widget.post is Map
          ? (widget.post['id'] ?? widget.post['postId'] ?? widget.post['post_id'] ?? '').toString()
          : (widget.post?.id ?? widget.post?.postId ?? '').toString());

  String get userId => (widget.post is GamerPost)
      ? (widget.post as GamerPost).userId
      : (widget.post is Map
          ? (widget.post['userId'] ?? widget.post['user_id'] ?? '').toString()
          : (widget.post?.userId ?? '').toString());

  String get username => (widget.post is GamerPost)
      ? (widget.post as GamerPost).username
      : (widget.post is Map
          ? (widget.post['username'] ?? widget.post['users']?['username'] ?? '').toString()
          : (widget.post?.username ?? '').toString());

  String get displayName => (widget.post is GamerPost)
      ? (widget.post as GamerPost).displayName
      : (widget.post is Map
          ? (widget.post['displayName'] ?? widget.post['display_name'] ?? widget.post['users']?['display_name'] ?? username).toString()
          : (widget.post?.displayName ?? username).toString());

  String get userPhoto {
    final currentGamer = _authService.currentGamer;
    final currentUid = _authService.currentUid;
    final isCurrent = currentGamer != null &&
        (userId == currentGamer.uid ||
            (currentUid != null && currentUid.isNotEmpty && userId == currentUid) ||
            (username.isNotEmpty &&
                username.toLowerCase() == currentGamer.username.toLowerCase()));

    if (isCurrent && currentGamer.photoUrl.isNotEmpty) {
      return currentGamer.photoUrl;
    }

    return (widget.post is GamerPost)
        ? (widget.post as GamerPost).userPhoto
        : (widget.post is Map
            ? (widget.post['userPhoto'] ??
                    widget.post['user_avatar'] ??
                    widget.post['avatar_url'] ??
                    widget.post['users']?['avatar_url'] ??
                    '')
                .toString()
            : (widget.post?.userPhoto ?? '').toString());
  }

  String get postText => (widget.post is GamerPost)
      ? (widget.post as GamerPost).text
      : (widget.post is Map
          ? (widget.post['text'] ?? widget.post['content'] ?? widget.post['caption'] ?? '').toString()
          : (widget.post?.text ?? widget.post?.caption ?? '').toString());

  String get gameTag => (widget.post is GamerPost)
      ? (widget.post as GamerPost).gameTag
      : (widget.post is Map
          ? (widget.post['gameTag'] ?? widget.post['game_tag'] ?? widget.post['game'] ?? 'Gaming').toString()
          : (widget.post?.gameTag ?? widget.post?.game ?? 'Gaming').toString());

  String? get imageUrl => (widget.post is GamerPost)
      ? (widget.post as GamerPost).imageUrl
      : (widget.post is Map
          ? (widget.post['imageUrl'] ?? widget.post['image_url'])?.toString()
          : widget.post?.imageUrl?.toString());

  String? get videoUrl => (widget.post is GamerPost)
      ? (widget.post as GamerPost).videoUrl
      : (widget.post is Map
          ? (widget.post['videoUrl'] ?? widget.post['video_url'] ?? widget.post['mediaUrl'] ?? widget.post['media_url'] ?? widget.post['video'])?.toString()
          : (widget.post?.videoUrl ?? widget.post?.mediaUrl ?? widget.post?.video)?.toString());

  int get likesCount => (widget.post is GamerPost)
      ? (widget.post as GamerPost).likesCount
      : (widget.post is Map
          ? (widget.post['likesCount'] ?? widget.post['likes_count'] ?? 0)
          : (widget.post?.likesCount ?? 0));

  int get commentsCount => (widget.post is GamerPost)
      ? (widget.post as GamerPost).commentsCount
      : (widget.post is Map
          ? (widget.post['commentsCount'] ?? widget.post['comments_count'] ?? 0)
          : (widget.post?.commentsCount ?? 0));

  int get repostsCount => (widget.post is GamerPost)
      ? (widget.post as GamerPost).repostsCount
      : (widget.post is Map
          ? ((widget.post['repostsCount'] ?? widget.post['reposts_count'] ?? widget.post['shares_count'] ?? 0) as num).toInt()
          : (widget.post?.repostsCount ?? 0));

  bool get isRepost => (widget.post is GamerPost)
      ? (widget.post as GamerPost).isRepost
      : (widget.post is Map
          ? (widget.post['is_repost'] == true || widget.post['isRepost'] == true)
          : (widget.post?.isRepost ?? false));

  String? get repostOfId => (widget.post is GamerPost)
      ? (widget.post as GamerPost).repostOfId
      : (widget.post is Map
          ? (widget.post['repost_of_id'] ?? widget.post['repostOfId'])?.toString()
          : widget.post?.repostOfId?.toString());

  String? get repostType => (widget.post is GamerPost)
      ? (widget.post as GamerPost).repostType
      : (widget.post is Map
          ? (widget.post['repost_type'] ?? widget.post['repostType'])?.toString()
          : widget.post?.repostType?.toString());

  String? get originalAuthorId => (widget.post is GamerPost)
      ? (widget.post as GamerPost).originalAuthorId
      : (widget.post is Map
          ? (widget.post['original_author_id'] ?? widget.post['originalAuthorId'])?.toString()
          : widget.post?.originalAuthorId?.toString());

  String? get originalAuthorUsername => (widget.post is GamerPost)
      ? (widget.post as GamerPost).originalAuthorUsername
      : (widget.post is Map
          ? (widget.post['original_author_username'] ?? widget.post['originalAuthorUsername'])?.toString()
          : widget.post?.originalAuthorUsername?.toString());

  String? get originalAuthorAvatar => (widget.post is GamerPost)
      ? (widget.post as GamerPost).originalAuthorAvatar
      : (widget.post is Map
          ? (widget.post['original_author_avatar'] ?? widget.post['originalAuthorAvatar'])?.toString()
          : widget.post?.originalAuthorAvatar?.toString());

  String? get originalContent => (widget.post is GamerPost)
      ? (widget.post as GamerPost).originalContent
      : (widget.post is Map
          ? (widget.post['original_content'] ?? widget.post['originalContent'])?.toString()
          : widget.post?.originalContent?.toString());

  String? get originalImageUrl => (widget.post is GamerPost)
      ? (widget.post as GamerPost).originalImageUrl
      : (widget.post is Map
          ? (widget.post['original_image_url'] ?? widget.post['originalImageUrl'])?.toString()
          : widget.post?.originalImageUrl?.toString());

  DateTime? get createdAt => (widget.post is GamerPost)
      ? (widget.post as GamerPost).createdAt
      : (widget.post is Map
          ? (widget.post['createdAt'] is DateTime
              ? widget.post['createdAt']
              : (widget.post['created_at'] is String ? DateTime.tryParse(widget.post['created_at']) : null))
          : widget.post?.createdAt);

  @override
  void initState() {
    super.initState();
    _isAuthorVerified = (widget.post is GamerPost && (widget.post as GamerPost).isVerified) ||
        VerificationService.isVerifiedCached(userId);
    _checkVerification();
    _checkIfReposted();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _checkVerification();
      _checkIfReposted();
    }
  }

  Future<void> _checkIfReposted() async {
    final uid = _authService.currentUid ?? widget.currentUserId;
    if (uid == null || uid.isEmpty || postId.isEmpty) return;
    try {
      final res = await SupabaseService.client
          .from('reposts')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', uid)
          .maybeSingle();
      if (mounted && res != null) {
        setState(() => _isRepostedByMe = true);
      }
    } catch (_) {}
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

  // Share post with game info, direct video link for WhatsApp preview, and Play Store link
  Future<void> _sharePost() async {
    await AppShareService.sharePost(
      authorName: displayName,
      username: username,
      content: postText,
      gameTag: gameTag,
      videoUrl: videoUrl,
    );
  }

  // Audio cleanup before deleting post
  Future<void> _confirmDelete() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardElevated,
        title: Text('delete_post_q'.tr(), style: const TextStyle(color: GamerTheme.textWhite)),
        content: Text('confirm_delete_post_desc'.tr(), style: const TextStyle(color: GamerTheme.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr(), style: const TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              // 1. Immediately pause and dispose audio / video
              await _stopAndDisposeVideo();

              // 2. Call custom onDeleteTap or standard database deletion
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
                  SnackBar(content: Text('msg_post_deleted'.tr()), backgroundColor: GamerTheme.cardHover),
                );
              }
            },
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRepostSheet() {
    if (widget.onRepostTap != null) {
      widget.onRepostTap!();
      return;
    }

    final curUid = _authService.currentUid ?? widget.currentUserId ?? '';
    if (curUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('err_login_required_post'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeService.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeService.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              if (_isRepostedByMe) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.repeat_rounded, color: Colors.red, size: 22),
                  ),
                  title: const Text(
                    'Undo Repost',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  subtitle: Text(
                    'Remove this repost from your feed',
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleUndoRepost();
                  },
                ),
              ] else ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.repeat_rounded, color: Color(0xFF00FF88), size: 22),
                  ),
                  title: Text(
                    'Repost',
                    style: TextStyle(fontWeight: FontWeight.bold, color: ThemeService.textPrimary),
                  ),
                  subtitle: Text(
                    'Instantly share this post to your feed',
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleInstantRepost();
                  },
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1877F2).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF1877F2), size: 22),
                ),
                title: Text(
                  'Quote Repost',
                  style: TextStyle(fontWeight: FontWeight.bold, color: ThemeService.textPrimary),
                ),
                subtitle: Text(
                  'Add your own thoughts or caption before reposting',
                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openQuoteRepostDialog();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleInstantRepost() async {
    final curUid = _authService.currentUid ?? widget.currentUserId ?? '';
    if (curUid.isEmpty || postId.isEmpty) return;

    setState(() {
      _isRepostedByMe = true;
      _repostsCountDelta++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.repeat_rounded, color: Color(0xFF00FF88), size: 20),
            SizedBox(width: 8),
            Text('Reposted to your feed! 🔁'),
          ],
        ),
        backgroundColor: Color(0xFF1F2937),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await _socialService.createRepost(
        originalPostId: postId,
        originalAuthorId: userId,
        originalAuthorUsername: username,
        originalAuthorAvatar: userPhoto,
        originalContent: postText,
        originalImageUrl: imageUrl,
        originalGame: gameTag,
        quoteText: null,
      );
    } catch (e) {
      debugPrint('[PostCard] Instant repost error: $e');
    }
  }

  Future<void> _handleUndoRepost() async {
    final curUid = _authService.currentUid ?? widget.currentUserId ?? '';
    if (curUid.isEmpty || postId.isEmpty) return;

    setState(() {
      _isRepostedByMe = false;
      _repostsCountDelta--;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Repost removed'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await _socialService.undoRepost(
        originalPostId: postId,
        userId: curUid,
      );
    } catch (e) {
      debugPrint('[PostCard] Undo repost error: $e');
    }
  }

  void _openQuoteRepostDialog() {
    final quoteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeService.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          bool isSubmitting = false;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: ThemeService.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      Text(
                        'Quote Repost',
                        style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF88),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final quoteText = quoteController.text.trim();
                                if (quoteText.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please add your thoughts or caption.')),
                                  );
                                  return;
                                }
                                setModalState(() => isSubmitting = true);
                                Navigator.pop(ctx);

                                setState(() {
                                  _isRepostedByMe = true;
                                  _repostsCountDelta++;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.edit_note_rounded, color: Color(0xFF00FF88), size: 20),
                                        SizedBox(width: 8),
                                        Text('Quote repost shared! 💬'),
                                      ],
                                    ),
                                    backgroundColor: Color(0xFF1F2937),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );

                                try {
                                  await _socialService.createRepost(
                                    originalPostId: postId,
                                    originalAuthorId: userId,
                                    originalAuthorUsername: username,
                                    originalAuthorAvatar: userPhoto,
                                    originalContent: postText,
                                    originalImageUrl: imageUrl,
                                    originalGame: gameTag,
                                    quoteText: quoteText,
                                  );
                                } catch (e) {
                                  debugPrint('[PostCard] Quote repost error: $e');
                                }
                              },
                        child: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quoteController,
                    maxLines: 4,
                    minLines: 2,
                    autofocus: true,
                    style: TextStyle(color: ThemeService.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Add your comment...',
                      hintStyle: TextStyle(color: ThemeService.textSecondary),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThemeService.cardElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ThemeService.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GamerAvatar(
                              photoUrl: userPhoto,
                              displayName: displayName,
                              radius: 12,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: ThemeService.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '@$username',
                              style: TextStyle(
                                fontSize: 11,
                                color: ThemeService.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (postText.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            postText,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: ThemeService.textPrimary),
                          ),
                        ],
                        if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl!,
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
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
    final currentUid = _authService.currentUid ?? widget.currentUserId ?? '';
    final isAuthor = currentUid == userId;
    final gameColor = GamerTheme.gameColors[gameTag] ?? GamerTheme.accentBlue;
    final gameEmoji = GamerTheme.gameEmojis[gameTag] ?? '🎮';
    final isDark = ThemeService.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeService.border),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repost Banner
          if (isRepost)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  const Icon(Icons.repeat_rounded, size: 14, color: Color(0xFF00FF88)),
                  const SizedBox(width: 6),
                  Text(
                    currentUid == userId ? 'You reposted' : '$displayName reposted',
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Header: Avatar, Name, @username, Game Tag & Menu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ValueListenableBuilder(
                  valueListenable: _authService.currentGamerNotifier,
                  builder: (context, _, __) {
                    return GamerAvatar(
                      photoUrl: userPhoto,
                      displayName: displayName,
                      radius: 20,
                      onTap: _openProfile,
                    );
                  },
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
                                style: TextStyle(
                                  color: ThemeService.textPrimary,
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
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, color: GamerTheme.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Text('delete_post_q'.tr(), style: const TextStyle(color: GamerTheme.redAccent, fontSize: 13)),
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
                style: TextStyle(
                  color: ThemeService.textPrimary,
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

          // Quoted post preview inside the card
          if (repostType == 'quote' && (originalContent != null && originalContent!.isNotEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeService.cardElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (originalAuthorAvatar != null && originalAuthorAvatar!.isNotEmpty) ...[
                          GamerAvatar(
                            photoUrl: originalAuthorAvatar!,
                            displayName: originalAuthorUsername ?? 'gamer',
                            radius: 11,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          '@${originalAuthorUsername ?? "gamer"}',
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      originalContent!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ThemeService.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    if (originalImageUrl != null && originalImageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: originalImageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 120,
                            color: GamerTheme.cardElevated,
                          ),
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),
          const Divider(color: GamerTheme.borderDark, height: 1),

          // Bottom Action Bar: Like, Comment, Repost, Share
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isLiked ? GamerTheme.redAccent : GamerTheme.textGray,
                              size: 19,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$likesCount',
                              style: TextStyle(
                                color: isLiked ? GamerTheme.redAccent : GamerTheme.textGray,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
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
                  onTap: widget.onCommentTap ?? _showCommentsSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: GamerTheme.textGray,
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$commentsCount',
                          style: const TextStyle(
                            color: GamerTheme.textGray,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Repost Button
                InkWell(
                  onTap: _showRepostSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          color: _isRepostedByMe ? const Color(0xFF00FF88) : GamerTheme.textGray,
                          size: 19,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${(repostsCount + _repostsCountDelta) < 0 ? 0 : (repostsCount + _repostsCountDelta)}',
                          style: TextStyle(
                            color: _isRepostedByMe ? const Color(0xFF00FF88) : GamerTheme.textGray,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.share_outlined,
                          color: GamerTheme.textGray,
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'share'.tr(),
                          style: const TextStyle(
                            color: GamerTheme.textGray,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
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
        SnackBar(content: Text('login_create_gamer_id_to_comment'.tr())),
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
            Text(
              'gamer_discussion'.tr(),
              style: const TextStyle(
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: GamerTheme.textMuted, size: 36),
                          const SizedBox(height: 8),
                          Text('no_comments_be_first'.tr(), style: const TextStyle(color: GamerTheme.textMuted, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('drop_gamer_tip'.tr(), style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
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
                      hintText: 'add_gaming_comment'.tr(),
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
