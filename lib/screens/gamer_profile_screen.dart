// ===============================================================================
// GAMER PROFILE SCREEN — Full About Details, Badges & Multi-Language Sync
// + Adaptive Dark & Light Mode + Early Bird 1200 VIP Banner
// -------------------------------------------------------------------------------
// File: lib/screens/gamer_profile_screen.dart
// ===============================================================================

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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
import 'coin_wallet_screen.dart';
import '../services/app_share_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/rank_badge_widget.dart';
import '../widgets/early_bird_banner_widget.dart';
import '../services/profile_service.dart';
import '../services/block_service.dart';
import '../widgets/posts_tab.dart';
import 'create_gamer_id_screen.dart';
import 'followers_following_screen.dart';
import 'gamer_auth_screen.dart';
import 'profile_screen.dart';
import 'blocked_users_screen.dart';
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
  final BlockService _blockService = BlockService();
  final SocialProfileController _socialController = SocialProfileController();

  bool _isBlockedByMe = false;
  bool _isBlockedByThem = false;

  GamerUser? _cachedUser;
  bool _initialFetchDone = false;
  Timer? _refreshTimer;

  bool get _isOwnProfile {
    final currentUid = _authService.currentUid ?? '';
    final targetUid = widget.userId ?? currentUid;
    return currentUid.isNotEmpty &&
        GamerSocialService.stringToUuid(currentUid) ==
            GamerSocialService.stringToUuid(targetUid);
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
    final uid = widget.userId ?? currentUid;
    if (uid.isEmpty) return;
    try {
      final user = await _fetchGamerFromSupabase(uid);
      if (user != null && mounted) {
        setState(() {
          _cachedUser = user;
        });
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
    final uid = widget.userId ?? currentUid;
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
      await _socialController.bindProfile(
        targetUserId: user.uid,
        initialUser: user,
        currentUid: currentUid,
      );
    }
  }

  Future<void> _checkBlockStatus() async {
    final currentUid = _authService.currentUid ?? '';
    final targetUid = widget.userId ?? currentUid;
    if (currentUid.isEmpty ||
        GamerSocialService.stringToUuid(currentUid) ==
            GamerSocialService.stringToUuid(targetUid)) {
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
    });
  }

  Future<GamerUser?> _fetchGamerFromSupabase(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final row = await SupabaseService.client
          .from('users')
          .select()
          .or('id.eq.$userId,uid.eq.$userId')
          .maybeSingle();

      if (row != null) {
        var gamer = GamerUser.fromMap(row, userId);

        // Always read authoritative G-Coins balance from public.coin_wallets.g_coins
        try {
          if (_isOwnProfile) {
            final wallet = await CoinWalletService().getOrCreateWallet(userId);
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
                .eq('user_id', userId)
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

  void _shareProfile(GamerUser user) {
    final displayName = user.displayName.isNotEmpty ? user.displayName : user.username;
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
                    Text(
                      title,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    final isOwnProfile = _isOwnProfile;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageService.currentLanguage,
          builder: (context, langCode, _) {
            if (!isOwnProfile && _isBlockedByThem) {
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
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
                  ),
                ),
              );
            }

            if (_cachedUser == null) {
              if (!_initialFetchDone) {
                return Scaffold(
                  backgroundColor: ThemeService.bg,
                  body: const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2))),
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
                  child: isOwnProfile
                      ? ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CreateGamerIdScreen()),
                            );
                          },
                          child: Text('btn_create_gamer_id'.tr()),
                        )
                      : Text('gamer_id_not_found'.tr(), style: TextStyle(color: ThemeService.textPrimary)),
                ),
              );
            }

            final user = _cachedUser!;
            final gameEmoji = GamerTheme.gameEmojis[user.favoriteGame] ?? '🎮';
            final referralCode = CoinWalletService().getReferralCode(user.uid);
            final userRank = (user.selectedRank.isNotEmpty && user.selectedRank != 'None')
                ? user.selectedRank
                : (user.rank.isNotEmpty && user.rank != 'None' ? user.rank : 'Bronze');
            final joinedDate = user.createdAt != null
                ? DateFormat('dd MMM yyyy').format(user.createdAt!)
                : 'Recent Member';

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
                      automaticallyImplyLeading: !isOwnProfile,
                      iconTheme: IconThemeData(color: ThemeService.textPrimary),
                      actions: [
                        if (isOwnProfile)
                          IconButton(
                            icon: Icon(Icons.settings_rounded, color: ThemeService.textSecondary),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ProfileScreen()),
                              );
                            },
                          ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 175,
                              width: double.infinity,
                              decoration: BoxDecoration(color: ThemeService.cardSecondary),
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
                                  border: Border.all(color: ThemeService.card, width: 4),
                                ),
                                child: GamerAvatar(
                                  key: ValueKey('avatar_${user.uid}_${user.photoUrl}'),
                                  photoUrl: user.photoUrl,
                                  displayName: user.displayName,
                                  radius: 46,
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
                                    user.displayName.isNotEmpty ? user.displayName : user.username,
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
                                  const Icon(Icons.verified, color: Color(0xFF1877F2), size: 18),
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

                            // Early Bird Banner sirf apni profile par aur shuru ke 1200 users ko dikhega
                            if (isOwnProfile) ...[
                              const SizedBox(height: 10),
                              EarlyBirdBannerWidget(userId: user.uid),
                            ],

                            // Leader & Member Eligibility Banner sirf apni profile par dikhega
                            if (isOwnProfile) ...[
                              const SizedBox(height: 14),
                              ValueListenableBuilder<int>(
                                valueListenable: WalletRepository.instance.gCoinsBalance,
                                builder: (context, repoCoins, _) {
                                  final int liveGCoins = repoCoins > 0
                                      ? repoCoins
                                      : (CoinWalletService().currentWallet?.gCoins ?? user.coins);
                                  return _buildTeamEligibilityCard(liveGCoins);
                                },
                              ),
                            ],

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
                                final isToggling =
                                    _socialController.isToggling;

                                return Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: ThemeService.card,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: ThemeService.border),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildStatColumn('${user.postsCount}', 'posts'.tr(), () {
                                            _tabController.animateTo(0);
                                          }),
                                          Container(height: 24, width: 1, color: ThemeService.border),
                                          _buildStatColumn('$liveSquadCount', 'squad'.tr(), () async {
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => SquadAlliesScreen(
                                                  userId: user.uid,
                                                  displayName: user.displayName,
                                                  initialTabIndex: 0,
                                                ),
                                              ),
                                            );
                                            await _socialController.refresh(currentUid: currentUid);
                                            _refreshSilently();
                                          }),
                                          Container(height: 24, width: 1, color: ThemeService.border),
                                          _buildStatColumn('$liveAlliesCount', 'allies'.tr(), () async {
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => SquadAlliesScreen(
                                                  userId: user.uid,
                                                  displayName: user.displayName,
                                                  initialTabIndex: 1,
                                                ),
                                              ),
                                            );
                                            await _socialController.refresh(currentUid: currentUid);
                                            _refreshSilently();
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
                                                backgroundColor: const Color(0xFF1877F2),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              icon: const Icon(Icons.edit_rounded, size: 18),
                                              label: Text('btn_edit_profile'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                              onPressed: () async {
                                                await Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => CreateGamerIdScreen(
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
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                            ),
                                            icon: Icon(Icons.share_rounded, size: 18, color: ThemeService.textSecondary),
                                            label: Text('share'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                            onPressed: () => _shareProfile(user),
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
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              icon: isToggling
                                                  ? SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: isAllied
                                                            ? ThemeService.textPrimary
                                                            : Colors.white,
                                                      ),
                                                    )
                                                  : Icon(
                                                      isAllied
                                                          ? Icons.how_to_reg_rounded
                                                          : Icons.person_add_alt_1_rounded,
                                                      size: 18,
                                                    ),
                                              label: Text(
                                                isAllied ? 'btn_allied'.tr() : 'btn_add_ally'.tr(),
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: isToggling
                                                  ? null
                                                  : () => _handleToggleAlly(currentUid),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: ThemeService.cardSecondary,
                                              foregroundColor: ThemeService.textPrimary,
                                              side: BorderSide(color: ThemeService.border),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                            ),
                                            icon: Icon(Icons.share_rounded, size: 18, color: ThemeService.textSecondary),
                                            label: Text('share'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                            onPressed: () => _shareProfile(user),
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
                            Tab(icon: const Icon(Icons.grid_view_rounded, size: 18), text: 'tab_posts'.tr()),
                            Tab(icon: const Icon(Icons.info_outline_rounded, size: 18), text: 'tab_about'.tr()),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    PostsTab(user: user, isOwnProfile: isOwnProfile),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // 1. Main Game & Claimed Rank (Public)
                          _buildAboutTile(
                            icon: Icons.sports_esports_rounded,
                            iconColor: const Color(0xFF1877F2),
                            title: 'main_game_label'.tr(),
                            subtitle: '$gameEmoji ${user.favoriteGame}',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF8A00).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.4)),
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

                          // 2. Character ID / In-game UID (Locked: Sirf profile owner ko dikhega)
                          if (isOwnProfile)
                            _buildAboutTile(
                              icon: Icons.badge_outlined,
                              iconColor: const Color(0xFF00FF88),
                              title: 'game_uid_label'.tr(),
                              subtitle: user.gameId.isNotEmpty ? user.gameId : 'Not set',
                              trailing: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                color: ThemeService.textSecondary,
                                tooltip: 'Copy ID',
                                onPressed: () {
                                  final text = user.gameId.isNotEmpty ? user.gameId : user.uid;
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('ID copied: $text'),
                                      backgroundColor: const Color(0xFF00FF88),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ),

                          // 3. G-Coins Balance & 4. eSports Team Eligibility (Live Synced with WalletRepository)
                          ValueListenableBuilder<int>(
                            valueListenable: WalletRepository.instance.gCoinsBalance,
                            builder: (context, repoCoins, _) {
                              final int liveGCoins = isOwnProfile
                                  ? (repoCoins > 0
                                      ? repoCoins
                                      : (CoinWalletService().currentWallet?.gCoins ?? user.coins))
                                  : user.coins;
                              final String formattedGCoins =
                                  '${NumberFormat('#,###').format(liveGCoins)} G-Coins';

                              String esportsSubtitle;
                              if (liveGCoins >= 1000) {
                                final trLeader = 'esports_status_leader'.tr();
                                esportsSubtitle = (trLeader.isNotEmpty && trLeader != 'esports_status_leader')
                                    ? trLeader
                                    : 'Leader & Member Eligible';
                              } else if (liveGCoins >= 500) {
                                final trMember = 'esports_status_member'.tr();
                                esportsSubtitle = (trMember.isNotEmpty && trMember != 'esports_status_member')
                                    ? trMember
                                    : 'Team Member Eligible';
                              } else {
                                final trIneligible = 'esports_status_ineligible'.tr();
                                esportsSubtitle = (trIneligible.isNotEmpty && trIneligible != 'esports_status_ineligible')
                                    ? trIneligible
                                    : 'Ineligible (Min 500 G-Coins)';
                              }

                              return Column(
                                children: [
                                  if (isOwnProfile)
                                    _buildAboutTile(
                                      icon: Icons.monetization_on_rounded,
                                      iconColor: const Color(0xFFFFD700),
                                      title: 'G-Coins',
                                      subtitle: formattedGCoins,
                                      trailing: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: ThemeService.cardSecondary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.history_rounded,
                                          size: 18,
                                          color: Color(0xFFFFD700),
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const CoinWalletScreen(),
                                          ),
                                        );
                                      },
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

                          // 5. Squad Referral Code (Locked: Sirf profile owner ko dikhega)
                          if (isOwnProfile)
                            _buildAboutTile(
                              icon: Icons.group_add_rounded,
                              iconColor: const Color(0xFF38BDF8),
                              title: 'Squad Invite Code',
                              subtitle: referralCode,
                              trailing: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                color: const Color(0xFF38BDF8),
                                tooltip: 'Copy Invite Code',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: referralCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Squad Invite Code copied: $referralCode'),
                                      backgroundColor: const Color(0xFF38BDF8),
                                      duration: const Duration(seconds: 2),
                                    ),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: ThemeService.card, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => true;
}
