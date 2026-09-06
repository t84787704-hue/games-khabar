import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/gamer_theme.dart';
import '../models/clip_model.dart';
import '../services/clip_service.dart';
import '../services/gamer_auth_service.dart';
import '../widgets/gamer_avatar.dart';
import 'gamer_profile_screen.dart';

class ClipsScreen extends StatefulWidget {
  const ClipsScreen({super.key});

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends State<ClipsScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ClipService _clipService = ClipService();
  final GamerAuthService _authService = GamerAuthService();
  late AnimationController _spinController;

  // Fallback default viral BGMI clips so feed is immediately addictive
  final List<GamerClip> _defaultClips = [
    const GamerClip(
      id: 'default_1',
      userId: 'pro_sniper_99',
      username: 'MortalSniper',
      displayName: 'AWM King Naman',
      title: 'INSANE 1v4 AWM No-Scope Clutch in Pochinki! 🎯🔥 #BGMI #Sniper',
      mediaUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1200&auto=format&fit=crop',
      gameTag: 'BGMI',
      songTitle: 'Khabar Beats - BGMI Trap Bass',
      likesCount: 1420,
      commentsCount: 238,
      sharesCount: 95,
    ),
    const GamerClip(
      id: 'default_2',
      userId: 'scout_god',
      username: 'DynamoRush',
      displayName: 'DynamoOP',
      title: 'POV: You rush a bridge camp with a Dacia and survive with 1 HP 😂🚗 #BGMI #Meme',
      mediaUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=1200&auto=format&fit=crop',
      gameTag: 'BGMI',
      songTitle: 'Phonk Gaming Anthem - Brazilian Drift',
      likesCount: 3105,
      commentsCount: 512,
      sharesCount: 380,
    ),
    const GamerClip(
      id: 'default_3',
      userId: 'ace_conqueror_01',
      username: 'JonathanVibes',
      displayName: 'GodL Jonathan',
      title: 'Conqueror Lobby 22 Kills Solo vs Squad Gameplay Highlights 💀⚡',
      mediaUrl: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?q=80&w=1200&auto=format&fit=crop',
      gameTag: 'BGMI',
      songTitle: 'Jonathan Gyro Master Sound',
      likesCount: 5820,
      commentsCount: 890,
      sharesCount: 640,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  void _openUploadClipSheet() {
    final currentGamer = _authService.currentGamer;
    if (currentGamer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create your Gamer ID to upload clips!')),
      );
      return;
    }

    final titleController = TextEditingController();
    final urlController = TextEditingController();
    String selectedTag = 'BGMI';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: GamerTheme.borderLight, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Text('🎬', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text(
                  'POST GAMING CLIP / MEME',
                  style: TextStyle(color: GamerTheme.textWhite, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('CLIP CAPTION / TITLE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Crazy 1v4 clutch in Bootcamp! 🔥 #BGMI',
                hintStyle: const TextStyle(color: GamerTheme.textMuted),
                filled: true,
                fillColor: GamerTheme.bgDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            const Text('IMAGE / CLIP URL', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://images.unsplash.com/... or video link',
                hintStyle: const TextStyle(color: GamerTheme.textMuted),
                filled: true,
                fillColor: GamerTheme.bgDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GamerTheme.accentOrange,
                  foregroundColor: GamerTheme.bgDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  final clip = GamerClip(
                    id: '',
                    userId: currentGamer.uid,
                    username: currentGamer.username,
                    displayName: currentGamer.displayName,
                    userAvatar: currentGamer.photoUrl,
                    title: titleController.text.trim(),
                    mediaUrl: urlController.text.trim().isNotEmpty
                        ? urlController.text.trim()
                        : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1200&auto=format&fit=crop',
                    gameTag: selectedTag,
                    songTitle: 'Original Audio - ${currentGamer.displayName}',
                  );
                  await _clipService.uploadClip(clip);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🔥 Gaming clip posted to Reels feed!'), backgroundColor: GamerTheme.accentOrange),
                    );
                  }
                },
                child: const Text('SHARE TO CLIPS FEED 🚀', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ),
          ],
        ),
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                          title: Text(d['username'] ?? 'gamer', style: const TextStyle(color: GamerTheme.accentOrange, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<List<GamerClip>>(
            stream: _clipService.getClipsStream(),
            builder: (context, snapshot) {
              final clips = (snapshot.data != null && snapshot.data!.isNotEmpty)
                  ? snapshot.data!
                  : _defaultClips;

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: clips.length,
                itemBuilder: (context, index) {
                  return _buildClipItem(clips[index]);
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
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.black45),
                    icon: const Icon(Icons.video_call_rounded, color: GamerTheme.accentOrange, size: 24),
                    onPressed: _openUploadClipSheet,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClipItem(GamerClip clip) {
    final currentGamer = _authService.currentGamer;
    final currentUid = currentGamer?.uid ?? '';
    final isLiked = clip.likedBy.contains(currentUid);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Simulated Video / Image Canvas
        Image.network(
          clip.mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF140D24),
            child: const Center(
              child: Icon(Icons.sports_esports_rounded, size: 80, color: GamerTheme.accentOrange),
            ),
          ),
        ),

        // Gradient Dark Overlays (Top & Bottom)
        Container(
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
              stops: [0.0, 0.25, 0.6, 1.0],
            ),
          ),
        ),

        // Right Action Column (Instagram Reels Style)
        Positioned(
          right: 12,
          bottom: 40,
          child: Column(
            children: [
              // Author Avatar with profile click
              GestureDetector(
                onTap: () {
                  if (clip.userId.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: clip.userId)),
                    );
                  }
                },
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

              const SizedBox(height: 18),

              // Like Button
              _buildActionButton(
                icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isLiked ? Colors.redAccent : Colors.white,
                label: '${clip.likesCount}',
                onTap: () async {
                  if (currentGamer == null) return;
                  await _clipService.toggleLikeClip(
                    clipId: clip.id,
                    userId: currentGamer.uid,
                    authorId: clip.userId,
                  );
                },
              ),

              const SizedBox(height: 16),

              // Comment Button
              _buildActionButton(
                icon: Icons.chat_bubble_rounded,
                color: Colors.white,
                label: '${clip.commentsCount}',
                onTap: () => _openCommentsSheet(clip),
              ),

              const SizedBox(height: 16),

              // Share Button
              _buildActionButton(
                icon: Icons.share_rounded,
                color: Colors.white,
                label: 'Share',
                onTap: () {
                  Share.share('🔥 Check out this sick gaming clip by ${clip.displayName} on Gamers Khabar!\n"${clip.title}"');
                },
              ),

              const SizedBox(height: 18),

              // Spinning Vinyl / Sound Icon
              AnimatedBuilder(
                animation: _spinController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _spinController.value * 2 * pi,
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

        // Bottom Left Info Overlay: Username, Caption, Music tag
        Positioned(
          left: 16,
          bottom: 30,
          right: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author tag
              GestureDetector(
                onTap: () {
                  if (clip.userId.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: clip.userId)),
                    );
                  }
                },
                child: Row(
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
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Colors.blue, size: 16),
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
}
