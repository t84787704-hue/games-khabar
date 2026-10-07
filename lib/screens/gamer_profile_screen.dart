import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/theme_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../services/supabase_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/rank_badge_widget.dart';
import '../services/verification_service.dart';
import '../models/challenge_model.dart';
import '../services/challenge_service.dart';
import '../services/profile_service.dart';
import '../widgets/posts_tab.dart';
import 'create_gamer_id_screen.dart';
import 'followers_following_screen.dart';
import 'gamer_auth_screen.dart';
import 'saved_news_tab_screen.dart';
import 'verification_screen.dart';
import 'profile_screen.dart';
import 'follow_us_screen.dart';
import 'gamer_delete_account_screen.dart';
import 'gamer_download_data_screen.dart';
import '../widgets/coin_history_sheet.dart';

class GamerProfileScreen extends StatefulWidget {
  final String? userId;

  const GamerProfileScreen({super.key, this.userId});

  @override
  State<GamerProfileScreen> createState() => _GamerProfileScreenState();
}

class _GamerProfileScreenState extends State<GamerProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GamerAuthService _authService = GamerAuthService();
  final GamerSocialService _socialService = GamerSocialService();

  VerificationProgress? _liveProgress;
  bool _isCheckingVerification = false;
  String? _lastCheckedUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<GamerUser?> _fetchGamerFromSupabase(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final uuid = SupabaseService.toUuid(userId);
      final row = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', uuid)
          .maybeSingle();

      if (row == null) return null;

      return GamerUser(
        uid: userId,
        username: (row['username'] ?? 'gamer').toString(),
        displayName:
            (row['display_name'] ?? row['username'] ?? 'Gamer').toString(),
        photoUrl: (row['avatar_url'] ?? '').toString(),
        coverUrl: (row['cover_url'] ?? '').toString(),
        bio: (row['bio'] ?? '').toString(),
        favoriteGame: (row['favorite_game'] ?? 'BGMI').toString(),
        selectedGame: (row['selected_game'] ?? '').toString(),
        selectedRank: (row['selected_rank'] ?? '').toString(),
        rank: (row['rank'] ?? '').toString(),
        rankScreenshot: (row['rank_screenshot'] ?? '').toString(),
        rankStatus: (row['rank_status'] ?? 'None').toString(),
        rankVerifiedBy: (row['rank_verified_by'] ?? '').toString(),
        rankRejectReason: (row['rank_reject_reason'] ?? '').toString(),
        isRankVerified: row['is_rank_verified'] == true,
        gameId: (row['game_id'] ?? '').toString(),
        coins: (row['coins'] as num?)?.toInt() ?? 0,
        followersCount: (row['followers_count'] as num?)?.toInt() ?? 0,
        followingCount: (row['following_count'] as num?)?.toInt() ?? 0,
        postsCount: (row['posts_count'] as num?)?.toInt() ?? 0,
        likesReceived: (row['likes_received'] as num?)?.toInt() ?? 0,
        reportsCount: (row['reports_count'] as num?)?.toInt() ?? 0,
        isVerified: row['is_verified'] == true,
        verificationStatus: (row['blue_tick_status'] ?? 'none').toString(),
        activeFrame: (row['active_frame'] ?? '').toString(),
        unlockedFrames: List<String>.from(row['unlocked_frames'] ?? []),
        activeBadge: (row['active_badge'] ?? '').toString(),
        unlockedBadges: List<String>.from(row['unlocked_badges'] ?? []),
        chatColor: (row['chat_color'] ?? '#00FF66').toString(),
        unlockedChatColors:
            List<String>.from(row['unlocked_chat_colors'] ?? []),
        isVipMember: row['is_vip_member'] == true,
        kdRatio: (row['kd_ratio'] as num?)?.toDouble() ?? 0.0,
        createdAt:
            DateTime.tryParse((row['created_at'] ?? '').toString()),
        isRankPublic: row['is_rank_public'] != false,
        isUidPublic: row['is_uid_public'] == true,
        isCoinsPublic: row['is_coins_public'] == true,
        isMemberSincePublic: row['is_member_since_public'] == true,
        isFollowingPublic: row['is_following_public'] != false,
        isFollowersPublic: row['is_followers_public'] != false,
        isBioPublic: row['is_bio_public'] != false,
        isGamePublic: row['is_game_public'] != false,
      );
    } catch (e) {
      debugPrint('[ProfileScreen] Supabase fetch error: $e');
      return null;
    }
  }

  Stream<GamerUser?> _gamerStream(String userId) async* {
    while (true) {
      yield await _fetchGamerFromSupabase(userId);
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> _updatePrivacy({
    bool? isRankPublic,
    bool? isUidPublic,
    bool? isCoinsPublic,
    bool? isMemberSincePublic,
    bool? isFollowingPublic,
    bool? isFollowersPublic,
    bool? isBioPublic,
    bool? isGamePublic,
  }) async {
    final uid = _authService.currentUid ?? '';
    if (uid.isEmpty) return;

    try {
      final uuid = SupabaseService.toUuid(uid);
      final Map<String, dynamic> updates = {};
      if (isRankPublic != null) updates['is_rank_public'] = isRankPublic;
      if (isUidPublic != null) updates['is_uid_public'] = isUidPublic;
      if (isCoinsPublic != null) updates['is_coins_public'] = isCoinsPublic;
      if (isMemberSincePublic != null)
        updates['is_member_since_public'] = isMemberSincePublic;
      if (isFollowingPublic != null)
        updates['is_following_public'] = isFollowingPublic;
      if (isFollowersPublic != null)
        updates['is_followers_public'] = isFollowersPublic;
      if (isBioPublic != null) updates['is_bio_public'] = isBioPublic;
      if (isGamePublic != null) updates['is_game_public'] = isGamePublic;

      if (updates.isEmpty) return;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await SupabaseService.client
          .from('users')
          .update(updates)
          .eq('id', uuid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Privacy settings updated'),
            backgroundColor: Color(0xFF34A853),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      debugPrint('[Profile] Privacy update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Privacy update failed: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  void _showPrivacySettingsSheet(GamerUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          bool rankPublic = user.isRankPublic;
          bool uidPublic = user.isUidPublic;
          bool coinsPublic = user.isCoinsPublic;
          bool memberSincePublic = user.isMemberSincePublic;
          bool followingPublic = user.isFollowingPublic;
          bool followersPublic = user.isFollowersPublic;
          bool bioPublic = user.isBioPublic;
          bool gamePublic = user.isGamePublic;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: const EdgeInsets.only(top: 12, bottom: 28),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCED0D4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE7F3FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_rounded,
                                color: Color(0xFF1877F2), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Privacy Settings',
                              style: TextStyle(
                                color: Color(0xFF050505),
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFF65676B), size: 22),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Choose what others can see on your profile',
                          style:
                              TextStyle(color: Color(0xFF65676B), fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFCED0D4), height: 1),
                    _buildPrivacyTile(
                      icon: Icons.military_tech_rounded,
                      title: 'Show My Rank',
                      subtitle: 'Display your competitive rank publicly',
                      value: rankPublic,
                      onChanged: (v) {
                        setModalState(() => rankPublic = v);
                        _updatePrivacy(isRankPublic: v);
                      },
                    ),
                    _buildPrivacyTile(
                      icon: Icons.tag_rounded,
                      title: 'Show My Game UID',
                      subtitle: 'Make your in-game UID visible',
                      value: uidPublic,
                      onChanged: (v) {
                        setModalState(() => uidPublic = v);
                        _updatePrivacy(isUidPublic: v);
                      },
                    ),
                    _buildPrivacyTile(
                      icon: Icons.monetization_on_rounded,
                      title: 'Show My Coins',
                      subtitle: 'Display your G-Coins balance',
                      value: coinsPublic,
                      onChanged: (v) {
                        setModalState(() => coinsPublic = v);
                        _updatePrivacy(isCoinsPublic: v);
                      },
                    ),
                    _buildPrivacyTile(
                      icon: Icons.calendar_today_rounded,
                      title: 'Show Member Since',
                      subtitle: 'Display when you joined Gamers ID',
                      value: memberSincePublic,
                      onChanged: (v) {
                        setModalState(() => memberSincePublic = v);
                        _updatePrivacy(isMemberSincePublic: v);
                      },
                    ),
                    _buildPrivacyTile(
                      icon: Icons.people_alt_rounded,
                      title: 'Show Followers Count',
                      subtitle: 'Let others see your followers',
                      value: followersPublic,
                      onChanged: (v) {
                        setModalState(() => followersPublic = v);
                        _updatePrivacy(isFollowersPublic: v);
                      },
                    ),
                    _buildPrivacyTile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Show Following Count',
                      subtitle: 'Let others see who you follow',
                      value: followingPublic,
                      onChanged: (v) {
                        setModalState(() => followingPublic = v);
                        _updatePrivacy(isFollowingPublic: v);
                      },
                    ),
                    _buildPrivacyTile(
                      icon: Icons.edit_note_rounded,
                      title: 'Show My Bio',
                      subtitle: 'Display your gamer bio publicly',
                      value: bioPublic,
                      onChanged: (v) {
                        setModalState(() => bioPublic = v);
                        _updatePrivacy(isBioPublic: v);
                      },
                    ),
                    _buildPrivacyTile(
                      icon: Icons.sports_esports_rounded,
                      title: 'Show My Game',
                      subtitle: 'Display your favorite game',
                      value: gamePublic,
                      onChanged: (v) {
                        setModalState(() => gamePublic = v);
                        _updatePrivacy(isGamePublic: v);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrivacyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Color(0xFFE7F3FF),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF1877F2), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF050505),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF65676B), fontSize: 12),
      ),
      value: value,
      activeColor: const Color(0xFF1877F2),
      onChanged: onChanged,
    );
  }

  void _showChangeCoverSheet(BuildContext context, GamerUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCED0D4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Change Cover Photo',
                  style: TextStyle(
                    color: Color(0xFF050505),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose a custom banner or select a BGMI theme',
                  style: TextStyle(color: Color(0xFF65676B), fontSize: 12),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded,
                        color: Color(0xFF1877F2), size: 20),
                  ),
                  title: const Text('Choose from Gallery',
                      style: TextStyle(
                          color: Color(0xFF050505),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  subtitle: const Text('Upload your custom gaming banner',
                      style: TextStyle(
                          color: Color(0xFF65676B), fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadCoverPhoto(user);
                  },
                ),
                const Divider(color: Color(0xFFCED0D4), height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sports_esports_rounded,
                        color: Color(0xFF1877F2), size: 20),
                  ),
                  title: const Text('BGMI Erangel Scrims Banner',
                      style: TextStyle(
                          color: Color(0xFF050505),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  subtitle: const Text('Official action theme',
                      style: TextStyle(
                          color: Color(0xFF65676B), fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setPresetCover(user,
                        'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.military_tech_rounded,
                        color: Color(0xFF1877F2), size: 20),
                  ),
                  title: const Text('BGMI Battlegrounds Cyber Banner',
                      style: TextStyle(
                          color: Color(0xFF050505),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  subtitle: const Text('Action battleground style',
                      style: TextStyle(
                          color: Color(0xFF65676B), fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setPresetCover(user,
                        'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=1200&auto=format&fit=crop&q=80');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadCoverPhoto(GamerUser user) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Uploading cover photo...'),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );

      final file = File(picked.path);
      final uploadedUrl = await _authService.uploadCoverPhoto(file, user.uid);
      final finalUrl = uploadedUrl.isNotEmpty ? uploadedUrl : '';

      if (finalUrl.isNotEmpty) {
        final uuid = SupabaseService.toUuid(user.uid);
        await SupabaseService.client.from('users').update({
          'cover_url': finalUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', uuid);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cover photo updated successfully!'),
              backgroundColor: GamerTheme.accentGreen,
            ),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload cover photo: $e'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _setPresetCover(GamerUser user, String coverUrl) async {
    try {
      final uuid = SupabaseService.toUuid(user.uid);
      await SupabaseService.client.from('users').update({
        'cover_url': coverUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uuid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BGMI cover banner applied!'),
            backgroundColor: GamerTheme.accentGreen,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set cover: $e'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    }
  }

  void _showCelebrationDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Celebration',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved =
            CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE7F3FF),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF1877F2),
                    size: 60,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '🎉 CONGRATULATIONS! 🎉',
                  style: TextStyle(
                    color: Color(0xFF1877F2),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You Are Now Verified!',
                  style: TextStyle(
                    color: Color(0xFF050505),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'You have completed all community requirements! The official Blue Tick ✓ has been permanently added to your Gamer ID and all your posts.',
                  style: TextStyle(
                    color: Color(0xFF65676B),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Awesome! Let\'s Flex 🎮',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _show1v1ChallengeDialog(GamerUser targetUser) {
    final currentGamer = _authService.currentGamer;
    if (currentGamer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please create your Gamer ID to challenge players!')),
      );
      return;
    }

    String selectedGame = targetUser.favoriteGame.isNotEmpty
        ? targetUser.favoriteGame
        : 'BGMI';
    String selectedMode = 'TDM 1v1 Warehouse';
    String selectedWeapon = 'M416 Only';

    final modes = [
      'TDM 1v1 Warehouse',
      'TDM 1v1 Hangar',
      'Room 1v1 Erangel',
      'Sniper 1v1 Ruins'
    ];
    final weapons = [
      'M416 Only',
      'Sniper / AWM Only',
      'Shotgun Only',
      'All Weapons Allowed'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE7F3FF),
                  shape: BoxShape.circle,
                ),
                child: const Text('⚔️', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1v1 CHALLENGE',
                      style: TextStyle(
                        color: Color(0xFF1877F2),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'vs ${targetUser.displayName}',
                      style: const TextStyle(
                        color: Color(0xFF050505),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCED0D4)),
                  ),
                  child: Row(
                    children: [
                      GamerAvatar(
                        photoUrl: targetUser.photoUrl,
                        displayName: targetUser.displayName,
                        radius: 18,
                        frameId: targetUser.activeFrame,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetUser.displayName,
                              style: const TextStyle(
                                  color: Color(0xFF050505),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            Text(
                              'Rank: ${targetUser.rank} • UID: ${targetUser.gameId.isEmpty ? "Not set" : targetUser.gameId}',
                              style: const TextStyle(
                                  color: Color(0xFF65676B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('SELECT MAP / MODE',
                    style: TextStyle(
                        color: Color(0xFF65676B),
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCED0D4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedMode,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      items: modes
                          .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m,
                                  style: const TextStyle(
                                      color: Color(0xFF050505),
                                      fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setDialogState(
                          () => selectedMode = v ?? selectedMode),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('WEAPON RULE',
                    style: TextStyle(
                        color: Color(0xFF65676B),
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCED0D4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedWeapon,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      items: weapons
                          .map((w) => DropdownMenuItem(
                              value: w,
                              child: Text(w,
                                  style: const TextStyle(
                                      color: Color(0xFF050505),
                                      fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setDialogState(
                          () => selectedWeapon = v ?? selectedWeapon),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF65676B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final challenge = GamerChallenge(
                  id: '',
                  challengerId: currentGamer.uid,
                  challengerName: currentGamer.displayName,
                  challengerAvatar: currentGamer.photoUrl,
                  challengedId: targetUser.uid,
                  challengedName: targetUser.displayName,
                  challengedAvatar: targetUser.photoUrl,
                  game: selectedGame,
                  mode: selectedMode,
                  weaponRule: selectedWeapon,
                );
                await ChallengeService().sendChallenge(challenge);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '⚔️ 1v1 Challenge Sent to ${targetUser.displayName}!'),
                    backgroundColor: const Color(0xFF1877F2),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('SEND 1v1 ⚔️',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareProfile(GamerUser user) {
    final text =
        '🎮 Check out ${user.displayName}\'s Gamer ID on Gamers ID!\n\n'
        'Handle: @${user.username}\n'
        'Game: ${user.favoriteGame} | Rank: ${user.rank}\n'
        'Bio: ${user.bio}\n\n'
        'Join the Mini Facebook for Gamers!';
    Share.share(text);
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out',
            style: TextStyle(
                color: Color(0xFF050505), fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to log out of Gamers ID?',
            style: TextStyle(color: Color(0xFF65676B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF65676B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const GamerAuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
      String count, String label, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Text(
              count,
              style: const TextStyle(
                color: Color(0xFF050505),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF65676B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? '';
    final targetUid = widget.userId ?? currentUid;
    final isOwnProfile = currentUid == targetUid;

    return StreamBuilder<GamerUser?>(
      stream: _gamerStream(targetUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFF0F2F5),
            body: Center(
                child: CircularProgressIndicator(color: Color(0xFF1877F2))),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF0F2F5),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 1,
              title: const Text(
                'Gamer Profile',
                style: TextStyle(
                  color: Color(0xFF1877F2),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sentiment_dissatisfied_rounded,
                      color: Color(0xFF65676B), size: 54),
                  const SizedBox(height: 12),
                  const Text('Gamer ID not found or not set up yet.',
                      style: TextStyle(color: Color(0xFF050505))),
                  const SizedBox(height: 16),
                  if (isOwnProfile)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1877F2),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const CreateGamerIdScreen()),
                        );
                      },
                      child: const Text('Create Your Gamer ID',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          );
        }

        final gameColor = GamerTheme.gameColors[user.favoriteGame] ??
            const Color(0xFF1877F2);
        final gameEmoji =
            GamerTheme.gameEmojis[user.favoriteGame] ?? '🎮';

        final bool canShowBio = isOwnProfile || user.isBioPublic;
        final bool canShowGame = isOwnProfile || user.isGamePublic;
        final bool canShowRank = isOwnProfile || user.isRankPublic;
        final bool canShowCoins = isOwnProfile || user.isCoinsPublic;
        final bool canShowMemberSince =
            isOwnProfile || user.isMemberSincePublic;
        final bool canShowFollowers =
            isOwnProfile || user.isFollowersPublic;
        final bool canShowFollowing =
            isOwnProfile || user.isFollowingPublic;
        final bool canShowUid = isOwnProfile || user.isUidPublic;

        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: Colors.white,
                  elevation: 1,
                  automaticallyImplyLeading: !isOwnProfile,
                  iconTheme:
                      const IconThemeData(color: Color(0xFF65676B)),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _showProfileSettingsMenu(
                                user, isOwnProfile),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFCED0D4),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: Color(0xFF65676B),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () {
                            final cover = user.coverUrl.isNotEmpty
                                ? user.coverUrl
                                : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80';
                            _showFullScreenPhotoViewer(
                                imageUrl: cover,
                                title:
                                    '${user.displayName} • Cover Photo');
                          },
                          child: Container(
                            height: 175,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Color(0xFFCED0D4),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: user.coverUrl.isNotEmpty
                                  ? user.coverUrl
                                  : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80',
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: const Color(0xFFCED0D4),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child:
                                        CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF1877F2)),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Image.network(
                                'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 129,
                          left: 20,
                          child: GestureDetector(
                            onTap: () {
                              if (user.photoUrl.isNotEmpty) {
                                _showFullScreenPhotoViewer(
                                    imageUrl: user.photoUrl,
                                    title:
                                        '${user.displayName} • Profile Photo');
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: GamerAvatar(
                                photoUrl: user.photoUrl,
                                displayName: user.displayName,
                                radius: 46,
                                hasGlow: false,
                                borderColor: Colors.transparent,
                                frameId: user.activeFrame,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName,
                                style: const TextStyle(
                                  color: Color(0xFF050505),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!user.isOwnerUser &&
                                canShowRank &&
                                user.isRankApproved &&
                                user.rank.isNotEmpty &&
                                user.rank.toLowerCase() != 'none') ...[
                              const SizedBox(width: 6),
                              RankBadgeWidget(
                                badge: user.getRankBadge(),
                                size: 16,
                                showLabel: true,
                              ),
                            ],
                            if (user.activeBadge.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              GamerBadgeWidget(
                                  badgeId: user.activeBadge, scale: 1.0),
                            ],
                            if (user.hasBlueTick) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified,
                                  color: Color(0xFF1877F2), size: 18),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${user.username}',
                          style: const TextStyle(
                            color: Color(0xFF65676B),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (user.bio.isNotEmpty && canShowBio) ...[
                          const SizedBox(height: 10),
                          Text(
                            user.bio,
                            style: const TextStyle(
                              color: Color(0xFF050505),
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (user.favoriteGame.isNotEmpty && canShowGame)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: gameColor.withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          gameColor.withOpacity(0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(gameEmoji,
                                        style: const TextStyle(
                                            fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Text(
                                      user.favoriteGame,
                                      style: TextStyle(
                                        color: gameColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFCED0D4)),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn(
                                  '${user.postsCount}', 'Posts', () {
                                _tabController.animateTo(0);
                              }),
                              Container(
                                  height: 24,
                                  width: 1,
                                  color: const Color(0xFFCED0D4)),
                              _buildStatColumn(
                                  canShowFollowers
                                      ? '${user.followersCount}'
                                      : '🔒',
                                  'Followers', () {
                                if (!canShowFollowers) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FollowersFollowingScreen(
                                      userId: user.uid,
                                      displayName: user.displayName,
                                      initialTabIndex: 0,
                                    ),
                                  ),
                                );
                              }),
                              Container(
                                  height: 24,
                                  width: 1,
                                  color: const Color(0xFFCED0D4)),
                              _buildStatColumn(
                                  canShowFollowing
                                      ? '${user.followingCount}'
                                      : '🔒',
                                  'Following', () {
                                if (!canShowFollowing) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FollowersFollowingScreen(
                                      userId: user.uid,
                                      displayName: user.displayName,
                                      initialTabIndex: 1,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (isOwnProfile) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF1877F2),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.edit_rounded,
                                      size: 18),
                                  label: const Text('Edit Profile',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CreateGamerIdScreen(
                                          isEditing: true,
                                          existingUser: user,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFE4E6EB),
                                  foregroundColor:
                                      const Color(0xFF050505),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 12),
                                ),
                                icon: const Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 18,
                                    color: Color(0xFF65676B)),
                                label: const Text('Cover',
                                    style: TextStyle(
                                        color: Color(0xFF050505),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                onPressed: () =>
                                    _showChangeCoverSheet(context, user),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFE4E6EB),
                                  foregroundColor:
                                      const Color(0xFF050505),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 12),
                                ),
                                icon: const Icon(Icons.share_rounded,
                                    size: 18,
                                    color: Color(0xFF65676B)),
                                label: const Text('Share',
                                    style: TextStyle(
                                        color: Color(0xFF050505),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                onPressed: () => _shareProfile(user),
                              ),
                            ] else ...[
                              Expanded(
                                flex: 3,
                                child: StreamBuilder<bool>(
                                  stream: _socialService
                                      .isFollowingStream(
                                          currentUid, user.uid),
                                  builder: (context, snap) {
                                    final isFollowing =
                                        snap.data ?? false;
                                    return ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing
                                            ? const Color(0xFFE4E6EB)
                                            : const Color(0xFF1877F2),
                                        foregroundColor: isFollowing
                                            ? const Color(0xFF050505)
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    8)),
                                        padding:
                                            const EdgeInsets.symmetric(
                                                vertical: 12),
                                        elevation: 0,
                                      ),
                                      icon: Icon(
                                        isFollowing
                                            ? Icons.check_rounded
                                            : Icons.person_add_rounded,
                                        size: 16,
                                        color: isFollowing
                                            ? const Color(0xFF34A853)
                                            : Colors.white,
                                      ),
                                      label: Text(
                                        isFollowing
                                            ? 'Following'
                                            : 'Follow',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: isFollowing
                                              ? const Color(
                                                  0xFF050505)
                                              : Colors.white,
                                        ),
                                      ),
                                      onPressed: () async {
                                        if (currentUid.isEmpty) return;
                                        if (isFollowing) {
                                          await _socialService
                                              .unfollowUser(
                                                  currentUid:
                                                      currentUid,
                                                  targetUid:
                                                      user.uid);
                                        } else {
                                          await _socialService
                                              .followUser(
                                                  currentUid:
                                                      currentUid,
                                                  targetUid:
                                                      user.uid);
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Color(0xFFF87171),
                                        width: 1.2),
                                    backgroundColor:
                                        const Color(0xFFFEE2E2),
                                    foregroundColor:
                                        const Color(0xFFDC2626),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  icon: const Text('⚔️',
                                      style:
                                          TextStyle(fontSize: 14)),
                                  label: const Text(
                                    '1v1 Battle',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _show1v1ChallengeDialog(user),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFE4E6EB),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                ),
                                icon: const Icon(Icons.share_rounded,
                                    size: 18,
                                    color: Color(0xFF65676B)),
                                onPressed: () => _shareProfile(user),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF1877F2),
                      indicatorWeight: 3,
                      labelColor: const Color(0xFF1877F2),
                      unselectedLabelColor: const Color(0xFF65676B),
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: const [
                        Tab(
                            icon: Icon(Icons.grid_view_rounded,
                                size: 18),
                            text: 'Posts'),
                        Tab(
                            icon: Icon(
                                Icons.info_outline_rounded,
                                size: 18),
                            text: 'About'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                PostsTab(
                  user: user,
                  isOwnProfile: isOwnProfile,
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAboutCard(
                        icon: Icons.badge_outlined,
                        title: 'Official Gamer Handle',
                        value: '@${user.username}',
                        color: GamerTheme.accentOrange,
                      ),
                      const SizedBox(height: 12),
                      if (canShowGame)
                        _buildAboutCard(
                          icon: Icons.sports_esports_outlined,
                          title: 'Main Game',
                          value: '$gameEmoji ${user.favoriteGame}',
                          color: gameColor,
                        ),
                      if (canShowGame) const SizedBox(height: 12),
                      if (canShowUid && user.gameId.isNotEmpty)
                        _buildAboutCard(
                          icon: Icons.tag_rounded,
                          title: 'In-Game UID',
                          value: user.gameId,
                          color: GamerTheme.accentOrange,
                        ),
                      if (canShowUid && user.gameId.isNotEmpty)
                        const SizedBox(height: 12),
                      if (canShowMemberSince)
                        _buildAboutCard(
                          icon: Icons.calendar_today_outlined,
                          title: 'Member Since',
                          value: user.createdAt != null
                              ? DateFormat('MMMM yyyy')
                                  .format(user.createdAt!)
                              : '2026',
                          color: GamerTheme.accentBlue,
                        ),
                      if (canShowCoins)
                        _buildAboutCard(
                          icon: Icons.monetization_on_rounded,
                          title: 'G-Coins Balance',
                          value: '${user.coins} Coins',
                          color: const Color(0xFFFFD700),
                        ),
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

  Widget _buildAboutCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCED0D4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1877F2), size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF65676B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFF050505),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  void _showFullScreenPhotoViewer(
      {required String imageUrl, required String title}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.92),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(
                            color: GamerTheme.accentOrange),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Icon(Icons.broken_image_rounded,
                          color: Colors.red, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSettingsMenu(GamerUser user, bool isOwnProfile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCED0D4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE7F3FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.tune_rounded,
                            color: Color(0xFF1877F2), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Profile Menu & Settings',
                          style: TextStyle(
                            color: Color(0xFF050505),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF65676B), size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFFCED0D4), height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_pin_rounded,
                        color: Color(0xFF1877F2), size: 20),
                  ),
                  title: Text(
                    isOwnProfile
                        ? 'My Gamer Profile'
                        : '@${user.username}\'s Profile',
                    style: const TextStyle(
                        color: Color(0xFF050505),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  subtitle: Text(
                    'Level ${user.level} • ${user.favoriteGame}',
                    style: const TextStyle(
                        color: Color(0xFF65676B), fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF65676B), size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isOwnProfile) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateGamerIdScreen(
                            isEditing: true,
                            existingUser: user,
                          ),
                        ),
                      );
                    }
                  },
                ),
                if (isOwnProfile)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE7F3FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded,
                          color: Color(0xFF1877F2), size: 20),
                    ),
                    title: const Text(
                      'Privacy Settings',
                      style: TextStyle(
                          color: Color(0xFF050505),
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Control what others can see on your profile',
                      style: TextStyle(
                          color: Color(0xFF65676B), fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF65676B), size: 14),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showPrivacySettingsSheet(user);
                    },
                  ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF7E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🪙',
                        style: TextStyle(fontSize: 18)),
                  ),
                  title: const Text(
                    'G-Coins Wallet',
                    style: TextStyle(
                        color: Color(0xFF050505),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  subtitle: Text(
                    '${user.coins} Coins • Tap for Transaction History',
                    style: const TextStyle(
                        color: Color(0xFF65676B), fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E6EB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${user.coins}',
                      style: const TextStyle(
                        color: Color(0xFF050505),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    CoinHistorySheet.show(context, userId: user.uid);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_rounded,
                        color: Color(0xFF1877F2), size: 20),
                  ),
                  title: const Text(
                    'Share Profile',
                    style: TextStyle(
                        color: Color(0xFF050505),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Share Gamer ID link with friends & squad',
                    style: TextStyle(
                        color: Color(0xFF65676B), fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF65676B), size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareProfile(user);
                  },
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeService.themeModeNotifier,
                  builder: (context, mode, _) {
                    final isDark = mode == ThemeMode.dark;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF7E0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: const Color(0xFFF59E0B),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        isDark ? 'Day Mode' : 'Night Mode',
                        style: const TextStyle(
                            color: Color(0xFF050505),
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      subtitle: Text(
                        isDark
                            ? 'Switch to bright display theme'
                            : 'Switch to dark gaming theme',
                        style: const TextStyle(
                            color: Color(0xFF65676B), fontSize: 12),
                      ),
                      trailing: Switch.adaptive(
                        value: isDark,
                        activeColor: const Color(0xFF1877F2),
                        onChanged: (val) {
                          ThemeService.toggleTheme();
                        },
                      ),
                      onTap: () {
                        ThemeService.toggleTheme();
                      },
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bookmark_rounded,
                        color: Color(0xFF1877F2), size: 20),
                  ),
                  title: const Text(
                    'Saved Posts & News',
                    style: TextStyle(
                        color: Color(0xFF050505),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  subtitle: const Text(
                    'View your bookmarked clips & articles',
                    style: TextStyle(
                        color: Color(0xFF65676B), fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF65676B), size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor:
                              const Color(0xFFF0F2F5),
                          appBar: AppBar(
                            backgroundColor: Colors.white,
                            elevation: 1,
                            title: const Text('Saved Posts & News',
                                style: TextStyle(
                                    color: Color(0xFF1877F2),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                          ),
                          body: const SavedNewsTabScreen(),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE4E6EB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.settings_rounded,
                        color: Color(0xFF65676B), size: 20),
                  ),
                  title: const Text(
                    'Settings & Preferences',
                    style: TextStyle(
                        color: Color(0xFF050505),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Follow Us, sound, notifications & accounts',
                    style: TextStyle(
                        color: Color(0xFF65676B), fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF65676B), size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                if (isOwnProfile) ...[
                  const Divider(color: Color(0xFFCED0D4), height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE7F3FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.download_rounded,
                          color: Color(0xFF1877F2), size: 20),
                    ),
                    title: const Text(
                      'Download My Data',
                      style: TextStyle(
                          color: Color(0xFF050505),
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Get a copy of your Gamers ID data (JSON)',
                      style: TextStyle(
                          color: Color(0xFF65676B), fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF65676B), size: 14),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const GamerDownloadDataScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_forever_rounded,
                          color: Color(0xFFDC2626), size: 20),
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Permanently delete your Gamer ID (30-day grace)',
                      style: TextStyle(
                          color: Color(0xFF65676B), fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF65676B), size: 14),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const GamerDeleteAccountScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Color(0xFFDC2626), size: 20),
                    ),
                    title: const Text(
                      'Log Out',
                      style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Sign out of Gamers ID Network',
                      style: TextStyle(
                          color: Color(0xFF65676B), fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmSignOut();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return false;
  }
}