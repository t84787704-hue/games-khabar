import '../services/cloudinary_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../constants/gamer_theme.dart';
import '../models/clip_model.dart';
import '../services/clip_service.dart';
import '../services/gamer_auth_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/blue_tick_badge.dart';
import '../widgets/clip_upload_modal.dart';
import 'gamer_profile_screen.dart';

/// Global manager for Clips video playback.
/// Keeps track of active video controllers across all clip cards,
/// and allows immediate pausing when leaving the Clips tab, opening overlays, or minimizing the app.
class ClipsPlaybackManager {
  static final Set<VideoPlayerController> _activeControllers = {};
  static final ValueNotifier<bool> isClipsTabActive = ValueNotifier<bool>(true);

  /// Register an initialized controller
  static void register(VideoPlayerController? controller) {
    if (controller != null) {
      _activeControllers.add(controller);
    }
  }

  /// Unregister when disposed or replaced
  static void unregister(VideoPlayerController? controller) {
    if (controller != null) {
      _activeControllers.remove(controller);
    }
  }

  /// Immediately pauses all active clips so no background audio leaks across tabs/screens
  static void pauseAllClips() {
    for (final c in _activeControllers.toList()) {
      try {
        if (c.value.isInitialized && c.value.isPlaying) {
          c.pause();
        }
      } catch (_) {}
    }
  }
}

class ClipsScreen extends StatefulWidget {
  final bool isTabActive;

  const ClipsScreen({
    super.key,
    this.isTabActive = true,
  });

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends State<ClipsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final ClipService _clipService = ClipService();
  final GamerAuthService _authService = GamerAuthService();
  late AnimationController _spinController;
  int _currentPage = 0;
  final Set<String> _reportedClipIds = {};

