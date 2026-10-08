import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
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
import '../models/team_model.dart';
import 'admin/admin_team_matches_screen.dart';

class GamerAdminDashboardScreen extends StatefulWidget {
  const GamerAdminDashboardScreen({super.key});

  @override
  State<GamerAdminDashboardScreen> createState() => _GamerAdminDashboardScreenState();
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
    _tabController = TabController(length: 7, vsync: this);
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
            content: Text('Successfully created 10 Professional Demo Accounts with Posts!'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seeding demo accounts: $e'), backgroundColor: const Color(0xFFFF4655)),
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
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655)),
            SizedBox(width: 8),
            Text('Delete All Demo Accounts?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will permanently delete all 10 demo accounts (isDemoAccount == true) and their posts, clips, and follows. Real accounts will not be touched.',
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All', style: TextStyle(fontWeight: FontWeight.bold)),
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
            content: Text('Successfully deleted $count demo accounts and associated data.'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting demo accounts: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingDemo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
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
                      _buildPendingProofsReviewSection(),
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
                    unselectedLabelColor: const Color(0xFF8B949E),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: [
                      const Tab(text: 'Users'),
                      _buildRankVerifyTabTitle(),
                      const Tab(text: 'Blue Tick Requests (3 pending)'),
                      const Tab(text: 'Posts Moderation'),
                      const Tab(text: 'Team Matches ⚔️'),
                      const Tab(text: 'Reports'),
                      const Tab(text: 'Coins'),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildUsersTab(),
              _buildRankVerifyTab(),
              _buildBlueTickRequestsTab(),
              _buildPostsModerationTab(),
              const AdminTeamMatchesScreen(),
              _buildReportsTab(),
              _buildCoinsTab(),
            ],
          ),
        ),
      ),
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
                if (g is Map && g['status'] == 'pending') {
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

  // ─────────────── HEADER (100% Supabase) ───────────────
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
            color: const Color(0xFF10141D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2B3E)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
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
                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
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
                    const Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        color: Colors.white,
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
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00FF88)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Color(0xFF00FF88), size: 10),
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

  Widget _buildPendingProofsReviewSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('active_matches')
          .stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        final matches = snapshot.data ?? [];
        final pendingProofs = matches.where((m) {
          final st = (m['status'] ?? '').toString().toLowerCase();
          final pst = (m['proof_status'] ?? '').toString().toLowerCase();
          return st == 'under_review' && (pst == 'pending' || pst.isEmpty);
        }).toList();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF131A29),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: pendingProofs.isNotEmpty ? const Color(0xFFFFB800) : const Color(0xFF2A3447),
              width: pendingProofs.isNotEmpty ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (pendingProofs.isNotEmpty)
                BoxShadow(
                  color: const Color(0xFFFFB800).withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: pendingProofs.isNotEmpty
                          ? const Color(0xFFFFB800).withOpacity(0.15)
                          : const Color(0xFF1B2436),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.fact_check_rounded,
                      color: pendingProofs.isNotEmpty ? const Color(0xFFFFB800) : const Color(0xFF00FF88),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pending Proofs Review',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pendingProofs.isNotEmpty
                              ? '${pendingProofs.length} match proof(s) awaiting verification'
                              : 'No match proofs pending review',
                          style: const TextStyle(
                            color: Color(0xFF8B949E),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: pendingProofs.isNotEmpty
                          ? const Color(0xFFFFB800)
                          : const Color(0xFF00FF88).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pendingProofs.isNotEmpty ? '${pendingProofs.length} PENDING' : 'ALL CLEAR ✅',
                      style: TextStyle(
                        color: pendingProofs.isNotEmpty ? Colors.black : const Color(0xFF00FF88),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (pendingProofs.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0xFF2A3447), height: 1),
                const SizedBox(height: 12),
                ...pendingProofs.map((match) => _AdminPendingProofCard(
                  key: ValueKey(match['id']),
                  match: match,
                  teamService: TeamService(),
                )),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─────────────── STATS CARDS (100% Supabase) ───────────────
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
        color: const Color(0xFF10141D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2B3E)),
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
                style: const TextStyle(
                  color: Color(0xFF8B949E),
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

  // ===================== TAB 1: USERS LIST (SUPABASE) =====================
  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) =>
                setState(() => _userSearchQuery = val.toLowerCase().trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search users by name, @username, or tag...',
              hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF8B949E), size: 20),
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Color(0xFF8B949E), size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _userSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF10141D),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1F2B3E)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1F2B3E)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00FF88)),
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
                    backgroundColor: const Color(0xFF00FF88).withOpacity(0.12),
                    foregroundColor: const Color(0xFF00FF88),
                    side: const BorderSide(color: Color(0xFF00FF88), width: 1.2),
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
                    backgroundColor: const Color(0xFFFF4655).withOpacity(0.12),
                    foregroundColor: const Color(0xFFFF4655),
                    side: const BorderSide(color: Color(0xFFFF4655), width: 1.2),
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
                        const Text(
                          'Could not load users',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFF8B949E), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                );
              }

              final docs = snapshot.data ?? [];
              List<GamerUser> users =
                  docs.map((d) => GamerUser.fromMap(d)).toList();

              if (_userSearchQuery.isNotEmpty) {
                users = users.where((u) {
                  return u.displayName.toLowerCase().contains(_userSearchQuery) ||
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
                            color: const Color(0xFF10141D),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF1F2B3E)),
                          ),
                          child: const Icon(Icons.people_outline_rounded,
                              color: Color(0xFF8B949E), size: 40),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No users found',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _userSearchQuery.isNotEmpty
                              ? 'Try a different search term'
                              : 'No users registered yet',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFF8B949E), fontSize: 12),
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
        color: const Color(0xFF10141D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isBanned
              ? const Color(0xFFFF4655)
              : const Color(0xFF1F2B3E),
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
                borderColor: user.isBanned ? const Color(0xFFFF4655) : const Color(0xFFFF8A00),
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
                            user.displayName.isNotEmpty ? user.displayName : '@${user.username}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.hasBlueTick) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Color(0xFF38BDF8), size: 16),
                        ],
                        const SizedBox(width: 6),
                        RankBadgeWidget(badge: user.getRankBadge(), size: 14, showLabel: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '@${user.username}',
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
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
                          style: const TextStyle(color: Color(0xFF6E7681), fontSize: 11),
                        ),
                        if (user.isDemoAccount) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF21262D),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF8B949E), width: 0.8),
                            ),
                            child: const Text(
                              'DEMO',
                              style: TextStyle(
                                color: Color(0xFF8B949E),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4655).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFF4655)),
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
          const Divider(color: Color(0xFF1F2B3E), height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _toggleBanUser(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: user.isBanned ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                  side: BorderSide(
                    color: user.isBanned ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(
                  user.isBanned ? Icons.check_circle_outline : Icons.block_rounded,
                  size: 14,
                ),
                label: Text(
                  user.isBanned ? 'Unban' : 'Ban',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                ? (nextBanned ? const Color(0xFFFF4655) : const Color(0xFF00FF88))
                : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating user ban: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  // ===================== TAB 2: RANK VERIFICATION TAB (SUPABASE) =====================
  Widget _buildRankVerifyTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xFF0B0F14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _rankSearchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by username or Game ID...',
                  hintStyle: const TextStyle(color: Color(0xFF6E7681), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00FF88), size: 18),
                  suffixIcon: _rankSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF6E7681), size: 16),
                          onPressed: () {
                            _rankSearchController.clear();
                            setState(() => _rankSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF10141D),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1F2B3E)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1F2B3E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF00FF88)),
                  ),
                ),
                onChanged: (val) => setState(() => _rankSearchQuery = val.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final game in ['All', ...MobileGamesRankData.games]) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(game),
                          selected: _selectedRankGameFilter == game,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedRankGameFilter = game);
                          },
                          selectedColor: const Color(0xFF00FF88),
                          backgroundColor: const Color(0xFF161B26),
                          labelStyle: TextStyle(
                            color: _selectedRankGameFilter == game ? const Color(0xFF0B0F14) : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: _selectedRankGameFilter == game ? const Color(0xFF00FF88) : const Color(0xFF1F2B3E),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    FilterChip(
                      label: Text(_showOnlyPendingRanks ? '⏳ Pending' : '📋 All History'),
                      selected: _showOnlyPendingRanks,
                      onSelected: (val) => setState(() => _showOnlyPendingRanks = val),
                      selectedColor: const Color(0xFFFF8A00).withOpacity(0.2),
                      backgroundColor: const Color(0xFF161B26),
                      labelStyle: TextStyle(
                        color: _showOnlyPendingRanks ? const Color(0xFFFF8A00) : const Color(0xFF8B949E),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _showOnlyPendingRanks ? const Color(0xFFFF8A00) : const Color(0xFF1F2B3E),
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
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4655), size: 48),
                        const SizedBox(height: 14),
                        const Text('Could not load rank requests',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text('${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
              }

              final docs = snapshot.data ?? [];
              final List<_RankQueueItem> allItems = [];

              for (final doc in docs) {
                final user = GamerUser.fromMap(doc);
                for (int i = 0; i < user.games.length; i++) {
                  final game = user.games[i];
                  allItems.add(_RankQueueItem(user: user, game: game, gameIndex: i));
                }

                final bool hasGameForRank = user.games.any(
                  (g) => g.claimedRank.toLowerCase() == user.rank.toLowerCase(),
                );
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
                        : (user.favoriteGame.isNotEmpty ? user.favoriteGame : 'BGMI'),
                    gameId: user.gameId.isNotEmpty ? user.gameId : 'N/A',
                    claimedRank: user.rank,
                    verifiedRank: (user.isRankApproved || rankStatus == 'verified') ? user.rank : '',
                    isVerified: user.isRankApproved || rankStatus == 'verified',
                    screenshotUrl: user.rankScreenshot,
                    status: normalizedStatus,
                    submittedAt: user.createdAt,
                    rejectReason: user.rankRejectReason,
                    ownerUid: user.uid,
                  );
                  allItems.add(_RankQueueItem(user: user, game: primaryGame, gameIndex: -1));
                }
              }

              final filtered = allItems.where((item) {
                if (_showOnlyPendingRanks && item.game.status != 'pending') {
                  return false;
                }
                if (_selectedRankGameFilter != 'All' &&
                    item.game.gameName.toLowerCase() != _selectedRankGameFilter.toLowerCase()) {
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
                if (a.game.status == 'pending' && b.game.status != 'pending') return -1;
                if (a.game.status != 'pending' && b.game.status == 'pending') return 1;
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
                            color: const Color(0xFF10141D),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF1F2B3E)),
                          ),
                          child: const Icon(Icons.verified_outlined, color: Color(0xFF8B949E), size: 40),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No rank verification requests found',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _showOnlyPendingRanks
                              ? 'All pending screenshot rank submissions have been reviewed!'
                              : 'No requests match the selected filters.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
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
        color: const Color(0xFF10141D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? const Color(0xFFFF8A00).withOpacity(0.4) : const Color(0xFF1F2B3E),
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
                displayName: user.displayName.isNotEmpty ? user.displayName : user.username,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isNotEmpty ? user.displayName : user.username,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '@${user.username} • UID: ${user.uid.length > 8 ? user.uid.substring(0, 8) : user.uid}',
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
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
          const Divider(color: Color(0xFF1F2B3E), height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B26),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2E384D)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sports_esports_rounded, size: 14, color: Color(0xFF00FF88)),
                    const SizedBox(width: 4),
                    Text(
                      game.gameName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                style: const TextStyle(color: Color(0xFF6E7681), fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Text(
                'Claimed Rank: ',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.5)),
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
                const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF8B949E)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
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
                title: '${user.displayName} • ${game.gameName} Rank Proof',
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
                        color: const Color(0xFF161B26),
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF00FF88), strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 140,
                        color: const Color(0xFF161B26),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 36),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Tap to inspect proof',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                color: const Color(0xFF161B26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.image_not_supported_rounded, color: Color(0xFF8B949E), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'No screenshot uploaded',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],

          if (isRejected && game.rejectReason != null && game.rejectReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4655).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFFF4655), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${game.rejectReason}',
                      style: const TextStyle(color: Color(0xFFFF4655), fontSize: 12),
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

  void _showScreenshotViewerDialog({required String imageUrl, required String title}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF10141D),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
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
                      child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                    ),
                    errorWidget: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Icon(Icons.broken_image_rounded, color: Colors.red, size: 48),
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
      final targetUserId = item.game.ownerUid.isNotEmpty ? item.game.ownerUid : item.user.uid;
      final currentAdmin = GamerAuthService().currentGamer?.displayName ?? 'Admin';

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
          body: 'آپ کا ${item.game.claimedRank} (${item.game.gameName}) رینک ایڈمن کی طرف سے منظور ہو گیا ہے۔',
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
            backgroundColor: ok ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving rank: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  Future<void> _rejectRankVerification(_RankQueueItem item, String reason) async {
    try {
      final targetUserId = item.game.ownerUid.isNotEmpty ? item.game.ownerUid : item.user.uid;
      final currentAdmin = GamerAuthService().currentGamer?.displayName ?? 'Admin';
      const defaultUrduMsg = 'آپ کا اسکرین شاٹ درست نہیں ہے، دوبارہ اپلوڈ کریں';
      final finalReason = reason.trim().isNotEmpty ? reason.trim() : defaultUrduMsg;

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
            backgroundColor: ok ? const Color(0xFFFF8A00) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting rank: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  // ===================== TAB 3: BLUE TICK QUEUE (SUPABASE) =====================
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
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4655), size: 48),
                  const SizedBox(height: 14),
                  const Text('Could not load blue tick requests',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final docs = snapshot.data ?? [];
        final allUsers = docs.map((d) => GamerUser.fromMap(d)).toList();

        List<GamerUser> requests = allUsers
            .where((u) =>
                !u.hasBlueTick &&
                (u.verificationStatus == 'pending' || u.blueTickStatus == 'pending'))
            .toList();

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
                      color: const Color(0xFF10141D),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1F2B3E)),
                    ),
                    child: const Icon(Icons.verified_outlined, color: Color(0xFF38BDF8), size: 40),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No Blue Tick Requests',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All verification requests have been reviewed!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
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
        color: const Color(0xFF10141D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
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
                            user.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        RankBadgeWidget(badge: user.getRankBadge(), size: 14, showLabel: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username} • BGMI UID: ${user.gameId.isNotEmpty ? user.gameId : '512903819'}',
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'K/D: ${user.kdRatio.toStringAsFixed(1)} • Followers: ${user.followersCount}',
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          const Divider(color: Color(0xFF1F2B3E), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _rejectVerification(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF4655),
                  side: const BorderSide(color: Color(0xFFFF4655)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _approveVerification(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9BF0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.verified, size: 16),
                label: const Text('Approve Blue Tick', style: TextStyle(fontWeight: FontWeight.bold)),
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
                Text(ok ? 'Approved! Blue tick added to @${user.username}' : 'Error approving'),
              ],
            ),
            backgroundColor: ok ? const Color(0xFF1D9BF0) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving verification: $e'), backgroundColor: const Color(0xFFFF4655)),
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
            content: Text(ok ? 'Rejected verification for @${user.username}' : 'Error rejecting'),
            backgroundColor: ok ? const Color(0xFFFF4655) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  // ===================== TAB 4: POSTS MODERATION (SUPABASE) =====================
  Widget _buildPostsModerationTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getRealtimePosts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4655), size: 48),
                  const SizedBox(height: 14),
                  const Text('Could not load posts',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
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
                      color: const Color(0xFF10141D),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1F2B3E)),
                    ),
                    child: const Icon(Icons.dynamic_feed_rounded, color: Color(0xFF8B949E), size: 40),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No posts to moderate',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Community is clean — no posts need review!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
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
                color: const Color(0xFF10141D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1F2B3E)),
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
                                    style: const TextStyle(
                                        color: Colors.white,
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
                                  content: Text(ok ? 'Post deleted by admin' : 'Error deleting'),
                                  backgroundColor: const Color(0xFFFF4655)),
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
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
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
                          color: const Color(0xFF161B26),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF00FF88), strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 140,
                          color: const Color(0xFF161B26),
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded,
                                color: Colors.white38, size: 36),
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
                        style: const TextStyle(
                            color: Color(0xFF6E7681),
                            fontSize: 10,
                            fontFamily: 'monospace'),
                      ),
                      const Spacer(),
                      if (userId.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            final sbAdminId = SupabaseService.client.auth.currentUser?.id ?? '';
                            final ok = await SupabaseService.banUser(
                              userId: userId,
                              adminId: sbAdminId,
                              reason: 'Banned from post moderation',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(ok ? 'Author $author banned' : 'Error banning'),
                                    backgroundColor: const Color(0xFFFF4655)),
                              );
                            }
                          },
                          child: const Text('Ban Author',
                              style: TextStyle(color: Color(0xFFFF4655), fontSize: 11)),
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

  // ===================== TAB 6: REPORTS (SUPABASE) =====================
  Widget _buildReportsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getRealtimeReports(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4655), size: 48),
                  const SizedBox(height: 14),
                  const Text('Could not load reports',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
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
                  const Text(
                    'Community Safe • 0 Open Reports',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No offensive content or active player violations reported.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
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
            final reporterName = (data['reporter_username'] ?? 'Player').toString();
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
                color: const Color(0xFF10141D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1F2B3E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4655).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFFF4655), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              targetType.isNotEmpty ? targetType.toUpperCase() : 'REPORT',
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.5)),
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
                          final ok = await SupabaseService.deleteReport(reportId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(ok ? 'Report deleted' : 'Error'),
                                  backgroundColor: const Color(0xFFFF4655)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          color: Color(0xFF8B949E), size: 14),
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
                        color: const Color(0xFF161B26),
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
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (targetContent.isNotEmpty) ...[
                    const Text('Reported Content:',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      targetContent,
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
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
                          style: const TextStyle(
                              color: Color(0xFF6E7681),
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
                          icon: const Icon(Icons.check_circle_outline, size: 14),
                          label: const Text('Mark Resolved',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final ok = await SupabaseService.updateReport(
                              reportId: reportId,
                              status: 'resolved',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(ok ? 'Report marked resolved' : 'Error'),
                                    backgroundColor: const Color(0xFF00FF88)),
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

  // ===================== TAB 7: COINS (SUPABASE) =====================
  Widget _buildCoinsTab() {
    return const _AdminCoinsVaultTab();
  }
}

class _AdminCoinsVaultTab extends StatefulWidget {
  const _AdminCoinsVaultTab();

  @override
  State<_AdminCoinsVaultTab> createState() => _AdminCoinsVaultTabState();
}

class _AdminCoinsVaultTabState extends State<_AdminCoinsVaultTab> {
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '100');

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
      final users = await SupabaseService.query('users', select: '*', limit: 500);
      final clean = raw.toLowerCase().replaceAll('@', '').trim();

      for (final u in users) {
        final docId = (u['id'] ?? '').toString();
        final uUid = (u['uid'] ?? docId).toString().trim();
        final uName = (u['username'] ?? '').toString().toLowerCase().trim();
        final uEmail = (u['email'] ?? '').toString().toLowerCase().trim();
        final uDisplay = (u['display_name'] ?? '').toString().toLowerCase().trim();

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
        _errorMessage = 'صارف نہیں ملا';
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
        _errorMessage = 'صارف نہیں ملا';
      }
    });

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'صارف نہیں ملا ("$target")',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF4655),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _awardCoins() async {
    final target = _targetController.text.trim();
    if (target.isEmpty) {
      setState(() => _errorMessage = 'صارف نہیں ملا');
      return;
    }

    final amountText = _amountController.text.trim();
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'براہ کرم 1 یا اس سے زیادہ سکے کی درست تعداد درج کریں');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('براہ کرم 1 یا اس سے زیادہ سکے کی درست تعداد درج کریں'),
          backgroundColor: Color(0xFFFF4655),
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
          _errorMessage = 'صارف نہیں ملا';
        });
        return;
      }

      final targetDocId = docId;
      final targetDisplayName = (user['display_name'] ??
              user['displayName'] ??
              user['username'] ??
              'صارف')
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
          _errorMessage = 'سکے بھیجنے میں خرابی';
        });
        return;
      }

      // Refresh user coins
      final freshUser = await _findUser(target);

      final successText = 'کامیابی! $targetDisplayName کو $amount سکے بھیج دیے گئے';

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
              const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAwarding = false;
        _errorMessage = 'سکے بھیجنے میں خرابی: $e';
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
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A24), Color(0xFF261D10)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gamers ID Coins Vault',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Grant coins to players by Username, UID, or Email',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Grant Coins to Player',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'صارف کو Username، UID یا Email سے تلاش کر کے سکے بھیجیں',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _targetController,
                  style: const TextStyle(color: Colors.white),
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
                    hintStyle: const TextStyle(color: Color(0xFF555E6D), fontSize: 13),
                    labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                    prefixIcon: const Icon(Icons.person_search_rounded,
                        color: Color(0xFF38BDF8)),
                    suffixIcon: _targetController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white54, size: 18),
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
                    fillColor: const Color(0xFF10141D),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFD700)),
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
                    backgroundColor: const Color(0xFF1F2B3E),
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
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded, size: 20),
                            Text('تلاش کریں',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold)),
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
                color: const Color(0xFF0D2319),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
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
                                style: const TextStyle(
                                    color: Colors.white,
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
                                color: const Color(0xFF00FF88).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF00FF88), size: 12),
                                  SizedBox(width: 3),
                                  Text(
                                    'صارف مل گیا',
                                    style: TextStyle(
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
                          style: const TextStyle(
                              color: Color(0xFF8B949E), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'موجودہ بیلنس: ',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11),
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
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Coins Amount',
              labelStyle: const TextStyle(color: Color(0xFF8B949E)),
              prefixIcon: const Icon(Icons.monetization_on_rounded,
                  color: Color(0xFFFFD700)),
              helperText: 'کوئی حد نہیں — ایڈمن جتنی چاہے سکے بھیج سکتا ہے',
              helperStyle:
                  const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
              filled: true,
              fillColor: const Color(0xFF10141D),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFD700)),
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
                    backgroundColor: const Color(0xFF1A2130),
                    labelStyle: const TextStyle(color: Color(0xFFFFD700)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF26354D)),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2D1216),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0E281C),
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
                _isAwarding ? 'سکے بھیجے جا رہے ہیں...' : 'Award Coins Now',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Coin Awards History',
                style: TextStyle(
                    color: Colors.white,
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
            stream: SupabaseService.getRealtimeCoinTransactions(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Error loading history: ${snap.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 12));
              }
              final docs = (snap.data ?? [])
                  .where((t) =>
                      t['type'] == 'admin_grant' || t['type'] == 'coin_grant')
                  .take(10)
                  .toList();

              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10141D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2B3E)),
                  ),
                  child: const Center(
                    child: Text(
                      'کوئی حالیہ ٹرانزیکشن نہیں ملی',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
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
                  final description =
                      data['description'] ?? 'Admin ne $amount coins diye';
                  final date = data['created_at']?.toString() ?? '';
                  final targetUserId = (data['user_id'] ?? '').toString();

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10141D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1F2B3E)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.12),
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
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'UID: $targetUserId ${date.isNotEmpty ? '• ${date.substring(0, 19).replaceAll('T', ' ')}' : ''}',
                                style: const TextStyle(
                                    color: Color(0xFF8B949E), fontSize: 10.5),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0B0F14),
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
  State<_AdminRankActionButtons> createState() => _AdminRankActionButtonsState();
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
              color: const Color(0xFF161B26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _reasonController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Enter rejection reason (e.g. Screenshot unclear, UID mismatch)...',
                    hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2B3E),
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
                  backgroundColor: const Color(0xFFFF4655).withOpacity(0.1),
                  foregroundColor: const Color(0xFFFF4655),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: Text(
                  _showReasonField ? 'Confirm Reject' : 'Reject',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.check_rounded, size: 14),
                label: const Text(
                  'Approve Rank',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminPendingProofCard extends StatefulWidget {
  final Map<String, dynamic> match;
  final TeamService teamService;

  const _AdminPendingProofCard({
    super.key,
    required this.match,
    required this.teamService,
  });

  @override
  State<_AdminPendingProofCard> createState() => _AdminPendingProofCardState();
}

class _AdminPendingProofCardState extends State<_AdminPendingProofCard> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Proof Screenshot 📸',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (c, u) => const SizedBox(
                      height: 200,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF00FF88)))),
                  errorWidget: (c, u, e) => const SizedBox(
                      height: 200,
                      child: Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white30))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final matchId = widget.match['id'];
      final team1Id = (widget.match['team1_id'] ?? '').toString();
      final team2Id = (widget.match['team2_id'] ?? '').toString();
      final submittedByRaw = (widget.match['submitted_by_team_id'] ??
              widget.match['winner_team_id'])
          ?.toString();
      final winnerId = (submittedByRaw != null && submittedByRaw.isNotEmpty)
          ? submittedByRaw
          : (widget.match['winner_team_id'] ?? '').toString();
      final winnerUuid = winnerId.isNotEmpty ? SupabaseService.toUuid(winnerId) : '';

      final ok = await SupabaseService.approveProof(
        matchId: matchId.toString(),
        winnerTeamId: winnerUuid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? '✅ Proof accepted! Match completed.'
                : 'Error accepting proof'),
            backgroundColor:
                ok ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error accepting proof: $e'),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final matchId = widget.match['id'];
      final reason = _reasonController.text.trim();
      final finalReason =
          reason.isNotEmpty ? reason : 'Proof screenshot was unclear or invalid';

      final ok = await SupabaseService.rejectProof(
        matchId: matchId.toString(),
        reason: finalReason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? '❌ Proof rejected with note: $finalReason'
                : 'Error rejecting'),
            backgroundColor:
                ok ? const Color(0xFFFF4655) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error rejecting proof: $e'),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t1 = (widget.match['team1_id'] ?? '').toString();
    final t2 = (widget.match['team2_id'] ?? '').toString();
    final result = (widget.match['result'] ?? 'WIN').toString().toUpperCase();
    final proofUrl = widget.match['proof_url']?.toString();
    final dateRaw = widget.match['ended_at'] ?? widget.match['created_at'];
    String formattedDate = '';
    if (dateRaw != null) {
      try {
        final dt = DateTime.parse(dateRaw.toString()).toLocal();
        formattedDate = DateFormat('dd MMM, hh:mm a').format(dt);
      } catch (_) {
        formattedDate = dateRaw.toString();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2436),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3447)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<TeamModel?>>(
                  future: Future.wait([
                    widget.teamService.getTeam(t1),
                    widget.teamService.getTeam(t2),
                  ]),
                  builder: (context, snap) {
                    final t1Name = snap.data?[0]?.name ??
                        widget.match['team1_name'] ??
                        'Team 1';
                    final t2Name = snap.data?[1]?.name ??
                        widget.match['team2_name'] ??
                        'Team 2';
                    return Text(
                      '$t1Name  ⚔️  $t2Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
                ),
                child: Text(
                  'Claim: $result',
                  style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (formattedDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FutureBuilder<TeamModel?>(
                  future:
                      (widget.match['submitted_by_team_id'] ??
                                  widget.match['winner_team_id']) !=
                              null
                          ? widget.teamService.getTeam(
                              (widget.match['submitted_by_team_id'] ??
                                      widget.match['winner_team_id'])
                                  .toString())
                          : Future.value(null),
                  builder: (context, snap) {
                    final subName = snap.data?.name ??
                        (widget.match['submitted_by_team_id'] != null
                            ? 'Team'
                            : 'Submitter');
                    return Text(
                      'Submitted By: $subName',
                      style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5),
                    );
                  },
                ),
                Text(
                  'Date: $formattedDate',
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),

          if (proofUrl != null && proofUrl.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _showImageDialog(context, proofUrl),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: proofUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => Container(
                        height: 160,
                        color: const Color(0xFF10141D),
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF00FF88)),
                        ),
                      ),
                      errorWidget: (c, u, e) => Container(
                        height: 100,
                        color: const Color(0xFF10141D),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.white30),
                              SizedBox(width: 8),
                              Text('Could not load image',
                                  style: TextStyle(
                                      color: Colors.white30, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Tap to View',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF10141D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('No screenshot attached',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 10),
          ],

          TextField(
            controller: _reasonController,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
            decoration: InputDecoration(
              hintText: 'Reject reason (ضروری اگر Reject کرنا ہو)...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF10141D),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A3447)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A3447)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFF4655)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          if (_isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: Color(0xFF00FF88)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4655),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text(
                        'Reject Proof ❌',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: _handleReject,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_rounded,
                          size: 16, color: Colors.black),
                      label: const Text(
                        'Accept Proof ✅',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                      onPressed: _handleAccept,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}