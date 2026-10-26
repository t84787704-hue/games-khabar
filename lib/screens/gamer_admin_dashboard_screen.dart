// ===============================================================================
// GAMER ADMIN DASHBOARD SCREEN — Real-time Counts, Dual Proofs & Auto Leaderboard
// File: lib/screens/gamer_admin_dashboard_screen.dart
// ===============================================================================

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/gamer_theme.dart';
import '../constants/mobile_games_rank_data.dart';
import '../models/gamer_user_model.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/rank_badge_widget.dart';
import '../utils/admin_security.dart';
import '../services/demo_accounts_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/coin_reward_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/team_service.dart';
import '../services/theme_service.dart';
import '../models/team_model.dart';
import 'admin/admin_team_matches_screen.dart';
import 'admin/admin_proofs_tabs.dart';

class GamerAdminDashboardScreen extends StatefulWidget {
  const GamerAdminDashboardScreen({super.key});

  @override
  State<GamerAdminDashboardScreen> createState() =>
      _GamerAdminDashboardScreenState();
}

class _GamerAdminDashboardScreenState extends State<GamerAdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _userSearchQuery = '';
  bool _isSeedingDemo = false;
  bool _isDeletingDemo = false;

  final TextEditingController _rankSearchController = TextEditingController();
  String _rankSearchQuery = '';
  String _selectedRankGameFilter = 'All';
  bool _showOnlyPendingRanks = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 14, vsync: this);
    _ensureSampleQueueExists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _rankSearchController.dispose();
    super.dispose();
  }

  Future<void> _ensureSampleQueueExists() async {
    try {
      final demoService = DemoAccountsService();
      final count = await demoService.getDemoAccountsCount();
      if (count == 0) {
        await demoService.seedDemoAccounts();
      }
    } catch (_) {}
  }

  Future<void> _handleSeedDemoAccounts() async {
    setState(() => _isSeedingDemo = true);
    try {
      await DemoAccountsService().seedDemoAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Successfully created 10 Professional Demo Accounts with Posts!'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error seeding demo accounts: $e'),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeedingDemo = false);
    }
  }

  Future<void> _handleDeleteAllDemoAccounts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655)),
            const SizedBox(width: 8),
            Text('Delete All Demo Accounts?',
                style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This will permanently delete all 10 demo accounts (isDemoAccount == true) and their posts, clips, and follows. Real accounts will not be touched.',
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeletingDemo = true);
    try {
      final count = await DemoAccountsService().deleteAllDemoAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Successfully deleted $count demo accounts and associated data.'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting demo accounts: $e'),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingDemo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: ThemeService.bg,
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 14),
                          _buildStatsCards(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: const Color(0xFF00FF88),
                        indicatorWeight: 3,
                        labelColor: const Color(0xFF00FF88),
                        unselectedLabelColor: ThemeService.textSecondary,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        tabs: [
                          const Tab(text: 'Tournaments 🏆'),
                          const Tab(text: 'Banner 📢'),
                          const Tab(text: 'Users'),
                          _buildRankVerifyTabTitle(),
                          _buildBlueTickTabTitle(),
                          const Tab(text: 'UC Requests ⚡'),
                          const Tab(text: 'UC History 📜'),
                          const Tab(text: 'Posts Moderation'),
                          const Tab(text: 'Team Matches ⚔️'),
                          const Tab(text: 'Reports'),
                          const Tab(text: 'Coins'),
                          const Tab(text: 'Referrals 👥'),
                          const Tab(text: 'Under Review 🔍'),
                          const Tab(text: 'History 📜'),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  const _AdminTournamentsTab(),
                  const _AdminBannerControlTab(),
                  _buildUsersTab(),
                  _buildRankVerifyTab(),
                  _buildBlueTickRequestsTab(),
                  const _AdminUcRequestsTab(),
                  const _AdminUcHistoryTab(),
                  _buildPostsModerationTab(),
                  const AdminTeamMatchesScreen(),
                  _buildReportsTab(),
                  _buildCoinsTab(),
                  _buildReferralsTrackerTab(),
                  const AdminUnderReviewTab(),
                  const AdminProofHistoryTab(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankVerifyTabTitle() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, snapshot) {
        int pendingCount = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!) {
            final rawGames = doc['games'];
            if (rawGames is List) {
              for (final g in rawGames) {
                if (g is Map && (g['status'] ?? '').toString().toLowerCase() == 'pending') {
                  pendingCount++;
                }
              }
            }
          }
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Rank Verify'),
            if (pendingCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A00),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingCount pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBlueTickTabTitle() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, snapshot) {
        int pendingCount = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!) {
            final isVerified = doc['is_verified'] == true || doc['has_blue_tick'] == true;
            final vStatus = (doc['verification_status'] ?? doc['blue_tick_status'] ?? '').toString().toLowerCase();
            if (!isVerified && (vStatus == 'pending' || vStatus == 'under_review' || vStatus == 'submitted')) {
              pendingCount++;
            }
          }
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Blue Tick Requests'),
            if (pendingCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingCount pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, snapshot) {
        String currentEmail = 'Admin';
        if (snapshot.hasData) {
          final sbUserId = SupabaseService.client.auth.currentUser?.id;
          if (sbUserId != null) {
            for (final u in snapshot.data!) {
              if (u['id'] == sbUserId) {
                currentEmail = u['email']?.toString() ?? 'Admin';
                break;
              }
            }
          }
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThemeService.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF00FF88).withOpacity(0.4)),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFF00FF88),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Gamers ID Network • Admin Only',
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Active Admin: $currentEmail',
                      style: TextStyle(
                        color: ThemeService.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00FF88)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record,
                        color: Color(0xFF00FF88), size: 10),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCards() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, userSnap) {
        int totalUsers = 0;
        int totalCoins = 0;

        if (userSnap.hasData) {
          totalUsers = userSnap.data!.length;
          for (final doc in userSnap.data!) {
            final raw = doc['coins'];
            totalCoins += (raw as num?)?.toInt() ?? 0;
          }
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.getRealtimePosts(),
          builder: (context, postSnap) {
            final totalPosts = postSnap.data?.length ?? 0;

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.getRealtimeReports(),
              builder: (context, reportSnap) {
                final totalReports = reportSnap.data?.length ?? 0;

                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.8,
                  children: [
                    _buildStatCard(
                      title: 'Total Users',
                      value: '$totalUsers',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF38BDF8),
                    ),
                    _buildStatCard(
                      title: 'Posts',
                      value: '$totalPosts',
                      icon: Icons.dynamic_feed_rounded,
                      color: const Color(0xFF00FF88),
                    ),
                    _buildStatCard(
                      title: 'Reports',
                      value: '$totalReports',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFFF4655),
                    ),
                    _buildStatCard(
                      title: 'Coins Distributed',
                      value: '$totalCoins 🪙',
                      icon: Icons.monetization_on_rounded,
                      color: const Color(0xFFFFD700),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeService.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ===================== TAB 1: USERS =====================
  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) =>
                setState(() => _userSearchQuery = val.toLowerCase().trim()),
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search users by name, @username, or tag...',
              hintStyle:
                  TextStyle(color: ThemeService.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  color: ThemeService.textSecondary, size: 20),
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color: ThemeService.textSecondary, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _userSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: ThemeService.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ThemeService.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ThemeService.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Color(0xFF00FF88)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSeedingDemo ? null : _handleSeedDemoAccounts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF00FF88).withOpacity(0.12),
                    foregroundColor: const Color(0xFF00FF88),
                    side: const BorderSide(
                        color: Color(0xFF00FF88), width: 1.2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSeedingDemo
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF00FF88)),
                        )
                      : const Icon(Icons.group_add_rounded, size: 16),
                  label: Text(
                    _isSeedingDemo ? 'Seeding...' : 'Seed 10 Pro Demo',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _isDeletingDemo ? null : _handleDeleteAllDemoAccounts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFFF4655).withOpacity(0.12),
                    foregroundColor: const Color(0xFFFF4655),
                    side: const BorderSide(
                        color: Color(0xFFFF4655), width: 1.2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isDeletingDemo
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFFF4655)),
                        )
                      : const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: Text(
                    _isDeletingDemo ? 'Deleting...' : 'Delete All Demo',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.getRealtimeUsers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFFF4655), size: 48),
                        const SizedBox(height: 14),
                        Text(
                          'Could not load users',
                          style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: ThemeService.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFF00FF88)),
                );
              }

              final docs = snapshot.data ?? [];
              List<GamerUser> users =
                  docs.map((d) => GamerUser.fromMap(d)).toList();

              if (_userSearchQuery.isNotEmpty) {
                users = users.where((u) {
                  return u.displayName
                          .toLowerCase()
                          .contains(_userSearchQuery) ||
                      u.username.toLowerCase().contains(_userSearchQuery) ||
                      u.uid.toLowerCase().contains(_userSearchQuery);
                }).toList();
              }

              if (users.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: ThemeService.card,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: ThemeService.border),
                          ),
                          child: Icon(Icons.people_outline_rounded,
                              color: ThemeService.textSecondary, size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No users found',
                          style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _userSearchQuery.isNotEmpty
                              ? 'Try a different search term'
                              : 'No users registered yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: ThemeService.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _buildUserCard(user);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(GamerUser user) {
    final joinedDays = user.createdAt != null
        ? DateTime.now().difference(user.createdAt!).inDays
        : 14;
    final joinedText = 'Joined $joinedDays days ago';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isBanned
              ? const Color(0xFFFF4655)
              : ThemeService.border,
          width: user.isBanned ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GamerAvatar(
                photoUrl: user.photoUrl,
                displayName: user.displayName,
                radius: 22,
                borderColor: user.isBanned
                    ? const Color(0xFFFF4655)
                    : const Color(0xFFFF8A00),
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
                            user.displayName.isNotEmpty
                                ? user.displayName
                                : '@${user.username}',
                            style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.hasBlueTick) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              color: Color(0xFF38BDF8), size: 16),
                        ],
                        const SizedBox(width: 6),
                        RankBadgeWidget(
                            badge: user.getRankBadge(),
                            size: 14,
                            showLabel: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '@${user.username}',
                          style: TextStyle(
                              color: ThemeService.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  🪙 ${user.coins} Coins',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          joinedText,
                          style: TextStyle(
                              color: ThemeService.textSecondary.withOpacity(0.7), fontSize: 11),
                        ),
                        if (user.isDemoAccount) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: ThemeService.cardSecondary,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: ThemeService.border, width: 0.8),
                            ),
                            child: Text(
                              'DEMO',
                              style: TextStyle(
                                color: ThemeService.textSecondary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                        if (user.isBanned) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFFF4655).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: const Color(0xFFFF4655)),
                            ),
                            child: const Text(
                              'BANNED',
                              style: TextStyle(
                                color: Color(0xFFFF4655),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: ThemeService.border, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _toggleBanUser(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: user.isBanned
                      ? const Color(0xFF00FF88)
                      : const Color(0xFFFF4655),
                  side: BorderSide(
                    color: user.isBanned
                        ? const Color(0xFF00FF88)
                        : const Color(0xFFFF4655),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(
                  user.isBanned
                      ? Icons.check_circle_outline
                      : Icons.block_rounded,
                  size: 14,
                ),
                label: Text(
                  user.isBanned ? 'Unban' : 'Ban',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBanUser(GamerUser user) async {
    final nextBanned = !user.isBanned;
    final sbAdminId = SupabaseService.client.auth.currentUser?.id ?? '';
    try {
      bool ok;
      if (nextBanned) {
        ok = await SupabaseService.banUser(
          userId: user.uid,
          adminId: sbAdminId,
          reason: 'Violating community guidelines or banned by admin',
        );
      } else {
        ok = await SupabaseService.unbanUser(user.uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? (nextBanned
                      ? 'User @${user.username} banned successfully'
                      : 'User @${user.username} unbanned successfully')
                  : 'Error updating ban status',
            ),
            backgroundColor: ok
                ? (nextBanned
                    ? const Color(0xFFFF4655)
                    : const Color(0xFF00FF88))
                : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating user ban: $e'),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  // ===================== TAB 2: RANK VERIFY =====================
  Widget _buildRankVerifyTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: ThemeService.bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _rankSearchController,
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by username or Game ID...',
                  hintStyle:
                      TextStyle(color: ThemeService.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF00FF88), size: 18),
                  suffixIcon: _rankSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: ThemeService.textSecondary, size: 16),
                          onPressed: () {
                            _rankSearchController.clear();
                            setState(() => _rankSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: ThemeService.card,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ThemeService.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ThemeService.border),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: Color(0xFF00FF88)),
                  ),
                ),
                onChanged: (val) => setState(
                    () => _rankSearchQuery = val.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final game in [
                      'All',
                      ...MobileGamesRankData.games
                    ]) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(game),
                          selected: _selectedRankGameFilter == game,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedRankGameFilter = game);
                            }
                          },
                          selectedColor: const Color(0xFF00FF88),
                          backgroundColor: ThemeService.card,
                          labelStyle: TextStyle(
                            color: _selectedRankGameFilter == game
                                ? const Color(0xFF0B0F14)
                                : ThemeService.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: _selectedRankGameFilter == game
                                  ? const Color(0xFF00FF88)
                                  : ThemeService.border,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    FilterChip(
                      label: Text(_showOnlyPendingRanks
                          ? '⏳ Pending'
                          : '📋 All History'),
                      selected: _showOnlyPendingRanks,
                      onSelected: (val) =>
                          setState(() => _showOnlyPendingRanks = val),
                      selectedColor:
                          const Color(0xFFFF8A00).withOpacity(0.2),
                      backgroundColor: ThemeService.card,
                      labelStyle: TextStyle(
                        color: _showOnlyPendingRanks
                            ? const Color(0xFFFF8A00)
                            : ThemeService.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _showOnlyPendingRanks
                              ? const Color(0xFFFF8A00)
                              : ThemeService.border,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.getRealtimeUsers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFFF4655), size: 48),
                        const SizedBox(height: 14),
                        Text('Could not load rank requests',
                            style: TextStyle(
                                color: ThemeService.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 6),
                        Text('${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: ThemeService.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF00FF88)));
              }

              final docs = snapshot.data ?? [];
              final List<_RankQueueItem> allItems = [];

              for (final doc in docs) {
                final user = GamerUser.fromMap(doc);
                for (int i = 0; i < user.games.length; i++) {
                  final game = user.games[i];
                  allItems.add(
                      _RankQueueItem(user: user, game: game, gameIndex: i));
                }

                final bool hasGameForRank = user.games.any((g) =>
                    g.claimedRank.toLowerCase() == user.rank.toLowerCase());
                if (!hasGameForRank &&
                    user.rank.isNotEmpty &&
                    user.rank.toLowerCase() != 'none' &&
                    user.rank.toLowerCase() != 'skip' &&
                    (user.rankStatus.toLowerCase() == 'pending' ||
                        user.rankStatus.toLowerCase() == 'verified' ||
                        user.rankStatus.toLowerCase() == 'rejected' ||
                        user.rankScreenshot.isNotEmpty)) {
                  final rankStatus = user.rankStatus.toLowerCase();
                  final normalizedStatus = rankStatus == 'verified'
                      ? 'approved'
                      : (rankStatus == 'rejected' ? 'rejected' : 'pending');
                  final primaryGame = UserGameRank(
                    id: 'primary_${user.uid}',
                    gameName: user.selectedGame.isNotEmpty
                        ? user.selectedGame
                        : (user.favoriteGame.isNotEmpty
                            ? user.favoriteGame
                            : 'BGMI'),
                    gameId: user.gameId.isNotEmpty ? user.gameId : 'N/A',
                    claimedRank: user.rank,
                    verifiedRank: (user.isRankApproved ||
                            rankStatus == 'verified')
                        ? user.rank
                        : '',
                    isVerified:
                        user.isRankApproved || rankStatus == 'verified',
                    screenshotUrl: user.rankScreenshot,
                    status: normalizedStatus,
                    submittedAt: user.createdAt,
                    rejectReason: user.rankRejectReason,
                    ownerUid: user.uid,
                  );
                  allItems.add(_RankQueueItem(
                      user: user, game: primaryGame, gameIndex: -1));
                }
              }

              final filtered = allItems.where((item) {
                if (_showOnlyPendingRanks && item.game.status != 'pending') {
                  return false;
                }
                if (_selectedRankGameFilter != 'All' &&
                    item.game.gameName.toLowerCase() !=
                        _selectedRankGameFilter.toLowerCase()) {
                  return false;
                }
                if (_rankSearchQuery.isNotEmpty) {
                  final uName = item.user.username.toLowerCase();
                  final dName = item.user.displayName.toLowerCase();
                  final gId = item.game.gameId.toLowerCase();
                  final rank = item.game.claimedRank.toLowerCase();
                  if (!uName.contains(_rankSearchQuery) &&
                      !dName.contains(_rankSearchQuery) &&
                      !gId.contains(_rankSearchQuery) &&
                      !rank.contains(_rankSearchQuery)) {
                    return false;
                  }
                }
                return true;
              }).toList();

              filtered.sort((a, b) {
                if (a.game.status == 'pending' &&
                    b.game.status != 'pending') return -1;
                if (a.game.status != 'pending' &&
                    b.game.status == 'pending') return 1;
                final aTime = a.game.submittedAt ?? DateTime(2020);
                final bTime = b.game.submittedAt ?? DateTime(2020);
                return bTime.compareTo(aTime);
              });

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: ThemeService.card,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: ThemeService.border),
                          ),
                          child: Icon(Icons.verified_outlined,
                              color: ThemeService.textSecondary, size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No rank verification requests found',
                          style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _showOnlyPendingRanks
                              ? 'All pending screenshot rank submissions have been reviewed!'
                              : 'No requests match the selected filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: ThemeService.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildVerificationRequestCard(filtered[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationRequestCard(_RankQueueItem item) {
    final user = item.user;
    final game = item.game;
    final isPending = game.status == 'pending';
    final isApproved = game.status == 'approved' || game.isVerified;
    final isRejected = game.status == 'rejected';

    final Color statusColor = isApproved
        ? const Color(0xFF00FF88)
        : (isPending ? const Color(0xFFFF8A00) : const Color(0xFFFF4655));

    final String statusLabel = isApproved
        ? 'Approved ✓'
        : (isPending ? 'Pending Review ⏳' : 'Rejected ✕');

    final String dateStr = game.submittedAt != null
        ? DateFormat('dd MMM, hh:mm a').format(game.submittedAt!)
        : 'Recently';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? const Color(0xFFFF8A00).withOpacity(0.5)
              : ThemeService.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GamerAvatar(
                photoUrl: user.photoUrl,
                radius: 20,
                displayName: user.displayName.isNotEmpty
                    ? user.displayName
                    : user.username,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isNotEmpty
                          ? user.displayName
                          : user.username,
                      style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    Text(
                      '@${user.username} • UID: ${user.uid.length > 8 ? user.uid.substring(0, 8) : user.uid}',
                      style: TextStyle(
                          color: ThemeService.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: ThemeService.border, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sports_esports_rounded,
                        size: 14, color: Color(0xFF00FF88)),
                    const SizedBox(width: 4),
                    Text(
                      game.gameName,
                      style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ID: ${game.gameId}',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dateStr,
                style:
                    TextStyle(color: ThemeService.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Claimed Rank: ',
                style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xFFFF8A00).withOpacity(0.5)),
                ),
                child: Text(
                  game.claimedRank,
                  style: const TextStyle(
                    color: Color(0xFFFF8A00),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isApproved && game.verifiedRank.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded,
                    size: 12, color: ThemeService.textSecondary),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.5)),
                  ),
                  child: Text(
                    'Verified: ${game.verifiedRank}',
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (game.screenshotUrl.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _showScreenshotViewerDialog(
                imageUrl: game.screenshotUrl,
                title:
                    '${user.displayName} • ${game.gameName} Rank Proof',
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: game.screenshotUrl,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 140,
                        color: ThemeService.cardSecondary,
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF00FF88), strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 140,
                        color: ThemeService.cardSecondary,
                        child: Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: ThemeService.textSecondary, size: 36),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded,
                                size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Tap to inspect proof',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeService.cardSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.image_not_supported_rounded,
                      color: ThemeService.textSecondary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'No screenshot uploaded',
                    style:
                        TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          if (isRejected &&
              game.rejectReason != null &&
              game.rejectReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4655).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFF4655).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFFF4655), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${game.rejectReason}',
                      style: const TextStyle(
                          color: Color(0xFFFF4655), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            _AdminRankActionButtons(
              item: item,
              onApprove: () => _approveRankVerification(item),
              onReject: (reason) => _rejectRankVerification(item, reason),
            ),
          ],
        ],
      ),
    );
  }

  void _showScreenshotViewerDialog(
      {required String imageUrl, required String title}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ThemeService.card,
        insetPadding: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: ThemeService.textSecondary, size: 20),
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
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(
                          color: Color(0xFF00FF88)),
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

  Future<void> _approveRankVerification(_RankQueueItem item) async {
    try {
      final targetUserId = item.game.ownerUid.isNotEmpty
          ? item.game.ownerUid
          : item.user.uid;
      final currentAdmin =
          GamerAuthService().currentGamer?.displayName ?? 'Admin';

      final ok = await SupabaseService.approveRank(
        userId: targetUserId,
        rank: item.game.claimedRank,
        gameName: item.game.gameName,
        adminName: currentAdmin,
      );

      try {
        await NotificationService().createNotification(
          userId: targetUserId,
          title: 'Rank Verified! 🎉',
          body:
              'rank_approved_notif_body'.tr(args: [item.game.claimedRank, item.game.gameName]),
          type: 'rank_verified',
        );
      } catch (e) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Approved ${item.game.gameName} rank (${item.game.claimedRank}) for @${item.user.username}!'
                  : 'Error approving rank',
            ),
            backgroundColor:
                ok ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error approving rank: $e'),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  Future<void> _rejectRankVerification(
      _RankQueueItem item, String reason) async {
    try {
      final targetUserId = item.game.ownerUid.isNotEmpty
          ? item.game.ownerUid
          : item.user.uid;
      final currentAdmin =
          GamerAuthService().currentGamer?.displayName ?? 'Admin';
      final defaultUrduMsg = 'screenshot_invalid_reupload'.tr();
      final finalReason =
          reason.trim().isNotEmpty ? reason.trim() : defaultUrduMsg;

      final ok = await SupabaseService.rejectRank(
        userId: targetUserId,
        reason: finalReason,
        adminName: currentAdmin,
      );

      try {
        await NotificationService().createNotification(
          userId: targetUserId,
          title: 'Rank Verification Notice ⚠️',
          body: defaultUrduMsg,
          type: 'rank_rejected',
        );
      } catch (e) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Rejected ${item.game.gameName} rank verification for @${item.user.username}'
                  : 'Error rejecting rank',
            ),
            backgroundColor:
                ok ? const Color(0xFFFF8A00) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error rejecting rank: $e'),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  // ===================== TAB 3: BLUE TICK REQUESTS =====================
  Widget _buildBlueTickRequestsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFFF4655), size: 48),
                  const SizedBox(height: 14),
                  Text('Could not load blue tick requests',
                      style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ThemeService.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final docs = snapshot.data ?? [];

        final allUsersSorted = List<Map<String, dynamic>>.from(docs);
        allUsersSorted.sort((a, b) {
          final tA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2020);
          final tB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2020);
          return tA.compareTo(tB);
        });

        final List<Map<String, dynamic>> requestsWithIndex = [];
        for (final d in docs) {
          final isVerified = d['is_verified'] == true || d['has_blue_tick'] == true;
          final vStatus = (d['verification_status'] ?? d['blue_tick_status'] ?? '').toString().toLowerCase();

          if (!isVerified && (vStatus == 'pending' || vStatus == 'under_review' || vStatus == 'submitted')) {
            final userObj = GamerUser.fromMap(d);
            final userIndex = allUsersSorted.indexWhere((u) => (u['id'] ?? u['uid']) == userObj.uid) + 1;

            requestsWithIndex.add({
              'user': userObj,
              'raw': d,
              'rankNumber': userIndex > 0 ? userIndex : 9999,
            });
          }
        }

        if (requestsWithIndex.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: ThemeService.border),
                    ),
                    child: const Icon(Icons.verified_outlined,
                        color: Color(0xFF38BDF8), size: 40),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No Blue Tick Requests',
                    style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All verification requests have been reviewed!',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          itemCount: requestsWithIndex.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = requestsWithIndex[index];
            return _buildVerificationRequestCard(
              item['user'] as GamerUser,
              rankNumber: item['rankNumber'] as int,
              rawData: item['raw'] as Map<String, dynamic>,
            );
          },
        );
      },
    );
  }

  Widget _buildVerificationRequestCard(_RankQueueItem item) {
    final user = item.user;
    final game = item.game;
    final isPending = game.status == 'pending';
    final isApproved = game.status == 'approved' || game.isVerified;
    final isRejected = game.status == 'rejected';

    final Color statusColor = isApproved
        ? const Color(0xFF00FF88)
        : (isPending ? const Color(0xFFFF8A00) : const Color(0xFFFF4655));

    final String statusLabel = isApproved
        ? 'Approved ✓'
        : (isPending ? 'Pending Review ⏳' : 'Rejected ✕');

    final String dateStr = game.submittedAt != null
        ? DateFormat('dd MMM, hh:mm a').format(game.submittedAt!)
        : 'Recently';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? const Color(0xFFFF8A00).withOpacity(0.5)
              : ThemeService.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GamerAvatar(
                photoUrl: user.photoUrl,
                radius: 20,
                displayName: user.displayName.isNotEmpty
                    ? user.displayName
                    : user.username,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isNotEmpty
                          ? user.displayName
                          : user.username,
                      style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    Text(
                      '@${user.username} • UID: ${user.uid.length > 8 ? user.uid.substring(0, 8) : user.uid}',
                      style: TextStyle(
                          color: ThemeService.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: ThemeService.border, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sports_esports_rounded,
                        size: 14, color: Color(0xFF00FF88)),
                    const SizedBox(width: 4),
                    Text(
                      game.gameName,
                      style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ID: ${game.gameId}',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dateStr,
                style:
                    TextStyle(color: ThemeService.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Claimed Rank: ',
                style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xFFFF8A00).withOpacity(0.5)),
                ),
                child: Text(
                  game.claimedRank,
                  style: const TextStyle(
                    color: Color(0xFFFF8A00),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isApproved && game.verifiedRank.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded,
                    size: 12, color: ThemeService.textSecondary),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.5)),
                  ),
                  child: Text(
                    'Verified: ${game.verifiedRank}',
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (game.screenshotUrl.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _showScreenshotViewerDialog(
                imageUrl: game.screenshotUrl,
                title:
                    '${user.displayName} • ${game.gameName} Rank Proof',
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: game.screenshotUrl,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 140,
                        color: ThemeService.cardSecondary,
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF00FF88), strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 140,
                        color: ThemeService.cardSecondary,
                        child: Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: ThemeService.textSecondary, size: 36),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded,
                                size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Tap to inspect proof',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeService.cardSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.image_not_supported_rounded,
                      color: ThemeService.textSecondary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'No screenshot uploaded',
                    style:
                        TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          if (isRejected &&
              game.rejectReason != null &&
              game.rejectReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4655).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFF4655).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFFF4655), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${game.rejectReason}',
                      style: const TextStyle(
                          color: Color(0xFFFF4655), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            _AdminRankActionButtons(
              item: item,
              onApprove: () => _approveRankVerification(item),
              onReject: (reason) => _rejectRankVerification(item, reason),
            ),
          ],
        ],
      ),
    );
  }

  // ===================== HELPER METHODS FOR TABS =====================
  Widget _buildPostsModerationTab() {
    return const Center(child: Text('Posts Moderation', style: TextStyle(color: Colors.white)));
  }

  Widget _buildReportsTab() {
    return const Center(child: Text('Reports Tab', style: TextStyle(color: Colors.white)));
  }

  Widget _buildCoinsTab() {
    return const _AdminCoinsVaultTab();
  }

  Widget _buildReferralsTrackerTab() {
    return const Center(child: Text('Referrals Tracker', style: TextStyle(color: Colors.white)));
  }
}

