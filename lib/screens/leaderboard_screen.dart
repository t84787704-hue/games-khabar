import 'package:flutter/material.dart';
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

      final res = await SupabaseService.client
          .from('teams')
          .select('id, name, tag, wins')
          .gt('wins', 0)
          .order('wins', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _topTeams = List<Map<String, dynamic>>.from(res as List);
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
      width: 44,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: rank <= 3 ? rankColor.withOpacity(0.15) : const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rank <= 3 ? rankColor.withOpacity(0.5) : const Color(0xFF2A3447),
        ),
      ),
      child: rank <= 3
          ? Text(
              '$rankEmoji #$rank',
              style: TextStyle(
                color: rankColor,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            )
          : Text(
              '#$rank',
              style: TextStyle(
                color: rankColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
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
        title: const Text(
          '🏆 TOP 100 TEAMS - Most Wins',
          style: TextStyle(
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
                              'Failed to load leaderboard\n$_errorMessage',
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
                              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                const Text(
                                  'No Ranked Teams Yet',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'میچز جیت کر ونس حاصل کریں اور ٹاپ 100 لیڈر بورڈ میں شامل ہوں!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
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
                          final teamName = team['name']?.toString() ?? 'Team';
                          final tag = team['tag']?.toString() ?? '';
                          final displayName = tag.isNotEmpty ? '$teamName [$tag]' : teamName;
                          final wins = (team['wins'] as num?)?.toInt() ?? 0;

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: Row(
                              children: [
                                // #Rank (Top 3 gold/silver/bronze)
                                _buildRankBadge(rank),
                                const SizedBox(width: 14),

                                // Team Name [Tag] (e.g. J17 [TAG])
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

                                // Spacer
                                const SizedBox(width: 10),

                                // "X Wins" (e.g. "3 Wins") bold green right side pe
                                Text(
                                  '$wins Wins',
                                  style: const TextStyle(
                                    color: Color(0xFF00FF88),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
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
