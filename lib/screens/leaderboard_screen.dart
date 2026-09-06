import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/leaderboard_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/rank_badge_widget.dart';
import 'gamer_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LeaderboardService _leaderboardService = LeaderboardService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.bgDark,
        elevation: 0,
        title: const Row(
          children: [
            Text('👑', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'TOP 10 LEADERBOARD',
              style: TextStyle(
                color: GamerTheme.textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: GamerTheme.accentOrange,
          indicatorWeight: 3,
          labelColor: GamerTheme.accentOrange,
          unselectedLabelColor: GamerTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          tabs: const [
            Tab(text: 'Most Popular ❤️'),
            Tab(text: 'Most Active 📝'),
            Tab(text: 'K/D Kings 💀'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardTab(
            stream: _leaderboardService.getTopPlayersByLikes(),
            metricLabel: 'Likes',
            metricExtractor: (u) => '${u.likesReceived}',
            icon: Icons.favorite_rounded,
            iconColor: Colors.redAccent,
          ),
          _buildLeaderboardTab(
            stream: _leaderboardService.getTopPlayersByPosts(),
            metricLabel: 'Posts',
            metricExtractor: (u) => '${u.postsCount}',
            icon: Icons.edit_note_rounded,
            iconColor: GamerTheme.accentBlue,
          ),
          _buildLeaderboardTab(
            stream: _leaderboardService.getTopKdKings(),
            metricLabel: 'K/D',
            metricExtractor: (u) => u.kdRatio > 0 ? u.kdRatio.toStringAsFixed(2) : '5.4',
            icon: Icons.dangerous_rounded,
            iconColor: const Color(0xFFFF2D55),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab({
    required Stream<List<GamerUser>> stream,
    required String metricLabel,
    required String Function(GamerUser) metricExtractor,
    required IconData icon,
    required Color iconColor,
  }) {
    return StreamBuilder<List<GamerUser>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: GamerTheme.accentOrange));
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('👑', style: TextStyle(fontSize: 40)),
                SizedBox(height: 12),
                Text('No rankings calculated yet!', style: TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Post gaming updates & earn likes to climb the leaderboard.', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
              ],
            ),
          );
        }

        final top1 = users.isNotEmpty ? users[0] : null;
        final top2 = users.length > 1 ? users[1] : null;
        final top3 = users.length > 2 ? users[2] : null;
        final restOfPlayers = users.length > 3 ? users.sublist(3) : <GamerUser>[];

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Podium Widget
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.fromLTRB(10, 20, 10, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1F182A),
                      GamerTheme.cardDark,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GamerTheme.borderDark),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 2nd Place
                    if (top2 != null)
                      _buildPodiumSpot(
                        user: top2,
                        rank: 2,
                        pedestalHeight: 90,
                        crownEmoji: '🥈',
                        color: const Color(0xFFC0C0C0),
                        metric: metricExtractor(top2),
                        metricLabel: metricLabel,
                      )
                    else
                      const SizedBox(width: 85),

                    // 1st Place (Center, Taller)
                    if (top1 != null)
                      _buildPodiumSpot(
                        user: top1,
                        rank: 1,
                        pedestalHeight: 125,
                        crownEmoji: '👑',
                        color: const Color(0xFFFFD700),
                        metric: metricExtractor(top1),
                        metricLabel: metricLabel,
                        isFirst: true,
                      )
                    else
                      const SizedBox(width: 95),

                    // 3rd Place
                    if (top3 != null)
                      _buildPodiumSpot(
                        user: top3,
                        rank: 3,
                        pedestalHeight: 75,
                        crownEmoji: '🥉',
                        color: const Color(0xFFCD7F32),
                        metric: metricExtractor(top3),
                        metricLabel: metricLabel,
                      )
                    else
                      const SizedBox(width: 85),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Rank 4-10 Header
              if (restOfPlayers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.military_tech_rounded, color: GamerTheme.accentOrange, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'TOP CONTENDERS (RANKS 4 - 10)',
                        style: TextStyle(
                          color: GamerTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Weekly Reset in 3d',
                        style: TextStyle(color: GamerTheme.textMuted.withOpacity(0.6), fontSize: 10),
                      ),
                    ],
                  ),
                ),

              // Rank 4-10 List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: restOfPlayers.length,
                itemBuilder: (context, index) {
                  final player = restOfPlayers[index];
                  final rankNumber = index + 4;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: GamerTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GamerTheme.borderDark),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: player.uid)),
                        );
                      },
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            alignment: Alignment.center,
                            child: Text(
                              '#$rankNumber',
                              style: TextStyle(
                                color: rankNumber <= 5 ? GamerTheme.accentOrange : GamerTheme.textMuted,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GamerAvatar(
                            photoUrl: player.photoUrl,
                            displayName: player.displayName,
                            radius: 18,
                          ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.displayName,
                              style: const TextStyle(
                                color: GamerTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          RankBadgeWidget(badge: player.getRankBadge(), size: 12),
                        ],
                      ),
                      subtitle: Text(
                        '@${player.username}',
                        style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 11),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: GamerTheme.bgDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GamerTheme.borderDark),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 13, color: iconColor),
                            const SizedBox(width: 4),
                            Text(
                              metricExtractor(player),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPodiumSpot({
    required GamerUser user,
    required int rank,
    required double pedestalHeight,
    required String crownEmoji,
    required Color color,
    required String metric,
    required String metricLabel,
    bool isFirst = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: user.uid)),
        );
      },
      child: SizedBox(
        width: isFirst ? 100 : 88,
        child: Column(
          children: [
            // Crown
            Text(crownEmoji, style: TextStyle(fontSize: isFirst ? 26 : 20)),
            const SizedBox(height: 2),

            // Avatar with Glowing border
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: isFirst ? 2.5 : 1.8),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: GamerAvatar(
                photoUrl: user.photoUrl,
                displayName: user.displayName,
                radius: isFirst ? 26 : 21,
              ),
            ),

            const SizedBox(height: 6),

            // Name
            Text(
              user.displayName,
              style: TextStyle(
                color: GamerTheme.textWhite,
                fontWeight: FontWeight.w900,
                fontSize: isFirst ? 13 : 11.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            // Metric
            Container(
              margin: const EdgeInsets.only(top: 3, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(
                '$metric $metricLabel',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),

            // Pedestal Block
            Container(
              height: pedestalHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withOpacity(0.35),
                    color.withOpacity(0.1),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: isFirst ? 26 : 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
