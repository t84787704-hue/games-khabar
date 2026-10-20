// ===============================================================================
// GAMER PROFILE SCREEN — With eSports 500/1000 Coins Team Eligibility Badges
// + Multi-Language Live Translation Sync via LanguageService
// + Adaptive Dark & Light Mode + 100% Clean Compilation
// -------------------------------------------------------------------------------
// File: lib/screens/gamer_profile_screen.dart
// ===============================================================================

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
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
import '../services/language_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/rank_badge_widget.dart';
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

  bool _isBlockedByMe = false;
  bool _isBlockedByThem = false;

  GamerUser? _cachedUser;
  bool _initialFetchDone = false;
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
      if (mounted) setState(() => _initialFetchDone = true);
      return;
    }

    final user = await _fetchGamerFromSupabase(uid);
    if (!mounted) return;
    setState(() {
      _cachedUser = user;
      _initialFetchDone = true;
    });
  }

  Future<void> _checkBlockStatus() async {
    final currentUid = _authService.currentUid ?? '';
    final targetUid = widget.userId ?? currentUid;
    if (currentUid.isEmpty || currentUid == targetUid) return;

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
        return GamerUser.fromMap(row, userId);
      }
    } catch (e) {
      debugPrint('[GamerProfile] Fetch error: $e');
    }
    return null;
  }

  void _shareProfile(GamerUser user) {
    final displayName = user.displayName.isNotEmpty ? user.displayName : user.username;
    final game = user.favoriteGame.isNotEmpty ? user.favoriteGame : 'BGMI';

    final bool hasValidRank = user.isRankApproved &&
        user.rank.isNotEmpty &&
        user.rank.toLowerCase() != 'none' &&
        user.rank.toLowerCase() != 'skip';
    final String rankText = hasValidRank ? ' | Rank: ${user.rank}' : '';

    final bio = user.bio.trim();
    final String bioText = bio.isNotEmpty ? '\n💬 "$bio"' : '';

    const String appLink = 'https://play.google.com/store/apps/details?id=com.gameskhabar.gamersid';

    final String shareMessage = '''
🔥 Check out $displayName on Gamers ID!

🎮 Handle: @${user.username}
🎯 Game: $game$rankText
📊 Stats: ${user.followersCount} Followers • ${user.postsCount} Posts$bioText

⚔️ Mujhe custom rooms aur 1v1 matches mein challenge karein!
📲 Download Gamers ID App:
👉 $appLink
'''.trim();

    Share.share(
      shareMessage,
      subject: 'Follow $displayName on Gamers ID',
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

  /// ✅ eSports Team Eligibility Badge (1,000 / 500 Coins Rule)
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
                        'coins_count_label'.tr(args: ['$coins']),
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

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? '';
    final targetUid = widget.userId ?? currentUid;
    final isOwnProfile = currentUid == targetUid;

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
            final gameColor = GamerTheme.gameColors[user.favoriteGame] ?? const Color(0xFF1877F2);
            final gameEmoji = GamerTheme.gameEmojis[user.favoriteGame] ?? '🎮';

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
                                    user.displayName,
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

                            const SizedBox(height: 14),

                            // ✅ eSports Team Eligibility Card
                            _buildTeamEligibilityCard(user.coins),

                            const SizedBox(height: 14),

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
                                  _buildStatColumn('${user.followersCount}', 'followers'.tr(), () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FollowersFollowingScreen(
                                          userId: user.uid,
                                          displayName: user.displayName,
                                          initialTabIndex: 0,
                                        ),
                                      ),
                                    );
                                  }),
                                  Container(height: 24, width: 1, color: ThemeService.border),
                                  _buildStatColumn('${user.followingCount}', 'following'.tr(), () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FollowersFollowingScreen(
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
                                        backgroundColor: const Color(0xFF1877F2),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.share_rounded, size: 16),
                                      label: Text('btn_share_profile'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      onPressed: () => _shareProfile(user),
                                    ),
                                  ),
                                ],
                              ],
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.sports_esports, color: Color(0xFF1877F2)),
                            title: Text('main_game_label'.tr()),
                            subtitle: Text('$gameEmoji ${user.favoriteGame}'),
                          ),
                          if (user.gameId.isNotEmpty)
                            ListTile(
                              leading: const Icon(Icons.tag, color: Color(0xFF1877F2)),
                              title: Text('game_uid_label'.tr()),
                              subtitle: Text(user.gameId),
                            ),
                          ListTile(
                            leading: const Icon(Icons.monetization_on, color: Color(0xFFFFD700)),
                            title: Text('g_coins_label'.tr()),
                            subtitle: Text('coins_count'.tr(args: ['${user.coins}'])),
                            trailing: const Icon(Icons.history_rounded, size: 20),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => CoinHistorySheet(userId: user.uid),
                              );
                            },
                          ),
                          ListTile(
                            leading: Icon(
                              user.coins >= 1000
                                  ? Icons.verified_user_rounded
                                  : user.coins >= 500
                                      ? Icons.shield_outlined
                                      : Icons.warning_amber_rounded,
                              color: user.coins >= 1000
                                  ? const Color(0xFF00FF88)
                                  : user.coins >= 500
                                      ? const Color(0xFFFFB800)
                                      : const Color(0xFFFF4655),
                            ),
                            title: Text('esports_team_status'.tr()),
                            subtitle: Text(
                              user.coins >= 1000
                                  ? 'esports_status_leader'.tr()
                                  : user.coins >= 500
                                      ? 'esports_status_member'.tr()
                                      : 'esports_status_ineligible'.tr(),
                            ),
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
