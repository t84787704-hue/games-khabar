// ===============================================================================
// GAMER ADMIN DASHBOARD SCREEN — Real-time Counts, Dual Proofs & Theme Adaptive
// File: lib/screens/gamer_admin_dashboard_screen.dart
// ===============================================================================

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/gamer_theme.dart';
import '../constants/mobile_games_rank_data.dart';
import '../constants/tournament_game_categories.dart';
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
import '../services/tournament_service.dart';
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
    _tabController = TabController(length: 10, vsync: this);
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
                          const Tab(text: 'Users'),
                          _buildRankVerifyTabTitle(),
                          _buildBlueTickTabTitle(),
                          const Tab(text: 'Posts Moderation'),
                          const Tab(text: 'Team Matches ⚔️'),
                          const Tab(text: 'Reports'),
                          const Tab(text: 'Coins'),
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
                  _buildUsersTab(),
                  _buildRankVerifyTab(),
                  _buildBlueTickRequestsTab(),
                  _buildPostsModerationTab(),
                  const AdminTeamMatchesScreen(),
                  _buildReportsTab(),
                  _buildCoinsTab(),
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
      initialData: const [],
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, snapshot) {
        int pendingCount = 0;
        final docs = snapshot.data ?? [];
        for (final doc in docs) {
          final rawGames = doc['games'];
          if (rawGames is List) {
            for (final g in rawGames) {
              if (g is Map && (g['status'] ?? '').toString().toLowerCase() == 'pending') {
                pendingCount++;
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
      initialData: const [],
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, snapshot) {
        int pendingCount = 0;
        final docs = snapshot.data ?? [];
        for (final doc in docs) {
          final isVerified = doc['is_verified'] == true || doc['has_blue_tick'] == true;
          final vStatus = (doc['verification_status'] ?? doc['blue_tick_status'] ?? '').toString().toLowerCase();
          if (!isVerified && (vStatus == 'pending' || vStatus == 'under_review')) {
            pendingCount++;
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
      initialData: const [],
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, snapshot) {
        String currentEmail = 'Admin';
        final docs = snapshot.data ?? [];
        final sbUserId = SupabaseService.client.auth.currentUser?.id;
        if (sbUserId != null && docs.isNotEmpty) {
          for (final u in docs) {
            if (u['id'] == sbUserId) {
              currentEmail = u['email']?.toString() ?? 'Admin';
              break;
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
      initialData: const [],
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, userSnap) {
        int totalUsers = 0;
        int totalCoins = 0;

        final uDocs = userSnap.data ?? [];
        totalUsers = uDocs.length;
        for (final doc in uDocs) {
          final raw = doc['coins'];
          totalCoins += (raw as num?)?.toInt() ?? 0;
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          initialData: const [],
          stream: SupabaseService.getRealtimePosts(),
          builder: (context, postSnap) {
            final totalPosts = postSnap.data?.length ?? 0;

            return StreamBuilder<List<Map<String, dynamic>>>(
              initialData: const [],
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
            initialData: const [],
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
                  (!snapshot.hasData || snapshot.data!.isEmpty)) {
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
            initialData: const [],
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
                  (!snapshot.hasData || snapshot.data!.isEmpty)) {
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
                  return _buildRankVerificationCard(filtered[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRankVerificationCard(_RankQueueItem item) {
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

  // ===================== TAB 3: BLUE TICK =====================
  Widget _buildBlueTickRequestsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      initialData: const [],
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
            (!snapshot.hasData || snapshot.data!.isEmpty)) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final docs = snapshot.data ?? [];
        
        final List<GamerUser> requests = [];
        for (final d in docs) {
          final isVerified = d['is_verified'] == true || d['has_blue_tick'] == true;
          final vStatus = (d['verification_status'] ?? d['blue_tick_status'] ?? '').toString().toLowerCase();

          if (!isVerified && (vStatus == 'pending' || vStatus == 'under_review' || vStatus == 'submitted')) {
            requests.add(GamerUser.fromMap(d));
          }
        }

        if (requests.isEmpty) {
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
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final req = requests[index];
            return _buildVerificationRequestCard(req);
          },
        );
      },
    );
  }

  Widget _buildVerificationRequestCard(GamerUser user) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GamerAvatar(
                photoUrl: user.photoUrl,
                displayName: user.displayName,
                radius: 24,
                borderColor: const Color(0xFF38BDF8),
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
                            user.displayName.isNotEmpty ? user.displayName : user.username,
                            style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        RankBadgeWidget(
                            badge: user.getRankBadge(),
                            size: 14,
                            showLabel: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username} • UID: ${user.uid.length > 8 ? user.uid.substring(0, 8) : user.uid}',
                      style: TextStyle(
                          color: ThemeService.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Game: ${user.selectedGame.isNotEmpty ? user.selectedGame : "BGMI"} • ID: ${user.gameId.isNotEmpty ? user.gameId : "N/A"}',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Text(
                  'PENDING',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: ThemeService.border, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _rejectVerification(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF4655),
                  side: const BorderSide(color: Color(0xFFFF4655)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _approveVerification(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9BF0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.verified, size: 16),
                label: const Text('Approve Blue Tick',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveVerification(GamerUser user) async {
    try {
      final ok = await SupabaseService.approveBlueTick(user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.verified, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(ok
                    ? 'Approved! Blue tick added to @${user.username}'
                    : 'Error approving'),
              ],
            ),
            backgroundColor:
                ok ? const Color(0xFF1D9BF0) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error approving verification: $e'),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  Future<void> _rejectVerification(GamerUser user) async {
    try {
      final ok = await SupabaseService.rejectBlueTick(user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Rejected verification for @${user.username}'
                : 'Error rejecting'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error rejecting: $e'),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  // ===================== TAB 4: POSTS MODERATION =====================
  Widget _buildPostsModerationTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      initialData: const [],
      stream: SupabaseService.getRealtimePosts(),
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
                  Text('Could not load posts',
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
            (!snapshot.hasData || snapshot.data!.isEmpty)) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final docs = snapshot.data ?? [];

        if (docs.isEmpty) {
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
                    child: Icon(Icons.dynamic_feed_rounded,
                        color: ThemeService.textSecondary, size: 40),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No posts to moderate',
                    style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Community is clean — no posts need review!',
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
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index];
            final postId = (data['id'] ?? '').toString();
            final text = (data['content'] ?? 'Gaming Post').toString();
            final author = (data['display_name'] ?? 'Player').toString();
            final userId = (data['user_id'] ?? '').toString();
            final game = (data['game'] ?? '').toString();
            final imageUrl = (data['image_url'] ?? '').toString();
            final isVerified = data['is_verified'] == true;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeService.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeService.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GamerAvatar(
                        photoUrl: (data['user_avatar'] ?? '').toString(),
                        displayName: author,
                        radius: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    author,
                                    style: TextStyle(
                                        color: ThemeService.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified,
                                      color: Color(0xFF38BDF8), size: 14),
                                ],
                              ],
                            ),
                            if (game.isNotEmpty)
                              Text(
                                'Game: $game',
                                style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFFFF4655), size: 20),
                        tooltip: 'Delete Post',
                        onPressed: () async {
                          final ok = await SupabaseService.deletePost(postId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(ok
                                      ? 'Post deleted by admin'
                                      : 'Error deleting'),
                                  backgroundColor:
                                      const Color(0xFFFF4655)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (text.isNotEmpty) ...[
                    Text(
                      text,
                      style: TextStyle(
                          color: ThemeService.textPrimary, fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (imageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
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
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Text(
                        'ID: ${postId.length > 8 ? postId.substring(0, 8) : postId}',
                        style: TextStyle(
                            color: ThemeService.textSecondary,
                            fontSize: 10,
                            fontFamily: 'monospace'),
                      ),
                      const Spacer(),
                      if (userId.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            final sbAdminId =
                                SupabaseService.client.auth.currentUser?.id ??
                                    '';
                            final ok = await SupabaseService.banUser(
                              userId: userId,
                              adminId: sbAdminId,
                              reason: 'Banned from post moderation',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(ok
                                        ? 'Author $author banned'
                                        : 'Error banning'),
                                    backgroundColor:
                                        const Color(0xFFFF4655)),
                              );
                            }
                          },
                          child: const Text('Ban Author',
                              style: TextStyle(
                                  color: Color(0xFFFF4655), fontSize: 11)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===================== TAB 6: REPORTS =====================
  Widget _buildReportsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      initialData: const [],
      stream: SupabaseService.getRealtimeReports(),
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
                  Text('Could not load reports',
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
            (!snapshot.hasData || snapshot.data!.isEmpty)) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final docs = snapshot.data ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user_rounded,
                        color: Color(0xFF00FF88), size: 40),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Community Safe • 0 Open Reports',
                    style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No offensive content or active player violations reported.',
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
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index];
            final reportId = (data['id'] ?? '').toString();
            final reporterName =
                (data['reporter_username'] ?? 'Player').toString();
            final reason = (data['reason'] ?? 'Report').toString();
            final targetType = (data['target_type'] ?? '').toString();
            final targetId = (data['target_id'] ?? '').toString();
            final targetContent = (data['target_content'] ?? '').toString();
            final status = (data['status'] ?? 'pending').toString();

            final statusColor = status == 'resolved'
                ? const Color(0xFF00FF88)
                : (status == 'rejected'
                    ? const Color(0xFFFF4655)
                    : const Color(0xFFFFB800));

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeService.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeService.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4655).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFFFF4655)
                                  .withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFFF4655), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              targetType.isNotEmpty
                                  ? targetType.toUpperCase()
                                  : 'REPORT',
                              style: const TextStyle(
                                  color: Color(0xFFFF4655),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: statusColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFFFF4655), size: 20),
                        tooltip: 'Delete Report',
                        onPressed: () async {
                          final ok =
                              await SupabaseService.deleteReport(reportId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(ok
                                      ? 'Report deleted'
                                      : 'Error'),
                                  backgroundColor:
                                      const Color(0xFFFF4655)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          color: ThemeService.textSecondary, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Reported by: $reporterName',
                          style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (reason.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ThemeService.cardSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFFFB800), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                  color: ThemeService.textPrimary, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (targetContent.isNotEmpty) ...[
                    Text('Reported Content:',
                        style: TextStyle(
                            color: ThemeService.textSecondary, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      targetContent,
                      style: TextStyle(
                          color: ThemeService.textPrimary, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      if (targetId.isNotEmpty)
                        Text(
                          'Target ID: ${targetId.length > 8 ? targetId.substring(0, 8) : targetId}',
                          style: TextStyle(
                              color: ThemeService.textSecondary,
                              fontSize: 10,
                              fontFamily: 'monospace'),
                        ),
                      const Spacer(),
                      if (status != 'resolved')
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF00FF88),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          icon: const Icon(Icons.check_circle_outline,
                              size: 14),
                          label: const Text('Mark Resolved',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final ok = await SupabaseService.updateReport(
                              reportId: reportId,
                              status: 'resolved',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(ok
                                        ? 'Report marked resolved'
                                        : 'Error'),
                                    backgroundColor:
                                        const Color(0xFF00FF88)),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===================== TAB 7: COINS =====================
  Widget _buildCoinsTab() {
    return const _AdminCoinsVaultTab();
  }
}

// ===================== TAB 0: TOURNAMENTS ADMIN CONTROLLER =====================
class _AdminTournamentsTab extends StatefulWidget {
  const _AdminTournamentsTab();

  @override
  State<_AdminTournamentsTab> createState() => _AdminTournamentsTabState();
}

class _AdminTournamentsTabState extends State<_AdminTournamentsTab> {
  final SupabaseClient _supabase = SupabaseService.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tournaments = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Free Fire',
    'PUBG Mobile',
    'Call Of Duty',
    'BGMI',
    'Minecraft',
    'Apex Legends',
    'Valorant',
    'Clash of Clans',
  ];

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch from 'tournaments' table with 4s timeout
      final res = await _supabase
          .from('tournaments')
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 4));

      List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(res);

      // 2. If 'tournaments' table is empty, fall back to tournament_rooms
      if (list.isEmpty) {
        try {
          final roomRes = await _supabase
              .from('tournament_rooms')
              .select()
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 3));
          for (final r in roomRes) {
            list.add({
              'id': r['id']?.toString() ?? '',
              'title': r['title']?.toString() ?? 'Tournament',
              'game_mode': r['game_mode']?.toString() ?? 'Squad 4v4',
              'map_name': r['map']?.toString() ?? 'Erangel',
              'game': r['game_type']?.toString() ?? r['game']?.toString() ?? 'Free Fire',
              'entry_fee': (r['entry_fee_coins'] as num?)?.toInt() ?? 0,
              'prize_pool': (r['prize_pool_coins'] as num?)?.toInt() ?? 500,
              'max_teams': (r['max_slots'] as num?)?.toInt() ?? 25,
              'current_teams': (r['current_slots'] as num?)?.toInt() ?? 0,
              'match_time': r['start_time']?.toString() ?? DateTime.now().toIso8601String(),
              'room_id': r['room_id']?.toString() ?? '',
              'room_password': r['password']?.toString() ?? '',
              'status': r['status']?.toString() ?? 'upcoming',
              'proof_url': r['win_proof_url']?.toString() ?? '',
            });
          }
        } catch (_) {}
      }

      // 3. Fallback to TournamentService cached/default rooms so it never wipes to empty
      if (list.isEmpty) {
        final localRooms = TournamentService().rooms;
        for (final r in localRooms) {
          list.add({
            'id': r.id,
            'title': r.title,
            'game_mode': r.gameMode,
            'map_name': r.map,
            'game': r.gameType,
            'entry_fee': r.entryFeeCoins,
            'prize_pool': r.prizePoolCoins,
            'max_teams': r.maxSlots,
            'current_teams': r.currentSlots,
            'match_time': r.startTime.toIso8601String(),
            'room_id': r.roomId,
            'room_password': r.password,
            'status': r.status.toLowerCase() == 'active' ? 'upcoming' : r.status.toLowerCase(),
            'proof_url': r.winProofUrl ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _tournaments = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tournaments: $e');
      final localRooms = TournamentService().rooms;
      final List<Map<String, dynamic>> fallbackList = [];
      for (final r in localRooms) {
        fallbackList.add({
          'id': r.id,
          'title': r.title,
          'game_mode': r.gameMode,
          'map_name': r.map,
          'game': r.gameType,
          'entry_fee': r.entryFeeCoins,
          'prize_pool': r.prizePoolCoins,
          'max_teams': r.maxSlots,
          'current_teams': r.currentSlots,
          'match_time': r.startTime.toIso8601String(),
          'room_id': r.roomId,
          'room_password': r.password,
          'status': 'upcoming',
          'proof_url': r.winProofUrl ?? '',
        });
      }
      if (mounted) {
        setState(() {
          _tournaments = fallbackList;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveProof(String tournamentId) async {
    try {
      await _supabase.from('tournaments').update({
        'proof_status': 'approved',
      }).eq('id', tournamentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Victory proof approved successfully! 🎉'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
      _loadTournaments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving proof: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  Future<void> _rejectProof(String tournamentId, String reason) async {
    try {
      await _supabase.from('tournaments').update({
        'proof_status': 'rejected',
        'proof_reject_reason': reason,
        'proof_url': null,
      }).eq('id', tournamentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proof rejected and reason saved. User can re-upload.'),
            backgroundColor: Color(0xFFFF8A00),
          ),
        );
      }
      _loadTournaments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting proof: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  void _showProofReviewDialog(Map<String, dynamic> tournament) {
    final tournamentId = tournament['id'].toString();
    final proofUrl = (tournament['proof_url'] ?? '').toString();
    final proofStatus = (tournament['proof_status'] ?? 'pending').toString().toUpperCase();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFFFF8A00), size: 20),
            const SizedBox(width: 8),
            const Text('Review Victory Proof',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A00).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                proofStatus,
                style: const TextStyle(color: Color(0xFFFF8A00), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (proofUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: InteractiveViewer(
                    maxScale: 3.5,
                    child: CachedNetworkImage(
                      imageUrl: proofUrl,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 220,
                        color: Colors.black26,
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 220,
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 40),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('No screenshot uploaded yet', style: TextStyle(color: Colors.white54)),
                ),
              const SizedBox(height: 16),
              const Text('Rejection Reason (if rejecting):',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'e.g. Screenshot blurry, match time mismatch, not winner...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFF0A0E17),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  'Screenshot unclear/blurry',
                  'Game ID mismatch',
                  'Not winner screenshot',
                  'Already distributed',
                ].map((reason) {
                  return InkWell(
                    onTap: () {
                      reasonController.text = reason;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        reason,
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              final reason = reasonController.text.trim().isNotEmpty
                  ? reasonController.text.trim()
                  : 'Screenshot was not accepted. Please upload a clear end-game score screenshot.';
              _rejectProof(tournamentId, reason);
            },
            icon: const Icon(Icons.close_rounded, color: Color(0xFFFF4655), size: 16),
            label: const Text('Reject Proof', style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _approveProof(tournamentId);
            },
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Approve Proof', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openCreateTournamentDialog() {
    final titleController = TextEditingController();
    final mapController = TextEditingController(text: 'Erangel');
    final feeController = TextEditingController(text: '0');
    final prizeController = TextEditingController(text: '1000');
    final roomController = TextEditingController();
    final passController = TextEditingController();
    int maxTeams = 25;
    String mode = 'Squad 4v4';
    String selectedGame = 'Call Of Duty';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF161A22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: Color(0xFF00FF88)),
                SizedBox(width: 8),
                Text('Create Tournament',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Tournament Title',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedGame,
                    dropdownColor: const Color(0xFF161A22),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Select Game',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Call Of Duty', child: Text('Call Of Duty')),
                      DropdownMenuItem(value: 'Free Fire', child: Text('Free Fire')),
                      DropdownMenuItem(value: 'PUBG Mobile', child: Text('PUBG Mobile')),
                      DropdownMenuItem(value: 'Minecraft', child: Text('Minecraft')),
                      DropdownMenuItem(value: 'Apex Legends', child: Text('Apex Legends')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDState(() => selectedGame = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: mode,
                    dropdownColor: const Color(0xFF161A22),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Match Mode',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Squad 4v4', child: Text('Squad 4v4')),
                      DropdownMenuItem(value: 'Duo 2v2', child: Text('Duo 2v2')),
                      DropdownMenuItem(value: 'Solo 1v1', child: Text('Solo 1v1')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDState(() => mode = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mapController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Map Name (Erangel, Bermuda, Crash, etc.)',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: feeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Entry Fee 🪙 (0 = Free)',
                            labelStyle: TextStyle(color: Colors.white60),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: prizeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Prize Pool 🪙',
                            labelStyle: TextStyle(color: Colors.white60),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: maxTeams,
                    dropdownColor: const Color(0xFF161A22),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Max Slots / Teams',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2 Teams (1v1 Final)')),
                      DropdownMenuItem(value: 4, child: Text('4 Teams (Fast Tournament)')),
                      DropdownMenuItem(value: 8, child: Text('8 Teams')),
                      DropdownMenuItem(value: 16, child: Text('16 Teams (Classic Squad)')),
                      DropdownMenuItem(value: 25, child: Text('25 Teams (Full Lobby)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDState(() => maxTeams = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: roomController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Room ID (optional)',
                            labelStyle: TextStyle(color: Colors.white60),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: passController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Room Pass (optional)',
                            labelStyle: TextStyle(color: Colors.white60),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;

                  final fee = int.tryParse(feeController.text.trim()) ?? 0;
                  final prize = int.tryParse(prizeController.text.trim()) ?? 1000;

                  try {
                    await _supabase.from('tournaments').insert({
                      'title': title,
                      'game': selectedGame,
                      'game_mode': mode,
                      'map_name': mapController.text.trim().isEmpty ? 'Erangel' : mapController.text.trim(),
                      'entry_fee': fee,
                      'prize_pool': prize,
                      'max_teams': maxTeams,
                      'current_teams': 0,
                      'match_time': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
                      'room_id': roomController.text.trim(),
                      'room_password': passController.text.trim(),
                      'status': 'upcoming',
                    });

                    if (context.mounted) Navigator.pop(ctx);
                    _loadTournaments();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tournament Created Successfully! 🎉'),
                          backgroundColor: Color(0xFF00FF88),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error creating tournament: $e')),
                      );
                    }
                  }
                },
                child: const Text('Publish Tournament', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openRoomCredentialsDialog(String tournamentId, String oldId, String oldPass) {
    final idController = TextEditingController(text: oldId);
    final passController = TextEditingController(text: oldPass);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        title: const Text('Set Room ID & Password', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Custom Room ID', labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Room Password', labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
            onPressed: () async {
              try {
                await _supabase.from('tournaments').update({
                  'room_id': idController.text.trim(),
                  'room_password': passController.text.trim(),
                }).eq('id', tournamentId);
              } catch (_) {}

              if (context.mounted) Navigator.pop(ctx);
              _loadTournaments();
            },
            child: const Text('Save Credentials'),
          ),
        ],
      ),
    );
  }

  void _openDeclareWinnerDialog(String tournamentId, int prizePool) async {
    List regRes = [];
    try {
      regRes = await _supabase
          .from('tournament_registrations')
          .select('team_id, teams:teams(id, name, leader_id)')
          .eq('tournament_id', tournamentId);
    } catch (_) {}

    if (regRes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No teams registered in this tournament yet!')),
      );
      return;
    }

    String? selectedTeamId = regRes.first['team_id']?.toString();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF161A22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.military_tech_rounded, color: Color(0xFFFFD700)),
                SizedBox(width: 8),
                Text('Declare Winner & Pay', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Prize: $prizePool Coins',
                    style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                const Text('Select Winning Team:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedTeamId,
                  dropdownColor: const Color(0xFF161A22),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: regRes.map<DropdownMenuItem<String>>((r) {
                    final tName = r['teams']?['name']?.toString() ?? 'Team #${r['team_id'].toString().substring(0, 5)}';
                    return DropdownMenuItem(value: r['team_id'].toString(), child: Text(tName));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDState(() => selectedTeamId = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
                onPressed: () async {
                  if (selectedTeamId == null) return;
                  try {
                    await _supabase.rpc('distribute_match_reward', params: {
                      'p_team_id': selectedTeamId,
                      'p_total_prize': prizePool,
                    });

                    await _supabase.from('tournaments').update({
                      'status': 'completed',
                      'winner_team_id': selectedTeamId,
                    }).eq('id', tournamentId);

                    if (context.mounted) Navigator.pop(ctx);
                    _loadTournaments();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Winner Declared & Prize Coins Distributed to Squad Members! 🏆'),
                          backgroundColor: Color(0xFF00FF88),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Reward distribution failed: $e')),
                      );
                    }
                  }
                },
                child: const Text('Distribute Prize Now', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteTournament(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        title: const Text('Delete Tournament?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this tournament?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('tournaments').delete().eq('id', id);
      _loadTournaments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter list by game category and title search query
    final filtered = _tournaments.where((item) {
      final title = (item['title'] ?? '').toString().toLowerCase();
      final game = (item['game'] ?? item['title'] ?? '').toString().toLowerCase();
      
      if (_searchQuery.isNotEmpty && !title.contains(_searchQuery) && !game.contains(_searchQuery)) {
        return false;
      }
      
      if (_selectedCategory != 'All') {
        final catClean = _selectedCategory.toLowerCase().replaceAll(' ', '');
        final gameClean = game.replaceAll(' ', '');
        final titleClean = title.replaceAll(' ', '');
        if (!gameClean.contains(catClean) && !titleClean.contains(catClean)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTournamentDialog,
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Tournament', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search tournaments by title...',
                hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00FF88), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: ThemeService.textSecondary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: ThemeService.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

          // 2. Game Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                    },
                    selectedColor: const Color(0xFF00FF88),
                    backgroundColor: ThemeService.card,
                    checkmarkColor: const Color(0xFF0B0F14),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF0B0F14) : ThemeService.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF00FF88) : ThemeService.border,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // 3. Tournament List or Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: ThemeService.card,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: ThemeService.border),
                                ),
                                child: const Icon(
                                  Icons.emoji_events_outlined,
                                  color: Color(0xFFFFD700),
                                  size: 48,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'No Tournaments Found',
                                style: TextStyle(
                                  color: ThemeService.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the "Create Tournament" button below to launch a new match!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ThemeService.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final tId = item['id'].toString();
                          final title = (item['title'] ?? 'Tournament').toString();
                          final game = (item['game'] ?? title).toString();
                          final mode = (item['game_mode'] ?? 'Squad 4v4').toString();
                          final currentTeams = item['current_teams'] ?? 0;
                          final maxTeams = item['max_teams'] ?? 25;
                          final prize = item['prize_pool'] ?? 1000;
                          final fee = item['entry_fee'] ?? 0;
                          final feeText = fee == 0 ? 'Free' : '$fee Coins';
                          final status = (item['status'] ?? 'upcoming').toString();
                          final roomId = (item['room_id'] ?? '').toString();
                          final roomPass = (item['room_password'] ?? '').toString();
                          final proofUrl = (item['proof_url'] ?? '').toString().trim();

                          // Format Date
                          DateTime date = DateTime.now();
                          try {
                            if (item['match_time'] != null) {
                              date = DateTime.parse(item['match_time'].toString());
                            }
                          } catch (_) {}
                          final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ThemeService.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: ThemeService.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Chips: Game, Mode, Status
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00FF88).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        game,
                                        style: const TextStyle(
                                          color: Color(0xFF00FF88),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ThemeService.cardSecondary,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: ThemeService.border),
                                      ),
                                      child: Text(
                                        mode,
                                        style: TextStyle(
                                          color: ThemeService.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: status == 'completed'
                                            ? Colors.white10
                                            : const Color(0xFF38BDF8).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: status == 'completed'
                                              ? Colors.white24
                                              : const Color(0xFF38BDF8).withOpacity(0.4),
                                        ),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          color: status == 'completed' ? Colors.white60 : const Color(0xFF38BDF8),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Title
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: ThemeService.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Match Time
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded, size: 12, color: ThemeService.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      formattedDate,
                                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Prize, Fee, Slots
                                Row(
                                  children: [
                                    const Text('🪙 ', style: TextStyle(fontSize: 12)),
                                    RichText(
                                      text: TextSpan(
                                        text: 'Prize: ',
                                        style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                                        children: [
                                          TextSpan(
                                            text: '$prize Coins',
                                            style: const TextStyle(
                                              color: Color(0xFFFFD700),
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    RichText(
                                      text: TextSpan(
                                        text: 'Fee: ',
                                        style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                                        children: [
                                          TextSpan(
                                            text: feeText,
                                            style: TextStyle(
                                              color: ThemeService.textPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Slots: $currentTeams/$maxTeams',
                                      style: const TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Room ID & Pass Bar with Set Room Button
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: ThemeService.cardSecondary,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: ThemeService.border),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.key_rounded, size: 14, color: Color(0xFFFF8A00)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          roomId.isNotEmpty
                                              ? 'ID: $roomId • Pass: $roomPass'
                                              : 'Room ID & Pass: Not Published Yet',
                                          style: TextStyle(
                                            color: roomId.isNotEmpty ? ThemeService.textPrimary : ThemeService.textSecondary,
                                            fontSize: 11.5,
                                            fontWeight: roomId.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                            fontFamily: 'monospace',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _openRoomCredentialsDialog(tId, roomId, roomPass),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Row(
                                            children: [
                                              Text(
                                                'Set Room',
                                                style: TextStyle(
                                                  color: Color(0xFF00FF88),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                              SizedBox(width: 3),
                                              Icon(Icons.settings, size: 13, color: Color(0xFF00FF88)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (proofUrl.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () => _showProofReviewDialog(item),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF8A00).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.4)),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_search_rounded, color: Color(0xFFFF8A00), size: 16),
                                          SizedBox(width: 6),
                                          Text(
                                            'Victory Screenshot Submitted (Tap to View)',
                                            style: TextStyle(
                                              color: Color(0xFFFF8A00),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 10),
                                Divider(color: ThemeService.border, height: 1),
                                const SizedBox(height: 8),

                                // Bottom actions
                                Row(
                                  children: [
                                    if (status != 'completed')
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFFD700),
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                        icon: const Icon(Icons.military_tech_rounded, size: 14),
                                        label: const Text('Declare Winner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () => _openDeclareWinnerDialog(tId, prize),
                                      ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.share_rounded, color: Color(0xFF38BDF8), size: 18),
                                      tooltip: 'Share',
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Tournament ID: $tId')),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit_note_rounded, color: ThemeService.textSecondary, size: 20),
                                      tooltip: 'Edit Credentials',
                                      onPressed: () => _openRoomCredentialsDialog(tId, roomId, roomPass),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4655), size: 20),
                                      tooltip: 'Delete Tournament',
                                      onPressed: () => _deleteTournament(tId),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AdminCoinsVaultTab extends StatefulWidget {
  const _AdminCoinsVaultTab();

  @override
  State<_AdminCoinsVaultTab> createState() => _AdminCoinsVaultTabState();
}

class _AdminCoinsVaultTabState extends State<_AdminCoinsVaultTab> {
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _amountController =
      TextEditingController(text: '100');

  bool _isSearching = false;
  bool _isAwarding = false;
  Map<String, dynamic>? _foundUser;
  String? _foundDocId;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _targetController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _findUser(String input) async {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    try {
      final users =
          await SupabaseService.query('users', select: '*', limit: 500);
      final clean = raw.toLowerCase().replaceAll('@', '').trim();

      for (final u in users) {
        final docId = (u['id'] ?? '').toString();
        final uUid = (u['uid'] ?? docId).toString().trim();
        final uName = (u['username'] ?? '').toString().toLowerCase().trim();
        final uEmail = (u['email'] ?? '').toString().toLowerCase().trim();
        final uDisplay =
            (u['display_name'] ?? '').toString().toLowerCase().trim();

        if (docId == raw ||
            docId.toLowerCase() == clean ||
            uUid == raw ||
            uUid.toLowerCase() == clean ||
            uName == clean ||
            uEmail == clean ||
            uDisplay == clean ||
            (clean.length >= 2 &&
                (uName.contains(clean) ||
                    uEmail.contains(clean) ||
                    uDisplay.contains(clean) ||
                    uUid.contains(clean)))) {
          final d = Map<String, dynamic>.from(u);
          d['docId'] = docId;
          return d;
        }
      }
    } catch (e) {
      debugPrint('Error searching user: $e');
    }

    return null;
  }

  Future<void> _handleSearch() async {
    final target = _targetController.text.trim();
    if (target.isEmpty) {
      setState(() {
        _errorMessage = 'user_not_found'.tr();
        _successMessage = null;
        _foundUser = null;
        _foundDocId = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final user = await _findUser(target);

    if (!mounted) return;

    setState(() {
      _isSearching = false;
      if (user != null) {
        _foundUser = user;
        _foundDocId = user['docId'] as String?;
        _errorMessage = null;
      } else {
        _foundUser = null;
        _foundDocId = null;
        _errorMessage = 'user_not_found'.tr();
      }
    });

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'user_not_found_target'.tr(args: [target]),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF4655),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _awardCoins() async {
    final target = _targetController.text.trim();
    if (target.isEmpty) {
      setState(() => _errorMessage = 'user_not_found'.tr());
      return;
    }

    final amountText = _amountController.text.trim();
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(
          () => _errorMessage = 'enter_valid_coin_amount'.tr());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('enter_valid_coin_amount'.tr()),
          backgroundColor: const Color(0xFFFF4655),
        ),
      );
      return;
    }

    setState(() {
      _isAwarding = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      Map<String, dynamic>? user = _foundUser;
      String? docId = _foundDocId;

      if (user == null || docId == null) {
        user = await _findUser(target);
        if (user != null) {
          docId = user['docId'] as String?;
        }
      }

      if (user == null || docId == null || docId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isAwarding = false;
          _foundUser = null;
          _foundDocId = null;
          _errorMessage = 'user_not_found'.tr();
        });
        return;
      }

      final targetDocId = docId;
      final targetDisplayName = (user['display_name'] ??
              user['displayName'] ??
              user['username'] ?? 'user'.tr())
          .toString();

      final sbAdminId = SupabaseService.client.auth.currentUser?.id ?? '';

      final ok = await SupabaseService.awardCoins(
        userId: targetDocId,
        amount: amount,
        adminId: sbAdminId,
      );

      if (!ok) {
        if (!mounted) return;
        setState(() {
          _isAwarding = false;
          _errorMessage = 'err_sending_coins'.tr();
        });
        return;
      }

      final freshUser = await _findUser(target);

      final successText = 'coins_sent_success'.tr(namedArgs: {'user': targetDisplayName, 'amount': amount.toString()});

      if (!mounted) return;
      setState(() {
        _isAwarding = false;
        _foundUser = freshUser ?? user;
        _foundDocId = targetDocId;
        _errorMessage = null;
        _successMessage = successText;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  successText,
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00FF88),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAwarding = false;
        _errorMessage = 'err_sending_coins_with_e'.tr(args: [e.toString()]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ThemeService.isDarkMode
                    ? const [Color(0xFF1A1A24), Color(0xFF261D10)]
                    : const [Color(0xFFFFF9E6), Color(0xFFFFF0CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.monetization_on_rounded,
                      color: Color(0xFFFFD700), size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gamers ID Coins Vault',
                        style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Grant coins to players by Username, UID, or Email',
                        style: TextStyle(
                            color: ThemeService.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Grant Coins to Player',
            style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'search_user_to_send_coins_desc'.tr(),
            style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _targetController,
                  style: TextStyle(color: ThemeService.textPrimary),
                  onChanged: (val) {
                    if (_foundUser != null && _foundDocId != val.trim()) {
                      setState(() {
                        _foundUser = null;
                        _foundDocId = null;
                        _errorMessage = null;
                        _successMessage = null;
                      });
                    }
                  },
                  onSubmitted: (_) => _handleSearch(),
                  decoration: InputDecoration(
                    labelText: 'Target Username or UID',
                    hintText: 'e.g. fua, @user, UID, or email',
                    hintStyle: TextStyle(
                        color: ThemeService.textSecondary.withOpacity(0.6), fontSize: 13),
                    labelStyle: TextStyle(color: ThemeService.textSecondary),
                    prefixIcon: const Icon(Icons.person_search_rounded,
                        color: Color(0xFF38BDF8)),
                    suffixIcon: _targetController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: ThemeService.textSecondary, size: 18),
                            onPressed: () {
                              _targetController.clear();
                              setState(() {
                                _foundUser = null;
                                _foundDocId = null;
                                _errorMessage = null;
                                _successMessage = null;
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: ThemeService.card,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ThemeService.border)),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide:
                          BorderSide(color: Color(0xFFFFD700)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _handleSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeService.cardSecondary,
                    foregroundColor: const Color(0xFF38BDF8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Color(0xFF38BDF8), strokeWidth: 2),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_rounded, size: 20),
                            Text('search'.tr(),
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ],
          ),
          if (_foundUser != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF00FF88).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  GamerAvatar(
                    photoUrl: (_foundUser!['avatar_url'] ??
                            _foundUser!['photoUrl'] ??
                            '')
                        .toString(),
                    displayName: (_foundUser!['display_name'] ??
                            _foundUser!['displayName'] ??
                            _foundUser!['username'] ??
                            'User')
                        .toString(),
                    radius: 22,
                    frameId: (_foundUser!['active_frame'] ?? '').toString(),
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
                                (_foundUser!['display_name'] ??
                                        _foundUser!['displayName'] ??
                                        _foundUser!['username'] ??
                                        'User')
                                    .toString(),
                                style: TextStyle(
                                    color: ThemeService.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF88)
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF00FF88), size: 12),
                                  const SizedBox(width: 3),
                                  Text(
                                    'user_found'.tr(),
                                    style: const TextStyle(
                                        color: Color(0xFF00FF88),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${_foundUser!['username'] ?? ''} • ${_foundUser!['email'] ?? _foundDocId ?? ''}',
                          style: TextStyle(
                              color: ThemeService.textSecondary, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'current_balance_prefix'.tr(),
                              style: TextStyle(
                                  color: ThemeService.textSecondary, fontSize: 11),
                            ),
                            Text(
                              '${(_foundUser!['coins'] ?? 0)} 🪙',
                              style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: ThemeService.textPrimary),
            decoration: InputDecoration(
              labelText: 'Coins Amount',
              labelStyle: TextStyle(color: ThemeService.textSecondary),
              prefixIcon: const Icon(Icons.monetization_on_rounded,
                  color: Color(0xFFFFD700)),
              helperText: 'admin_unlimited_coins_desc'.tr(),
              helperStyle: TextStyle(
                  color: ThemeService.textSecondary, fontSize: 11),
              filled: true,
              fillColor: ThemeService.card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ThemeService.border)),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Color(0xFFFFD700)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [100, 500, 1000, 5000, 10000, 50000].map((amt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(
                      '+$amt 🪙',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: ThemeService.cardSecondary,
                    labelStyle:
                        const TextStyle(color: Color(0xFFFFD700)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: ThemeService.border),
                    ),
                    onPressed: () {
                      _amountController.text = amt.toString();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          if (_errorMessage != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4655).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFFF4655).withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFFF4655), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Color(0xFFFF7080),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_successMessage != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF00FF88).withOpacity(0.6)),
                ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF00FF88), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(
                          color: Color(0xFF80FFC0),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isAwarding ? null : _awardCoins,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF554400),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isAwarding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2.2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _isAwarding ? 'sending_coins_progress'.tr() : 'Award Coins Now',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Coin Awards History',
                style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.history_rounded,
                        color: Color(0xFFFFD700), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Live Logs',
                      style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Map<String, dynamic>>>(
            initialData: const [],
            stream: SupabaseService.getRealtimeCoinTransactions(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Error loading history: ${snap.error}',
                    style:
                        const TextStyle(color: Colors.red, fontSize: 12));
              }
              final docs = (snap.data ?? [])
                  .where((t) =>
                      t['type'] == 'admin_grant' ||
                      t['type'] == 'coin_grant')
                  .take(10)
                  .toList();

              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeService.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThemeService.border),
                  ),
                  child: Center(
                    child: Text(
                      'no_recent_transactions_found'.tr(),
                      style:
                          TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final data = docs[index];
                  final amount = (data['amount'] as num?)?.toInt() ?? 0;
                  final description = data['description'] ??
                      'Admin ne $amount coins diye';
                  final date = data['created_at']?.toString() ?? '';
                  final targetUserId =
                      (data['user_id'] ?? '').toString();

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ThemeService.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFD700).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.monetization_on_rounded,
                              color: Color(0xFFFFD700), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                description,
                                style: TextStyle(
                                    color: ThemeService.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'UID: $targetUserId ${date.isNotEmpty ? '• ${date.substring(0, 19).replaceAll('T', ' ')}' : ''}',
                                style: TextStyle(
                                    color: ThemeService.textSecondary,
                                    fontSize: 10.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+$amount 🪙',
                          style: const TextStyle(
                            color: Color(0xFF00FF88),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
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