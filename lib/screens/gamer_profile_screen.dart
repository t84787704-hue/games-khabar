// ================================================================
// EXACT DIFF — Full Adaptive Day & Night Mode Support for GamerProfileScreen
// + StreamBuilder removed / direct _cachedUser use
// + 10-second silent background refresh
// + Direct Settings navigation on Gear icon
// ----------------------------------------------------------------
// File: lib/screens/gamer_profile_screen.dart
// ================================================================

import 'dart:async';
import 'dart:io';
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
import '../services/profile_service.dart';
import '../services/block_service.dart';
import '../widgets/posts_tab.dart';
import 'create_gamer_id_screen.dart';
import 'followers_following_screen.dart';
import 'gamer_auth_screen.dart';
import 'saved_news_tab_screen.dart';
import 'profile_screen.dart';
import 'gamer_delete_account_screen.dart';
import 'gamer_download_data_screen.dart';
import 'gamer_privacy_policy_screen.dart';
import 'gamer_terms_of_service_screen.dart';
import 'blocked_users_screen.dart';
import '../widgets/coin_history_sheet.dart';
import 'coin_wallet_screen.dart';

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
  final BlockService _blockService = BlockService();

  bool _isBlockedByMe = false;
  bool _isBlockedByThem = false;
  bool _loadingBlockStatus = true;

  GamerUser? _cachedUser;
  bool _initialFetchDone = false;
  String _lastFetchedUid = '';

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkBlockStatus();
    _prefetchCurrentUser();

    GamerAuthService().currentGamerNotifier.addListener(_onGamerChanged);

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshSilently();
    });
  }

  void _onGamerChanged() {
    if (!mounted) return;
    final updated = GamerAuthService().currentGamer;
    if (updated != null) {
      setState(() {
        _cachedUser = updated;
      });
    }
  }

  Future<void> _refreshSilently() async {
    if (!mounted) return;
    final uid = widget.userId ?? (_authService.currentUid ?? '');
    if (uid.isEmpty) return;
    try {
      final user = await _fetchGamerFromSupabase(uid);
      if (user != null && mounted) {
        setState(() {
          _cachedUser = user;
          _lastFetchedUid = uid;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    GamerAuthService().currentGamerNotifier.removeListener(_onGamerChanged);
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _prefetchCurrentUser() async {
    final uid = widget.userId ?? (_authService.currentUid ?? '');

    if (uid.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      final retryUid = widget.userId ?? (_authService.currentUid ?? '');
      if (retryUid.isEmpty) {
        if (mounted) setState(() => _initialFetchDone = true);
        return;
      }
      final user = await _fetchGamerFromSupabase(retryUid);
      if (!mounted) return;
      setState(() {
        _cachedUser = user;
        _lastFetchedUid = retryUid;
        _initialFetchDone = true;
      });
      return;
    }

    final user = await _fetchGamerFromSupabase(uid);
    if (!mounted) return;
    setState(() {
      _cachedUser = user;
      _lastFetchedUid = uid;
      _initialFetchDone = true;
    });
  }

  Future<void> _checkBlockStatus() async {
    final currentUid = _authService.currentUid ?? '';
    final targetUid = widget.userId ?? currentUid;
    if (currentUid.isEmpty || currentUid == targetUid) {
      if (mounted) setState(() => _loadingBlockStatus = false);
      return;
    }
    final blocked = await _blockService.isBlocked(
        currentUid: currentUid, targetUid: targetUid);
    final blockedBy = await _blockService.isBlockedBy(
        currentUid: currentUid, targetUid: targetUid);
    if (!mounted) return;
    setState(() {
      _isBlockedByMe = blocked;
      _isBlockedByThem = blockedBy;
      _loadingBlockStatus = false;
    });
  }

  Future<GamerUser?> _fetchGamerFromSupabase(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final rowById = await SupabaseService.client
          .from('users')
          .select()
          .or('id.eq.$userId,uid.eq.$userId')
          .maybeSingle();

      if (rowById != null) {
        return _rowToGamerUser(rowById, userId);
      }

      final rowByUid = await SupabaseService.client
          .from('users')
          .select()
          .eq('uid', userId)
          .maybeSingle();

      if (rowByUid != null) {
        final actualId = (rowByUid['id'] ?? userId).toString();
        return _rowToGamerUser(rowByUid, actualId);
      }

      final rowByUsername = await SupabaseService.client
          .from('users')
          .select()
          .eq('username', userId)
          .maybeSingle();

      if (rowByUsername != null) {
        final actualId = (rowByUsername['id'] ?? userId).toString();
        return _rowToGamerUser(rowByUsername, actualId);
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Supabase fetch error: $e');
    }
    return null;
  }

  GamerUser _rowToGamerUser(Map<String, dynamic> row, String fallbackUid) {
    return GamerUser.fromMap(row, fallbackUid);
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
          .or('id.eq.$uid,uid.eq.$uid')
          .select();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Privacy settings updated'),
            backgroundColor: Color(0xFF34A853),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Privacy] ERROR: $e');
    }
  }

  Future<void> _confirmBlock(GamerUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Block User?',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Block ${user.displayName}?\n\nThey won\'t be able to:\n• See your profile or posts\n• Comment or follow you\n• Send you messages',
          style: TextStyle(color: ThemeService.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final uid = _authService.currentUid ?? '';
    final ok = await _blockService.blockUser(
        currentUid: uid, targetUid: user.uid);

    if (!mounted) return;
    if (ok) {
      setState(() => _isBlockedByMe = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚫 ${user.displayName} blocked'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _unblockUser(GamerUser user) async {
    final uid = _authService.currentUid ?? '';
    final ok = await _blockService.unblockUser(
        currentUid: uid, targetUid: user.uid);
    if (!mounted) return;
    if (ok) {
      setState(() => _isBlockedByMe = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User unblocked'),
          backgroundColor: Color(0xFF34A853),
        ),
      );
    }
  }

  void _showPrivacySettingsSheet(GamerUser user) {
    bool rankPublic = user.isRankPublic;
    bool uidPublic = user.isUidPublic;
    bool coinsPublic = user.isCoinsPublic;
    bool memberSincePublic = user.isMemberSincePublic;
    bool followingPublic = user.isFollowingPublic;
    bool followersPublic = user.isFollowersPublic;
    bool bioPublic = user.isBioPublic;
    bool gamePublic = user.isGamePublic;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: ThemeService.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
                        color: ThemeService.border,
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
                          Expanded(
                            child: Text(
                              'Privacy Settings',
                              style: TextStyle(
                                color: ThemeService.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: ThemeService.textSecondary, size: 22),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: ThemeService.border, height: 1),
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
        style: TextStyle(
          color: ThemeService.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
      ),
      value: value,
      activeColor: const Color(0xFF1877F2),
      onChanged: onChanged,
    );
  }

  void _showChangeCoverSheet(BuildContext context, GamerUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeService.card,
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
                      color: ThemeService.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Change Cover Photo',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
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
                  title: Text('Choose from Gallery',
                      style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadCoverPhoto(user);
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

      final file = File(picked.path);
      final uploadedUrl = await _authService.uploadCoverPhoto(file, user.uid);
      final finalUrl = uploadedUrl.isNotEmpty ? uploadedUrl : '';

      if (finalUrl.isNotEmpty) {
        await SupabaseService.client.from('users').update({
          'cover_url': finalUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).or('id.eq.${user.uid},uid.eq.${user.uid}');

        try {
          if (user.coverUrl.isNotEmpty) {
            await CachedNetworkImage.evictFromCache(user.coverUrl);
          }
          await CachedNetworkImage.evictFromCache(finalUrl);
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        } catch (_) {}

        final latest = await _fetchGamerFromSupabase(user.uid);
        if (latest != null && mounted) {
          setState(() => _cachedUser = latest);
        }
      }
    } catch (_) {}
  }

  void _shareProfile(GamerUser user) {
    final text =
        '🎮 Check out ${user.displayName}\'s Gamer ID on Gamers ID!\n\n'
        'Handle: @${user.username}\n'
        'Game: ${user.favoriteGame} | Rank: ${user.rank}\n'
        'Bio: ${user.bio}';
    Share.share(text);
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Out',
            style: TextStyle(
                color: ThemeService.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to log out of Gamers ID?',
            style: TextStyle(color: ThemeService.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: ThemeService.textSecondary,
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

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        if (!isOwnProfile && _isBlockedByThem) {
          return Scaffold(
            backgroundColor: ThemeService.bg,
            appBar: AppBar(
              backgroundColor: ThemeService.appBarBg,
              elevation: 1,
              iconTheme: IconThemeData(color: ThemeService.textPrimary),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 64, color: ThemeService.textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      'Profile Unavailable',
                      style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This profile isn\'t available right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (_cachedUser == null) {
          if (!_initialFetchDone) {
            return Scaffold(
              backgroundColor: ThemeService.bg,
              body: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1877F2))),
            );
          }

          return Scaffold(
            backgroundColor: ThemeService.bg,
            appBar: AppBar(
              backgroundColor: ThemeService.appBarBg,
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
                  Icon(Icons.sentiment_dissatisfied_rounded,
                      color: ThemeService.textSecondary, size: 54),
                  const SizedBox(height: 12),
                  Text('Gamer ID not found or not set up yet.',
                      style: TextStyle(color: ThemeService.textPrimary)),
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

        final user = _cachedUser!;

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
          backgroundColor: ThemeService.bg,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: ThemeService.card,
                  elevation: ThemeService.isDarkMode ? 0 : 1,
                  automaticallyImplyLeading: !isOwnProfile,
                  iconTheme:
                      IconThemeData(color: ThemeService.textPrimary),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: Material(
                          color: ThemeService.card,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              if (isOwnProfile) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileScreen(),
                                  ),
                                );
                              } else {
                                _showProfileSettingsMenu(user, isOwnProfile);
                              }
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ThemeService.cardSecondary,
                                border: Border.all(
                                  color: ThemeService.border,
                                  width: 1.0,
                                ),
                              ),
                              child: Icon(
                                Icons.settings_rounded,
                                color: ThemeService.textSecondary,
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
                        Container(
                          height: 175,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: ThemeService.cardSecondary,
                          ),
                          child: CachedNetworkImage(
                            imageUrl: user.coverUrl.isNotEmpty
                                ? user.coverUrl
                                : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80',
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 129,
                          left: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: ThemeService.card, width: 4),
                            ),
                            child: GamerAvatar(
                              key: ValueKey('avatar_${user.uid}_${user.photoUrl}'),
                              photoUrl: user.photoUrl,
                              displayName: user.displayName,
                              radius: 46,
                              hasGlow: false,
                              borderColor: Colors.transparent,
                              frameId: user.activeFrame,
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
                                style: TextStyle(
                                  color: ThemeService.textPrimary,
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
                          style: TextStyle(
                            color: ThemeService.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (user.bio.isNotEmpty && canShowBio) ...[
                          const SizedBox(height: 10),
                          Text(
                            user.bio,
                            style: TextStyle(
                              color: ThemeService.textPrimary,
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
                            color: ThemeService.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: ThemeService.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(ThemeService.isDarkMode ? 0.2 : 0.04),
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
                                  color: ThemeService.border),
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
                                  color: ThemeService.border),
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
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CreateGamerIdScreen(
                                          isEditing: true,
                                          existingUser: user,
                                        ),
                                      ),
                                    );
                                    _refreshSilently();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: ThemeService.cardSecondary,
                                  foregroundColor: ThemeService.textPrimary,
                                  side: BorderSide(color: ThemeService.border),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 12),
                                ),
                                icon: Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 18,
                                    color: ThemeService.textSecondary),
                                label: Text('Cover',
                                    style: TextStyle(
                                        color: ThemeService.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                onPressed: () =>
                                    _showChangeCoverSheet(context, user),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: ThemeService.cardSecondary,
                                  foregroundColor: ThemeService.textPrimary,
                                  side: BorderSide(color: ThemeService.border),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 12),
                                ),
                                icon: Icon(Icons.share_rounded,
                                    size: 18,
                                    color: ThemeService.textSecondary),
                                label: Text('Share',
                                    style: TextStyle(
                                        color: ThemeService.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                onPressed: () => _shareProfile(user),
                              ),
                            ] else ...[
                              if (_isBlockedByMe) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFFEE2E2),
                                      side: const BorderSide(
                                          color: Color(0xFFDC2626),
                                          width: 1.2),
                                      foregroundColor:
                                          const Color(0xFFDC2626),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                    icon: const Icon(Icons.block_rounded,
                                        size: 16),
                                    label: const Text(
                                        'Blocked • Tap to Unblock',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            color: Color(0xFFDC2626))),
                                    onPressed: () => _unblockUser(user),
                                  ),
                                ),
                              ] else ...[
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
                                    ),
                                    icon: const Icon(Icons.share_rounded, size: 16),
                                    label: const Text('Share Profile',
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: () => _shareProfile(user),
                                  ),
                                ),
                              ],
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
                      unselectedLabelColor: ThemeService.textSecondary,
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
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeService.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ThemeService.isDarkMode ? 0.2 : 0.04),
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
              color: ThemeService.cardSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1877F2), size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: ThemeService.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ],
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
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
                      color: ThemeService.border,
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
                          child: Icon(
                            isOwnProfile
                                ? Icons.tune_rounded
                                : Icons.more_horiz_rounded,
                            color: const Color(0xFF1877F2),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isOwnProfile
                                ? 'Profile Menu & Settings'
                                : 'More Options',
                            style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: ThemeService.textSecondary, size: 22),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: ThemeService.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_pin_rounded, color: Color(0xFF1877F2)),
                    title: Text(
                      isOwnProfile ? 'My Gamer Profile' : '@${user.username}\'s Profile',
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    onTap: () => Navigator.pop(ctx),
                  ),
                ],
              ),
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
      color: ThemeService.card,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return true;
  }
}
