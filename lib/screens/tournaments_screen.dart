// ===============================================================================
// TOURNAMENTS SCREEN — Tournament Feed & Match Status Management
// File: lib/screens/tournaments_screen.dart
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/theme_service.dart';
import 'tournament_detail_screen.dart';

class TournamentsScreen extends StatefulWidget {
  final String? gameName;

  const TournamentsScreen({super.key, this.gameName});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _registeringTournamentId;
  
  // 👇 یہاں List کی ٹائپ ٹھیک کر دی گئی ہے
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
          final leaderTeamRes = await _supabase
              .from('teams')
              .select('id')
              .eq('leader_id', user.id)
              .maybeSingle();

          _myTeamId = leaderTeamRes?['id']?.toString();

          if (_myTeamId == null) {
            try {
              final capRes = await _supabase
                  .from('teams')
                  .select('id')
                  .eq('captain_id', user.id)
                  .maybeSingle();
              _myTeamId = capRes?['id']?.toString();
            } catch (_) {}
          }

          if (_myTeamId == null) {
            try {
              final memberRes = await _supabase
                  .from('team_members')
                  .select('team_id')
                  .eq('user_id', user.id)
                  .maybeSingle();
              _myTeamId = memberRes?['team_id']?.toString();
            } catch (_) {}
          }

