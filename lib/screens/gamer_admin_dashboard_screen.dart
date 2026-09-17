import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/rank_badge_widget.dart';
import '../utils/admin_security.dart';
import '../services/demo_accounts_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/coin_reward_service.dart';

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

  // Multi-Game Rank Verification state
  final TextEditingController _rankSearchController = TextEditingController();
  String _rankSearchQuery = '';
  String _selectedRankGameFilter = 'All';
  bool _showOnlyPendingRanks = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _ensureSampleQueueExists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _rankSearchController.dispose();
    super.dispose();
  }

  /// Ensures 10 Pro Demo Accounts exist for testing & full app experience
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
              _buildReportsTab(),
              _buildCoinsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankVerifyTabTitle() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        int pendingCount = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            final rawGames = data?['games'];
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

  Widget _buildHeader() {
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? 'tufailm483@gmail.com';
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
  }

  Widget _buildStatsCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnap) {
        final totalUsers = userSnap.data?.docs.length ?? 0;
        int totalCoins = 0;
        if (userSnap.hasData) {
          for (final doc in userSnap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final raw = data['coins'] ?? data['gCoins'];
            totalCoins += (raw as num?)?.toInt() ?? 0;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('posts').snapshots(),
          builder: (context, postSnap) {
            final totalPosts = postSnap.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('reports').snapshots(),
              builder: (context, reportSnap) {
                final totalReports = reportSnap.data?.docs.length ?? 0;

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

  // ===================== TAB 1: USERS LIST =====================
  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _userSearchQuery = val.toLowerCase().trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search users by name, @username, or tag...',
              hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8B949E), size: 20),
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF8B949E), size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _userSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF10141D),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

        // Demo Accounts Management Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              // Seed 10 Pro Demo Accounts button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSeedingDemo ? null : _handleSeedDemoAccounts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88).withOpacity(0.12),
                    foregroundColor: const Color(0xFF00FF88),
                    side: const BorderSide(color: Color(0xFF00FF88), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSeedingDemo
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF88)),
                        )
                      : const Icon(Icons.group_add_rounded, size: 16),
                  label: Text(
                    _isSeedingDemo ? 'Seeding...' : 'Seed 10 Pro Demo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Delete All Demo Accounts button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isDeletingDemo ? null : _handleDeleteAllDemoAccounts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4655).withOpacity(0.12),
                    foregroundColor: const Color(0xFFFF4655),
                    side: const BorderSide(color: Color(0xFFFF4655), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isDeletingDemo
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF4655)),
                        )
                      : const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: Text(
                    _isDeletingDemo ? 'Deleting...' : 'Delete All Demo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              List<GamerUser> users = docs.map((d) => GamerUser.fromFirestore(d)).toList();

              // Ensure @fua is included if empty
              if (users.isEmpty) {
                users.add(
                  GamerUser(
                    uid: FirebaseAuth.instance.currentUser?.uid ?? 'sample_fua',
                    username: 'fua',
                    displayName: 'Fua',
                    coins: 400,
                    rank: 'Ace',
                    createdAt: DateTime.now().subtract(const Duration(days: 14)),
                  ),
                );
              }

              if (_userSearchQuery.isNotEmpty) {
                users = users.where((u) {
                  return u.displayName.toLowerCase().contains(_userSearchQuery) ||
                      u.username.toLowerCase().contains(_userSearchQuery) ||
                      u.uid.toLowerCase().contains(_userSearchQuery);
                }).toList();
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
              // Ban / Unban button
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
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    try {
      if (nextBanned) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isBanned': true,
          'bannedAt': FieldValue.serverTimestamp(),
          'bannedBy': adminUid,
          'bannedReason': 'Violating community guidelines or banned by admin',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isBanned': false,
          'bannedAt': null,
          'bannedReason': null,
          'bannedBy': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextBanned
                  ? 'User @${user.username} banned successfully'
                  : 'User @${user.username} unbanned successfully',
            ),
            backgroundColor: nextBanned ? const Color(0xFFFF4655) : const Color(0xFF00FF88),
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

  // ===================== TAB 2: RANK VERIFICATION TAB =====================
  Widget _buildRankVerifyTab() {
    return Column(
      children: [
        // Top Search & Filters
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xFF0B0F14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
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

              // Game Filter Chips & History Toggle
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final game in ['All', 'BGMI', 'Free Fire', 'PUBG Mobile', 'COD Mobile', 'Valorant']) ...[
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
                    // Pending vs All toggle
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

        // Requests List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
              }

              final docs = snapshot.data?.docs ?? [];
              final List<_RankQueueItem> allItems = [];

              for (final doc in docs) {
                final user = GamerUser.fromFirestore(doc);
                for (int i = 0; i < user.games.length; i++) {
                  final game = user.games[i];
                  allItems.add(_RankQueueItem(user: user, game: game, gameIndex: i));
                }
              }

              // Apply Filters
              final filtered = allItems.where((item) {
                // Pending filter
                if (_showOnlyPendingRanks && item.game.status != 'pending') {
                  return false;
                }

                // Game Name filter
                if (_selectedRankGameFilter != 'All' &&
                    item.game.gameName.toLowerCase() != _selectedRankGameFilter.toLowerCase()) {
                  return false;
                }

                // Search query
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

              // Sort: pending first, then by submittedAt desc
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
          // User Info & Status
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

          // Game Name + Game UID + Claimed Rank
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

          // Claimed Rank & Verified Rank Info
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

          // Screenshot Thumbnail (Tappable for full screen zoom)
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

          // Rejection reason banner if rejected
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

          // Approve / Reject Actions (when pending)
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

  int _getRankWeight(String rankName) {
    final r = rankName.toLowerCase().trim();
    if (r.contains('conqueror') || r.contains('radiant') || r.contains('grandmaster')) return 100;
    if (r.contains('legendary') || r.contains('immortal') || r.contains('heroic')) return 90;
    if (r.contains('ace') || r.contains('ascendant')) return 80;
    if (r.contains('crown') || r.contains('master')) return 70;
    if (r.contains('diamond')) return 60;
    if (r.contains('platinum') || r.contains('pro')) return 50;
    if (r.contains('gold') || r.contains('elite')) return 40;
    if (r.contains('silver') || r.contains('veteran')) return 30;
    if (r.contains('bronze') || r.contains('rookie') || r.contains('iron')) return 20;
    return 10;
  }

  Future<void> _approveRankVerification(_RankQueueItem item) async {
    try {
      final targetDocId = item.game.ownerUid.isNotEmpty ? item.game.ownerUid : item.user.uid;
      final updatedGames = List<UserGameRank>.from(item.user.games);
      final approvedGame = item.game.copyWith(
        isVerified: true,
        verifiedRank: item.game.claimedRank,
        status: 'approved',
        ownerUid: targetDocId,
      );
      updatedGames[item.gameIndex] = approvedGame;

      // Update user's main display rank if this approved rank has higher weight
      String newMainRank = item.user.rank;
      if (_getRankWeight(item.game.claimedRank) > _getRankWeight(item.user.rank) ||
          item.user.rank.toLowerCase() == 'bronze' ||
          item.user.rank.isEmpty) {
        newMainRank = item.game.claimedRank;
      }

      await FirebaseFirestore.instance.collection('users').doc(targetDocId).set({
        'games': updatedGames.map((g) => g.toMap()).toList(),
        'rank': newMainRank,
        'tier': newMainRank,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Approved ${item.game.gameName} rank (${item.game.claimedRank}) for @${item.user.username}!',
            ),
            backgroundColor: const Color(0xFF00FF88),
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
      final targetDocId = item.game.ownerUid.isNotEmpty ? item.game.ownerUid : item.user.uid;
      final updatedGames = List<UserGameRank>.from(item.user.games);
      final rejectedGame = item.game.copyWith(
        isVerified: false,
        status: 'rejected',
        rejectReason: reason.trim().isNotEmpty ? reason.trim() : 'Screenshot does not verify Game ID and Rank',
        ownerUid: targetDocId,
      );
      updatedGames[item.gameIndex] = rejectedGame;

      await FirebaseFirestore.instance.collection('users').doc(targetDocId).set({
        'games': updatedGames.map((g) => g.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected ${item.game.gameName} rank verification for @${item.user.username}'),
            backgroundColor: const Color(0xFFFF8A00),
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

  // ===================== TAB 3: BLUE TICK QUEUE =====================
  Widget _buildBlueTickRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final docs = snapshot.data?.docs ?? [];
        final allUsers = docs.map((d) => GamerUser.fromFirestore(d)).toList();

        // Requests that need review (pending and NOT yet approved)
        final bool isKiroApproved = allUsers.any(
            (u) => (u.username == 'kiro_yt' || u.uid == 'demo_01' || u.uid == 'sample_kiro_yt') && u.hasBlueTick);
        final bool isShadowApproved = allUsers.any(
            (u) => (u.username == 'shadownova' || u.username == 'shadow_nova' || u.uid == 'demo_02' || u.uid == 'sample_shadownova') && u.hasBlueTick);

        List<GamerUser> requests = allUsers
            .where((u) => !u.hasBlueTick && (u.verificationStatus == 'pending' || u.blueTickStatus == 'pending'))
            .toList();

        // Add Kiro_YT if not yet approved and not in requests list
        if (!isKiroApproved && !requests.any((u) => u.username == 'kiro_yt')) {
          final kiroUser = allUsers.firstWhere(
            (u) => u.username == 'kiro_yt' || u.uid == 'demo_01',
            orElse: () => const GamerUser(
              uid: 'demo_01',
              username: 'kiro_yt',
              displayName: 'Kiro_YT',
              rank: 'Conqueror',
              kdRatio: 5.4,
              gameId: '519283711',
              followersCount: 3420,
              verificationStatus: 'pending',
              blueTickStatus: 'pending',
            ),
          );
          requests.add(kiroUser);
        }

        // Add ShadowNova if not yet approved and not in requests list
        if (!isShadowApproved && !requests.any((u) => u.username == 'shadownova' || u.username == 'shadow_nova')) {
          final shadowUser = allUsers.firstWhere(
            (u) => u.username == 'shadownova' || u.username == 'shadow_nova' || u.uid == 'demo_02',
            orElse: () => const GamerUser(
              uid: 'demo_02',
              username: 'shadownova',
              displayName: 'ShadowNova',
              rank: 'Ace',
              kdRatio: 5.2,
              gameId: '588492019',
              followersCount: 3400,
              verificationStatus: 'pending',
              blueTickStatus: 'pending',
            ),
          );
          requests.add(shadowUser);
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
              // Reject Button
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
              // Approve Button
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
      final updateData = {
        'isBlueTickVerified': true,
        'blueTickVerified': true,
        'blueTickStatus': 'approved',
        'isVerifiedBlue': true,
        'isVerified': true,
        'verificationStatus': 'verified',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(updateData, SetOptions(merge: true));

      if (user.username == 'kiro_yt') {
        await FirebaseFirestore.instance.collection('users').doc('demo_01').set(updateData, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('users').doc('sample_kiro_yt').set(updateData, SetOptions(merge: true));
      } else if (user.username == 'shadownova' || user.username == 'shadow_nova') {
        await FirebaseFirestore.instance.collection('users').doc('demo_02').set(updateData, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('users').doc('sample_shadownova').set(updateData, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.verified, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Approved! Blue tick added to @${user.username}'),
              ],
            ),
            backgroundColor: const Color(0xFF1D9BF0),
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
      final rejectData = {
        'isBlueTickVerified': false,
        'blueTickVerified': false,
        'blueTickStatus': 'rejected',
        'isVerifiedBlue': false,
        'isVerified': false,
        'verificationStatus': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(rejectData, SetOptions(merge: true));

      if (user.username == 'kiro_yt') {
        await FirebaseFirestore.instance.collection('users').doc('demo_01').set(rejectData, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('users').doc('sample_kiro_yt').set(rejectData, SetOptions(merge: true));
      } else if (user.username == 'shadownova' || user.username == 'shadow_nova') {
        await FirebaseFirestore.instance.collection('users').doc('demo_02').set(rejectData, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('users').doc('sample_shadownova').set(rejectData, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected verification for @${user.username}'),
            backgroundColor: const Color(0xFFFF4655),
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

  // ===================== TAB 3: POSTS MODERATION =====================
  Widget _buildPostsModerationTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00FF88), size: 48),
                SizedBox(height: 12),
                Text('No posts found to moderate', style: TextStyle(color: Color(0xFF8B949E))),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final postId = doc.id;
            final text = data['text'] ?? data['title'] ?? 'Gaming Post';
            final author = data['displayName'] ?? data['username'] ?? 'Player';
            final userId = data['userId'] ?? '';

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        author,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4655), size: 20),
                        tooltip: 'Delete Post',
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post deleted by admin'), backgroundColor: Color(0xFFFF4655)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Post ID: $postId', style: const TextStyle(color: Color(0xFF6E7681), fontSize: 10, fontFamily: 'monospace')),
                      const Spacer(),
                      if (userId.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('users').doc(userId).set({
                              'isBanned': true,
                            }, SetOptions(merge: true));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Author $author banned'), backgroundColor: const Color(0xFFFF4655)),
                              );
                            }
                          },
                          child: const Text('Ban Author', style: TextStyle(color: Color(0xFFFF4655), fontSize: 11)),
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

  // ===================== TAB 4: REPORTS =====================
  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF00FF88), size: 40),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Community Safe • 0 Open Reports',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No offensive content or active player violations reported.',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              color: const Color(0xFF10141D),
              child: ListTile(
                title: Text(data['reason'] ?? 'Report', style: const TextStyle(color: Colors.white)),
                subtitle: Text('Target: ${data['targetId'] ?? 'N/A'}', style: const TextStyle(color: Color(0xFF8B949E))),
                trailing: IconButton(
                  icon: const Icon(Icons.check, color: Color(0xFF00FF88)),
                  onPressed: () => doc.reference.delete(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===================== TAB 5: COINS =====================
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

  /// Searches for a user in Firestore across:
  /// 1. Document ID (UID)
  /// 2. 'uid' field
  /// 3. 'username' field (case-insensitive, strips '@')
  /// 4. 'tag' field
  /// 5. 'email' field
  /// 6. Comprehensive in-memory fallback scan across users collection
  Future<Map<String, dynamic>?> _findUser(String input) async {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    final firestore = FirebaseFirestore.instance;

    // 1. Direct document ID (UID) lookup
    try {
      final docSnap = await firestore.collection('users').doc(raw).get();
      if (docSnap.exists && docSnap.data() != null) {
        final d = Map<String, dynamic>.from(docSnap.data()!);
        d['docId'] = docSnap.id;
        return d;
      }
    } catch (_) {}

    // 2. Query by 'uid' field
    try {
      final qUid = await firestore.collection('users').where('uid', isEqualTo: raw).limit(1).get();
      if (qUid.docs.isNotEmpty) {
        final d = Map<String, dynamic>.from(qUid.docs.first.data());
        d['docId'] = qUid.docs.first.id;
        return d;
      }
    } catch (_) {}

    final clean = raw.toLowerCase().replaceAll('@', '').trim();

    // 3. Query by 'username'
    try {
      final qUser = await firestore.collection('users').where('username', isEqualTo: clean).limit(1).get();
      if (qUser.docs.isNotEmpty) {
        final d = Map<String, dynamic>.from(qUser.docs.first.data());
        d['docId'] = qUser.docs.first.id;
        return d;
      }
    } catch (_) {}

    // 4. Query by 'tag'
    try {
      final qTag = await firestore.collection('users').where('tag', isEqualTo: clean).limit(1).get();
      if (qTag.docs.isNotEmpty) {
        final d = Map<String, dynamic>.from(qTag.docs.first.data());
        d['docId'] = qTag.docs.first.id;
        return d;
      }
    } catch (_) {}

    // 5. Query by 'email' (lowercase)
    final cleanEmail = raw.toLowerCase().trim();
    try {
      final qEmail = await firestore.collection('users').where('email', isEqualTo: cleanEmail).limit(1).get();
      if (qEmail.docs.isNotEmpty) {
        final d = Map<String, dynamic>.from(qEmail.docs.first.data());
        d['docId'] = qEmail.docs.first.id;
        return d;
      }
    } catch (_) {}

    // 6. Query by 'email' (raw)
    try {
      final qEmailRaw = await firestore.collection('users').where('email', isEqualTo: raw).limit(1).get();
      if (qEmailRaw.docs.isNotEmpty) {
        final d = Map<String, dynamic>.from(qEmailRaw.docs.first.data());
        d['docId'] = qEmailRaw.docs.first.id;
        return d;
      }
    } catch (_) {}

    // 7. Comprehensive in-memory fallback scan across all users
    try {
      final allUsersSnap = await firestore.collection('users').limit(200).get();
      for (final doc in allUsersSnap.docs) {
        final data = doc.data();
        final docId = doc.id;
        final uUid = (data['uid'] ?? docId).toString().trim();
        final uName = (data['username'] ?? data['tag'] ?? '').toString().toLowerCase().trim();
        final uEmail = (data['email'] ?? '').toString().toLowerCase().trim();
        final uDisplay = (data['displayName'] ?? data['bgmiName'] ?? '').toString().toLowerCase().trim();
        final inGameId = (data['gameId'] ?? data['bgmiUid'] ?? '').toString().trim();

        if (docId == raw ||
            uUid == raw ||
            uName == clean ||
            uEmail == cleanEmail ||
            uDisplay == clean ||
            inGameId == raw ||
            (clean.length >= 3 && (uName.contains(clean) || uEmail.contains(clean) || uDisplay.contains(clean)))) {
          final d = Map<String, dynamic>.from(data);
          d['docId'] = docId;
          return d;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _handleSearch() async {
    final target = _targetController.text.trim();
    if (target.isEmpty) {
      setState(() {
        _errorMessage = 'براہ کرم تلاش کے لیے Username، UID یا Email درج کریں';
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
        _errorMessage = 'صارف نہیں ملا! براہ کرم درست Username، UID یا Email درج کریں۔';
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
      setState(() => _errorMessage = 'براہ کرم Target Username، UID یا Email درج کریں');
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
      // 1. Resolve user if not yet resolved or if query input changed
      Map<String, dynamic>? user = _foundUser;
      String? docId = _foundDocId;

      if (user == null || docId == null) {
        user = await _findUser(target);
        if (user != null) {
          docId = user['docId'] as String?;
        }
      }

      // If user still not found: show RED ERROR MESSAGE and STOP!
      if (user == null || docId == null || docId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isAwarding = false;
          _foundUser = null;
          _foundDocId = null;
          _errorMessage = 'صارف نہیں ملا! براہ کرم درست Username، UID یا Email درج کریں۔';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'صارف نہیں ملا! سکے نہیں بھیجے جا سکے۔',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFFFF4655),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final targetDocId = docId;
      final targetDisplayName = (user['displayName'] ?? user['bgmiName'] ?? user['username'] ?? user['tag'] ?? 'صارف').toString();
      final targetUsername = (user['username'] ?? user['tag'] ?? '').toString();

      final firestore = FirebaseFirestore.instance;
      final currentAdmin = FirebaseAuth.instance.currentUser;
      final adminEmail = currentAdmin?.email ?? 'Admin';
      final adminUid = currentAdmin?.uid ?? 'admin';

      // 2. Atomic updates across users, wallets, and coin_wallets
      final batch = firestore.batch();

      // users collection update (immediate database save)
      final userRef = firestore.collection('users').doc(targetDocId);
      batch.set(userRef, {
        'coins': FieldValue.increment(amount),
        'gCoins': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastRewardAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // wallets collection update
      final walletRef = firestore.collection('wallets').doc(targetDocId);
      batch.set(walletRef, {
        'coins': FieldValue.increment(amount),
        'gCoins': FieldValue.increment(amount),
        'userId': targetDocId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // coin_wallets collection update
      final coinWalletRef = firestore.collection('coin_wallets').doc(targetDocId);
      batch.set(coinWalletRef, {
        'coins': FieldValue.increment(amount),
        'gCoins': FieldValue.increment(amount),
        'lifetimeEarned': FieldValue.increment(amount),
        'userId': targetDocId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Write transaction to both 'transactions' & 'coin_transactions' collections
      // Required log format: "Admin ne [تعداد] coins دیے" with timestamp
      final txRef = firestore.collection('transactions').doc();
      final String txId = txRef.id;
      final String formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      final txData = {
        'id': txId,
        'userId': targetDocId,
        'amount': amount,
        'type': 'admin_grant',
        'title': 'Admin Award 🪙',
        'description': 'Admin ne $amount coins diye',
        'status': 'completed',
        'adminUid': adminUid,
        'adminEmail': adminEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'date': formattedDate,
      };

      batch.set(txRef, txData);
      batch.set(firestore.collection('coin_transactions').doc(txId), txData);

      await batch.commit();

      // 4. Update local in-memory state if this device is the user
      final currentGamer = GamerAuthService().currentGamer;
      if (currentGamer != null && (currentGamer.uid == targetDocId || targetDocId.isEmpty)) {
        final newBal = currentGamer.coins + amount;
        GamerAuthService().currentGamerNotifier.value = currentGamer.copyWith(coins: newBal);
        CoinRewardService().coinsNotifier.value = newBal;
      }

      // 5. Refresh user state in preview
      final updatedSnap = await firestore.collection('users').doc(targetDocId).get();
      if (updatedSnap.exists && updatedSnap.data() != null) {
        final d = Map<String, dynamic>.from(updatedSnap.data()!);
        d['docId'] = updatedSnap.id;
        user = d;
      }

      final successText = 'کامیابی! $targetDisplayName کو $amount سکے بھیج دیے گئے';

      if (!mounted) return;
      setState(() {
        _isAwarding = false;
        _foundUser = user;
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
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13.5),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خرابی: $e'), backgroundColor: const Color(0xFFFF4655)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
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
                  child: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 32),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gamers ID Coins Vault',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'صارف کو Username، UID یا Email سے تلاش کر کے سکے بھیجیں',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Target Username or UID input field with search button
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
                    prefixIcon: const Icon(Icons.person_search_rounded, color: Color(0xFF38BDF8)),
                    suffixIcon: _targetController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded, size: 20),
                            Text('تلاش کریں', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ],
          ),

          // Found User Preview Card
          if (_foundUser != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2319),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  GamerAvatar(
                    photoUrl: (_foundUser!['photoUrl'] ?? _foundUser!['avatar'] ?? '').toString(),
                    radius: 22,
                    frameId: (_foundUser!['activeFrame'] ?? '').toString(),
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
                                (_foundUser!['displayName'] ?? _foundUser!['bgmiName'] ?? _foundUser!['username'] ?? 'User').toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF88).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 12),
                                  SizedBox(width: 3),
                                  Text(
                                    'صارف مل گیا',
                                    style: TextStyle(color: Color(0xFF00FF88), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${_foundUser!['username'] ?? _foundUser!['tag'] ?? ''} • ${_foundUser!['email'] ?? _foundDocId ?? ''}',
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'موجودہ بیلنس: ',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            Text(
                              '${(_foundUser!['coins'] ?? _foundUser!['gCoins'] ?? 0)} 🪙',
                              style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 12),
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

          // Coins Amount Input Field
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Coins Amount',
              labelStyle: const TextStyle(color: Color(0xFF8B949E)),
              prefixIcon: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700)),
              helperText: 'کوئی حد نہیں — ایڈمن جتنی چاہے سکے بھیج سکتا ہے',
              helperStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
              filled: true,
              fillColor: const Color(0xFF10141D),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFD700)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Quick Amount Selection Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [100, 500, 1000, 5000, 10000, 50000].map((amt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(
                      '+$amt 🪙',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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

          // Red Error Message Banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2D1216),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4655), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFFF7080), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Green Success Message Banner
          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0E281C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(color: Color(0xFF80FFC0), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // "Award Coins Now" Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isAwarding ? null : _awardCoins,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF554400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isAwarding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _isAwarding ? 'سکے بھیجے جا رہے ہیں...' : 'Award Coins Now',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Live Recent Coin Grants History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Coin Awards History',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.history_rounded, color: Color(0xFFFFD700), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Live Logs',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('type', isEqualTo: 'admin_grant')
                .limit(10)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Error loading history: ${snap.error}', style: const TextStyle(color: Colors.red, fontSize: 12));
              }
              final docs = snap.data?.docs ?? [];
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

              // Sort locally in case composite index is not built
              final sorted = List<QueryDocumentSnapshot>.from(docs);
              sorted.sort((a, b) {
                final da = a.data() as Map<String, dynamic>;
                final db = b.data() as Map<String, dynamic>;
                final ta = da['createdAt'] as Timestamp? ?? Timestamp.now();
                final tb = db['createdAt'] as Timestamp? ?? Timestamp.now();
                return tb.compareTo(ta);
              });

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final data = sorted[index].data() as Map<String, dynamic>;
                  final amount = (data['amount'] as num?)?.toInt() ?? 0;
                  final description = data['description'] ?? 'Admin ne $amount coins diye';
                  final date = data['date']?.toString() ?? '';
                  final targetUserId = (data['userId'] ?? '').toString();

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          child: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                description,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'UID: $targetUserId ${date.isNotEmpty ? '• $date' : ''}',
                                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10.5),
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
            // Reject button
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
            // Approve button
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

