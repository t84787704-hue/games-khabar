// ===============================================================================
// TOURNAMENTS SCREEN — Tournament Feed, 10-Min Hook & Rewards Vault Connected
// File: lib/screens/tournaments_screen.dart
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/theme_service.dart';
import '../widgets/gamer_growth_hub_dialog.dart';
import 'tournament_detail_screen.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _tournaments = [];
  final Set<String> _registeredTournamentIds = {};
  String? _myTeamId;
  Timer? _countdownRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
    _countdownRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTournaments() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;

    try {
      if (user != null) {
        try {
          // 1. Check if user is a team leader
          final leaderTeamRes = await _supabase
              .from('teams')
              .select('id')
              .eq('leader_id', user.id)
              .maybeSingle();

          _myTeamId = leaderTeamRes?['id']?.toString();

          // 2. If not a leader, check if user is a member of any team
          if (_myTeamId == null) {
            final memberRes = await _supabase
                .from('team_members')
                .select('team_id')
                .eq('user_id', user.id)
                .maybeSingle();
            
            _myTeamId = memberRes?['team_id']?.toString();
          }

          if (_myTeamId != null) {
            final regRes = await _supabase
                .from('tournament_registrations')
                .select('tournament_id')
                .eq('team_id', _myTeamId!);

            _registeredTournamentIds.clear();
            for (var r in regRes) {
              _registeredTournamentIds.add(r['tournament_id'].toString());
            }
          }
        } catch (_) {}
      }

      final res = await _supabase
          .from('tournaments')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _tournaments = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _registerTeam(String tournamentId, int entryFee) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      return;
    }

    // 🔍 Safety check: Agar _myTeamId null hai toh dobara fetch karne ki koshish karein
    if (_myTeamId == null) {
      try {
        final leaderTeamRes = await _supabase
            .from('teams')
            .select('id')
            .eq('leader_id', user.id)
            .maybeSingle();
        _myTeamId = leaderTeamRes?['id']?.toString();

        if (_myTeamId == null) {
          final memberRes = await _supabase
              .from('team_members')
              .select('team_id')
              .eq('user_id', user.id)
              .maybeSingle();
          _myTeamId = memberRes?['team_id']?.toString();
        }
      } catch (_) {}
    }

    if (_myTeamId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You need your own team to register! Please create a team first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final currentTourney = _tournaments.firstWhere(
        (t) => t['id'].toString() == tournamentId,
        orElse: () => {},
      );
      final tourneyTitle = currentTourney['title']?.toString() ?? 'Tournament';

      // 1. Insert Registration with leader_id
      await _supabase.from('tournament_registrations').insert({
        'tournament_id': tournamentId,
        'team_id': _myTeamId,
        'leader_id': user.id,
      });

      // 2. Increment Slots via RPC
      await _supabase.rpc('increment_tournament_teams', params: {'t_id': tournamentId});

      // 3. Send Notifications
      try {
        final membersRes = await _supabase
            .from('team_members')
            .select('user_id')
            .eq('team_id', _myTeamId!);

        final List<Map<String, dynamic>> notifInserts = [];
        for (final m in membersRes) {
          final memberUid = m['user_id']?.toString();
          if (memberUid != null && memberUid != user.id) {
            notifInserts.add({
              'user_id': memberUid,
              'title': 'Tournament Registered! 🎮',
              'body': 'Your squad registered the team for "$tourneyTitle". Be ready for the match!',
              'type': 'tournament',
              'data': {'tournament_id': tournamentId},
              'created_at': DateTime.now().toIso8601String(),
              'is_read': false,
            });
          }
        }

        if (notifInserts.isNotEmpty) {
          await _supabase.from('notifications').insert(notifInserts);
        }
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Squad Registered & Team Notified! 🎉'),
          backgroundColor: Color(0xFF00FF88),
        ),
      );

      _fetchTournaments();
    } catch (e) {
      debugPrint('CRITICAL REGISTRATION ERROR: $e');
      if (!mounted) return;
      
      // 🚨 Yeh ab agar koi database error hoga toh direct screen par dikha dega
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('FAIL: $e'),
          backgroundColor: const Color(0xFFFF4655),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  void _openRewardsVault() {
    showDialog(
      context: context,
      builder: (_) => const GamerGrowthHubDialog(),
    ).then((_) {
      if (mounted) setState(() {});
    });
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
            title: Text(
              'Tournaments 🏆',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ThemeService.textPrimary,
                fontSize: 18,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700).withOpacity(0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: const Color(0xFFFFD700).withOpacity(0.4)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 18),
                  label: const Text(
                    'Rewards & UC',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: _openRewardsVault,
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _fetchTournaments,
            color: const Color(0xFF00FF88),
            backgroundColor: ThemeService.card,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
                : _tournaments.isEmpty
                    ? Center(
                        child: Text(
                          'No tournaments available right now',
                          style: TextStyle(color: ThemeService.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _tournaments.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildTopEngagementBanner();
                          }

                          final item = _tournaments[index - 1];
                          final tId = item['id'].toString();
                          final maxTeams = (item['max_teams'] ?? 16) as int;
                          final currentTeams = (item['current_teams'] ?? 0) as int;
                          final isFull = currentTeams >= maxTeams;
                          final isRegistered = _registeredTournamentIds.contains(tId);

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TournamentDetailScreen(
                                    tournament: item,
                                    isRegistered: isRegistered,
                                  ),
                                ),
                              ).then((_) => _fetchTournaments());
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: ThemeService.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isRegistered
                                      ? const Color(0xFF00FF88).withOpacity(0.5)
                                      : ThemeService.border,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['title'] ?? 'Tournament',
                                          style: TextStyle(
                                            color: ThemeService.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00FF88).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Prize: ${item['prize_pool']} Coins',
                                          style: const TextStyle(
                                            color: Color(0xFF00FF88),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _badge(Icons.sports_esports, item['game_mode'] ?? 'Squad (4v4)'),
                                      const SizedBox(width: 8),
                                      _badge(Icons.map, item['map_name'] ?? 'Erangel'),
                                      const SizedBox(width: 8),
                                      _badge(Icons.monetization_on, 'Fee: ${item['entry_fee'] ?? 0}'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildRoomHookCard(item, isRegistered),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: maxTeams > 0 ? (currentTeams / maxTeams) : 0,
                                      backgroundColor: ThemeService.border.withOpacity(0.4),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isRegistered ? const Color(0xFF00FF88) : const Color(0xFF1877F2),
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Slots: $currentTeams / $maxTeams Teams Registered',
                                        style: TextStyle(
                                          color: ThemeService.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Row(
                                        children: [
                                          Text(
                                            'View Details',
                                            style: TextStyle(
                                              color: Color(0xFF38BDF8),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: Color(0xFF38BDF8),
                                            size: 10,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isRegistered
                                            ? const Color(0xFF00FF88).withOpacity(0.15)
                                            : (isFull ? ThemeService.cardSecondary : const Color(0xFF00FF88)),
                                        foregroundColor: isRegistered
                                            ? const Color(0xFF00FF88)
                                            : (isFull ? ThemeService.textSecondary : Colors.black),
                                        disabledBackgroundColor: isRegistered
                                            ? const Color(0xFF00FF88).withOpacity(0.15)
                                            : ThemeService.cardSecondary,
                                        disabledForegroundColor: isRegistered
                                            ? const Color(0xFF00FF88)
                                            : ThemeService.textSecondary,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: isRegistered
                                              ? const BorderSide(color: Color(0xFF00FF88), width: 1.2)
                                              : BorderSide.none,
                                        ),
                                      ),
                                      onPressed: (isFull || isRegistered)
                                          ? null
                                          : () => _registerTeam(tId, item['entry_fee'] ?? 0),
                                      child: Text(
                                        isRegistered
                                            ? '✓ Squad Registered'
                                            : (isFull ? 'Slots Full' : 'Register Squad'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isRegistered
                                              ? const Color(0xFF00FF88)
                                              : (isFull ? ThemeService.textSecondary : Colors.black),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        );
      },
    );
  }

  Widget _buildTopEngagementBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.alarm_on_rounded, color: Color(0xFFFFD700), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily 10-Min Stay Bonus',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Spend 10 mins in app = Earn +50 Coins & Redeem 60 UC',
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _openRewardsVault,
            child: const Text('Open Vault', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomHookCard(Map<String, dynamic> item, bool isRegistered) {
    final matchTimeStr = item['match_time']?.toString();
    final roomId = (item['room_id'] ?? '').toString();
    final roomPass = (item['room_password'] ?? '').toString();

    DateTime? matchTime;
    if (matchTimeStr != null) {
      try {
        matchTime = DateTime.parse(matchTimeStr).toLocal();
      } catch (_) {}
    }

    final now = DateTime.now();
    final difference = matchTime != null ? matchTime.difference(now) : null;
    final bool isWithin10Mins = difference != null && difference.inMinutes <= 10 && difference.inMinutes >= -90;
    final String formattedDate = matchTime != null ? DateFormat('dd MMM, hh:mm a').format(matchTime) : 'Scheduled';

    final bool canReveal = isRegistered && isWithin10Mins && roomId.isNotEmpty;

    return Container(
      padding: const SisterPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: canReveal
            ? const Color(0xFF00FF88).withOpacity(0.12)
            : const Color(0xFFFF8A00).withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canReveal
              ? const Color(0xFF00FF88).withOpacity(0.4)
              : const Color(0xFFFF8A00).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            canReveal ? Icons.vpn_key_rounded : Icons.lock_clock_rounded,
            size: 16,
            color: canReveal ? const Color(0xFF00FF88) : const Color(0xFFFF8A00),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match Time: $formattedDate',
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                if (canReveal) ...[
                  Text(
                    'Room ID: $roomId • Pass: $roomPass',
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ] else if (!isRegistered) ...[
                  Text(
                    'Register squad to view Room Credentials',
                    style: TextStyle(
                      color: ThemeService.textSecondary.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ] else ...[
                  Text(
                    difference != null && difference.inMinutes > 0
                        ? '🔒 Room ID unlocks 10m before match (${difference.inMinutes}m left)'
                        : '🔒 Waiting for Admin to drop Room ID',
                    style: const TextStyle(
                      color: Color(0xFFFF8A00),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ThemeService.cardSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ThemeService.border.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ThemeService.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: ThemeService.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
