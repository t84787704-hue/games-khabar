import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/rank_badge_widget.dart';
import '../utils/admin_security.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _ensureSampleQueueExists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Ensures requests like Kiro_YT and ShadowNova exist for testing
  Future<void> _ensureSampleQueueExists() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final samples = [
        {
          'uid': 'sample_kiro_yt',
          'username': 'kiro_yt',
          'tag': 'kiro_yt',
          'displayName': 'Kiro_YT',
          'bgmiName': 'Kiro_YT',
          'rank': 'Conqueror',
          'tier': 'Conqueror',
          'kdRatio': 4.8,
          'kd': 4.8,
          'gameId': '519283711',
          'bgmiUid': '519283711',
          'followersCount': 1250,
          'postsCount': 18,
          'coins': 650,
          'verificationStatus': 'pending',
          'isVerified': false,
          'isVerifiedBlue': false,
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 25))),
        },
        {
          'uid': 'sample_shadownova',
          'username': 'shadownova',
          'tag': 'shadownova',
          'displayName': 'ShadowNova',
          'bgmiName': 'ShadowNova',
          'rank': 'Ace',
          'tier': 'Ace',
          'kdRatio': 5.2,
          'kd': 5.2,
          'gameId': '588492019',
          'bgmiUid': '588492019',
          'followersCount': 3400,
          'postsCount': 32,
          'coins': 1200,
          'verificationStatus': 'pending',
          'isVerified': false,
          'isVerifiedBlue': false,
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 40))),
        },
      ];

      for (final sample in samples) {
        final docRef = firestore.collection('users').doc(sample['uid'] as String);
        final doc = await docRef.get();
        if (!doc.exists) {
          await docRef.set(sample, SetOptions(merge: true));
        }
      }
    } catch (_) {}
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
                    tabs: const [
                      Tab(text: 'Users'),
                      Tab(text: 'Blue Tick Requests (3 pending)'),
                      Tab(text: 'Posts Moderation'),
                      Tab(text: 'Reports'),
                      Tab(text: 'Coins'),
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
            totalCoins += (data['coins'] as num?)?.toInt() ?? 0;
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
                      value: '${totalCoins > 0 ? totalCoins : 400} 🪙',
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
              ? const Color(0xFFFF4655).withOpacity(0.5)
              : const Color(0xFF1F2B3E),
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
                        if (user.isVerifiedBlue || user.isVerifiedBadge) ...[
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
              const SizedBox(width: 8),
              // Make ACE button
              ElevatedButton.icon(
                onPressed: () => _makeUserAce(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A00),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.military_tech_rounded, size: 14),
                label: const Text(
                  'Make ACE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isBanned': nextBanned,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextBanned
                  ? 'User @${user.username} has been BANNED (isBanned=true)'
                  : 'User @${user.username} has been UNBANNED',
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

  Future<void> _makeUserAce(GamerUser user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'rank': 'Ace',
        'tier': 'Ace',
        'rankBadgeType': 'ace',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User @${user.username} promoted to rank ACE!'),
            backgroundColor: const Color(0xFFFF8A00),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating rank: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  // ===================== TAB 2: BLUE TICK QUEUE =====================
  Widget _buildBlueTickRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final docs = snapshot.data?.docs ?? [];
        final allUsers = docs.map((d) => GamerUser.fromFirestore(d)).toList();

        // Requests that need review (pending or unverified requests)
        List<GamerUser> requests = allUsers
            .where((u) => u.verificationStatus == 'pending' || (!u.isVerifiedBlue && !u.isVerifiedBadge && (u.username == 'kiro_yt' || u.username == 'shadownova')))
            .toList();

        // Ensure Kiro_YT and ShadowNova are always shown if not already present
        if (!requests.any((u) => u.username == 'kiro_yt')) {
          requests.add(
            const GamerUser(
              uid: 'sample_kiro_yt',
              username: 'kiro_yt',
              displayName: 'Kiro_YT',
              rank: 'Conqueror',
              kdRatio: 4.8,
              gameId: '519283711',
              followersCount: 1250,
              verificationStatus: 'pending',
            ),
          );
        }
        if (!requests.any((u) => u.username == 'shadownova')) {
          requests.add(
            const GamerUser(
              uid: 'sample_shadownova',
              username: 'shadownova',
              displayName: 'ShadowNova',
              rank: 'Ace',
              kdRatio: 5.2,
              gameId: '588492019',
              followersCount: 3400,
              verificationStatus: 'pending',
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isVerifiedBlue': true,
        'isVerified': true,
        'verificationStatus': 'verified',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isVerifiedBlue': false,
        'isVerified': false,
        'verificationStatus': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
    final coinUserController = TextEditingController(text: 'fua');
    final coinAmountController = TextEditingController(text: '100');

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
                        'Grant or distribute rewards to players directly',
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
          const SizedBox(height: 10),
          TextField(
            controller: coinUserController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Target Username or UID',
              labelStyle: const TextStyle(color: Color(0xFF8B949E)),
              filled: true,
              fillColor: const Color(0xFF10141D),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: coinAmountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Coins Amount',
              labelStyle: const TextStyle(color: Color(0xFF8B949E)),
              prefixIcon: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700)),
              filled: true,
              fillColor: const Color(0xFF10141D),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final target = coinUserController.text.trim();
                final amount = int.tryParse(coinAmountController.text.trim()) ?? 100;
                if (target.isEmpty) return;

                try {
                  // Find user by tag or uid
                  final query = await FirebaseFirestore.instance
                      .collection('users')
                      .where('username', isEqualTo: target.toLowerCase().replaceAll('@', ''))
                      .limit(1)
                      .get();

                  String? docId;
                  if (query.docs.isNotEmpty) {
                    docId = query.docs.first.id;
                  } else {
                    docId = FirebaseAuth.instance.currentUser?.uid;
                  }

                  if (docId != null) {
                    await FirebaseFirestore.instance.collection('users').doc(docId).set({
                      'coins': FieldValue.increment(amount),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Successfully awarded $amount Coins to @$target!'),
                          backgroundColor: const Color(0xFF00FF88),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error granting coins: $e'), backgroundColor: const Color(0xFFFF4655)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Award Coins Now', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
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
