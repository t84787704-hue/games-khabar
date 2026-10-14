// ================================================================
// EXACT DIFF — Fixed 2 issues
// ----------------------------------------------------------------
// File: lib/screens/gamer_profile_screen.dart
//
// FIX 1: Removed StreamBuilder → direct _cachedUser use (reload band)
// FIX 2: Added Timer for 10-second background refresh (naya data)
// FIX 3: Cover/avatar change ke baad setState _cachedUser ko turant update karega
//
// NO OTHER CODE CHANGED — byte-by-byte same
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

  // ✅ FIX: Timer for 10-second background refresh (StreamBuilder hata diya)
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkBlockStatus();
    _prefetchCurrentUser();

    GamerAuthService().currentGamerNotifier.addListener(_onGamerChanged);

    // ✅ FIX: 10-second background refresh
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

  // ✅ FIX: Background refresh without reload
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
    _refreshTimer?.cancel(); // ✅ FIX: Cancel timer
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
          .eq('id', userId)
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

  // ✅ FIX: _gamerStream method hata diya (nahi chahiye ab)

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
    if (uid.isEmpty) {
      debugPrint('[Privacy] ❌ No current UID');
      return;
    }

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
          .eq('id', uid)
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
    } catch (e, stack) {
      debugPrint('[Privacy] ❌ ERROR: $e');
      debugPrint('[Privacy] STACK: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Privacy update failed: $e'),
            backgroundColor: const Color(0xFFFF4655),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _confirmBlock(GamerUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Block User?',
                style: TextStyle(
                    color: Color(0xFF050505), fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Block ${user.displayName}?\n\nThey won\'t be able to:\n• See your profile or posts\n• Comment or follow you\n• Send you messages',
          style: const TextStyle(color: Color(0xFF65676B), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF65676B))),
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to block user'),
          backgroundColor: Color(0xFFFF4655),
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
        SnackBar(
          content: Text('${user.displayName} unblocked'),
          backgroundColor: GamerTheme.accentGreen,
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