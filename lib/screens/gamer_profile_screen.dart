// ===============================================================================
// GAMER PROFILE SCREEN — Full About Details, Match Stats, Badges & Multi-Language
// + Adaptive Dark & Light Mode + Early Bird 1200 VIP Banner
// -------------------------------------------------------------------------------
// File: lib/screens/gamer_profile_screen.dart
// ===============================================================================

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/theme_service.dart';
import '../controllers/social_profile_controller.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/wallet_repository.dart';
import '../services/direct_message_service.dart';
import 'coin_wallet_screen.dart';
import '../services/app_share_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/early_bird_banner_widget.dart';
import '../services/block_service.dart';
import '../widgets/posts_tab.dart';
import 'create_gamer_id_screen.dart';
import 'followers_following_screen.dart';
import 'gamer_auth_screen.dart';
import 'gamer_chat_screen.dart';
import 'profile_screen.dart';

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
  final BlockService _blockService = BlockService();
  final SocialProfileController _socialController = SocialProfileController();
  final DirectMessageService _dmService = DirectMessageService();

  bool _isBlockedByMe = false;
  bool _isBlockedByThem = false;

  GamerUser? _cachedUser;
  bool _initialFetchDone = false;
  Timer? _refreshTimer;

  int _matchesPlayed = 0;
  int _matchesWon = 0;
  int _tournamentsJoined = 0;

  bool get _isOwnProfile {
    final rawTarget = widget.userId?.trim() ?? '';
    if (rawTarget.isEmpty) return true;

    final currentUid = _authService.currentUid?.trim() ?? '';
    final currentGamerUid = _authService.currentGamer?.uid.trim() ?? '';

    if (currentUid.isNotEmpty) {
      if (currentUid.toLowerCase() == rawTarget.toLowerCase()) return true;
      if (GamerSocialService.stringToUuid(currentUid) ==
          GamerSocialService.stringToUuid(rawTarget)) {
        return true;
      }
    }
    if (currentGamerUid.isNotEmpty) {
      if (currentGamerUid.toLowerCase() == rawTarget.toLowerCase()) return true;
      if (GamerSocialService.stringToUuid(currentGamerUid) ==
          GamerSocialService.stringToUuid(rawTarget)) {
        return true;
      }
    }
    if (_cachedUser != null && currentUid.isNotEmpty) {
      if (_cachedUser!.uid.toLowerCase() == currentUid.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkBlockStatus();
    _prefetchCurrentUser();

    GamerAuthService().currentGamerNotifier.addListener(_onGamerChanged);
    WalletRepository.instance.gCoinsBalance.addListener(_onWalletBalanceChanged);
    WalletRepository.instance.refreshForCurrentUser();

    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshSilently();
    });
  }

  @override
  void didUpdateWidget(covariant GamerProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      setState(() {
        _cachedUser = null;
        _initialFetchDone = false;
        _isBlockedByMe = false;
        _isBlockedByThem = false;
        _matchesPlayed = 0;
        _matchesWon = 0;
        _tournamentsJoined = 0;
      });
      _checkBlockStatus();
      _prefetchCurrentUser();
    }
  }

  void _onGamerChanged() {
    if (!mounted || !_isOwnProfile) return;
    final updated = GamerAuthService().currentGamer;
    if (updated != null) {
      setState(() {
        _cachedUser = updated;
      });
      if (_socialController.targetUid.isEmpty) {
        _socialController.bindProfile(
          targetUserId: updated.uid,
          initialUser: updated,
          currentUid: updated.uid,
        );
      } else {
        _socialController.syncUser(updated);
      }
    }
  }

  Future<void> _refreshSilently() async {
    if (!mounted) return;
    final currentUid = _authService.currentUid ?? '';
    final uid = (widget.userId != null && widget.userId!.trim().isNotEmpty)
        ? widget.userId!.trim()
        : currentUid;
    if (uid.isEmpty) return;
    try {
      final user = await _fetchGamerFromSupabase(uid);
      if (user != null && mounted) {
        setState(() {
          _cachedUser = user;
        });
        unawaited(_fetchMatchSummaryStats(user.uid));
        if (_socialController.targetUid.isEmpty) {
          await _socialController.bindProfile(
            targetUserId: user.uid,
            initialUser: user,
            currentUid: currentUid,
          );
        } else {
          _socialController.syncUser(user);
          await _socialController.refresh(currentUid: currentUid);
        }
      }
    } catch (_) {}
  }

  void _onWalletBalanceChanged() {
    if (!mounted || !_isOwnProfile) return;
    final int liveCoins = WalletRepository.instance.currentGCoins;
    if (liveCoins > 0 && _cachedUser != null && _cachedUser!.coins != liveCoins) {
      setState(() {
        _cachedUser = _cachedUser!.copyWith(coins: liveCoins);
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    GamerAuthService().currentGamerNotifier.removeListener(_onGamerChanged);
    WalletRepository.instance.gCoinsBalance.removeListener(_onWalletBalanceChanged);
    _refreshTimer?.cancel();
    _socialController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _prefetchCurrentUser() async {
    final currentUid = _authService.currentUid ?? '';
    final uid = (widget.userId != null && widget.userId!.trim().isNotEmpty)
        ? widget.userId!.trim()
        : currentUid;
    if (uid.isEmpty) {
      if (mounted) setState(() => _initialFetchDone = true);
      return;
    }

    final user = await _fetchGamerFromSupabase(uid);
    if (!mounted) return;
    setState(() {
      _cachedUser = user;
      _initialFetchDone = true;
    });
    if (user != null) {
      unawaited(_fetchMatchSummaryStats(user.uid));
      await _socialController.bindProfile(
        targetUserId: user.uid,
        initialUser: user,
        currentUid: currentUid,
      );
    }
  }

  Future<void> _fetchMatchSummaryStats(String targetUserId) async {
    final cleanId = targetUserId.trim();
    if (cleanId.isEmpty) return;

    int played = 0;
    int won = 0;
    int tourneysJoined = 0;

    try {
      final teamIds = <String>{};

      // 1. Check teams led by this user
      try {
        final leaderTeams = await SupabaseService.client
            .from('teams')
            .select('id, team_id, wins, losses, matches_played')
            .eq('leader_id', cleanId)
            .limit(10);
        for (final row in (leaderTeams as List)) {
          if (row is! Map) continue;
          final tId = (row['id'] ?? '').toString();
          final tCode = (row['team_id'] ?? '').toString();
          if (tId.isNotEmpty) teamIds.add(tId);
          if (tCode.isNotEmpty) teamIds.add(tCode);
          final w = (row['wins'] as num?)?.toInt() ?? 0;
          final l = (row['losses'] as num?)?.toInt() ?? 0;
          final mp = (row['matches_played'] as num?)?.toInt() ?? (w + l);
          won += w;
          played += mp > (w + l) ? mp : (w + l);
        }
      } catch (_) {}

      // 2. Check team_members for teams the user belongs to
      try {
        final memberRows = await SupabaseService.client
            .from('team_members')
            .select('team_id')
            .eq('user_id', cleanId)
            .limit(10);
        final extraTeamIds = <String>[];
        for (final r in (memberRows as List)) {
          if (r is! Map) continue;
          final tid = (r['team_id'] ?? '').toString();
          if (tid.isNotEmpty && !teamIds.contains(tid)) {
            teamIds.add(tid);
            extraTeamIds.add(tid);
          }
        }
        if (extraTeamIds.isNotEmpty && played == 0 && won == 0) {
          for (final tid in extraTeamIds) {
            try {
              final tRow = await SupabaseService.client
                  .from('teams')
                  .select('wins, losses, matches_played')
                  .eq('id', tid)
                  .maybeSingle();
              if (tRow != null) {
                final w = (tRow['wins'] as num?)?.toInt() ?? 0;
                final l = (tRow['losses'] as num?)?.toInt() ?? 0;
                final mp = (tRow['matches_played'] as num?)?.toInt() ?? (w + l);
                won += w;
                played += mp > (w + l) ? mp : (w + l);
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      // 3. Check tournament_registrations
      try {
        final regRows = await SupabaseService.client
            .from('tournament_registrations')
            .select('id, tournament_id, team_id')
            .eq('leader_id', cleanId)
            .limit(50);
        tourneysJoined = (regRows as List).length;
      } catch (_) {}

      if (tourneysJoined == 0 && teamIds.isNotEmpty) {
        try {
          final regByTeam = await SupabaseService.client
              .from('tournament_registrations')
              .select('id')
              .inFilter('team_id', teamIds.toList())
              .limit(50);
          tourneysJoined = (regByTeam as List).length;
        } catch (_) {}
      }

      if (tourneysJoined > played) {
        played = tourneysJoined;
      }
      if (won > played) {
        played = won;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _matchesPlayed = played;
      _matchesWon = won;
      _tournamentsJoined = tourneysJoined;
    });
  }

  Future<void> _checkBlockStatus() async {
    final currentUid = _authService.currentUid ?? '';
    final targetUid = (widget.userId != null && widget.userId!.trim().isNotEmpty)
        ? widget.userId!.trim()
        : currentUid;
    if (currentUid.isEmpty ||
        GamerSocialService.stringToUuid(currentUid) ==
            GamerSocialService.stringToUuid(targetUid)) {
      return;
    }

    final blocked = await _blockService.isBlocked(
      currentUid: currentUid,
      targetUid: targetUid,
    );
    final blockedBy = await _blockService.isBlockedBy(
      currentUid: currentUid,
      targetUid: targetUid,
    );
    if (!mounted) return;
    setState(() {
      _isBlockedByMe = blocked;
      _isBlockedByThem = blockedBy;
    });
  }

  Future<GamerUser?> _fetchGamerFromSupabase(String userId) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return null;
    try {
      final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final isUuid = uuidRegex.hasMatch(cleanId);

      Map<String, dynamic>? row;
      if (isUuid) {
        try {
          row = await SupabaseService.client
              .from('users')
              .select()
              .or('id.eq.$cleanId,uid.eq.$cleanId')
              .maybeSingle();
        } catch (_) {
          try {
            row = await SupabaseService.client
                .from('users')
                .select()
                .eq('id', cleanId)
                .maybeSingle();
          } catch (_) {}
        }
      }

      if (row == null) {
        try {
          row = await SupabaseService.client
              .from('users')
              .select()
              .eq('uid', cleanId)
              .maybeSingle();
        } catch (_) {}
      }

      if (row == null) {
        final resolvedId = await _dmService.resolveToTableId(cleanId);
        if (resolvedId.isNotEmpty && uuidRegex.hasMatch(resolvedId)) {
          try {
            row = await SupabaseService.client
                .from('users')
                .select()
                .eq('id', resolvedId)
                .maybeSingle();
          } catch (_) {}

          if (row == null) {
            try {
              final profRow = await SupabaseService.client
                  .from('profiles')
                  .select()
                  .eq('id', resolvedId)
                  .maybeSingle();
              if (profRow != null) {
                await _dmService.ensureUserRecordLinked(
                  resolvedId,
                  fallbackDisplayName:
                      (profRow['display_name'] ?? profRow['username'] ?? '')
                          .toString(),
                  fallbackPhotoUrl: (profRow['avatar_url'] ?? '').toString(),
                );
                row = Map<String, dynamic>.from(profRow);
              }
            } catch (_) {}
          }
        }
      }

      if (row == null) {
        try {
          Map<String, dynamic>? profRow;
          if (isUuid) {
            profRow = await SupabaseService.client
                .from('profiles')
                .select()
                .eq('id', cleanId)
                .maybeSingle();
          }
          profRow ??= await SupabaseService.client
              .from('profiles')
              .select()
              .or('username.ilike.$cleanId,display_name.ilike.$cleanId')
              .limit(1)
              .maybeSingle();

          if (profRow != null) {
            final profId = (profRow['id'] ?? cleanId).toString().trim();
            await _dmService.ensureUserRecordLinked(
              profId,
              fallbackDisplayName:
                  (profRow['display_name'] ?? profRow['username'] ?? '')
                      .toString(),
              fallbackPhotoUrl: (profRow['avatar_url'] ?? '').toString(),
            );
            row = Map<String, dynamic>.from(profRow);
          }
        } catch (_) {}
      }

      if (row != null) {
        final resolvedId = (row['id'] ?? row['uid'] ?? cleanId).toString();
        var gamer = GamerUser.fromMap(row, resolvedId);

        // Enrich missing avatar or display name from public.profiles if available
        if ((gamer.photoUrl.isEmpty ||
                gamer.displayName.isEmpty ||
                gamer.displayName == 'Gamer') &&
            uuidRegex.hasMatch(resolvedId)) {
          try {
            final profRow = await SupabaseService.client
                .from('profiles')
                .select('username, display_name, avatar_url')
                .eq('id', resolvedId)
                .maybeSingle();
            if (profRow != null) {
              final profAvatar = DirectMessageService.normalizeAvatarUrl(
                profRow['avatar_url']?.toString(),
              );
              final profName =
                  (profRow['display_name'] ?? profRow['username'] ?? '')
                      .toString()
                      .trim();
              final profUsername =
                  (profRow['username'] ?? '').toString().trim();
              gamer = gamer.copyWith(
                photoUrl: gamer.photoUrl.isNotEmpty ? gamer.photoUrl : profAvatar,
                displayName: (gamer.displayName.isNotEmpty &&
                        gamer.displayName != 'Gamer')
                    ? gamer.displayName
                    : (profName.isNotEmpty ? profName : gamer.displayName),
                username: gamer.username.isNotEmpty
                    ? gamer.username
                    : profUsername,
              );
            }
          } catch (_) {}
        }

        // Always read authoritative G-Coins balance from public.coin_wallets.g_coins
        try {
          if (_isOwnProfile) {
            final wallet = await CoinWalletService().getOrCreateWallet(resolvedId);
            final int liveBalance = WalletRepository.instance.currentGCoins > 0
                ? WalletRepository.instance.currentGCoins
                : wallet.gCoins;
            if (liveBalance > 0 || gamer.coins != liveBalance) {
              gamer = gamer.copyWith(coins: liveBalance);
            }
          } else {
            final walletRow = await SupabaseService.client
                .from('coin_wallets')
                .select('g_coins, coins')
                .eq('user_id', resolvedId)
                .maybeSingle();
            if (walletRow != null) {
              final int gVal = (walletRow['g_coins'] as num?)?.toInt() ?? 0;
              final int cVal = (walletRow['coins'] as num?)?.toInt() ?? 0;
              final int resolvedWalletCoins = gVal > 0 ? gVal : cVal;
              if (resolvedWalletCoins > 0) {
                gamer = gamer.copyWith(coins: resolvedWalletCoins);
              }
            }
          }
        } catch (_) {}

        return gamer;
      }
    } catch (e) {
      debugPrint('[GamerProfile] Fetch error: $e');
    }
    return null;
  }

  Future<void> _handleToggleAlly(String currentUid) async {
    if (currentUid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('login_required_prompt'.tr()),
          action: SnackBarAction(
            label: 'btn_login'.tr(),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GamerAuthScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    if (_isBlockedByMe) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('blocked_users_sub'.tr()),
          backgroundColor: const Color(0xFFFF4655),
        ),
      );
      return;
    }

    final ok = await _socialController.toggleAlly(currentUid: currentUid);
    if (!ok && mounted) {
      final err = _socialController.errorMessage ?? 'action_failed'.tr();
      _socialController.clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: const Color(0xFFFF4655),
        ),
      );
    }
  }

  Future<void> _openDirectMessage(GamerUser user, String currentUid) async {
    if (currentUid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('login_required_prompt'.tr()),
          action: SnackBarAction(
            label: 'btn_login'.tr(),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GamerAuthScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    final resolvedTargetId = await _dmService.resolveToTableId(user.uid);
    final finalOtherId =
        resolvedTargetId.isNotEmpty ? resolvedTargetId : user.uid;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamerChatScreen(
          otherUserId: finalOtherId,
          otherUserName:
              user.displayName.isNotEmpty ? user.displayName : user.username,
          otherUserPhoto: user.photoUrl,
          otherUserVerified: user.hasBlueTick,
        ),
      ),
    );
  }

  void _shareProfile(GamerUser user) {
    final displayName =
        user.displayName.isNotEmpty ? user.displayName : user.username;
    final game = user.favoriteGame.isNotEmpty ? user.favoriteGame : 'BGMI';

    final bool hasValidRank = user.isRankApproved &&
        user.rank.isNotEmpty &&
        user.rank.toLowerCase() != 'none' &&
        user.rank.toLowerCase() != 'skip';

    final rankStr = hasValidRank ? user.rank : null;
    final bioStr = user.bio.trim().isNotEmpty ? user.bio.trim() : null;
    final liveSquadCount = _socialController.targetUid.isNotEmpty
        ? _socialController.squadCount
        : user.squadCount;

    AppShareService.shareProfile(
      displayName: displayName,
      username: user.username,
      game: game,
      rank: rankStr,
      squadCount: liveSquadCount,
      postsCount: user.postsCount,
      bio: bioStr,
    );
  }

  void _copyToClipboard({
    required String value,
    required String feedbackMessage,
    Color backgroundColor = const Color(0xFF00FF88),
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'not set') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Game UID not set',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Color(0xFFFF8A00),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: trimmed));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          feedbackMessage,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openFullScreenImagePreview({
    required String imageUrl,
    required String title,
    String displayName = '',
    bool isAvatar = false,
  }) {
    final trimmedUrl = imageUrl.trim();
    final isPreset = trimmedUrl.startsWith('preset:');
    final hasNetworkImage = trimmedUrl.isNotEmpty && !isPreset;

    if (!hasNetworkImage && !isAvatar) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Image Preview',
      barrierColor: Colors.black.withOpacity(0.92),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.black.withOpacity(0.55),
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                tooltip: 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(dialogContext).pop(),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent tap on image itself from closing modal
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.5,
                  child: hasNetworkImage
                      ? CachedNetworkImage(
                          imageUrl: trimmedUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF7A00),
                            ),
                          ),
                          errorWidget: (context, url, error) => isAvatar
                              ? GamerAvatar(
                                  photoUrl: trimmedUrl,
                                  displayName: displayName,
                                  radius: 120,
                                )
                              : const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.white54,
                                  size: 64,
                                ),
                        )
                      : GamerAvatar(
                          photoUrl: trimmedUrl,
                          displayName: displayName,
                          radius: 125,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String count, String label, VoidCallback? onTap) {
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

  Widget _buildMatchStatsSummaryCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeService.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(
                  Icons.sports_mma_rounded,
                  color: Color(0xFF00E5FF),
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  '$_matchesPlayed',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Matches Played',
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 28, width: 1, color: ThemeService.border),
          Expanded(
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700),
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  '$_matchesWon',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Wins',
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 28, width: 1, color: ThemeService.border),
          Expanded(
            child: Column(
              children: [
                const Icon(
                  Icons.military_tech_rounded,
                  color: Color(0xFF00FF88),
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  '$_tournamentsJoined',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tournaments',
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamEligibilityCard(int coins) {
    final isLeaderEligible = coins >= 1000;
    final isMemberEligible = coins >= 500;

    final Color badgeColor = isLeaderEligible
        ? const Color(0xFF00FF88)
        : isMemberEligible
            ? const Color(0xFFFFB800)
            : const Color(0xFFFF4655);

    final String title = isLeaderEligible
        ? 'eligible_leader_and_member'.tr()
        : isMemberEligible
            ? 'eligible_member_only'.tr()
            : 'ineligible_low_balance'.tr();

    final String subtitle = isLeaderEligible
        ? 'can_create_team_desc'.tr()
        : isMemberEligible
            ? 'can_join_team_need_coins_desc'.tr()
            : 'min_coins_to_remain_desc'.tr();

    final IconData icon = isLeaderEligible
        ? Icons.verified_user_rounded
        : isMemberEligible
            ? Icons.shield_outlined
            : Icons.warning_amber_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: badgeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${NumberFormat('#,###').format(coins)} G-Coins',
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeService.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: ThemeService.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: TextStyle(
              color: ThemeService.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? '';
    final bool isMe = _isOwnProfile;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageService.currentLanguage,
          builder: (context, langCode, _) {
            if (!isMe && _isBlockedByThem) {
              return Scaffold(
                backgroundColor: ThemeService.bg,
                appBar: AppBar(
                  backgroundColor: ThemeService.appBarBg,
                  elevation: 1,
                  iconTheme: IconThemeData(color: ThemeService.textPrimary),
                ),
                body: Center(
                  child: Text(
                    'profile_not_available'.tr(),
                    style: TextStyle(
                      color: ThemeService.textSecondary,
                      fontSize: 13,
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
                    child: CircularProgressIndicator(color: Color(0xFF1877F2)),
                  ),
                );
              }

              return Scaffold(
                backgroundColor: ThemeService.bg,
                appBar: AppBar(
                  backgroundColor: ThemeService.appBarBg,
                  elevation: 1,
                  title: Text('nav_profile'.tr()),
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: isMe
                        ? ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CreateGamerIdScreen(),
                                ),
                              );
                            },
                            child: Text('btn_create_gamer_id'.tr()),
                          )
                        : Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: ThemeService.card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: ThemeService.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1877F2)
                                        .withOpacity(0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.sports_esports_outlined,
                                    color: Color(0xFF00E5FF),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Gamer Profile Not Linked Yet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: ThemeService.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This user has registered an account but has not finished setting up their Gamer ID details yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: ThemeService.textSecondary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Go Back'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            ThemeService.textPrimary,
                                        side: BorderSide(
                                          color: ThemeService.border,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _initialFetchDone = false;
                                        });
                                        _prefetchCurrentUser();
                                      },
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Retry'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1877F2),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              );
            }

            final user = _cachedUser!;
            final gameEmoji = GamerTheme.gameEmojis[user.favoriteGame] ?? '🎮';
            final referralCode = CoinWalletService().getReferralCode(user.uid);
            final userRank = (user.selectedRank.isNotEmpty &&
                    user.selectedRank != 'None')
                ? user.selectedRank
                : (user.rank.isNotEmpty && user.rank != 'None'
                    ? user.rank
                    : 'Bronze');
            final joinedDate = user.createdAt != null
                ? DateFormat('dd MMM yyyy').format(user.createdAt!)
                : 'Recent Member';
            final rawGameUid = user.gameId.trim();
            final hasValidGameUid = rawGameUid.isNotEmpty &&
                rawGameUid.toLowerCase() != 'not set' &&
                rawGameUid != user.uid;
            final gameUidDisplay = hasValidGameUid ? rawGameUid : 'Not set';
            final gameUidCopyValue = hasValidGameUid ? rawGameUid : '';

            return Scaffold(
              backgroundColor: ThemeService.bg,
              body: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      expandedHeight: 250,
                      pinned: true,
                      backgroundColor: ThemeService.card,
                      elevation: 1,
                      automaticallyImplyLeading: !isMe,
                      iconTheme: IconThemeData(color: ThemeService.textPrimary),
                      actions: [
                        if (isMe)
                          IconButton(
                            icon: Icon(
                              Icons.settings_rounded,
                              color: ThemeService.textSecondary,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                            },
                          )
                        else
                          IconButton(
                            icon: Icon(
                              Icons.share_rounded,
                              color: ThemeService.textSecondary,
                            ),
                            tooltip: 'share'.tr(),
                            onPressed: () => _shareProfile(user),
                          ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                final effectiveCoverUrl = user.coverUrl.isNotEmpty
                                    ? user.coverUrl
                                    : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80';
                                final displayLabel = user.displayName.isNotEmpty
                                    ? user.displayName
                                    : user.username;
                                _openFullScreenImagePreview(
                                  imageUrl: effectiveCoverUrl,
                                  title: '$displayLabel • Cover Photo',
                                  displayName: displayLabel,
                                  isAvatar: false,
                                );
                              },
                              child: Container(
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
                            ),
                            Positioned(
                              top: 129,
                              left: 20,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  final displayLabel = user.displayName.isNotEmpty
                                      ? user.displayName
                                      : user.username;
                                  _openFullScreenImagePreview(
                                    imageUrl: user.photoUrl,
                                    title: '$displayLabel • Profile Photo',
                                    displayName: displayLabel,
                                    isAvatar: true,
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ThemeService.card,
                                      width: 4,
                                    ),
                                  ),
                                  child: GamerAvatar(
                                    key: ValueKey(
                                      'avatar_${user.uid}_${user.photoUrl}',
                                    ),
                                    photoUrl: user.photoUrl,
                                    displayName: user.displayName,
                                    radius: 46,
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
                                    user.displayName.isNotEmpty
                                        ? user.displayName
                                        : user.username,
                                    style: TextStyle(
                                      color: ThemeService.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (user.hasBlueTick) ...[
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.verified,
                                    color: Color(0xFF1877F2),
                                    size: 18,
                                  ),
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
                            if (user.bio.isNotEmpty) ...[
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

                            // Early Bird Banner for own profile
                            if (isMe) ...[
                              const SizedBox(height: 10),
                              EarlyBirdBannerWidget(userId: user.uid),
                            ],

                            // Leader & Member Eligibility Banner & G-Coins badge
                            const SizedBox(height: 14),
                            ValueListenableBuilder<int>(
                              valueListenable:
                                  WalletRepository.instance.gCoinsBalance,
                              builder: (context, repoCoins, _) {
                                final int liveGCoins = isMe
                                    ? (repoCoins > 0
                                        ? repoCoins
                                        : (CoinWalletService()
                                                .currentWallet
                                                ?.gCoins ??
                                            user.coins))
                                    : user.coins;
                                return _buildTeamEligibilityCard(liveGCoins);
                              },
                            ),

                            const SizedBox(height: 14),

                            ListenableBuilder(
                              listenable: _socialController,
                              builder: (context, _) {
                                final liveSquadCount =
                                    _socialController.targetUid.isNotEmpty
                                        ? _socialController.squadCount
                                        : user.squadCount;
                                final liveAlliesCount =
                                    _socialController.targetUid.isNotEmpty
                                        ? _socialController.alliesCount
                                        : user.alliesCount;
                                final isAllied = _socialController.isAlly;
                                final isToggling = _socialController.isToggling;

                                return Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ThemeService.card,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: ThemeService.border,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildStatColumn(
                                            '${user.postsCount}',
                                            'posts'.tr(),
                                            () {
                                              _tabController.animateTo(0);
                                            },
                                          ),
                                          Container(
                                            height: 24,
                                            width: 1,
                                            color: ThemeService.border,
                                          ),
                                          _buildStatColumn(
                                            '$liveSquadCount',
                                            'squad'.tr(),
                                            () async {
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      SquadAlliesScreen(
                                                    userId: user.uid,
                                                    displayName:
                                                        user.displayName,
                                                    initialTabIndex: 0,
                                                  ),
                                                ),
                                              );
                                              await _socialController.refresh(
                                                currentUid: currentUid,
                                              );
                                              _refreshSilently();
                                            },
                                          ),
                                          Container(
                                            height: 24,
                                            width: 1,
                                            color: ThemeService.border,
                                          ),
                                          _buildStatColumn(
                                            '$liveAlliesCount',
                                            'allies'.tr(),
                                            () async {
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      SquadAlliesScreen(
                                                    userId: user.uid,
                                                    displayName:
                                                        user.displayName,
                                                    initialTabIndex: 1,
                                                  ),
                                                ),
                                              );
                                              await _socialController.refresh(
                                                currentUid: currentUid,
                                              );
                                              _refreshSilently();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        if (isMe) ...[
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF1877F2),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.edit_rounded,
                                                size: 18,
                                              ),
                                              label: Text(
                                                'btn_edit_profile'.tr(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              onPressed: () async {
                                                await Navigator.of(context)
                                                    .push(
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
                                              backgroundColor:
                                                  ThemeService.cardSecondary,
                                              foregroundColor:
                                                  ThemeService.textPrimary,
                                              side: BorderSide(
                                                color: ThemeService.border,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 14,
                                              ),
                                            ),
                                            icon: Icon(
                                              Icons.share_rounded,
                                              size: 18,
                                              color: ThemeService.textSecondary,
                                            ),
                                            label: Text(
                                              'share'.tr(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            onPressed: () =>
                                                _shareProfile(user),
                                          ),
                                        ] else ...[
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isAllied
                                                    ? ThemeService.cardSecondary
                                                    : const Color(0xFF1877F2),
                                                foregroundColor: isAllied
                                                    ? ThemeService.textPrimary
                                                    : Colors.white,
                                                elevation: 0,
                                                side: BorderSide(
                                                  color: isAllied
                                                      ? ThemeService.border
                                                      : Colors.transparent,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                ),
                                              ),
                                              icon: isToggling
                                                  ? SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: isAllied
                                                            ? ThemeService
                                                                .textPrimary
                                                            : Colors.white,
                                                      ),
                                                    )
                                                  : Icon(
                                                      isAllied
                                                          ? Icons
                                                              .how_to_reg_rounded
                                                          : Icons
                                                              .person_add_alt_1_rounded,
                                                      size: 18,
                                                    ),
                                              label: Text(
                                                isAllied
                                                    ? 'btn_allied'.tr()
                                                    : 'btn_add_ally'.tr(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              onPressed: isToggling
                                                  ? null
                                                  : () => _handleToggleAlly(
                                                        currentUid,
                                                      ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                backgroundColor:
                                                    ThemeService.cardSecondary,
                                                foregroundColor:
                                                    ThemeService.textPrimary,
                                                side: BorderSide(
                                                  color: const Color(0xFF00E5FF)
                                                      .withOpacity(0.5),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 12,
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons
                                                    .chat_bubble_outline_rounded,
                                                size: 18,
                                                color: Color(0xFF00E5FF),
                                              ),
                                              label: const Text(
                                                'Message',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _openDirectMessage(
                                                user,
                                                currentUid,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor:
                                                  ThemeService.cardSecondary,
                                              foregroundColor:
                                                  ThemeService.textPrimary,
                                              side: BorderSide(
                                                color: ThemeService.border,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 12,
                                              ),
                                              minimumSize: const Size(44, 44),
                                            ),
                                            onPressed: () =>
                                                _shareProfile(user),
                                            child: Icon(
                                              Icons.share_rounded,
                                              size: 18,
                                              color: ThemeService.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
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
                          tabs: [
                            Tab(
                              icon: const Icon(
                                Icons.grid_view_rounded,
                                size: 18,
                              ),
                              text: 'tab_posts'.tr(),
                            ),
                            Tab(
                              icon: const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                              ),
                              text: 'tab_about'.tr(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    PostsTab(user: user, isOwnProfile: isMe),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // 0. Tournament & Match Summary Stats Card
                          _buildMatchStatsSummaryCard(),

                          // 1. Main Game & Claimed Rank (Public)
                          _buildAboutTile(
                            icon: Icons.sports_esports_rounded,
                            iconColor: const Color(0xFF1877F2),
                            title: 'main_game_label'.tr(),
                            subtitle: '$gameEmoji ${user.favoriteGame}',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFFF8A00).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      const Color(0xFFFF8A00).withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                userRank,
                                style: const TextStyle(
                                  color: Color(0xFFFF8A00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),

                          // 2. Game UID with copy confirmation feedback
                          _buildAboutTile(
                            icon: Icons.badge_outlined,
                            iconColor: const Color(0xFF00FF88),
                            title: 'game_uid_label'.tr(),
                            subtitle: gameUidDisplay,
                            onTap: () {
                              _copyToClipboard(
                                value: gameUidCopyValue,
                                feedbackMessage:
                                    'Game UID copied: $gameUidCopyValue',
                                backgroundColor: const Color(0xFF00FF88),
                              );
                            },
                            trailing: IconButton(
                              icon: Icon(
                                Icons.copy_rounded,
                                size: 18,
                                color: hasValidGameUid
                                    ? const Color(0xFF00FF88)
                                    : ThemeService.textSecondary,
                              ),
                              tooltip: hasValidGameUid
                                  ? 'Copy Game UID'
                                  : 'Game UID not set',
                              onPressed: () {
                                _copyToClipboard(
                                  value: gameUidCopyValue,
                                  feedbackMessage:
                                      'Game UID copied: $gameUidCopyValue',
                                  backgroundColor: const Color(0xFF00FF88),
                                );
                              },
                            ),
                          ),

                          // 3. G-Coins Balance & 4. Esports Team Eligibility
                          ValueListenableBuilder<int>(
                            valueListenable:
                                WalletRepository.instance.gCoinsBalance,
                            builder: (context, repoCoins, _) {
                              final int liveGCoins = isMe
                                  ? (repoCoins > 0
                                      ? repoCoins
                                      : (CoinWalletService()
                                              .currentWallet
                                              ?.gCoins ??
                                          user.coins))
                                  : user.coins;
                              final String formattedGCoins =
                                  '${NumberFormat('#,###').format(liveGCoins)} G-Coins';

                              String esportsSubtitle;
                              if (liveGCoins >= 1000) {
                                final trLeader = 'esports_status_leader'.tr();
                                esportsSubtitle = (trLeader.isNotEmpty &&
                                        trLeader != 'esports_status_leader')
                                    ? trLeader
                                    : 'Leader & Member Eligible';
                              } else if (liveGCoins >= 500) {
                                final trMember = 'esports_status_member'.tr();
                                esportsSubtitle = (trMember.isNotEmpty &&
                                        trMember != 'esports_status_member')
                                    ? trMember
                                    : 'Team Member Eligible';
                              } else {
                                final trIneligible =
                                    'esports_status_ineligible'.tr();
                                esportsSubtitle = (trIneligible.isNotEmpty &&
                                        trIneligible !=
                                            'esports_status_ineligible')
                                    ? trIneligible
                                    : 'Ineligible (Min 500 G-Coins)';
                              }

                              return Column(
                                children: [
                                  _buildAboutTile(
                                    icon: Icons.monetization_on_rounded,
                                    iconColor: const Color(0xFFFFD700),
                                    title: 'G-Coins',
                                    subtitle: formattedGCoins,
                                    trailing: isMe
                                        ? Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: ThemeService.cardSecondary,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.history_rounded,
                                              size: 18,
                                              color: Color(0xFFFFD700),
                                            ),
                                          )
                                        : null,
                                    onTap: isMe
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const CoinWalletScreen(),
                                              ),
                                            );
                                          }
                                        : null,
                                  ),
                                  _buildAboutTile(
                                    icon: liveGCoins >= 1000
                                        ? Icons.verified_user_rounded
                                        : liveGCoins >= 500
                                            ? Icons.shield_outlined
                                            : Icons.warning_amber_rounded,
                                    iconColor: liveGCoins >= 1000
                                        ? const Color(0xFF00FF88)
                                        : liveGCoins >= 500
                                            ? const Color(0xFFFFB800)
                                            : const Color(0xFFFF4655),
                                    title: 'esports_team_status'.tr(),
                                    subtitle: esportsSubtitle,
                                  ),
                                ],
                              );
                            },
                          ),

                          // 5. Squad Invite Code (Private: Shown only on own profile `isMe == true`)
                          if (isMe)
                            _buildAboutTile(
                              icon: Icons.group_add_rounded,
                              iconColor: const Color(0xFF38BDF8),
                              title: 'Squad Invite Code',
                              subtitle: referralCode,
                              onTap: () {
                                _copyToClipboard(
                                  value: referralCode,
                                  feedbackMessage:
                                      'Squad Invite Code copied: $referralCode',
                                  backgroundColor: const Color(0xFF38BDF8),
                                );
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                color: const Color(0xFF38BDF8),
                                tooltip: 'Copy Invite Code',
                                onPressed: () {
                                  _copyToClipboard(
                                    value: referralCode,
                                    feedbackMessage:
                                        'Squad Invite Code copied: $referralCode',
                                    backgroundColor: const Color(0xFF38BDF8),
                                  );
                                },
                              ),
                            ),

                          // 6. Member Since (Public)
                          _buildAboutTile(
                            icon: Icons.calendar_month_rounded,
                            iconColor: Colors.purpleAccent,
                            title: 'Member Since',
                            subtitle: joinedDate,
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
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: ThemeService.card, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => true;
}
