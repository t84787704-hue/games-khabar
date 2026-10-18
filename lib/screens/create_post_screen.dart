import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
  final TextEditingController _textController = TextEditingController();
  final GamerAuthService _authService = GamerAuthService();
  final GamerSocialService _socialService = GamerSocialService();

  bool _isLoading = false;
  String _selectedGame = 'Mobile Games';

  @override
  void initState() {
    super.initState();
    final user = _authService.currentGamer;
    if (user != null && GamerTheme.favoriteGames.contains(user.favoriteGame)) {
      _selectedGame = user.favoriteGame;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _publishPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('err_write_something'.tr()),
          backgroundColor: GamerTheme.accentOrange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sbUserId = await SupabaseService.getCurrentUserId();

      if (sbUserId == null || sbUserId.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('err_login_required_post'.tr()),
              backgroundColor: GamerTheme.redAccent,
            ),
          );
        }
        return;
      }

      final effectiveUid = sbUserId;

      final gamer = _authService.currentGamer;
      final username = (gamer?.username.isNotEmpty == true)
          ? gamer!.username
          : 'gamer';
      final displayName = (gamer?.displayName.isNotEmpty == true)
          ? gamer!.displayName
          : (gamer?.username.isNotEmpty == true ? gamer!.username : 'Gamer');
      final userPhoto = gamer?.photoUrl ?? '';
      final gameTag = (_selectedGame == 'Mobile Games' || _selectedGame == 'All')
          ? 'BGMI'
          : _selectedGame;

      await _socialService.createPost(
        userId: effectiveUid,
        username: username,
        displayName: displayName,
        userPhoto: userPhoto,
        text: text,
        gameTag: gameTag,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('msg_post_published'.tr()),
            backgroundColor: GamerTheme.neonGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error publishing post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_publish_failed'.tr(args: [e.toString()])),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gamer = _authService.currentGamer;
    final displayName = gamer?.displayName.isNotEmpty == true
        ? gamer!.displayName
        : (gamer?.username.isNotEmpty == true ? gamer!.username : 'Gamer');
    final username =
        gamer?.username.isNotEmpty == true ? gamer!.username : 'gamer';

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'create_post_title'.tr(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: GamerTheme.accentBlue),
                    ),
                  )
                : TextButton(
                    onPressed: _publishPost,
                    style: TextButton.styleFrom(
                      backgroundColor: GamerTheme.accentBlue,
                      foregroundColor: GamerTheme.bgDark,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'btn_post_caps'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5),
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GamerAvatar(
                    photoUrl: gamer?.photoUrl ?? '',
                    displayName: displayName,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '@$username',
                          style: const TextStyle(
                            color: GamerTheme.accentOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: GamerTheme.cardElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GamerTheme.borderLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGame,
                        dropdownColor: GamerTheme.cardElevated,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.white70),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        items: [
                          DropdownMenuItem(
                              value: 'Mobile Games',
                              child: Text('cat_mobile_games'.tr())),
                          const DropdownMenuItem(
                              value: 'BGMI', child: Text('BGMI')),
                          const DropdownMenuItem(
                              value: 'Free Fire', child: Text('Free Fire')),
                          const DropdownMenuItem(
                              value: 'COD Mobile', child: Text('COD Mobile')),
                          const DropdownMenuItem(
                              value: 'PUBG PC', child: Text('PUBG PC')),
                          const DropdownMenuItem(
                              value: 'Valorant', child: Text('Valorant')),
                          const DropdownMenuItem(
                              value: 'GTA V', child: Text('GTA V')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedGame = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, height: 1.4),
                  decoration: InputDecoration(
                    hintText: 'create_post_composer_hint'.tr(),
                    hintStyle: const TextStyle(
                        color: GamerTheme.textMuted, fontSize: 15),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
