import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/team_model.dart';
import '../services/supabase_service.dart';
import '../services/team_service.dart';
import '../services/theme_service.dart';
import 'team_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final TeamService _teamService = TeamService();

  bool _isLoading = true;
  int _selectedMode = 0; // 0: Per-Game Weekly Team Coins, 1: All-Time Team Points
  String _selectedGame = TeamService.supportedGames.first;

  List<Map<String, dynamic>> _weeklyGameLeaderboard = [];
  List<Map<String, dynamic>> _allTimeTopTeams = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _teamService.checkAndDistributeWeeklyGameRewards();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final weeklyFuture = _teamService.getGameWeeklyLeaderboard(_selectedGame);
      final allTimeFuture = SupabaseService.client
          .from('teams')
          .select('id, name, tag, game, wins, points')
          .order('points', ascending: false)
          .order('wins', ascending: false)
          .limit(100);

      final results = await Future.wait([weeklyFuture, allTimeFuture]);
      final weeklyList = results[0] as List<Map<String, dynamic>>;
      final allTimeRes = results[1] as List;

      if (mounted) {
        final List<Map<String, dynamic>> loadedTeams =
            List<Map<String, dynamic>>.from(allTimeRes);

        final filteredTeams = loadedTeams.where((t) {
          final pts = (t['points'] as num?)?.toInt() ?? 0;
          final w = (t['wins'] as num?)?.toInt() ?? 0;
          return pts > 0 || w > 0;
        }).toList();

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
          _weeklyGameLeaderboard = weeklyList;
          _allTimeTopTeams = filteredTeams;
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

  Future<void> _onGameSelected(String game) async {
    if (_selectedGame == game) return;
    setState(() {
      _selectedGame = game;
      _isLoading = true;
    });
    try {
      final weeklyList = await _teamService.getGameWeeklyLeaderboard(game);
      if (mounted) {
        setState(() {
          _weeklyGameLeaderboard = weeklyList;
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
      rankColor = ThemeService.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: rank <= 3 ? rankColor.withOpacity(0.15) : ThemeService.cardSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: rank <= 3 ? rankColor.withOpacity(0.5) : ThemeService.border,
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

  Widget _buildModeSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMode = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedMode == 0
                      ? const Color(0xFF00FF88).withOpacity(0.16)
                      : ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedMode == 0
                        ? const Color(0xFF00FF88)
                        : ThemeService.border,
                    width: _selectedMode == 0 ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      size: 16,
                      color: _selectedMode == 0
                          ? const Color(0xFF00FF88)
                          : ThemeService.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Weekly Team Coins',
                      style: TextStyle(
                        color: _selectedMode == 0
                            ? const Color(0xFF00FF88)
                            : ThemeService.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMode = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedMode == 1
                      ? const Color(0xFFFFD700).withOpacity(0.16)
                      : ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedMode == 1
                        ? const Color(0xFFFFD700)
                        : ThemeService.border,
                    width: _selectedMode == 1 ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 16,
                      color: _selectedMode == 1
                          ? const Color(0xFFFFD700)
                          : ThemeService.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'All-Time Points',
                      style: TextStyle(
                        color: _selectedMode == 1
                            ? const Color(0xFFFFD700)
                            : ThemeService.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameSelectorBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: TeamService.supportedGames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final game = TeamService.supportedGames[index];
          final isSelected = _selectedGame == game;
          return GestureDetector(
            onTap: () => _onGameSelected(game),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00FF88)
                    : ThemeService.cardSecondary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00FF88)
                      : ThemeService.border,
                ),
              ),
              child: Center(
                child: Text(
                  game,
                  style: TextStyle(
                    color: isSelected ? Colors.black : ThemeService.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayPolicyWeeklyBanner() {
    final cycleLabel = TeamService.getWeekRangeLabel();
    final pool = TeamService.weeklyGameRewardPkr;
    final currencyLabel = TeamService.getGameCurrencyLabel(_selectedGame);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThemeService.cardSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ThemeService.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: Color(0xFF00FF88), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$_selectedGame Weekly Cycle ($cycleLabel UTC)',
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFFFD700).withOpacity(0.45)),
                  ),
                  child: Text(
                    '#1 Prize: ${NumberFormat('#,###').format(pool)} PKR',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Coins earned from ads or bonuses go into each player\'s Personal Wallet first. Members manually contribute coins from their Personal Wallet to their team (up to 4 members). At the end of the 7-day cycle, the #1 team in $_selectedGame receives ${NumberFormat('#,###').format(pool)} PKR equivalent in $currencyLabel divided equally among its active members. Weekly team scores reset to 0 each new week. Public gaming handles & coin totals only.',
              style: TextStyle(
                color: ThemeService.textSecondary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTeamList() {
    if (_weeklyGameLeaderboard.isEmpty) {
      return Center(
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
                    color: ThemeService.cardSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: ThemeService.border),
                  ),
                  child: const Text('🏆', style: TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 16),
                Text(
                  'No $_selectedGame Teams Yet',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create or join a 4-member $_selectedGame team and contribute coins from your Personal Wallet to compete for the 1,500 PKR equivalent #1 Team Prize.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _weeklyGameLeaderboard.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = _weeklyGameLeaderboard[index];
        final TeamModel team = entry['team'] as TeamModel;
        final int rank = (entry['rank'] as num?)?.toInt() ?? (index + 1);
        final int memberCount =
            ((entry['memberCount'] as num?)?.toInt() ?? team.memberCount)
                .clamp(1, TeamModel.maxMembers);
        final int equalShare = TeamService.getEqualPkrShare(memberCount);
        final Map<String, int> memberCoins =
            (entry['memberCoins'] as Map<String, int>?) ?? const {};

        int computedTeamCoins = 0;
        for (final uid in team.cappedMembers) {
          final cleanUid = uid.trim();
          final lowerUid = cleanUid.toLowerCase();
          final uuidLower = SupabaseService.toUuid(cleanUid).toLowerCase();
          final c = memberCoins[cleanUid] ??
              memberCoins[lowerUid] ??
              memberCoins[uuidLower] ??
              0;
          computedTeamCoins += c;
        }
        final int weeklyCoins = team.cappedMembers.isNotEmpty
            ? computedTeamCoins
            : ((entry['weeklyCoins'] as num?)?.toInt() ?? 0);

        final String displayGameLabel = TeamService.displayGameLabel(team.game);
        final sanitizedName =
            TeamModel.sanitizePublicHandle(team.name, fallback: 'Team');
        final displayName = team.tag.trim().isNotEmpty
            ? '$sanitizedName [${team.tag}]'
            : sanitizedName;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamProfileScreen(
                  teamId: team.id,
                  team: team,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThemeService.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: rank == 1
                    ? const Color(0xFFFFD700).withOpacity(0.55)
                    : ThemeService.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildRankBadge(rank),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$displayGameLabel • $memberCount/${TeamModel.maxMembers} Members',
                            style: TextStyle(
                              color: ThemeService.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              '${NumberFormat('#,###').format(weeklyCoins)} Coins',
                              style: const TextStyle(
                                color: Color(0xFF00FF88),
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        if (rank == 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withOpacity(0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#1 Equal Split: $equalShare PKR / member',
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (team.cappedMembers.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: team.cappedMembers.map((uid) {
                      final cleanUid = uid.trim();
                      final lowerUid = cleanUid.toLowerCase();
                      final uuidLower = SupabaseService.toUuid(cleanUid).toLowerCase();
                      final rawHandle = team.memberNames[cleanUid] ??
                          team.memberNames[lowerUid] ??
                          team.memberNames[uuidLower] ??
                          (team.isLeader(cleanUid) ? team.leaderName : 'Gamer');
                      final handle = TeamModel.sanitizePublicHandle(
                        rawHandle,
                        fallback: team.isLeader(cleanUid) ? 'Leader' : 'Gamer',
                      );
                      final contributed = memberCoins[cleanUid] ??
                          memberCoins[lowerUid] ??
                          memberCoins[uuidLower] ??
                          0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThemeService.cardSecondary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ThemeService.border),
                        ),
                        child: Text(
                          '@$handle: +$contributed',
                          style: TextStyle(
                            color: ThemeService.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllTimeList() {
    if (_allTimeTopTeams.isEmpty) {
      return Center(
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
                    color: ThemeService.cardSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: ThemeService.border),
                  ),
                  child: const Text('🏆', style: TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 16),
                Text(
                  'no_ranked_teams_yet'.tr(),
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'no_ranked_teams_sub'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _allTimeTopTeams.length,
      separatorBuilder: (context, index) => Divider(
        color: ThemeService.border,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final team = _allTimeTopTeams[index];
        final rank = index + 1;
        final rawTeamName = team['name']?.toString() ?? 'label_team'.tr();
        final teamName =
            TeamModel.sanitizePublicHandle(rawTeamName, fallback: 'Team');
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
                  style: TextStyle(
                    color: ThemeService.textPrimary,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: ThemeService.textPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'leaderboard_top_teams_title'.tr(),
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
          body: Column(
            children: [
              _buildModeSwitcher(),
              if (_selectedMode == 0) ...[
                _buildGameSelectorBar(),
                _buildPlayPolicyWeeklyBanner(),
              ],
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF00FF88),
                  backgroundColor: ThemeService.card,
                  onRefresh: _fetchLeaderboard,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF00FF88)),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: SingleChildScrollView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.error_outline_rounded,
                                          color: Color(0xFFFF4655), size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        'err_failed_load_leaderboard'
                                            .tr(args: [_errorMessage ?? '']),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: ThemeService.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: _fetchLeaderboard,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF00FF88),
                                          foregroundColor: Colors.black,
                                        ),
                                        child: Text('try_again'.tr(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : _selectedMode == 0
                              ? _buildWeeklyTeamList()
                              : _buildAllTimeList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
