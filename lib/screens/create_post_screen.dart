import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../services/supabase_service.dart';
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
  final ImagePicker _picker = ImagePicker();

  String _selectedGameTag = 'BGMI';
  bool _isPosting = false;
  File? _selectedImage;
  bool _isUploadingImage = false;

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

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _submitPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something or attach a photo!'), backgroundColor: GamerTheme.redAccent),
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

    setState(() => _isPosting = true);

    try {
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        setState(() => _isUploadingImage = true);
        try {
          uploadedImageUrl = await SupabaseService.uploadFile(
            file: _selectedImage!,
            folder: 'post_media',
            bucket: SupabaseService.bucketPosts,
          );
        } catch (uploadErr) {
          debugPrint('Supabase upload notice: $uploadErr');
        } finally {
          if (mounted) setState(() => _isUploadingImage = false);
        }
      }

      await _socialService.createPost(
        userId: uid,
        username: user.username,
        displayName: user.displayName,
        userPhoto: user.photoUrl,
        text: text,
        gameTag: _selectedGameTag,
        imageUrl: uploadedImageUrl,
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
                  hintText: "What's on your mind, Gamer?\n\nShare gameplay status, custom room ID, tips, or squad recruitment...",
                  hintStyle: TextStyle(color: GamerTheme.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),

              // Selected Image Preview
              if (_selectedImage != null) ...[
                const SizedBox(height: 12),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    if (_isUploadingImage)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black54,
                          child: const Center(
                            child: CircularProgressIndicator(color: GamerTheme.accentBlue),
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Attach Photo Action Bar
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isPosting ? null : _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 18, color: GamerTheme.accentBlue),
                    label: Text(
                      _selectedImage == null ? 'Add Photo' : 'Change Photo',
                      style: const TextStyle(color: GamerTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GamerTheme.accentBlue.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: GamerTheme.borderDark),
              const SizedBox(height: 12),

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
