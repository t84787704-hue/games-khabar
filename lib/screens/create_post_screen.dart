import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../services/background_upload_manager.dart';
import '../widgets/gamer_avatar.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  final GamerAuthService _authService = GamerAuthService();
  final GamerSocialService _socialService = GamerSocialService();

  String _selectedGameTag = 'BGMI';
  bool _isPosting = false;
  File? _selectedVideoFile;
  double _videoSizeMB = 0.0;
  String? _videoFileName;

  final List<String> _quickTips = [
    'Looking for BGMI squad 🎖️',
    'Clutched 1v4 in Free Fire 🔥',
    'Hit Ace Master rank today! 🏆',
    'Valorant custom match code ⚡',
    'Best sensitivity settings for COD Mobile 🎯',
  ];

  @override
  void initState() {
    super.initState();
    final user = _authService.currentGamer;
    if (user != null && GamerTheme.favoriteGames.contains(user.favoriteGame)) {
      _selectedGameTag = user.favoriteGame;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      if (picked != null) {
        final file = File(picked.path);
        final bytes = await file.length();
        setState(() {
          _selectedVideoFile = file;
          _videoSizeMB = bytes / (1024 * 1024);
          _videoFileName = picked.name.isNotEmpty ? picked.name : 'clip.mp4';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select video: $e'), backgroundColor: GamerTheme.redAccent),
        );
      }
    }
  }

  Future<void> _submitPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedVideoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something or attach a gaming video clip!'), backgroundColor: GamerTheme.redAccent),
      );
      return;
    }

    final user = _authService.currentGamer;
    final uid = _authService.currentUid;
    if (user == null || uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set up your Gamer ID first'), backgroundColor: GamerTheme.redAccent),
      );
      return;
    }

    // IF VIDEO SELECTED: TIKTOK ULTRAFAST BACKGROUND UPLOAD
    if (_selectedVideoFile != null) {
      BackgroundUploadManager().startVideoUpload(
        videoFile: _selectedVideoFile!,
        text: text.isNotEmpty ? text : '🔥 Gameplay clutch by @${user.username}',
        gameTag: _selectedGameTag,
        userId: uid,
        username: user.username,
        displayName: user.displayName,
        userPhoto: user.photoUrl,
        estimatedDurationSeconds: 180,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.bolt_rounded, color: Colors.yellow, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('TikTok Fast Upload started in background! 🚀'),
              ),
            ],
          ),
          backgroundColor: GamerTheme.cardElevated,
          duration: Duration(seconds: 3),
        ),
      );

      // Close screen immediately like TikTok so user can use feed
      Navigator.of(context).pop();
      return;
    }

    // REGULAR TEXT POST
    setState(() => _isPosting = true);

    try {
      await _socialService.createPost(
        userId: uid,
        username: user.username,
        displayName: user.displayName,
        userPhoto: user.photoUrl,
        text: text,
        gameTag: _selectedGameTag,
      );

      // Refresh local user stats
      await _authService.refreshCurrentGamer();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post published to Gamers ID! 🚀'),
          backgroundColor: GamerTheme.neonGreen,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to publish post: $e'), backgroundColor: GamerTheme.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentGamer;
    final gameColor = GamerTheme.gameColors[_selectedGameTag] ?? GamerTheme.accentBlue;

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: GamerTheme.accentBlue,
                foregroundColor: GamerTheme.bgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'POST',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author info & game tag selector
              Row(
                children: [
                  GamerAvatar(
                    photoUrl: user?.photoUrl ?? '',
                    displayName: user?.displayName ?? 'Gamer',
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Gamer',
                          style: const TextStyle(
                            color: GamerTheme.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '@${user?.username ?? "gamer"}',
                          style: const TextStyle(
                            color: GamerTheme.accentOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Game Tag Selector Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: GamerTheme.cardElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: gameColor.withOpacity(0.5)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGameTag,
                        dropdownColor: GamerTheme.cardElevated,
                        icon: const Icon(Icons.arrow_drop_down, color: GamerTheme.textMuted),
                        items: GamerTheme.favoriteGames.map((g) {
                          final emoji = GamerTheme.gameEmojis[g] ?? '🎮';
                          return DropdownMenuItem<String>(
                            value: g,
                            child: Row(
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  g,
                                  style: TextStyle(
                                    color: GamerTheme.gameColors[g] ?? GamerTheme.accentBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedGameTag = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Main Text Area
              TextField(
                controller: _textController,
                maxLines: 5,
                style: const TextStyle(color: GamerTheme.textWhite, fontSize: 16, height: 1.4),
                decoration: const InputDecoration(
                  hintText: "What's on your mind, Gamer?\n\nShare gameplay status, custom room ID, tips, squad recruitment, or upload video clip...",
                  hintStyle: TextStyle(color: GamerTheme.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),

              const SizedBox(height: 12),

              // Video Attachment Section (TikTok Fast Upload)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.cardElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedVideoFile != null ? GamerTheme.neonGreen : GamerTheme.borderDark,
                    width: _selectedVideoFile != null ? 1.5 : 1,
                  ),
                ),
                child: _selectedVideoFile == null
                    ? InkWell(
                        onTap: _pickVideo,
                        borderRadius: BorderRadius.circular(10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: GamerTheme.accentBlue.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.video_library_rounded, color: GamerTheme.accentBlue, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Attach Video Clip (Up to 3 min / 1000MB)',
                                    style: TextStyle(
                                      color: GamerTheme.textWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: GamerTheme.neonGreen.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          '⚡ TIKTOK FAST UPLOAD',
                                          style: TextStyle(
                                            color: GamerTheme.neonGreen,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'GPU Hardware Compress',
                                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.add_circle_outline_rounded, color: GamerTheme.accentBlue, size: 24),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: GamerTheme.accentBlue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.movie_filter_rounded, color: GamerTheme.accentBlue, size: 24),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _videoFileName ?? 'video_clip.mp4',
                                      style: const TextStyle(
                                        color: GamerTheme.textWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${_videoSizeMB.toStringAsFixed(1)} MB • Hardware GPU Compress Active ⚡',
                                      style: const TextStyle(
                                        color: GamerTheme.accentOrange,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: GamerTheme.redAccent, size: 22),
                                onPressed: () {
                                  setState(() {
                                    _selectedVideoFile = null;
                                    _videoSizeMB = 0.0;
                                    _videoFileName = null;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: GamerTheme.bgDark,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.flash_on_rounded, color: GamerTheme.neonGreen, size: 14),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'TikTok Background Mode: Screen closes immediately on Post!',
                                    style: TextStyle(color: GamerTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 12),
              const Divider(color: GamerTheme.borderDark),
              const SizedBox(height: 8),

              // Quick Inspiration Prompts
              const Text(
                'QUICK STATUS IDEAS:',
                style: TextStyle(
                  color: GamerTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickTips.map((tip) {
                  return InkWell(
                    onTap: () {
                      _textController.text = tip;
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: GamerTheme.cardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GamerTheme.borderDark),
                      ),
                      child: Text(
                        tip,
                        style: const TextStyle(color: GamerTheme.textGray, fontSize: 12),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 30),

              // Pro Tip
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.accentBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GamerTheme.accentBlue.withOpacity(0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.lightbulb_outline_rounded, color: GamerTheme.accentBlue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gamers follow players with active tips, squad codes, and clutch moments.',
                        style: TextStyle(color: GamerTheme.accentBlue, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