          _registeredTournamentIds.clear();
          try {
            // 👇 یہاں List کی ٹائپ ٹھیک کر دی گئی ہے
            List<Map<String, dynamic>> regRes = [];

            if (_myTeamId != null && _myTeamId!.isNotEmpty) {
              final rawRes = await _supabase
                  .from('tournament_registrations')
                  .select('tournament_id')
                  .or('team_id.eq.$_myTeamId,leader_id.eq.${user.id}');
              regRes = List<Map<String, dynamic>>.from(rawRes);
            } else {
              final rawRes = await _supabase
                  .from('tournament_registrations')
                  .select('tournament_id')
                  .eq('leader_id', user.id);
              regRes = List<Map<String, dynamic>>.from(rawRes);
            }

            for (var r in regRes) {
              final tId = r['tournament_id']?.toString();
              if (tId != null && tId.isNotEmpty) {
                _registeredTournamentIds.add(tId);
              }
            }
          } catch (e) {
            debugPrint('Registration check error: $e');
          }
        } catch (_) {}
      }

      var query = _supabase.from('tournaments').select();
      
      if (widget.gameName != null && widget.gameName!.isNotEmpty) {
        query = query.or('game_name.ilike.%${widget.gameName}%,game.ilike.%${widget.gameName}%');
      }

      final res = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          // 👇 یہاں List کی ٹائپ ٹھیک کر دی گئی ہے
          _tournaments = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tournaments: $e')),
        );
      }
    }
  }

  Future<void> _registerTeam(Map<String, dynamic> tournament) async {
    final tournamentId = tournament['id']?.toString() ?? '';
    
    final format = (tournament['match_format'] ?? tournament['format'] ?? '').toString().toLowerCase();
    final isSoloMatch = format.contains('solo') || format.contains('single');

    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in first to register!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _registeringTournamentId = tournamentId);

    if (!isSoloMatch) {
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
        } catch (e) {
          debugPrint('Team fetch error: $e');
        }
      }

      if (_myTeamId == null) {
        setState(() => _registeringTournamentId = null);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aap ki koi Team nahi bani hui! Pehle "Teams" tab mein ja kar team banayein.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFFFF8A00),
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }
    }

    try {
      if (isSoloMatch) {
        await _supabase.from('tournament_registrations').insert({
          'tournament_id': tournamentId,
          'leader_id': user.id,
        });
      } else {
        try {
          await _supabase.from('tournament_registrations').insert({
            'tournament_id': tournamentId,
            'team_id': _myTeamId,
            'leader_id': user.id,
          });
        } catch (e) {
          if (e.toString().contains('leader_id')) {
            await _supabase.from('tournament_registrations').insert({
              'tournament_id': tournamentId,
              'team_id': _myTeamId,
              'user_id': user.id,
            });
          } else {
            rethrow;
          }
        }
      }

      try {
        await _supabase.rpc('increment_tournament_teams', params: {'t_id': tournamentId});
      } catch (_) {
        try {
          final curCount = int.tryParse(tournament['current_teams']?.toString() ?? tournament['joined_teams_count']?.toString() ?? '0') ?? 0;
          await _supabase.from('tournaments').update({
            'current_teams': curCount + 1,
            'joined_teams_count': curCount + 1,
          }).eq('id', tournamentId);
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSoloMatch ? 'Registered Successfully! 🎉' : 'Squad Registered Successfully! 🎉'),
          backgroundColor: const Color(0xFF00FF88),
        ),
      );

      _fetchTournaments();
    } catch (e) {
      debugPrint('CRITICAL REGISTRATION ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration Error: $e'),
          backgroundColor: const Color(0xFFFF4655),
        ),
      );
    } finally {
      if (mounted) setState(() => _registeringTournamentId = null);
    }
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
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: ThemeService.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.gameName != null ? '${widget.gameName} Tournaments 🏆' : 'Tournaments 🏆',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ThemeService.textPrimary,
                fontSize: 18,
              ),
            ),
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
                          'No tournaments available for this game right now',
                          style: TextStyle(color: ThemeService.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _tournaments.length,
                        itemBuilder: (context, index) {
                          final item = _tournaments[index];
                          final tId = item['id'].toString();

                          final maxTeams = int.tryParse(item['max_teams']?.toString() ?? item['max_slots']?.toString() ?? '16') ?? 16;
                          final currentTeams = int.tryParse(item['current_teams']?.toString() ?? item['joined_teams_count']?.toString() ?? '0') ?? 0;
                          final isFull = currentTeams >= maxTeams;
                          
                          final status = (item['status'] ?? 'upcoming').toString().trim().toLowerCase();
                          final isCompleted = status == 'completed';

                          final isRegistered = _registeredTournamentIds.contains(tId);
                          final isCurrentRegistering = _registeringTournamentId == tId;

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TournamentDetailScreen(
                                    tournament: item,
                                    isRegistered: isRegistered,
                                    selectedGameName: widget.gameName,
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
                                  color: isCompleted
                                      ? const Color(0xFFFFD700).withOpacity(0.5)
                                      : isRegistered
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
                                          item['title'] ?? item['name'] ?? 'Tournament',
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
                                          color: isCompleted
                                              ? const Color(0xFFFFD700).withOpacity(0.15)
                                              : const Color(0xFF00FF88).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isCompleted
                                                ? const Color(0xFFFFD700).withOpacity(0.4)
                                                : const Color(0xFF00FF88).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          isCompleted
                                              ? 'Completed 🏆'
                                              : 'Prize: ${item['prize_pool'] ?? 1000} Coins',
                                          style: TextStyle(
                                            color: isCompleted ? const Color(0xFFFFD700) : const Color(0xFF00FF88),
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
                                      _badge(Icons.sports_esports, (item['game_mode'] ?? item['match_format'] ?? 'Squad (4v4)').toString()),
                                      const SizedBox(width: 8),
                                      _badge(Icons.map, (item['map_name'] ?? 'Erangel').toString()),
                                      const SizedBox(width: 8),
                                      _badge(Icons.monetization_on, 'Fee: ${item['entry_fee'] ?? 'Free'}'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildRoomHookCard(item, isRegistered, isCompleted),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: maxTeams > 0 ? (currentTeams / maxTeams) : 0,
                                      backgroundColor: ThemeService.border.withOpacity(0.4),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isCompleted
                                            ? const Color(0xFFFFD700)
                                            : isRegistered
                                                ? const Color(0xFF00FF88)
                                                : const Color(0xFF1877F2),
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
                                        backgroundColor: isCompleted
                                            ? const Color(0xFFFFD700)
                                            : isRegistered
                                                ? const Color(0xFF00FF88).withOpacity(0.15)
                                                : (isFull ? ThemeService.cardSecondary : const Color(0xFF00FF88)),
                                        foregroundColor: isCompleted
                                            ? Colors.black
                                            : isRegistered
                                                ? const Color(0xFF00FF88)
                                                : (isFull ? ThemeService.textSecondary : Colors.black),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: (!isCompleted && isRegistered)
                                              ? const BorderSide(color: Color(0xFF00FF88), width: 1.2)
                                              : BorderSide.none,
                                        ),
                                      ),
                                      onPressed: isCompleted
                                          ? () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => TournamentDetailScreen(
                                                    tournament: item,
                                                    isRegistered: isRegistered,
                                                    selectedGameName: widget.gameName,
                                                  ),
                                                ),
                                              ).then((_) => _fetchTournaments());
                                            }
                                          : (isFull || isRegistered || isCurrentRegistering)
                                              ? null
                                              : () => _registerTeam(item),
                                      child: isCurrentRegistering
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                            )
                                          : Text(
                                              isCompleted
                                                  ? 'View Results & Winners 👑'
                                                  : isRegistered
                                                      ? '✓ Registered'
                                                      : (isFull ? 'Slots Full' : 'Register Now'),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                                color: isCompleted
                                                    ? Colors.black
                                                    : isRegistered
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

  Widget _buildRoomHookCard(Map<String, dynamic> item, bool isRegistered, bool isCompleted) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFFFD700)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Match Ended • Champion Crowned 🏆',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    'Register to view Room Credentials',
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