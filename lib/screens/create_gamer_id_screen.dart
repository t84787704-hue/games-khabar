// ═══════════════════════════════════════════════════════════════════════════════
// CREATE / EDIT GAMER ID SCREEN — Exact Mockup Design + Referral Code System
// File: lib/screens/create_gamer_id_screen.dart
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/gamer_theme.dart';
import '../constants/mobile_games_rank_data.dart';
import '../models/gamer_user_model.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../widgets/gamer_avatar.dart';
import 'coin_store_screen.dart';
import 'gamer_main_navigation_screen.dart';

class CreateGamerIdScreen extends StatefulWidget {
  final bool isEditing;
  final GamerUser? existingUser;

  const CreateGamerIdScreen({
    super.key,
    this.isEditing = false,
    this.existingUser,
  });

  @override
  State<CreateGamerIdScreen> createState() => _CreateGamerIdScreenState();
}

class _CreateGamerIdScreenState extends State<CreateGamerIdScreen> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _rankController = TextEditingController();
  final _gameIdController = TextEditingController();
  final _referralCodeController = TextEditingController();

  String _selectedGame = 'BGMI';
  String _selectedRankGame = 'BGMI (Battlegrounds Mobile India)';
  String _photoUrl = '';
  String _coverUrl = '';
  File? _pickedImageFile;
  File? _pickedCoverFile;
  bool _isSaving = false;

  String _selectedFrame = '';
  List<String> _unlockedFrames = [];
  String _selectedBadge = '';
  List<String> _unlockedBadges = [];

  static const String _defaultBgmiCoverUrl =
      'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80';

  final List<Map<String, dynamic>> _gamingPresets = [
    {'id': 'preset:helmet', 'icon': Icons.sports_motorsports_rounded},
    {'id': 'preset:skull', 'icon': Icons.dangerous_rounded},
    {'id': 'preset:ninja', 'icon': Icons.masks_rounded},
    {'id': 'preset:crown', 'icon': Icons.workspace_premium_rounded},
    {'id': 'preset:crosshair', 'icon': Icons.filter_center_focus_rounded},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingUser != null) {
      final u = widget.existingUser!;
      _usernameController.text = u.username;
      _displayNameController.text = u.displayName;
      _bioController.text = u.bio;
      _selectedGame = GamerTheme.favoriteGames.contains(u.favoriteGame)
          ? u.favoriteGame
          : 'BGMI';
      _selectedRankGame = MobileGamesRankData.resolveGameName(
        u.selectedGame.isNotEmpty ? u.selectedGame : u.favoriteGame,
      );
      final rawUserRank =
          u.selectedRank.isNotEmpty ? u.selectedRank : u.rank;
      _rankController.text = (rawUserRank.isNotEmpty &&
              rawUserRank != 'None' &&
              rawUserRank != 'Skip')
          ? rawUserRank
          : 'Bronze';
      _gameIdController.text =
          u.gameId.isNotEmpty ? u.gameId : '12345';
      _photoUrl = u.photoUrl;
      _coverUrl = u.coverUrl;
      _selectedFrame = u.activeFrame;
      _unlockedFrames = List<String>.from(u.unlockedFrames);
      _selectedBadge = u.activeBadge;
      _unlockedBadges = List<String>.from(u.unlockedBadges);
    } else {
      final fbUser = GamerAuthService().currentUser;
      if (fbUser != null) {
        final meta = fbUser.userMetadata ?? {};
        final fullName = (meta['full_name'] ??
                meta['name'] ??
                meta['display_name'] ??
                '')
            .toString();
        final avatar =
            (meta['avatar_url'] ?? meta['picture'] ?? '').toString();
        _displayNameController.text = fullName;
        if (avatar.isNotEmpty) _photoUrl = avatar;
      }
      _rankController.text = 'Bronze';
      _gameIdController.text = '12345';
    }
    _loadStorePerks();
  }

  Future<void> _loadStorePerks() async {
    final uid = widget.existingUser?.uid ?? GamerAuthService().currentUid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final localFrame = prefs.getString('user_active_frame_$uid') ?? '';
      final localFrames = prefs.getStringList('user_unlocked_frames_$uid') ?? [];
      final localBadge = prefs.getString('user_active_badge_$uid') ?? '';
      final localBadges = prefs.getStringList('user_unlocked_badges_$uid') ?? [];
      final data = await SupabaseService.getUser(uid);
      if (data != null && mounted) {
        setState(() {
          _selectedFrame = (data['activeFrame'] as String?) ?? localFrame;
          _unlockedFrames = List<String>.from(data['unlockedFrames'] ?? localFrames);
          _selectedBadge = (data['activeBadge'] as String?) ?? localBadge;
          _unlockedBadges = List<String>.from(data['unlockedBadges'] ?? localBadges);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _rankController.dispose();
    _gameIdController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  void _showRankComingSoonBanner() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Text('🚀', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Rank verification system is undergoing upgrades!',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF1877F2),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showLockedItemBanner(String itemName) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$itemName is locked! Unlock in Coin Store.'),
        backgroundColor: const Color(0xFF1877F2),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'STORE',
          textColor: Colors.white,
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoinStoreScreen()),
            );
            _loadStorePerks();
          },
        ),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() => _pickedImageFile = File(picked.path));
      }
    } catch (_) {}
  }

  Future<void> _pickCoverFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _pickedCoverFile = File(picked.path));
      }
    } catch (_) {}
  }

  Future<void> _processReferralBonus(String newUid, String inputCode) async {
    final cleanCode = inputCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    try {
      // Find the user whose UID matches or starts with the referral code
      final users = await SupabaseService.query('users', select: 'id,uid,coins');
      Map<String, dynamic>? referrer;

      for (final u in users) {
        final uId = (u['id'] ?? u['uid'] ?? '').toString();
        final candidateCode = CoinWalletService().getReferralCode(uId).toUpperCase();
        if (candidateCode == cleanCode && uId != newUid) {
          referrer = u;
          break;
        }
      }

      if (referrer != null) {
        final referrerUid = (referrer['id'] ?? referrer['uid'] ?? '').toString();

        // 1. Reward the new user +200 coins
        await SupabaseService.awardCoins(
          userId: newUid,
          amount: 200,
          adminId: 'referral_system',
        );

        // 2. Reward the inviter +200 coins
        await SupabaseService.awardCoins(
          userId: referrerUid,
          amount: 200,
          adminId: 'referral_system',
        );
      }
    } catch (e) {
      debugPrint('Referral bonus processing note: $e');
    }
  }

  Future<void> _saveGamerId() async {
    final rawUsername = _usernameController.text.toLowerCase().trim();
    final uid = GamerAuthService().currentUid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      String finalPhotoUrl = _photoUrl;
      if (_pickedImageFile != null) {
        final uploaded = await GamerAuthService().uploadProfilePhoto(_pickedImageFile!, uid);
        if (uploaded.isNotEmpty) finalPhotoUrl = uploaded;
      }

      String finalCoverUrl = _coverUrl;
      if (_pickedCoverFile != null) {
        final uploaded = await GamerAuthService().uploadCoverPhoto(_pickedCoverFile!, uid);
        if (uploaded.isNotEmpty) finalCoverUrl = uploaded;
      }

      final enteredRank = _rankController.text.trim();
      final gamerUser = GamerUser(
        uid: uid,
        username: rawUsername.isNotEmpty ? rawUsername : (widget.existingUser?.username ?? 'gamer'),
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : (rawUsername.isNotEmpty ? rawUsername : 'Gamer'),
        photoUrl: finalPhotoUrl,
        coverUrl: finalCoverUrl.isNotEmpty ? finalCoverUrl : (widget.existingUser?.coverUrl ?? ''),
        bio: _bioController.text.trim(),
        favoriteGame: _selectedGame,
        selectedGame: _selectedRankGame,
        selectedRank: enteredRank,
        rank: enteredRank,
        rankScreenshot: widget.existingUser?.rankScreenshot ?? '',
        rankStatus: widget.existingUser?.rankStatus ?? 'None',
        followersCount: widget.existingUser?.followersCount ?? 0,
        followingCount: widget.existingUser?.followingCount ?? 0,
        postsCount: widget.existingUser?.postsCount ?? 0,
        likesReceived: widget.existingUser?.likesReceived ?? 0,
        reportsCount: widget.existingUser?.reportsCount ?? 0,
        isVerified: widget.existingUser?.isVerified ?? false,
        gameId: _gameIdController.text.trim().isNotEmpty ? _gameIdController.text.trim() : '12345',
        createdAt: widget.existingUser?.createdAt ?? DateTime.now(),
        activeFrame: _selectedFrame,
        unlockedFrames: _unlockedFrames,
        activeBadge: _selectedBadge,
        unlockedBadges: _unlockedBadges,
      );

      await GamerAuthService().saveGamerProfile(gamerUser);

      await SupabaseService.client.from('users').update({
        'avatar_url': finalPhotoUrl,
        'cover_url': finalCoverUrl,
        'display_name': gamerUser.displayName,
        'bio': gamerUser.bio,
        'favorite_game': gamerUser.favoriteGame,
        'game_id': gamerUser.gameId,
        'rank': enteredRank,
        'selected_rank': enteredRank,
        'active_frame': _selectedFrame,
        'active_badge': _selectedBadge,
      }).or('id.eq.$uid,uid.eq.$uid');

      // Process referral code bonus if a new user entered a code
      if (!widget.isEditing && _referralCodeController.text.trim().isNotEmpty) {
        await _processReferralBonus(uid, _referralCodeController.text.trim());
      }

      GamerAuthService().currentGamerNotifier.value = gamerUser;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
        if (widget.isEditing) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const GamerMainNavigationScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        final isDark = ThemeService.isDarkMode;

        final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
        final cardColor = isDark ? const Color(0xFF161B22) : Colors.white;
        final secondaryCard = isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);
        final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
        final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subTextColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: primaryTextColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.isEditing ? 'Edit Gamer ID' : 'Create Gamer ID',
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : _saveGamerId,
                child: Text(
                  widget.isEditing ? 'Save' : 'Done',
                  style: const TextStyle(
                    color: Color(0xFFFF7A00),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cover Photo & Main Avatar
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(color: secondaryCard),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_pickedCoverFile != null)
                            Image.file(_pickedCoverFile!, fit: BoxFit.cover)
                          else if (_coverUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: _coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  Image.network(_defaultBgmiCoverUrl, fit: BoxFit.cover),
                            )
                          else
                            Image.network(_defaultBgmiCoverUrl, fit: BoxFit.cover),
                          Container(color: Colors.black.withOpacity(0.25)),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: InkWell(
                              onTap: _pickCoverFromGallery,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Change Cover Photo',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: -40,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [Color(0xFFFF9432), Color(0xFFFF5400)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF7A00).withOpacity(0.4),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: GamerAvatar(
                              photoUrl: _photoUrl,
                              imageFile: _pickedImageFile,
                              displayName: _displayNameController.text.isNotEmpty
                                  ? _displayNameController.text
                                  : 'Gamer',
                              radius: 40,
                              borderColor: Colors.transparent,
                              frameId: _selectedFrame,
                            ),
                          ),
                          InkWell(
                            onTap: _pickImageFromGallery,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF7A00),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 50),

                Center(
                  child: InkWell(
                    onTap: _pickImageFromGallery,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_rounded, size: 16, color: Color(0xFFFF7A00)),
                        SizedBox(width: 6),
                        Text(
                          'Upload from Gallery',
                          style: TextStyle(
                            color: Color(0xFFFF7A00),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Center(
                  child: Text(
                    'Pro Gamer Avatar Presets',
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _gamingPresets.map((preset) {
                    final isSel = _photoUrl == preset['id'] && _pickedImageFile == null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _pickedImageFile = null;
                            _photoUrl = preset['id'] as String;
                          });
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel ? const Color(0xFF1E293B) : secondaryCard,
                            border: Border.all(
                              color: isSel ? const Color(0xFFFF7A00) : borderColor,
                              width: isSel ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            preset['icon'] as IconData,
                            color: isSel ? Colors.white : subTextColor,
                            size: 22,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar Frame Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('🏆', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                'Avatar Frame',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CoinStoreScreen()),
                              );
                              _loadStorePerks();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C853),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.storefront_rounded, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'STORE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFrameChip('None', '', '🚫', isNone: true),
                            _buildFrameChip('Neon Fire', 'neon_fire', '🔥'),
                            _buildFrameChip('Royal', 'royal_crown', '👑'),
                            _buildFrameChip('Cyber Grid', 'cyber_glitch', '⚡'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Gamer Badge Section
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF1877F2)),
                          const SizedBox(width: 6),
                          Text(
                            'Gamer Badge',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildBadgeChip('None', '', Colors.grey),
                            _buildBadgeChip('PRO ELITE', 'pro_elite', const Color(0xFF1877F2)),
                            _buildBadgeChip('ASSASSIN 💀', 'kd_assassin', const Color(0xFFE11D48)),
                            _buildBadgeChip('CHAMP 🏆', 'room_champion', const Color(0xFFF59E0B)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Gamer Username
                      Row(
                        children: [
                          Text(
                            'Gamer Username',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 14),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person, color: subTextColor, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '@${_usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : "tufailm483"}',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 18),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Favorite Game Dropdown Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: GamerTheme.favoriteGames.contains(_selectedGame)
                                ? _selectedGame
                                : GamerTheme.favoriteGames.first,
                            isExpanded: true,
                            dropdownColor: cardColor,
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: subTextColor),
                            items: GamerTheme.favoriteGames.map((game) {
                              return DropdownMenuItem<String>(
                                value: game,
                                child: Row(
                                  children: [
                                    const Text('⭐', style: TextStyle(fontSize: 15)),
                                    const SizedBox(width: 10),
                                    Text(
                                      game,
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedGame = val);
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // My Game & Rank Proof Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'My Game & Rank Proof',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.shield_outlined, size: 15, color: Color(0xFF1877F2)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1877F2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Text('🚀 ', style: TextStyle(fontSize: 9)),
                                Text(
                                  'COMING SOON',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Rank verification instruction box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0284C7)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Upload a screenshot of your in-game profile showing your rank to get a verified rank badge.',
                                style: TextStyle(
                                  color: Color(0xFF0369A1),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Selected Game & Rank Subtitle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Your Rank',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            'BGMI (Battlegrounds Mobile)',
                            style: TextStyle(
                              color: Color(0xFFFF7A00),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3x3 Grid of Ranks
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.3,
                        children: [
                          _buildRankGridItem('Bronze', isSelected: true),
                          _buildRankGridItem('Silver', icon: Icons.shield_outlined),
                          _buildRankGridItem('Gold', icon: Icons.lock_outline),
                          _buildRankGridItem('Platinum', icon: Icons.shield_outlined),
                          _buildRankGridItem('Diamond', icon: Icons.shield_outlined),
                          _buildRankGridItem('Crown', icon: Icons.lock_outline),
                          _buildRankGridItem('Ace Master', icon: Icons.shield_outlined),
                          _buildRankGridItem('Ace Dominator', icon: Icons.lock_outline),
                          _buildRankGridItem('Conqueror', icon: Icons.lock_outline),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Rank Verification Coming Soon Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF0284C7)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Screenshot must clearly show your in-game IGN and current rank.',
                                    style: TextStyle(
                                      color: Color(0xFF0369A1),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.lock_clock_outlined, size: 15, color: Color(0xFF0369A1)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Rank Verification Coming Soon',
                                        style: TextStyle(
                                          color: Color(0xFF0369A1),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Manual rank verification is currently undergoing system upgrades.',
                                        style: TextStyle(
                                          color: const Color(0xFF0369A1).withOpacity(0.8),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF0284C7)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Bio Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Bio (About You)',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _bioController,
                            builder: (context, value, _) {
                              return Text(
                                '${value.text.length}/100',
                                style: TextStyle(color: subTextColor, fontSize: 11),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _bioController,
                        maxLength: 100,
                        style: TextStyle(color: primaryTextColor, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tell other gamers your playstyle or online timings...',
                          hintStyle: TextStyle(color: subTextColor.withOpacity(0.6), fontSize: 12),
                          filled: true,
                          fillColor: cardColor,
                          counterText: '',
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFF7A00)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Game Character ID
                      Row(
                        children: [
                          Text(
                            'Game Character ID / UID',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.lock_outline, size: 14, color: subTextColor),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            const Text('🎮', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _gameIdController.text.isNotEmpty ? _gameIdController.text : '12345',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Icon(Icons.edit_outlined, size: 16, color: subTextColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Character ID helps teammates search and add you in-game.',
                        style: TextStyle(color: subTextColor, fontSize: 11),
                      ),

                      // ═════════════════════════════════════════════════════════
                      // NEW: Squad Referral Code Box (Only on New Account Creation)
                      // ═════════════════════════════════════════════════════════
                      if (!widget.isEditing) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Squad Referral / Invite Code',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C853).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '+200 COINS',
                                style: TextStyle(
                                  color: Color(0xFF00C853),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              const Text('🎁', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _referralCodeController,
                                  textCapitalization: TextCapitalization.characters,
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    letterSpacing: 1.2,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter referral code (Optional)',
                                    hintStyle: TextStyle(
                                      color: subTextColor.withOpacity(0.6),
                                      fontSize: 12,
                                      letterSpacing: 0,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Have an invite code from a squad friend? Enter it to get +200 free coins!',
                          style: TextStyle(color: subTextColor, fontSize: 11),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Save Changes Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveGamerId,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 3,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check, size: 18, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.isEditing ? 'Save Changes' : 'Join & Save Profile',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Footer
                      Center(
                        child: Text(
                          'Gamers ID Official',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrameChip(String title, String frameId, String emoji, {bool isNone = false}) {
    final isSelected = _selectedFrame == frameId;
    final isUnlocked = isNone || _unlockedFrames.contains(frameId);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          if (isUnlocked) {
            setState(() => _selectedFrame = frameId);
          } else {
            _showLockedItemBanner(title);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFE8D6) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF7A00) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFF7A00) : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (!isUnlocked) ...[
                const SizedBox(width: 4),
                const Icon(Icons.lock_rounded, size: 12, color: Colors.amber),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeChip(String label, String badgeId, Color badgeColor) {
    final isNone = badgeId.isEmpty;
    final isSelected = _selectedBadge == badgeId;
    final isUnlocked = isNone || _unlockedBadges.contains(badgeId);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          if (isUnlocked) {
            setState(() => _selectedBadge = badgeId);
          } else {
            _showLockedItemBanner(label);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isNone
                ? (isSelected ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9))
                : badgeColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.black87 : Colors.transparent,
              width: isSelected ? 1.5 : 0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isNone ? const Color(0xFF0F172A) : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              if (!isUnlocked) ...[
                const SizedBox(width: 4),
                const Icon(Icons.lock_rounded, size: 11, color: Colors.amber),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankGridItem(String rank, {bool isSelected = false, IconData? icon}) {
    return InkWell(
      onTap: _showRankComingSoonBanner,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF7A00) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              const Icon(Icons.check, size: 13, color: Colors.white)
            else if (icon != null)
              Icon(icon, size: 13, color: const Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(
              rank,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.lock,
              size: 11,
              color: isSelected ? Colors.white70 : const Color(0xFF475569),
            ),
          ],
        ),
      ),
    );
  }
}
