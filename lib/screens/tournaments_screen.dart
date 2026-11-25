// ===============================================================================
// TOURNAMENTS SCREEN — Tournament Feed & Match Status Management
// File: lib/screens/tournaments_screen.dart
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/coin_wallet_service.dart';
import '../services/theme_service.dart';
import '../utils/admin_security.dart';
import 'tournament_detail_screen.dart';

class TournamentsScreen extends StatefulWidget {
  final String? gameName;

  const TournamentsScreen({super.key, this.gameName});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String kLastTeamStandingRule =
      'All joined teams play together in one room; the last team standing wins the prize pool.';

  bool _isLoading = true;
  String? _registeringTournamentId;
  
  var _tournaments = [];
  
  final Set<String> _registeredTournamentIds = {};
  String? _myTeamId;
  Timer? _countdownRefreshTimer;

  String _getFormatSlotMeaning(String format) {
    final lower = format.trim().toLowerCase();
    if (lower.contains('solo')) {
      return '1 Slot = 1 Player';
    } else if (lower.contains('duo')) {
      return '1 Slot = 1 Team (2 players)';
    } else if (lower.contains('squad')) {
      return '1 Slot = 1 Team (4 players)';
    } else if (lower.contains('single')) {
      return '1 Slot = 1 Team/Entry in a single match room';
    }
    return '1 Slot = 1 Team';
  }

  String _getMaxSlotsHelperText(String format, int maxSlots) {
    final slots = maxSlots > 0 ? maxSlots : 0;
    final lower = format.trim().toLowerCase();
    if (lower.contains('solo')) {
      final label = slots == 1 ? 'Player' : 'Players';
      return '$slots $label • up to $slots ${label.toLowerCase()}';
    } else if (lower.contains('duo')) {
      final label = slots == 1 ? 'Team' : 'Teams';
      final totalPlayers = slots * 2;
      return '$slots $label • up to $totalPlayers players';
    } else if (lower.contains('squad')) {
      final label = slots == 1 ? 'Team' : 'Teams';
      final totalPlayers = slots * 4;
      return '$slots $label • up to $totalPlayers players';
    } else if (lower.contains('single')) {
      final label = slots == 1 ? 'Team/Entry' : 'Teams/Entries';
      return '$slots $label in 1 custom room';
    }
    final label = slots == 1 ? 'Team' : 'Teams';
    return '$slots $label';
  }

  int _parseEntryFeeCoins(dynamic rawFee) {
    if (rawFee == null) return 0;
    if (rawFee is num) return rawFee.toInt() > 0 ? rawFee.toInt() : 0;
    final str = rawFee.toString().trim().toLowerCase();
    if (str.isEmpty || str == 'free' || str == '0') return 0;
    final digits = RegExp(r'\d+').firstMatch(str)?.group(0);
    return digits != null ? (int.tryParse(digits) ?? 0) : 0;
  }

  bool _isWithin15MinEntryLock(Map<String, dynamic> item) {
    final matchTimeStr = item['match_time']?.toString();
    if (matchTimeStr == null || matchTimeStr.isEmpty) return false;
    final matchTime = DateTime.tryParse(matchTimeStr)?.toLocal();
    if (matchTime == null) return false;
    final lockCutoff = matchTime.subtract(const Duration(minutes: 15));
    return DateTime.now().isAfter(lockCutoff) || DateTime.now().isAtSameMomentAs(lockCutoff);
  }

