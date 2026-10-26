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
  State<GamerAdminDashboardScreen> createState() => _GamerAdminDashboardScreenState();
}

class _GamerAdminDashboardScreenState extends State<GamerAdminDashboardScreen> with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _rankSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleSeedDemoAccounts() async {
    setState(() => _isSeedingDemo = true);
    try {
      await DemoAccountsService().seedDemoAccounts();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully created 10 Demo Accounts!'), backgroundColor: Color(0xFF00FF88)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error seeding: $e'), backgroundColor: const Color(0xFFFF4655)));
    } finally {
      if (mounted) setState(() => _isSeedingDemo = false);
    }
  }

  Future<void> _handleDeleteAllDemoAccounts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        title: const Text('Delete All Demo Accounts?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This will permanently delete all demo accounts and posts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655)), child: const Text('Delete All')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isDeletingDemo = true);
    try {
      final count = await DemoAccountsService().deleteAllDemoAccounts();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted $count demo accounts.'), backgroundColor: const Color(0xFFFF4655)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFFF4655)));
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
                        tabs: const [
                          Tab(text: 'Tournaments 🏆'),
                          Tab(text: 'Banner 📢'),
                          Tab(text: 'Users'),
                          Tab(text: 'Rank Verify'),
                          Tab(text: 'Blue Tick Requests'),
                          Tab(text: 'UC Requests ⚡'),
                          Tab(text: 'UC History 📜'),
                          Tab(text: 'Posts Moderation'),
                          Tab(text: 'Team Matches ⚔️'),
                          Tab(text: 'Reports'),
                          Tab(text: 'Coins'),
                          Tab(text: 'Referrals 👥'),
                          Tab(text: 'Under Review 🔍'),
                          Tab(text: 'History 📜'),
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
                  _AdminUcRequestsTab(),
                  _AdminUcHistoryTab(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ThemeService.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThemeService.border)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF00FF88).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.shield_rounded, color: Color(0xFF00FF88), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Dashboard', style: TextStyle(color: ThemeService.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                const Text('Gamers ID Network • Admin Only', style: TextStyle(color: Color(0xFF00FF88), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF00FF88).withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF00FF88))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.fiber_manual_record, color: Color(0xFF00FF88), size: 10), SizedBox(width: 4), Text('LIVE', style: TextStyle(color: Color(0xFF00FF88), fontSize: 10, fontWeight: FontWeight.w900))]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, userSnap) {
        int totalUsers = userSnap.data?.length ?? 0;
        int totalCoins = 0;
        if (userSnap.hasData) {
          for (final doc in userSnap.data!) {
            totalCoins += (doc['coins'] as num?)?.toInt() ?? 0;
          }
        }
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.getRealtimePosts(),
          builder: (context, postSnap) {
            int totalPosts = postSnap.data?.length ?? 0;
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                _buildStatCard('Total Users', '$totalUsers', Icons.people_alt_rounded, const Color(0xFF38BDF8)),
                _buildStatCard('Posts', '$totalPosts', Icons.dynamic_feed_rounded, const Color(0xFF00FF88)),
                _buildStatCard('Reports', 'Clean', Icons.warning_amber_rounded, const Color(0xFFFF4655)),
                _buildStatCard('Coins Distributed', '$totalCoins 🪙', Icons.monetization_on_rounded, const Color(0xFFFFD700)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: ThemeService.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeService.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: TextStyle(color: ThemeService.textSecondary, fontSize: 11)), Icon(icon, color: color, size: 16)]),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  // ===================== TAB: USERS =====================
  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _userSearchQuery = val.toLowerCase().trim()),
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    filled: true,
                    fillColor: ThemeService.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSeedingDemo ? null : _handleSeedDemoAccounts,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
                child: const Text('Seed Demo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: _isDeletingDemo ? null : _handleDeleteAllDemoAccounts,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655), foregroundColor: Colors.white),
                child: const Text('Delete Demo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.getRealtimeUsers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
              var users = snapshot.data!.map((d) => GamerUser.fromMap(d)).toList();
              if (_userSearchQuery.isNotEmpty) {
                users = users.where((u) => u.displayName.toLowerCase().contains(_userSearchQuery) || u.username.toLowerCase().contains(_userSearchQuery)).toList();
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final u = users[i];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: ThemeService.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: u.isBanned ? const Color(0xFFFF4655) : ThemeService.border)),
                    child: Row(
                      children: [
                        GamerAvatar(photoUrl: u.photoUrl, displayName: u.displayName, radius: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u.displayName.isNotEmpty ? u.displayName : '@${u.username}', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('@${u.username} • 🪙 ${u.coins} Coins', style: TextStyle(color: ThemeService.textSecondary, fontSize: 11)),
                        ])),
                        OutlinedButton(
                          onPressed: () => _toggleBanUser(u),
                          style: OutlinedButton.styleFrom(foregroundColor: u.isBanned ? const Color(0xFF00FF88) : const Color(0xFFFF4655)),
                          child: Text(u.isBanned ? 'Unban' : 'Ban', style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggleBanUser(GamerUser user) async {
    final nextBanned = !user.isBanned;
    final sbAdminId = SupabaseService.client.auth.currentUser?.id ?? '';
    if (nextBanned) {
      await SupabaseService.banUser(userId: user.uid, adminId: sbAdminId, reason: 'Banned by admin');
    } else {
      await SupabaseService.unbanUser(user.uid);
    }
  }

  // ===================== TAB: RANK VERIFY =====================
  Widget _buildRankVerifyTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        final docs = snapshot.data!;
        final List<_RankQueueItem> items = [];
        for (final doc in docs) {
          final user = GamerUser.fromMap(doc);
          for (int i = 0; i < user.games.length; i++) {
            if (user.games[i].status == 'pending') {
              items.add(_RankQueueItem(user: user, game: user.games[i], gameIndex: i));
            }
          }
        }
        if (items.isEmpty) {
          return const Center(child: Text('No pending rank verification requests! 🎉', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ThemeService.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.5))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.user.displayName} (@${item.user.username})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Game: ${item.game.gameName} | Claimed Rank: ${item.game.claimedRank}', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                  const SizedBox(height: 8),
                  if (item.game.screenshotUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(imageUrl: item.game.screenshotUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await SupabaseService.rejectRank(userId: item.user.uid, reason: 'Invalid screenshot', adminName: 'Admin');
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF4655)),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await SupabaseService.approveRank(userId: item.user.uid, rank: item.game.claimedRank, gameName: item.game.gameName, adminName: 'Admin');
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
                          child: const Text('Approve Rank'),
                        ),
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

  // ===================== TAB: BLUE TICK REQUESTS =====================
  Widget _buildBlueTickRequestsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.getRealtimeUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        final requests = snapshot.data!.where((d) => (d['verification_status'] ?? '').toString().toLowerCase() == 'pending').toList();
        if (requests.isEmpty) return const Center(child: Text('No pending blue tick requests!', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (ctx, i) {
            final u = requests[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ThemeService.card, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Expanded(child: Text(u['displayName'] ?? u['username'] ?? 'User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ElevatedButton(
                    onPressed: () async {
                      await SupabaseService.client.from('users').update({'is_verified': true, 'verification_status': 'approved'}).eq('id', u['id']);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.black),
                    child: const Text('Approve Tick'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostsModerationTab() => const Center(child: Text('Posts Moderation', style: TextStyle(color: Colors.white)));
  Widget _buildReportsTab() => const Center(child: Text('Reports Management', style: TextStyle(color: Colors.white)));
  Widget _buildCoinsTab() => _AdminCoinsVaultTab();
  Widget _buildReferralsTrackerTab() => const Center(child: Text('Referrals Tracker', style: TextStyle(color: Colors.white)));
}

// ===============================================================================
// ADVANCED TOURNAMENT MANAGEMENT SYSTEM (PUBG, BGMI, FREE FIRE, COD)
// ===============================================================================
class _AdminTournamentsTab extends StatefulWidget {
  const _AdminTournamentsTab();

  @override
  State<_AdminTournamentsTab> createState() => _AdminTournamentsTabState();
}

class _AdminTournamentsTabState extends State<_AdminTournamentsTab> {
  int _currentSubTab = 0;
  String _gameFilter = 'All';
  final List<String> _gameList = ['PUBG Mobile', 'BGMI', 'Free Fire', 'COD Mobile'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('🎮 Tournaments'),
                      selected: _currentSubTab == 0,
                      onSelected: (val) => setState(() => _currentSubTab = 0),
                      selectedColor: const Color(0xFF00FF88),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('🏆 Winner Proofs'),
                      selected: _currentSubTab == 1,
                      onSelected: (val) => setState(() => _currentSubTab = 1),
                      selectedColor: const Color(0xFFFF8A00),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openCreateEditModal(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(child: _currentSubTab == 0 ? _buildTournamentsList() : _buildWinnerProofsList()),
      ],
    );
  }

  Widget _buildTournamentsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client.from('tournaments').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        final list = snapshot.data!;
        if (list.isEmpty) return const Center(child: Text('No tournaments created yet!', style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final t = list[i];
            final id = t['id'].toString();
            final title = t['title'] ?? 'Tournament';
            final game = t['game_name'] ?? 'BGMI';
            final status = (t['status'] ?? 'upcoming').toString().toUpperCase();
            final roomId = t['room_id'] ?? '';
            final roomPass = t['room_password'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ThemeService.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThemeService.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF00FF88).withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text(game, style: const TextStyle(color: Color(0xFF00FF88), fontSize: 11, fontWeight: FontWeight.bold))),
                      const Spacer(),
                      Text(status, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Prize: 🪙 ${t['prize_pool'] ?? 1000} | Fee: ${t['entry_fee'] ?? 'Free'} | Slots: ${t['max_slots'] ?? 25}', style: const TextStyle(color: Colors.grey, fontSize: 11.5)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: ThemeService.cardSecondary, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(child: Text(roomId.isNotEmpty ? 'Room ID: $roomId | Pass: $roomPass' : 'Room ID: Not Set Yet', style: const TextStyle(fontSize: 11.5, color: Colors.white))),
                        InkWell(onTap: () => _openRoomModal(id, roomId, roomPass), child: const Text('Set Room ⚙️', style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11.5))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_note, color: Color(0xFF38BDF8)), onPressed: () => _openCreateEditModal(existing: t)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4655)), onPressed: () => SupabaseService.client.from('tournaments').delete().eq('id', id)),
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

  Widget _buildWinnerProofsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client.from('tournament_claims').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        final proofs = snapshot.data!;
        if (proofs.isEmpty) return const Center(child: Text('No winner proof screenshots submitted yet.', style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: proofs.length,
          itemBuilder: (ctx, i) {
            final p = proofs[i];
            final claimId = p['id'].toString();
            final team = p['team_name'] ?? 'Team';
            final img = p['screenshot_url'] ?? '';
            final status = p['status'] ?? 'pending';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ThemeService.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeService.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(team, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                      const Spacer(),
                      Text(status.toUpperCase(), style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (img.isNotEmpty)
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: img, height: 130, width: double.infinity, fit: BoxFit.cover)),
                  const SizedBox(height: 8),
                  if (status == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectProofDialog(claimId),
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF4655)),
                            child: const Text('Reject Proof'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await SupabaseService.client.from('tournament_claims').update({'status': 'approved'}).eq('id', claimId);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
                            child: const Text('Approve Winner'),
                          ),
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

  void _openCreateEditModal({Map<String, dynamic>? existing}) {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final prizeCtrl = TextEditingController(text: existing?['prize_pool']?.toString() ?? '1000');
    final feeCtrl = TextEditingController(text: existing?['entry_fee']?.toString() ?? 'Free');
    String game = existing?['game_name'] ?? _gameList[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeService.card,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(existing == null ? 'Create Tournament 🏆' : 'Edit Tournament', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: game,
              dropdownColor: ThemeService.card,
              items: _gameList.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (val) => game = val!,
              decoration: const InputDecoration(labelText: 'Game'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: prizeCtrl, decoration: const InputDecoration(labelText: 'Prize (Coins)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: feeCtrl, decoration: const InputDecoration(labelText: 'Fee'))),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () async {
                final payload = {'title': titleCtrl.text.trim(), 'game_name': game, 'prize_pool': prizeCtrl.text.trim(), 'entry_fee': feeCtrl.text.trim(), 'status': 'upcoming'};
                if (existing == null) {
                  await SupabaseService.client.from('tournaments').insert(payload);
                } else {
                  await SupabaseService.client.from('tournaments').update(payload).eq('id', existing['id']);
                }
                if (mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black, minimumSize: const Size.fromHeight(42)),
              child: const Text('Save & Publish 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openRoomModal(String id, String curId, String curPass) {
    final idCtrl = TextEditingController(text: curId);
    final passCtrl = TextEditingController(text: curPass);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        title: const Text('Set Custom Room ID & Pass'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'Room ID')),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Room Password')),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await SupabaseService.client.from('tournaments').update({'room_id': idCtrl.text.trim(), 'room_password': passCtrl.text.trim()}).eq('id', id);
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _rejectProofDialog(String claimId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        title: const Text('Reject Proof Reason'),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(hintText: 'e.g. Blurry screenshot, UID mismatch')),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await SupabaseService.client.from('tournament_claims').update({'status': 'rejected', 'reject_reason': reasonCtrl.text.trim()}).eq('id', claimId);
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655)),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }
}

// ===================== OTHER CONTROLLERS & DELEGATES =====================
class _AdminBannerControlTab extends StatefulWidget {
  const _AdminBannerControlTab();
  @override
  State<_AdminBannerControlTab> createState() => _AdminBannerControlTabState();
}

class _AdminBannerControlTabState extends State<_AdminBannerControlTab> {
  final TextEditingController _titleController = TextEditingController(text: 'Upcoming Tournament! 🏆');
  final TextEditingController _messageController = TextEditingController(text: 'Date: 08:00 PM Tonight');
  bool _isActive = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Banner Title')),
          const SizedBox(height: 10),
          TextField(controller: _messageController, decoration: const InputDecoration(labelText: 'Banner Message')),
          const SizedBox(height: 14),
          SwitchListTile(title: const Text('Show Banner on Home Feed'), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () async {
              await SupabaseService.client.from('app_announcements').upsert({'id': 'home_banner', 'title': _titleController.text.trim(), 'message': _messageController.text.trim(), 'is_active': _isActive});
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Banner Published! 📢')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black, minimumSize: const Size.fromHeight(44)),
            child: const Text('Publish Banner', style: TextStyle(fontWeight: FontWeight.bold)),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: ThemeService.bg, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class _RankQueueItem {
  final GamerUser user;
  final UserGameRank game;
  final int gameIndex;
  _RankQueueItem({required this.user, required this.game, required this.gameIndex});
}

class _AdminUcRequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(child: Text('UC Requests Tab', style: TextStyle(color: Colors.white)));
}

class _AdminUcHistoryTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(child: Text('UC History Tab', style: TextStyle(color: Colors.white)));
}

class _AdminCoinsVaultTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(child: Text('Coins Vault Tab', style: TextStyle(color: Colors.white)));
}