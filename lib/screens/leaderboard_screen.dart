import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/supabase_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _topTeams = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Points aur Wins ke hisaab se descending order mein fetch karein
      final res = await SupabaseService.client
          .from('teams')
          .select('id, name, tag, wins, points')
          .order('points', ascending: false)
          .order('wins', ascending: false)
          .limit(100);

      if (mounted) {
        final List<Map<String, dynamic>> loadedTeams =
            List<Map<String, dynamic>>.from(res as List);

        // Filter: Sirf woh teams jinke paas points > 0 ya wins > 0 hon
        final filteredTeams = loadedTeams.where((t) {
          final pts = (t['points'] as num?)?.toInt() ?? 0;
          final w = (t['wins'] as num?)?.toInt() ?? 0;
          return pts > 0 || w > 0;
        }).toList();

        // Local double-check sort for accurate ranking
        filteredTeams.sort((a, b) {
          final ptsA = (a['points'] as num?)?.toInt() ?? 0;
          final ptsB = (b['points'] as num?)?.toInt() ?? 0;
          final comp = ptsB.compareTo(ptsA);
          if (comp != 0) return comp;

          final winsA = (a['wins'] as num?)?.toInt() ?? 0;
          final winsB = (b['wins'] as num?)?.toInt() ?? 0;
          return winsB.compareTo(winsA);
        });

        setState(() {
          _topTeams = filteredTeams;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildRankBadge(int rank) {
    Color rankColor;
    String rankEmoji = '';

    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankEmoji = '🥇';
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankEmoji = '🥈';
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankEmoji = '🥉';
    } else {
      rankColor = const Color(0xFF8B949E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: rank <= 3 ? rankColor.withOpacity(0.15) : const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: rank <= 3 ? rankColor.withOpacity(0.5) : const Color(0xFF2A3447),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank <= 3) ...[
            Text(
              rankEmoji,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '#$rank',
            style: TextStyle(
              color: rankColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A29),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'leaderboard_top_teams_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF00FF88),
        backgroundColor: const Color(0xFF131A29),
        onRefresh: _fetchLeaderboard,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FF88)),
              )
            : _errorMessage != null
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4655), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'err_failed_load_leaderboard'.tr(args: [_errorMessage ?? '']),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchLeaderboard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FF88),
                                foregroundColor: Colors.black,
                              ),
                              child: Text('try_again'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : _topTeams.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
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
                                  child: const Text('🏆', style: TextStyle(fontSize: 40)),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'no_ranked_teams_yet'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'no_ranked_teams_sub'.tr(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _topTeams.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: Color(0xFF1B2436),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final team = _topTeams[index];
                          final rank = index + 1;
                          final teamName = team['name']?.toString() ?? 'label_team'.tr();
                          final tag = team['tag']?.toString() ?? '';
                          final displayName = tag.isNotEmpty ? '$teamName [$tag]' : teamName;
                          final wins = (team['wins'] as num?)?.toInt() ?? 0;
                          final points = (team['points'] as num?)?.toInt() ?? 0;

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: Row(
                              children: [
                                _buildRankBadge(rank),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$wins Wins',
                                          style: const TextStyle(
                                            color: Color(0xFF00FF88),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('🏆', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B00).withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFFF6B00).withOpacity(0.4),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('🪙', style: TextStyle(fontSize: 10)),
                                          const SizedBox(width: 3),
                                          Text(
                                            '$points Pts',
                                            style: const TextStyle(
                                              color: Color(0xFFFF6B00),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