  // Fallback default viral gaming clips so feed is immediately addictive & pure gaming
  final List<GamerClip> _defaultClips = [
    const GamerClip(
      id: 'default_1',
      userId: 'pro_sniper_99',
      username: 'MortalSniper',
      displayName: 'AWM King Naman',
      title: 'INSANE 1v4 AWM No-Scope Clutch in Pochinki! 🎯🔥 #BGMI #Sniper',
      mediaUrl: 'https://res.cloudinary.com/fka9mgwu/video/upload/v1789206218/pubg_clutch_clip.mp4',
      thumbnail: 'https://res.cloudinary.com/fka9mgwu/video/upload/so_1,w_540,c_fill/v1789206218/pubg_clutch_clip.jpg',
      gameTag: 'BGMI',
      songTitle: 'Khabar Beats - BGMI Trap Bass',
      likesCount: 1420,
      commentsCount: 238,
      sharesCount: 95,
      viewsCount: 6850,
    ),
    const GamerClip(
      id: 'default_2',
      userId: 'scout_god',
      username: 'DynamoRush',
      displayName: 'DynamoOP',
      title: 'Erangel Bridge Camp 1v4 Squad Wipe with M416 Laser Spray 💀🔥 #BGMI',
      mediaUrl: 'https://res.cloudinary.com/fka9mgwu/video/upload/v1789206225/bgmi_spray_clip.mp4',
      thumbnail: 'https://res.cloudinary.com/fka9mgwu/video/upload/so_1,w_540,c_fill/v1789206225/bgmi_spray_clip.jpg',
      gameTag: 'BGMI',
      songTitle: 'Phonk Gaming Anthem - Brazilian Drift',
      likesCount: 3105,
      commentsCount: 512,
      sharesCount: 380,
      viewsCount: 14200,
    ),
    const GamerClip(
      id: 'default_3',
      userId: 'ace_conqueror_01',
      username: 'JonathanVibes',
      displayName: 'GodL Jonathan',
      title: 'Conqueror Lobby 22 Kills Solo vs Squad Gameplay Highlights 💀⚡',
      mediaUrl: 'https://res.cloudinary.com/fka9mgwu/video/upload/v1789206227/freefire_headshot_clip.mp4',
      thumbnail: 'https://res.cloudinary.com/fka9mgwu/video/upload/so_1,w_540,c_fill/v1789206227/freefire_headshot_clip.jpg',
      gameTag: 'PUBG Mobile',
      songTitle: 'Jonathan Gyro Master Sound',
      likesCount: 5820,
      commentsCount: 890,
      sharesCount: 640,
      viewsCount: 28900,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    ClipsPlaybackManager.isClipsTabActive.addListener(_onGlobalTabActiveChanged);
  }

  void _onGlobalTabActiveChanged() {
    if (!ClipsPlaybackManager.isClipsTabActive.value) {
      ClipsPlaybackManager.pauseAllClips();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(ClipsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTabActive != widget.isTabActive) {
      if (!widget.isTabActive) {
        ClipsPlaybackManager.pauseAllClips();
      }
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ClipsPlaybackManager.pauseAllClips();
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isTabActive && ClipsPlaybackManager.isClipsTabActive.value) {
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ClipsPlaybackManager.isClipsTabActive.removeListener(_onGlobalTabActiveChanged);
    ClipsPlaybackManager.pauseAllClips();
    _pageController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  void _openUploadClipSheet() {
    ClipsPlaybackManager.pauseAllClips();
    final currentGamer = _authService.currentGamer;
    if (currentGamer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create your Gamer ID to upload clips!')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => ClipUploadModalSheet(
        currentGamer: currentGamer,
        onUploadSuccess: () {
          if (mounted && widget.isTabActive && ClipsPlaybackManager.isClipsTabActive.value) {
            setState(() {});
          }
        },
      ),
    );
  }

  void _openCommentsSheet(GamerClip clip) {
    final currentGamer = _authService.currentGamer;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.55,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: GamerTheme.borderLight, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text(
                'Comments (${clip.commentsCount})',
                style: const TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Divider(color: GamerTheme.borderDark),
              Expanded(
                child: StreamBuilder(
                  stream: _clipService.getClipComments(clip.id),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No comments yet. Say something awesome!', style: TextStyle(color: GamerTheme.textMuted)),
                      );
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, idx) {
                        final d = docs[idx].data() as Map<String, dynamic>? ?? {};
                        return ListTile(
                          dense: true,
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(d['username'] ?? 'gamer', style: const TextStyle(color: GamerTheme.accentOrange, fontWeight: FontWeight.bold)),
                              UserBlueTickBadge(userId: d['userId'] ?? '', size: 13),
                            ],
                          ),
                          subtitle: Text(d['text'] ?? '', style: const TextStyle(color: Colors.white)),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(color: GamerTheme.textMuted),
                        filled: true,
                        fillColor: GamerTheme.bgDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: GamerTheme.accentOrange),
                    onPressed: () async {
                      final text = commentController.text.trim();
                      if (text.isEmpty || currentGamer == null) return;
                      await _clipService.addComment(
                        clipId: clip.id,
                        userId: currentGamer.uid,
                        username: currentGamer.username,
                        text: text,
                      );
                      commentController.clear();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReportDialog(GamerClip clip) {
    ClipsPlaybackManager.pauseAllClips();
    final currentGamer = _authService.currentGamer;
    final currentUid = currentGamer?.uid ?? 'guest';

    String selectedReason = 'Non-Gaming Content (Car, Vlog, IRL, etc.)';
    final reasons = [
      'Non-Gaming Content (Car, Vlog, IRL, etc.)',
      'Inappropriate / Offensive Gameplay',
      'Spam, Scam or Misleading Video',
      'Hate Speech or Harassment',
      'Other Policy Violation',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (reportCtx) => StatefulBuilder(
        builder: (ctx, setReportState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).padding.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: GamerTheme.redAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flag_rounded, color: GamerTheme.redAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REPORT VIDEO',
                            style: TextStyle(
                              color: GamerTheme.textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Only gaming screen recordings & memes allowed.',
                            style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'SELECT REASON FOR REPORT',
                  style: TextStyle(
                    color: GamerTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...reasons.map((r) {
                  final isSel = selectedReason == r;
                  return InkWell(
                    onTap: () => setReportState(() => selectedReason = r),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? GamerTheme.redAccent.withOpacity(0.12) : GamerTheme.bgDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? GamerTheme.redAccent : GamerTheme.borderDark,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSel ? GamerTheme.redAccent : Colors.white38,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r,
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.white70,
                                fontSize: 12.5,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(reportCtx);
                      // Remove from user's current feed immediately
                      setState(() {
                        _reportedClipIds.add(clip.id);
                      });
                      await _clipService.reportClip(
                        clipId: clip.id,
                        reporterId: currentUid,
                        reason: selectedReason,
                        clipTitle: clip.title,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Video reported and hidden from your feed. Moderation team notified!'),
                            backgroundColor: GamerTheme.redAccent,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'SUBMIT REPORT & HIDE VIDEO',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: false,
      extendBodyBehindAppBar: false,
      body: Stack(
        children: [
          StreamBuilder<List<GamerClip>>(
            stream: _clipService.getClipsStream(),
            builder: (context, snapshot) {
              final rawClips = (snapshot.data != null && snapshot.data!.isNotEmpty)
                  ? snapshot.data!
                  : _defaultClips;
              final clips = rawClips.where((c) => !_reportedClipIds.contains(c.id)).toList();

              final currentGamer = _authService.currentGamer;
              final currentUid = currentGamer?.uid ?? '';

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: clips.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final clip = clips[index];
                  final isEffectivelyActive = widget.isTabActive && ClipsPlaybackManager.isClipsTabActive.value;

                  return ClipCard(
                    key: ValueKey(clip.id),
                    clip: clip,
                    isActive: index == _currentPage,
                    isTabActive: isEffectivelyActive,
                    isLiked: clip.likedBy.contains(currentUid),
                    spinController: _spinController,
                    onLike: () async {
                      if (currentGamer == null) return;
                      await _clipService.toggleLikeClip(
                        clipId: clip.id,
                        userId: currentGamer.uid,
                        authorId: clip.userId,
                      );
                    },
                    onComment: () => _openCommentsSheet(clip),
                    onShare: () {
                      Share.share(
                        '🔥 Check out this sick gaming clip by ${clip.displayName} on Gamers Khabar!\n"${clip.title}"',
                      );
                    },
                    onReport: () => _openReportDialog(clip),
                    onProfileTap: () {
                      if (clip.userId.isNotEmpty) {
                        ClipsPlaybackManager.pauseAllClips();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: clip.userId)),
                        ).then((_) {
                          if (mounted && widget.isTabActive && ClipsPlaybackManager.isClipsTabActive.value) {
                            setState(() {});
                          }
                        });
                      }
                    },
                  );
                },
              );
            },
          ),

          // Top App Bar Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  const Text(
                    'CLIPS & MEMES',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.0,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: GamerTheme.accentOrange,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: GamerTheme.accentOrange.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: _openUploadClipSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_circle_rounded, color: GamerTheme.bgDark, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'POST CLIP',
                              style: TextStyle(
                                color: GamerTheme.bgDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// TikTok / Reels style video player card for gaming clips.
/// - Fullscreen video playback using video_player
/// - CircularProgressIndicator while video is loading
/// - Auto-play when visible, pause when scrolled away
/// - Tap to pause / resume with animated indicator
/// - Social interaction overlays (Avatar, Likes, Comments, Share, Audio tag)
class ClipCard extends StatefulWidget {
  final GamerClip clip;
  final bool isActive;
  final bool isTabActive;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onProfileTap;
  final AnimationController spinController;

  const ClipCard({
    super.key,
    required this.clip,
    required this.isActive,
    this.isTabActive = true,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onReport,
    required this.onProfileTap,
    required this.spinController,
  });

  @override
  State<ClipCard> createState() => _ClipCardState();
}

class _ClipCardState extends State<ClipCard> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _userPaused = false;
  bool _hasCountedView = false;

  bool get _isVideo {
    final url = widget.clip.mediaUrl.toLowerCase();
    return url.contains('.mp4') ||
        url.contains('.mov') ||
        url.contains('.webm') ||
        url.contains('.mkv') ||
        url.contains('/video/upload/') ||
        url.contains('video');
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _initVideo();
    } else if (widget.isActive && widget.isTabActive && !_hasCountedView) {
      _hasCountedView = true;
      ClipService().incrementClipViews(widget.clip.id);
    }
  }

  Future<void> _initVideo() async {
    try {
      final videoUri = Uri.parse(widget.clip.mediaUrl);
      print('🎬 [CLIP_CARD] Initializing video: $videoUri');
      final controller = VideoPlayerController.networkUrl(videoUri);
      _controller = controller;
      ClipsPlaybackManager.register(controller);

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1.0);

      if (!mounted) {
        ClipsPlaybackManager.unregister(controller);
        try {
          controller.pause();
          controller.dispose();
        } catch (_) {}
        return;
      }

      setState(() {
        _isInitialized = true;
      });

      // Auto-play only if active on page AND active on tab
      if (widget.isActive && widget.isTabActive && !_userPaused) {
        controller.play();
        if (!_hasCountedView) {
          _hasCountedView = true;
          ClipService().incrementClipViews(widget.clip.id);
        }
      }
    } catch (e) {
      print('❌ [CLIP_CARD] Video initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(ClipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip.mediaUrl != widget.clip.mediaUrl) {
      ClipsPlaybackManager.unregister(_controller);
      try {
        _controller?.pause();
        _controller?.dispose();
      } catch (_) {}
      _controller = null;
      _isInitialized = false;
      _hasError = false;
      _userPaused = false;
      _hasCountedView = false;
      if (_isVideo) {
        _initVideo();
      }
    } else {
      // Auto-play when active and on active tab; pause when away or tab changed
      final shouldPlay = widget.isActive && widget.isTabActive && !_userPaused;
      if (shouldPlay) {
        if (_controller != null && _isInitialized && !_controller!.value.isPlaying) {
          _controller!.play();
        }
        if (!_hasCountedView) {
          _hasCountedView = true;
          ClipService().incrementClipViews(widget.clip.id);
        }
      } else {
        if (_controller != null && _isInitialized && _controller!.value.isPlaying) {
          _controller!.pause();
        }
      }
    }
  }

  @override
  void deactivate() {
    try {
      _controller?.pause();
    } catch (_) {}
    super.deactivate();
  }

  @override
  void dispose() {
    ClipsPlaybackManager.unregister(_controller);
    try {
      _controller?.pause();
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    super.dispose();
  }

  void _togglePlayPause() {
    if (_hasError || !_isInitialized) {
      // Tap on errored or uninitialized video triggers reload & play
      setState(() {
        _hasError = false;
        _isInitialized = false;
      });
      _initVideo();
      return;
    }
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _userPaused = true;
      } else {
        _controller!.play();
        _userPaused = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;

    // Derive Cloudinary video thumbnail if image URL is empty
    String displayImageUrl = clip.thumbnail;
    if (displayImageUrl.isEmpty) {
      if (clip.mediaUrl.contains('cloudinary.com') && _isVideo) {
        displayImageUrl = clip.mediaUrl
            .replaceAll('/video/upload/', '/video/upload/so_0,w_720,c_fill/')
            .replaceAll(RegExp(r'\.(mp4|mov|webm|mkv)(\?.*)?$', caseSensitive: false), '.jpg');
      } else {
        displayImageUrl = clip.mediaUrl;
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fullscreen Video / Thumbnail Surface
        GestureDetector(
          onTap: _togglePlayPause,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isVideo && _isInitialized && _controller != null)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: (_controller!.value.size.width > 0) ? _controller!.value.size.width : 720,
                      height: (_controller!.value.size.height > 0) ? _controller!.value.size.height : 1280,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              else
                // Thumbnail / placeholder image while loading or for non-video items
                Image.network(
                  displayImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E1430), Color(0xFF0F0818), Color(0xFF160D25)],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                              border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.8), width: 2),
                            ),
                            child: Icon(
                              _hasError ? Icons.refresh_rounded : Icons.sports_esports_rounded,
                              size: 48,
                              color: GamerTheme.accentOrange,
                            ),
                          ),
                          if (_hasError) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Tap to play / reload video ▶',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              // CircularProgressIndicator while video is initializing
              if (_isVideo && !_isInitialized && !_hasError)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: GamerTheme.accentOrange,
                      strokeWidth: 3,
                    ),
                  ),
                ),

              // Play Icon overlay when paused by user tap
              if (_isInitialized && _controller != null && !_controller!.value.isPlaying)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. Gradient overlays (Top and Bottom for contrast)
        IgnorePointer(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black54,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black87,
                ],
                stops: [0.0, 0.22, 0.65, 1.0],
              ),
            ),
          ),
        ),

        // 3. Top-left Game Badge (e.g. BGMI)
        Positioned(
          left: 16,
          top: MediaQuery.of(context).padding.top + 54,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GamerTheme.accentOrange, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: GamerTheme.accentOrange.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_esports_rounded, color: GamerTheme.accentOrange, size: 14),
                const SizedBox(width: 5),
                Text(
                  (clip.gameTag.isNotEmpty ? clip.gameTag : 'GAMING').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 4. Right Action Column (Avatar, Likes, Comments, Share, Views, Report, Audio Disc)
        Positioned(
          right: 12,
          bottom: 30,
          child: Column(
            children: [
              // Author Avatar with profile navigation
              GestureDetector(
                onTap: widget.onProfileTap,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: GamerTheme.accentOrange, width: 2),
                  ),
                  child: GamerAvatar(
                    photoUrl: clip.userAvatar,
                    displayName: clip.displayName,
                    radius: 22,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Like Button
              _buildActionButton(
                icon: widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: widget.isLiked ? Colors.redAccent : Colors.white,
                label: '${clip.likesCount}',
                onTap: widget.onLike,
              ),

              const SizedBox(height: 12),

              // Comment Button
              _buildActionButton(
                icon: Icons.chat_bubble_rounded,
                color: Colors.white,
                label: '${clip.commentsCount}',
                onTap: widget.onComment,
              ),

              const SizedBox(height: 12),

              // Share Button
              _buildActionButton(
                icon: Icons.share_rounded,
                color: Colors.white,
                label: 'Share',
                onTap: widget.onShare,
              ),

              const SizedBox(height: 12),

              // Views Count
              _buildActionButton(
                icon: Icons.visibility_rounded,
                color: Colors.white,
                label: _formatCount(clip.viewsCount > 0 ? clip.viewsCount : (clip.likesCount * 3 + 45)),
                onTap: () {},
              ),

              const SizedBox(height: 12),

              // Report Button (Moderation for non-gaming videos)
              _buildActionButton(
                icon: Icons.flag_rounded,
                color: GamerTheme.redAccent,
                label: 'Report',
                onTap: widget.onReport,
              ),

              const SizedBox(height: 14),

              // Spinning Vinyl Disc
              AnimatedBuilder(
                animation: widget.spinController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: widget.spinController.value * 2 * pi,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: GamerTheme.accentBlue, blurRadius: 8)],
                      ),
                      child: const Icon(Icons.music_note_rounded, color: GamerTheme.accentBlue, size: 18),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // 5. Bottom Left Info Overlay: Username, Caption, Music title
        Positioned(
          left: 16,
          bottom: 30,
          right: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author Tag
              GestureDetector(
                onTap: widget.onProfileTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@${clip.username}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                      ),
                    ),
                    UserBlueTickBadge(userId: clip.userId, size: 16),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Caption / Title
              Text(
                clip.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.3,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Music Tag
              Row(
                children: [
                  const Icon(Icons.music_note_rounded, color: GamerTheme.accentOrange, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      clip.songTitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return '$count';
  }
}
