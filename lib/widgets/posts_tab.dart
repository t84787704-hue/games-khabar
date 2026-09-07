import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_post_model.dart';
import '../models/gamer_user_model.dart';
import '../services/clip_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/post_card.dart';

/// PostsTab displays all text posts and video clips for a user merged together.
/// If doc has videoUrl -> shows VideoPlayer card
/// If doc has text -> shows text card like Feed (PostCard)
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
                  'Share gameplay updates, squad room codes & clips!',
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

            // If doc has videoUrl or is a clip -> show VideoPlayer card
            if (item.videoUrl.isNotEmpty || item.isClip) {
              return ProfileVideoCard(item: item);
            }

            // Otherwise show standard text post card like Feed
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

/// Video Player Card for Clips displayed inside the Gamer Profile Posts tab.
/// Includes video playback with play/pause, looping, mute toggle, and full social actions.
class ProfileVideoCard extends StatefulWidget {
  final ProfileFeedItem item;

  const ProfileVideoCard({super.key, required this.item});

  @override
  State<ProfileVideoCard> createState() => _ProfileVideoCardState();
}

class _ProfileVideoCardState extends State<ProfileVideoCard> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  late int _likesCount;
  bool _isLiked = false;
  final ClipService _clipService = ClipService();
  final GamerAuthService _authService = GamerAuthService();

  @override
  void initState() {
    super.initState();
    _likesCount = widget.item.likesCount;
    final currentUid = _authService.currentGamer?.uid ?? '';
    _isLiked = widget.item.originalClip?.likedBy.contains(currentUid) ?? false;
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.item.videoUrl.isNotEmpty ? widget.item.videoUrl : widget.item.mediaUrl;
    if (url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1.0);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('❌ [PROFILE_VIDEO_CARD] Error initializing video: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void didUpdateWidget(ProfileVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.videoUrl != widget.item.videoUrl ||
        oldWidget.item.mediaUrl != widget.item.mediaUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _hasError = false;
      _isPlaying = false;
      _initVideo();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  Future<void> _toggleLike() async {
    final currentGamer = _authService.currentGamer;
    if (currentGamer == null) return;

    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount = (_likesCount - 1).clamp(0, 999999);
      } else {
        _isLiked = true;
        _likesCount += 1;
      }
    });

    await _clipService.toggleLikeClip(
      clipId: widget.item.id,
      userId: currentGamer.uid,
      authorId: widget.item.userId,
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final gameColor = GamerTheme.gameColors[item.gameTag] ?? GamerTheme.accentOrange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GamerTheme.borderDark),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Avatar, Username, GameTag, Date)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GamerAvatar(
                  photoUrl: item.userPhoto,
                  displayName: item.displayName,
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.displayName,
                              style: const TextStyle(
                                color: GamerTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (item.isVerified)
                            const Icon(Icons.verified, color: Colors.blue, size: 15),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '@${item.username.replaceAll('@', '')}',
                            style: const TextStyle(
                              color: GamerTheme.accentBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.createdAt != null) ...[
                            const Text(' • ', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                            Text(
                              _formatDate(item.createdAt),
                              style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Game Tag Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: gameColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gameColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.movie_creation_outlined, color: GamerTheme.accentOrange, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        item.gameTag,
                        style: TextStyle(
                          color: gameColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Caption Text (if present)
          if (item.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
              child: Text(
                item.text,
                style: const TextStyle(
                  color: GamerTheme.textWhite,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),

          // 3. Video Player Container
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.black,
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 380),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isInitialized && _controller != null)
                    AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio > 0
                          ? _controller!.value.aspectRatio
                          : 16 / 9,
                      child: GestureDetector(
                        onTap: _togglePlayPause,
                        child: VideoPlayer(_controller!),
                      ),
                    )
                  else
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: const Color(0xFF10141D),
                        child: Center(
                          child: _hasError
                              ? const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.videocam_off_rounded, color: GamerTheme.textMuted, size: 40),
                                    SizedBox(height: 6),
                                    Text('Could not load clip', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                                  ],
                                )
                              : const CircularProgressIndicator(color: GamerTheme.accentOrange, strokeWidth: 2.5),
                        ),
                      ),
                    ),

                  // Play / Pause Overlay Icon
                  if (_isInitialized && !_isPlaying)
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // Mute / Unmute Button
                  if (_isInitialized)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: GestureDetector(
                        onTap: _toggleMute,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. Action Bar (Likes, Comments, Share, Audio tag)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Like Button
                InkWell(
                  onTap: _toggleLike,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _isLiked ? Colors.redAccent : GamerTheme.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_likesCount',
                          style: TextStyle(
                            color: _isLiked ? Colors.redAccent : GamerTheme.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Comments count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: GamerTheme.textMuted, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${item.commentsCount}',
                        style: const TextStyle(
                          color: GamerTheme.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Share Button
                InkWell(
                  onTap: () {
                    Share.share(
                      '🔥 Check out @${item.username}\'s gaming clip on Gamers Khabar!\n"${item.text}"\n${item.videoUrl}',
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(Icons.share_rounded, color: GamerTheme.textMuted, size: 18),
                  ),
                ),

                const Spacer(),

                // Audio / Clip Tag
                if (item.songTitle.isNotEmpty)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_note_rounded, color: GamerTheme.accentOrange, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.songTitle,
                            style: const TextStyle(
                              color: GamerTheme.textMuted,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }
}
