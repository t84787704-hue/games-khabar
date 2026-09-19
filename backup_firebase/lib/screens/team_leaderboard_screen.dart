import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/gamer_theme.dart';
import '../models/team_ranking_model.dart';
import '../services/team_match_service.dart';

class TeamLeaderboardScreen extends StatefulWidget {
  const TeamLeaderboardScreen({super.key});

  @override
  State<TeamLeaderboardScreen> createState() => _TeamLeaderboardScreenState();
}

class _TeamLeaderboardScreenState extends State<TeamLeaderboardScreen> {
  final TeamMatchService _matchService = TeamMatchService();

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF8B949E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A29),
        elevation: 0,
        title: const Row(
          children: [
            Text('🏆', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'TOP TEAMS LEADERBOARD',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<TeamRanking>>(
        stream: _matchService.getTopTeamsLeaderboard(limit: 20),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
          }

          final teams = snapshot.data ?? [];

          if (teams.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F2E),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2A3447)),
                      ),
                      child: const Text('🛡️', style: TextStyle(fontSize: 40)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Ranked Teams Yet',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ٹیموں کے درمیان مقابلے کروائیں اور میچ جیتنے پر ٹیم کی رینکنگ بڑھے گی!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              final rank = index + 1;
              final rankColor = _getRankColor(rank);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rank <= 3 ? const Color(0xFF172033) : const Color(0xFF131A29),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: rank <= 3 ? rankColor.withOpacity(0.6) : const Color(0xFF2A3447),
                    width: rank <= 3 ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    // Rank Badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: rankColor.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: rankColor, width: 1.2),
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            color: rankColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Team Avatar / Logo
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF26334D),
                        border: Border.all(color: Colors.white24),
                        image: team.avatar.isNotEmpty
                            ? DecorationImage(image: NetworkImage(team.avatar), fit: BoxFit.cover)
                            : null,
                      ),
                      child: team.avatar.isEmpty
                          ? const Center(child: Icon(Icons.shield_rounded, color: Colors.white70, size: 22))
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // Team Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  team.teamName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (rank == 1) ...[
                                const SizedBox(width: 4),
                                const Text('👑', style: TextStyle(fontSize: 13)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Leader: ${team.leaderName}',
                            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'W: ${team.wins}  L: ${team.losses}  D: ${team.draws}',
                                style: const TextStyle(
                                  color: Color(0xFF00FF88),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Win Rate: ${team.winRate.toStringAsFixed(0)}%',
                                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Points Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFF6B00)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${team.points}',
                            style: const TextStyle(
                              color: Color(0xFFFF6B00),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            'PTS',
                            style: TextStyle(
                              color: Color(0xFFFF6B00),
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
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
        },
      ),
    );
  }
}
