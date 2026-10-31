import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../services/team_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/theme_service.dart';
import '../constants/gamer_theme.dart';
import 'team_profile_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String? tournamentId;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? tournament;
  final bool isRegistered;
  final String? selectedGameName;

  const TournamentDetailScreen({
    super.key,
    this.tournamentId,
    this.initialData,
    this.tournament,
    this.isRegistered = false,
    this.selectedGameName,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  Map<String, dynamic>? _tournament;
  List<Map<String, dynamic>> _registrations = [];
  bool _isLoading = true;
  String? _winnerTeamName;
  String? _winnerTeamTag;
  List<String> _winnerMemberIds = [];
  String? _winnerLeaderId;

  String get currentUid => GamerAuthService().currentUid ?? '';

  String get effectiveTournamentId {
    if (widget.tournamentId != null && widget.tournamentId!.isNotEmpty) {
      return widget.tournamentId!;
    }
    final tMap = widget.tournament ?? widget.initialData;
    if (tMap != null && tMap['id'] != null) {
      return tMap['id'].toString();
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    final initData = widget.tournament ?? widget.initialData;
    if (initData != null) {
      _tournament = Map<String, dynamic>.from(initData);
      _isLoading = false;
    }
    _loadTournamentData();
  }

  Future<void> _loadTournamentData() async {
    final tId = effectiveTournamentId;
    if (tId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final res = await SupabaseService.client
          .from('tournaments')
          .select()
          .eq('id', tId)
          .maybeSingle();

      if (res != null) {
        _tournament = Map<String, dynamic>.from(res);
      }

      // Load registrations with team info
      try {
        List<dynamic>? regRes;
        try {
          regRes = await SupabaseService.client
              .from('tournament_registrations')
              .select('*, teams(id, name, tag, logo_url, leader_id)')
              .eq('tournament_id', tId)
              .order('slot_number', ascending: true);
        } catch (_) {
          regRes = await SupabaseService.client
              .from('tournament_registrations')
              .select()
              .eq('tournament_id', tId);
        }

        if (regRes is List) {
          final List<Map<String, dynamic>> enriched = [];
          for (final r in regRes) {
            final regMap = Map<String, dynamic>.from(r);
            if (regMap['teams'] == null && regMap['team_id'] != null) {
              final tid = regMap['team_id'].toString();
              try {
                final tUuid = SupabaseService.toUuid(tid);
                final tRow = await SupabaseService.client
                    .from('teams')
                    .select('id, name, tag, logo_url, leader_id')
                    .or('id.eq.$tUuid,id.eq.$tid')
                    .maybeSingle();
                if (tRow != null) {
                  regMap['teams'] = tRow;
                }
              } catch (_) {}
            }
            enriched.add(regMap);
          }
          _registrations = enriched;
        }
      } catch (e) {
        debugPrint('[TournamentDetail] Error loading registrations: $e');
      }

      // Check winning team info
      final winnerTeamId = (_tournament?['winner_team_id'] ??
              _tournament?['proof_team_id'] ??
              _tournament?['submitted_team_id'])
          ?.toString();

      if (_tournament?['proof_team_name'] != null) {
        _winnerTeamName = _tournament?['proof_team_name']?.toString();
      }

      if (winnerTeamId != null && winnerTeamId.isNotEmpty) {
        try {
          final tUuid = SupabaseService.toUuid(winnerTeamId);
          final tRes = await SupabaseService.client
              .from('teams')
              .select('name, tag, leader_id')
              .or('id.eq.$tUuid,id.eq.$winnerTeamId')
              .maybeSingle();

          if (tRes != null) {
            _winnerTeamName = tRes['name']?.toString() ?? _winnerTeamName;
            _winnerTeamTag = tRes['tag']?.toString();
            _winnerLeaderId = tRes['leader_id']?.toString();
          }

          // Fetch member IDs for winning team
          final memberRows = await SupabaseService.client
              .from('team_members')
              .select('user_id')
              .or('team_id.eq.$tUuid,team_id.eq.$winnerTeamId');

          _winnerMemberIds = [];
          if (_winnerLeaderId != null && _winnerLeaderId!.isNotEmpty) {
            _winnerMemberIds.add(_winnerLeaderId!);
          }
          for (final m in memberRows) {
            final uid = (m['user_id'] ?? '').toString().trim();
            if (uid.isNotEmpty && !_winnerMemberIds.contains(uid)) {
              _winnerMemberIds.add(uid);
            }
          }
        } catch (e) {
          debugPrint('[TournamentDetail] Error loading winner team info: $e');
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[TournamentDetail] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showChampionsCeremonyDialog(String teamName, int prize) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD700), width: 2),
              ),
              child: const Text('👑', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 16),
            const Text(
              'CHAMPION CEREMONY',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '🎉 Congratulations $teamName! 🎉',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
              ),
              child: Text(
                '🪙 $prize G-Coins Distributed to Squad Members! 🪙',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF00FF88),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '+25 Points added to Team Profile and Top 100 Leaderboard!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Claim Glory', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (_tournament?['title'] ?? 'Tournament').toString();
    final game = (_tournament?['game'] ?? 'Free Fire').toString().toUpperCase();
    final mode = (_tournament?['game_mode'] ?? 'Squad (4v4)').toString();
    final mapName = (_tournament?['map_name'] ?? _tournament?['map'] ?? 'Erangel').toString();
    final prizePool = (_tournament?['prize_pool'] is num)
        ? (_tournament?['prize_pool'] as num).toInt()
        : int.tryParse(_tournament?['prize_pool']?.toString() ?? '1000') ?? 1000;
    final entryFee = _tournament?['entry_fee'] ?? 0;
    final entryFeeText = entryFee == 0 ? 'Free Coins' : '$entryFee Coins';
    final status = (_tournament?['status'] ?? 'completed').toString().toLowerCase();
    final isCompleted = status == 'completed';
    final maxTeams = _tournament?['max_teams'] ?? 16;
    final currentTeams = _registrations.isNotEmpty ? _registrations.length : (_tournament?['current_teams'] ?? 2);

    // Check if current user is part of winning team
    final bool isUserInWinningTeam = _winnerMemberIds.contains(currentUid) ||
        (_winnerLeaderId != null && _winnerLeaderId == currentUid);

    final winnerDisplay = _winnerTeamName ?? _tournament?['winner_team_name'] ?? 'Champions Squad';
    final tagDisplay = _winnerTeamTag != null && _winnerTeamTag!.isNotEmpty ? ' [$_winnerTeamTag]' : '';

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
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Dynamic Top Banner (Fix #1: Dynamic Game & Title, not static)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B4D8), Color(0xFF0077B6), Color(0xFF1B4965)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0077B6).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -10,
                          bottom: -10,
                          child: Icon(
                            Icons.sports_esports_rounded,
                            size: 90,
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6)),
                              ),
                              child: Text(
                                '🏆 $game TOURNAMENT',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Map: $mapName • Mode: $mode',
                              style: const TextStyle(
                                color: Color(0xFF90E0EF),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Info Card (Completed chip, prize, slots, mode)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A29),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2A3447)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                const Text('🪙 ', style: TextStyle(fontSize: 14)),
                                Text(
                                  '$prizePool Coins',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 14),
                            const SizedBox(width: 5),
                            Text(
                              isCompleted
                                  ? 'Tournament Status: Successfully Completed'
                                  : 'Tournament Status: Active & In Progress',
                              style: const TextStyle(
                                color: Color(0xFF00FF88),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 4-Grid Mode, Map, Entry Fee, Slots
                        Row(
                          children: [
                            Expanded(
                              child: _buildGridItem(
                                icon: Icons.sports_esports_outlined,
                                label: 'Mode',
                                value: mode,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildGridItem(
                                icon: Icons.map_outlined,
                                label: 'Map',
                                value: mapName,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildGridItem(
                                icon: Icons.attach_money_rounded,
                                label: 'Entry Fee',
                                value: entryFeeText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildGridItem(
                                icon: Icons.group_outlined,
                                label: 'Slots',
                                value: '$currentTeams / $maxTeams Teams',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Match Result & Win Proof (Fix #2: Winning team name with WIN badge, ceremony button only for winner)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A29),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2A3447)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Match Result & Win Proof',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('🏆 ', style: TextStyle(fontSize: 18)),
                                  const Text(
                                    'Tournament Completed',
                                    style: TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  // WIN Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00FF88).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF00FF88)),
                                    ),
                                    child: const Text(
                                      'WIN',
                                      style: TextStyle(
                                        color: Color(0xFF00FF88),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Winning Team Name Displayed Prominently
                              Row(
                                children: [
                                  Text(
                                    'Champion: $winnerDisplay$tagDisplay',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• $prizePool Coins Awarded • +25 Points Added to Team Profile & Leaderboard',
                                style: const TextStyle(
                                  color: Color(0xFF00FF88),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              // View Champions Ceremony Button (ONLY visible for winning team members!)
                              if (isUserInWinningTeam) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFD700),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 3,
                                    ),
                                    icon: const Text('✨', style: TextStyle(fontSize: 14)),
                                    label: const Text(
                                      'View Champions Ceremony 👑',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                    onPressed: () => _showChampionsCeremonyDialog(winnerDisplay, prizePool),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Registered Squads
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A29),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2A3447)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Registered Squads',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '$currentTeams / $maxTeams',
                              style: const TextStyle(
                                color: Color(0xFF00FF88),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_registrations.isEmpty) ...[
                          if (_winnerTeamName != null && _winnerTeamName!.isNotEmpty) ...[
                            _buildSquadItem(
                              index: 1,
                              name: _winnerTeamName!,
                              slotNumber: 1,
                              isWinner: true,
                              teamId: _tournament?['winner_team_id']?.toString() ?? '',
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              alignment: Alignment.center,
                              child: const Text(
                                'No registered squads found for this tournament',
                                style: TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ),
                          ],
                        ] else ...[
                          ..._registrations.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final reg = entry.value;
                            final teamObj = reg['teams'] as Map<String, dynamic>?;
                            final teamName = teamObj?['name']?.toString() ?? reg['team_name']?.toString() ?? 'Squad #$idx';
                            final slotNum = reg['slot_number'] ?? (idx + 1);
                            final teamId = reg['team_id']?.toString() ?? '';
                            final isWinner = teamId == _tournament?['winner_team_id']?.toString();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildSquadItem(
                                index: idx,
                                name: teamName,
                                slotNumber: slotNum,
                                isWinner: isWinner,
                                teamId: teamId,
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildGridItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2436),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3447)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSquadItem({
    required int index,
    required String name,
    required dynamic slotNumber,
    bool isWinner = false,
    String? teamId,
  }) {
    return InkWell(
      onTap: teamId != null && teamId.isNotEmpty
          ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TeamProfileScreen(teamId: teamId)),
              )
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isWinner ? const Color(0xFFFFD700).withOpacity(0.1) : const Color(0xFF1B2436),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isWinner ? const Color(0xFFFFD700) : const Color(0xFF2A3447),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#$index',
                style: const TextStyle(
                  color: Color(0xFF00FF88),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isWinner ? const Color(0xFFFFD700) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  if (isWinner) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'WINNER',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              'Slot: #$slotNumber',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.shield_outlined, size: 16, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}