  Future<void> _evaluateEntryLockAndMinTeamsRule(List<Map<String, dynamic>> tournaments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final item in tournaments) {
        final tId = item['id']?.toString() ?? '';
        if (tId.isEmpty) continue;
        final status = (item['status'] ?? 'upcoming').toString().trim().toLowerCase();
        if (status == 'completed') continue;

        final isEntryClosed = _isWithin15MinEntryLock(item);
        if (!isEntryClosed) continue;

        final currentTeams = int.tryParse(
              item['current_teams']?.toString() ??
                  item['joined_teams_count']?.toString() ??
                  '0',
            ) ??
            0;

        if (currentTeams < 2) {
          // Fewer than 2 slots/teams joined when entry closed -> cancel tournament and refund entry fee coins
          if (status != 'cancelled') {
            item['status'] = 'cancelled';
            try {
              await _supabase
                  .from('tournaments')
                  .update({'status': 'cancelled'})
                  .eq('id', tId);
            } catch (_) {}
          }

          final entryFeeCoins = _parseEntryFeeCoins(item['entry_fee']);
          if (entryFeeCoins > 0 && currentTeams > 0) {
            try {
              final regs = await _supabase
                  .from('tournament_registrations')
                  .select('leader_id, user_id')
                  .eq('tournament_id', tId);
              if (regs is Iterable) {
                for (final r in regs) {
                  if (r is Map) {
                    final regUid = (r['leader_id'] ?? r['user_id'] ?? '').toString().trim();
                    if (regUid.isEmpty) continue;
                    final refundKey = 'refunded_cancelled_tournament_${tId}_$regUid';
                    if (prefs.getBool(refundKey) == true) continue;

                    await prefs.setBool(refundKey, true);
                    await CoinWalletService.updateCoins(
                      userId: regUid,
                      amount: entryFeeCoins,
                      type: 'refund',
                      title: 'Tournament Cancelled Refund',
                      description:
                          'Auto-refunded $entryFeeCoins G-Coins: fewer than 2 teams joined "${item['title'] ?? 'Tournament'}" before entry lock (15m rule).',
                      roomId: tId,
                    );
                  }
                }
              }
            } catch (e) {
              debugPrint('Auto-refund check error for $tId: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Entry lock rule evaluation error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
    _countdownRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _evaluateEntryLockAndMinTeamsRule(
          _tournaments.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        );
        setState(() {});
      }
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
            final List regRes = [];

            if (_myTeamId != null && _myTeamId!.isNotEmpty) {
              final rawRes = await _supabase
                  .from('tournament_registrations')
                  .select('tournament_id')
                  .or('team_id.eq.$_myTeamId,leader_id.eq.${user.id}');
              if (rawRes is Iterable) {
                regRes.addAll(rawRes);
              }
            } else {
              final rawRes = await _supabase
                  .from('tournament_registrations')
                  .select('tournament_id')
                  .eq('leader_id', user.id);
              if (rawRes is Iterable) {
                regRes.addAll(rawRes);
              }
            }

            for (var r in regRes) {
              if (r is Map) {
                final tId = r['tournament_id']?.toString();
                if (tId != null && tId.isNotEmpty) {
                  _registeredTournamentIds.add(tId);
                }
              }
            }
          } catch (e) {
            debugPrint('Registration check error: $e');
          }
        } catch (_) {}
      }

      final res = await _supabase.from('tournaments').select().order('created_at', ascending: false);

      final List<Map<String, dynamic>> resolvedTournaments = [];
      if (res is Iterable) {
        for (final item in res) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            // Strict per-game isolation: Only show tournaments for this specific game
            if (widget.gameName != null && widget.gameName!.trim().isNotEmpty) {
              final targetKey = _normalizeGameKey(widget.gameName!);
              final rawItemGame = (map['game_name'] ?? map['game'] ?? '').toString();
              final itemKey = _normalizeGameKey(rawItemGame);
              if (itemKey != targetKey) {
                continue; // Skip tournaments that belong to other games
              }
            }
            resolvedTournaments.add(map);
          }
        }
      }

      await _evaluateEntryLockAndMinTeamsRule(resolvedTournaments);

      if (mounted) {
        setState(() {
          _tournaments = resolvedTournaments;
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

  String _normalizeGameKey(String raw) {
    final clean = raw.trim().toLowerCase();
    // 1. Strict separation: Check Free Fire MAX first
    if (clean.contains('max') && (clean.contains('free') || clean.contains('fire') || clean.contains('ff') || clean.contains('garena'))) {
      return 'free_fire_max';
    }
    // 2. Standard Free Fire (strictly WITHOUT max)
    if (!clean.contains('max') && (clean.contains('free fire') || clean.contains('freefire') || clean == 'ff' || clean.startsWith('ff '))) {
      return 'free_fire';
    }
    // 3. PUBG Mobile
    if (clean.contains('pubg') || clean.contains('bgmi') || clean.contains('battleground')) {
      return 'pubg_mobile';
    }
    // 4. Call Of Duty
    if (clean.contains('call of duty') || clean == 'cod' || clean == 'codm' || clean.startsWith('cod ')) {
      return 'call_of_duty';
    }
    // 5. Clash Royale
    if (clean.contains('clash royale') || clean == 'cr') {
      return 'clash_royale';
    }
    // 6. Clash of Clans
    if (clean.contains('clash of clans') || clean == 'coc') {
      return 'clash_of_clans';
    }
    // 7. Candy Crush
    if (clean.contains('candy crush')) {
      return 'candy_crush';
    }
    // 8. Minecraft
    if (clean.contains('minecraft') || clean == 'mc') {
      return 'minecraft';
    }
    // 9. eFootball
    if (clean.contains('efootball') || clean.contains('pes')) {
      return 'efootball';
    }
    // 10. Asphalt 9
    if (clean.contains('asphalt')) {
      return 'asphalt_9';
    }
    // 11. Brawl Stars
    if (clean.contains('brawl')) {
      return 'brawl_stars';
    }
    // 12. Stumble Guys
    if (clean.contains('stumble')) {
      return 'stumble_guys';
    }
    // 13. Ludo
    if (clean.contains('ludo')) {
      return 'ludo';
    }
    // 14. 8 Ball Pool
    if (clean.contains('8 ball') || clean.contains('8ball')) {
      return '8_ball_pool';
    }
    return clean;
  }

  Future<void> _registerTeam(Map<String, dynamic> tournament) async {
    final tournamentId = tournament['id']?.toString() ?? '';
    
    final format = (tournament['match_format'] ?? tournament['format'] ?? '').toString().toLowerCase();
    final isSoloMatch = format.contains('solo') || format.contains('single');

    final maxTeams = int.tryParse(tournament['max_teams']?.toString() ?? tournament['max_slots']?.toString() ?? '16') ?? 16;
    final currentTeams = int.tryParse(tournament['current_teams']?.toString() ?? tournament['joined_teams_count']?.toString() ?? '0') ?? 0;
    final isFull = currentTeams >= maxTeams;
    final isEntryLocked = _isWithin15MinEntryLock(tournament);
    final rawStatus = (tournament['status'] ?? 'upcoming').toString().trim().toLowerCase();

    if (isFull) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slots Full! Registration is locked.'),
          backgroundColor: Color(0xFFFF8A00),
        ),
      );
      return;
    }

    if (isEntryLocked || rawStatus == 'cancelled') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentTeams < 2
                ? 'Tournament cancelled (< 2 teams joined 15m before start). Entry fees auto-refunded.'
                : 'Entry Locked! Registrations close 15 minutes before match start.',
          ),
          backgroundColor: const Color(0xFFFF4655),
        ),
      );
      _fetchTournaments();
      return;
    }

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

    final entryFeeCoins = _parseEntryFeeCoins(tournament['entry_fee']);
    if (entryFeeCoins > 0) {
      final wallet = await CoinWalletService().getOrCreateWallet(user.id);
      if (wallet.coins < entryFeeCoins) {
        if (mounted) {
          setState(() => _registeringTournamentId = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Insufficient G-Coins! Entry fee is $entryFeeCoins Coins (Your balance: ${wallet.coins} Coins).'),
              backgroundColor: const Color(0xFFFF4655),
            ),
          );
        }
        return;
      }
    }

    try {
      if (entryFeeCoins > 0) {
        await CoinWalletService.updateCoins(
          userId: user.id,
          amount: -entryFeeCoins,
          type: 'tournament_entry',
          title: 'Tournament Entry Fee',
          description: 'Entry fee for "${tournament['title'] ?? 'Tournament'}"',
          roomId: tournamentId,
        );
      }

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

      // Defensive guard: team registration must never auto-complete an upcoming tournament without a declared winner/approved proof
      try {
        final preStatus = (tournament['status'] ?? 'upcoming').toString().trim().toLowerCase();
        if (preStatus != 'completed') {
          final fresh = await _supabase
              .from('tournaments')
              .select('status, winner_team_id, proof_url')
              .eq('id', tournamentId)
              .maybeSingle();
          if (fresh != null) {
            final postStatus = (fresh['status'] ?? '').toString().trim().toLowerCase();
            final postWinner = (fresh['winner_team_id'] ?? '').toString().trim();
            final postProof = (fresh['proof_url'] ?? '').toString().trim();
            if (postStatus == 'completed' && postWinner.isEmpty && postProof.isEmpty) {
              await _supabase.from('tournaments').update({
                'status': preStatus.isNotEmpty ? preStatus : 'upcoming',
              }).eq('id', tournamentId);
            }
          }
        }
      } catch (_) {}

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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emoji_events_outlined,
                                size: 64,
                                color: ThemeService.textSecondary.withOpacity(0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No ${widget.gameName ?? ''} Tournaments Yet',
                                style: TextStyle(
                                  color: ThemeService.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tournaments created for ${widget.gameName ?? 'this game'} will appear here.',
                                style: TextStyle(
                                  color: ThemeService.textSecondary,
                                  fontSize: 12.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _tournaments.length,
                        itemBuilder: (context, index) {
                          final item = Map<String, dynamic>.from(_tournaments[index] as Map);
                          final tId = item['id'].toString();

                          final maxTeams = int.tryParse(item['max_teams']?.toString() ?? item['max_slots']?.toString() ?? '16') ?? 16;
                          final currentTeams = int.tryParse(item['current_teams']?.toString() ?? item['joined_teams_count']?.toString() ?? '0') ?? 0;
                          final isFull = currentTeams >= maxTeams;
                          final format = (item['game_mode'] ?? item['match_format'] ?? item['format'] ?? 'Squad 4v4').toString();
                          final slotMeaning = _getFormatSlotMeaning(format);
                          final maxSlotsHelper = _getMaxSlotsHelperText(format, maxTeams);

                          final status = (item['status'] ?? 'upcoming').toString().trim().toLowerCase();
                          final isCompleted = status == 'completed';
                          final isEntryWindowClosed = _isWithin15MinEntryLock(item);
                          final isCancelled = status == 'cancelled' || (!isCompleted && isEntryWindowClosed && currentTeams < 2);
                          final isEntryLocked = !isCompleted && !isCancelled && (isFull || isEntryWindowClosed);

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
                                      : isCancelled
                                          ? const Color(0xFFFF4655).withOpacity(0.5)
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
                                          (item['title'] ?? item['name'] ?? 'Tournament').toString(),
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
                                              : isCancelled
                                                  ? const Color(0xFFFF4655).withOpacity(0.15)
                                                  : const Color(0xFF00FF88).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isCompleted
                                                ? const Color(0xFFFFD700).withOpacity(0.4)
                                                : isCancelled
                                                    ? const Color(0xFFFF4655).withOpacity(0.4)
                                                    : const Color(0xFF00FF88).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          isCompleted
                                              ? 'Completed 🏆'
                                              : isCancelled
                                                  ? 'Cancelled (Refunded)'
                                                  : 'Prize: ${item['prize_pool'] ?? 1000} Coins',
                                          style: TextStyle(
                                            color: isCompleted
                                                ? const Color(0xFFFFD700)
                                                : isCancelled
                                                    ? const Color(0xFFFF4655)
                                                    : const Color(0xFF00FF88),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _badge(Icons.sports_esports, '$format • $slotMeaning'),
                                      _badge(Icons.map, (item['map_name'] ?? 'Erangel').toString()),
                                      _badge(Icons.monetization_on, 'Fee: ${item['entry_fee'] ?? 'Free'}'),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Rule 2: Last Team Standing Mode Banner
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00FF88).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.28)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.emoji_events_rounded, size: 15, color: Color(0xFF00FF88)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            kLastTeamStandingRule,
                                            style: TextStyle(
                                              color: ThemeService.textPrimary,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildRoomHookCard(item, isRegistered, isCompleted, isCancelled, isEntryWindowClosed, currentTeams),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: maxTeams > 0 ? (currentTeams / maxTeams).clamp(0.0, 1.0) : 0,
                                      backgroundColor: ThemeService.border.withOpacity(0.4),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isCompleted
                                            ? const Color(0xFFFFD700)
                                            : isCancelled
                                                ? const Color(0xFFFF4655)
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
                                      Expanded(
                                        child: Text(
                                          'Slots: $currentTeams / $maxTeams ($maxSlotsHelper)',
                                          style: TextStyle(
                                            color: ThemeService.textSecondary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      InkWell(
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
                                        child: const Row(
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
                                            : isCancelled
                                                ? const Color(0xFFFF4655).withOpacity(0.15)
                                                : isRegistered
                                                    ? const Color(0xFF00FF88).withOpacity(0.15)
                                                    : (isEntryLocked ? ThemeService.cardSecondary : const Color(0xFF00FF88)),
                                        foregroundColor: isCompleted
                                            ? Colors.black
                                            : isCancelled
                                                ? const Color(0xFFFF4655)
                                                : isRegistered
                                                    ? const Color(0xFF00FF88)
                                                    : (isEntryLocked ? ThemeService.textSecondary : Colors.black),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: (!isCompleted && isRegistered)
                                              ? const BorderSide(color: Color(0xFF00FF88), width: 1.2)
                                              : isCancelled
                                                  ? const BorderSide(color: Color(0xFFFF4655), width: 1.2)
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
                                          : isRegistered
                                              ? () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => TournamentDetailScreen(
                                                        tournament: item,
                                                        isRegistered: true,
                                                        selectedGameName: widget.gameName,
                                                      ),
                                                    ),
                                                  ).then((_) => _fetchTournaments());
                                                }
                                              : (isCancelled || isEntryLocked || isCurrentRegistering)
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
                                                  : isCancelled
                                                      ? 'Cancelled (< 2 Teams • Entry Fee Refunded)'
                                                      : isRegistered
                                                          ? '✓ Registered • View Details'
                                                          : isFull
                                                              ? 'Slots Full'
                                                              : isEntryWindowClosed
                                                                  ? 'Entry Locked (15m Before Start • Match Proceeding)'
                                                                  : 'Register Now',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12.5,
                                                color: isCompleted
                                                    ? Colors.black
                                                    : isCancelled
                                                        ? const Color(0xFFFF4655)
                                                        : isRegistered
                                                            ? const Color(0xFF00FF88)
                                                            : (isEntryLocked ? ThemeService.textSecondary : Colors.black),
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

  Widget _buildRoomHookCard(
    Map<String, dynamic> item,
    bool isRegistered,
    bool isCompleted,
    bool isCancelled,
    bool isEntryWindowClosed,
    int currentTeams,
  ) {
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

    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4655).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_rounded, size: 18, color: Color(0xFFFF4655)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Fewer than 2 teams joined 15m before start • Tournament Cancelled & Entry Fee Auto-Refunded to G-Coins Wallet',
                style: TextStyle(
                  color: Color(0xFFFF4655),
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final matchTimeStr = item['match_time']?.toString();
    final roomId = (item['room_id'] ?? '').toString().trim();
    final roomPass = (item['room_password'] ?? '').toString().trim();

    DateTime? matchTime;
    if (matchTimeStr != null) {
      try {
        matchTime = DateTime.parse(matchTimeStr).toLocal();
      } catch (_) {}
    }

    final now = DateTime.now();
    final difference = matchTime != null ? matchTime.difference(now) : null;
    final bool isPassed = difference != null && difference.isNegative;
    final bool isWithin10Mins = difference != null && difference.inMinutes <= 10 && difference.inMinutes >= -180;
    final String formattedDate = matchTime != null ? DateFormat('dd MMM, hh:mm a').format(matchTime) : 'Scheduled';

    final bool canReveal = isRegistered && (isWithin10Mins || isPassed) && roomId.isNotEmpty;

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
                  'Match Time: $formattedDate • Entry locks 15m before start (Min 2 teams)',
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                if (canReveal) ...[
                  Text(
                    'Room ID: $roomId • Pass: ${roomPass.isNotEmpty ? roomPass : "No Pass"}',
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ] else if (isEntryWindowClosed && currentTeams >= 2 && !isRegistered) ...[
                  const Text(
                    '🔒 Entry Locked (≥ 2 teams joined • Remaining slots locked & match proceeding)',
                    style: TextStyle(
                      color: Color(0xFFFF8A00),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else if (!isRegistered) ...[
                  Text(
                    'Register before 15m cutoff to view Room Credentials',
                    style: TextStyle(
                      color: ThemeService.textSecondary.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ] else if (isPassed) ...[
                  const Text(
                    'Match in Progress / Waiting for Result',
                    style: TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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
