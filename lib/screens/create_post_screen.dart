import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
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

  Future<void> _submitPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something before posting!'), backgroundColor: GamerTheme.redAccent),
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
                maxLines: 7,
                style: const TextStyle(color: GamerTheme.textWhite, fontSize: 16, height: 1.4),
                decoration: const InputDecoration(
                  hintText: "What's on your mind, Gamer?\n\nShare gameplay status, custom room ID, tips, squad recruitment...",
                  hintStyle: TextStyle(color: GamerTheme.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
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