// ===================== TAB: BANNER CONTROL (HOME ANNOUNCEMENT) =====================
class _AdminBannerControlTab extends StatefulWidget {
  const _AdminBannerControlTab();

  @override
  State<_AdminBannerControlTab> createState() => _AdminBannerControlTabState();
}

class _AdminBannerControlTabState extends State<_AdminBannerControlTab> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentBanner();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBanner() async {
    setState(() => _isLoading = true);
    try {
      final res = await SupabaseService.client
          .from('app_announcements')
          .select()
          .eq('id', 'home_banner')
          .maybeSingle();

      if (res != null && mounted) {
        _titleController.text = (res['title'] ?? 'Upcoming Tournament!').toString();
        _messageController.text = (res['message'] ?? '').toString();
        _isActive = res['is_active'] == true;
      } else {
        _titleController.text = 'Upcoming Tournament!';
        _messageController.text = 'Date: Coming Soon | Time: 08:00 PM';
        _isActive = true;
      }
    } catch (e) {
      debugPrint('Error loading announcement: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBanner() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a banner title!'),
          backgroundColor: Color(0xFFFF4655),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseService.client.from('app_announcements').upsert({
        'id': 'home_banner',
        'title': title,
        'message': message,
        'is_active': _isActive,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Home Feed Banner updated successfully! 🚀'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update banner: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThemeService.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Color(0xFF00FF88), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feed Announcement Banner',
                        style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sabhi users ke feed screen ke top par ye announcement card show hoga.',
                        style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: ThemeService.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ThemeService.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Show Banner on Feed',
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    Text(
                      _isActive ? 'Banner is currently VISIBLE to users' : 'Banner is currently HIDDEN',
                      style: TextStyle(
                        color: _isActive ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isActive,
                  activeColor: const Color(0xFF00FF88),
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Announcement Title',
            style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Upcoming Tournament! 🏆',
              hintStyle: TextStyle(color: ThemeService.textSecondary.withOpacity(0.6), fontSize: 13),
              filled: true,
              fillColor: ThemeService.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ThemeService.border)),
              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFF00FF88))),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Match Details / Date & Time',
            style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _messageController,
            maxLines: 3,
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Date: Coming Soon | Time: 08:00 PM',
              hintStyle: TextStyle(color: ThemeService.textSecondary.withOpacity(0.6), fontSize: 13),
              filled: true,
              fillColor: ThemeService.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ThemeService.border)),
              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFF00FF88))),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Icon(Icons.publish_rounded, size: 20),
              label: Text(
                _isSaving ? 'Updating...' : 'Publish Banner to Feed 📢',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _isSaving ? null : _saveBanner,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: ThemeService.bg,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _RankQueueItem {
  final GamerUser user;
  final UserGameRank game;
  final int gameIndex;

  _RankQueueItem({
    required this.user,
    required this.game,
    required this.gameIndex,
  });
}

class _AdminRankActionButtons extends StatefulWidget {
  final _RankQueueItem item;
  final VoidCallback onApprove;
  final ValueChanged<String> onReject;

  const _AdminRankActionButtons({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_AdminRankActionButtons> createState() =>
      _AdminRankActionButtonsState();
}

class _AdminRankActionButtonsState extends State<_AdminRankActionButtons> {
  final TextEditingController _reasonController = TextEditingController();
  bool _showReasonField = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showReasonField) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: ThemeService.cardSecondary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFFF4655).withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _reasonController,
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText:
                        'Enter rejection reason (e.g. Screenshot unclear, UID mismatch)...',
                    hintStyle: TextStyle(
                        color: ThemeService.textSecondary, fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: InputBorder.none,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      'Screenshot blurry',
                      'UID mismatch',
                      'Fake rank proof',
                      'Not profile/tier page',
                    ].map((reason) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _reasonController.text = reason;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ThemeService.card,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            reason,
                            style: const TextStyle(
                                color: Color(0xFF38BDF8), fontSize: 10),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  if (!_showReasonField) {
                    setState(() => _showReasonField = true);
                  } else {
                    widget.onReject(_reasonController.text);
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF4655)),
                  backgroundColor:
                      const Color(0xFFFF4655).withOpacity(0.1),
                  foregroundColor: const Color(0xFFFF4655),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: Text(
                  _showReasonField ? 'Confirm Reject' : 'Reject',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onApprove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  foregroundColor: const Color(0xFF0B0F14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.check_rounded, size: 14),
                label: const Text(
                  'Approve Rank',
                  style:
                      TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
