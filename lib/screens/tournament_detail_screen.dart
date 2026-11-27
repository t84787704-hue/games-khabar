import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/coin_wallet_service.dart';
import '../services/wallet_repository.dart';
import '../services/supabase_service.dart';
import '../services/team_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/theme_service.dart';
import 'team_profile_screen.dart';
import '../services/app_share_service.dart';

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
  static const String kLastTeamStandingRule =
      'All joined teams play together in one room; the last team standing wins the prize pool.';

  Map<String, dynamic>? _tournament;
  List<Map<String, dynamic>> _registrations = [];
  bool _isLoading = true;
  bool _isTournamentUnavailable = false;
  bool _isUploadingProof = false;
  bool _isRegistering = false;
  bool _isUserRegistered = false;
  String? _myTeamId;
  String? _myTeamName;
  String? _winnerTeamName;
  String? _winnerTeamTag;
  List<String> _winnerMemberIds = [];
  String? _winnerLeaderId;

  bool _isFullTournamentRecord(Map<String, dynamic>? data) {
    if (data == null) return false;
    final hasId = data['id'] != null && data['id'].toString().trim().isNotEmpty;
    final hasGameOrFormat = data['game_name'] != null ||
        data['game'] != null ||
        data['game_mode'] != null ||
        data['match_format'] != null ||
        data['format'] != null;
    final hasTimestampOrStatus = data['match_time'] != null ||
        data['created_at'] != null ||
        data['max_slots'] != null ||
        data['max_teams'] != null;
    return hasId && hasGameOrFormat && hasTimestampOrStatus;
  }

  DateTime? _parseMatchTimeUtc(dynamic rawMatchTime) {
    final str = rawMatchTime?.toString().trim();
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str)?.toUtc();
  }

  String get currentUid =>
      SupabaseService.client.auth.currentUser?.id ??
      GamerAuthService().currentUid ??
      '';

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
    if (str.isEmpty || str == 'free' || str == '0' || str.contains('free')) {
      return 0;
    }
    final digits = RegExp(r'\d+').firstMatch(str)?.group(0);
    return digits != null ? (int.tryParse(digits) ?? 0) : 0;
  }

  String _formatEntryFeeLabel(dynamic rawFee) {
    final feeCoins = _parseEntryFeeCoins(rawFee);
    if (feeCoins <= 0) {
      return 'Free Entry (0 G-Coins)';
    }
    return '${NumberFormat('#,###').format(feeCoins)} G-Coins';
  }

  bool _isWithin15MinEntryLock(DateTime? matchTime) {
    if (matchTime == null) return false;
    final lockCutoffUtc =
        matchTime.toUtc().subtract(const Duration(minutes: 15));
    final nowUtc = DateTime.now().toUtc();
    return nowUtc.isAfter(lockCutoffUtc) ||
        nowUtc.isAtSameMomentAs(lockCutoffUtc);
  }

  bool _hasMatchStarted(DateTime? matchTime, String rawStatus) {
    final lower = rawStatus.trim().toLowerCase();
    if (lower == 'live' ||
        lower == 'active' ||
        lower == 'ongoing' ||
        lower == 'in_progress' ||
        lower == 'completed') {
      return true;
    }
    if (matchTime == null) return false;
    final nowUtc = DateTime.now().toUtc();
    final matchUtc = matchTime.toUtc();
    return nowUtc.isAfter(matchUtc) || nowUtc.isAtSameMomentAs(matchUtc);
  }

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
    _isUserRegistered = widget.isRegistered;
    final initData = widget.tournament ?? widget.initialData;
    if (_isFullTournamentRecord(initData)) {
      _tournament = Map<String, dynamic>.from(initData!);
      _isLoading = false;
    } else {
      _tournament = null;
      _isLoading = true;
    }
    _loadTournamentData();
  }

  Future<void> _resolveMyTeam() async {
    final uid = currentUid;
    if (uid.isEmpty) return;

    try {
      final leaderTeamRes = await SupabaseService.client
          .from('teams')
          .select('id, name')
          .eq('leader_id', uid)
          .maybeSingle();

      if (leaderTeamRes != null) {
        _myTeamId = leaderTeamRes['id']?.toString();
        _myTeamName = leaderTeamRes['name']?.toString();
      }

      if (_myTeamId == null || _myTeamId!.isEmpty) {
        try {
          final capRes = await SupabaseService.client
              .from('teams')
              .select('id, name')
              .eq('captain_id', uid)
              .maybeSingle();
          if (capRes != null) {
            _myTeamId = capRes['id']?.toString();
            _myTeamName = capRes['name']?.toString();
          }
        } catch (_) {}
      }

      if (_myTeamId == null || _myTeamId!.isEmpty) {
        try {
          final memberRes = await SupabaseService.client
              .from('team_members')
              .select('team_id, teams(name)')
              .eq('user_id', uid)
              .maybeSingle();
          if (memberRes != null) {
            _myTeamId = memberRes['team_id']?.toString();
            _myTeamName =
                (memberRes['teams'] as Map?)?['name']?.toString() ?? _myTeamName;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[TournamentDetail] _resolveMyTeam error: $e');
    }
  }

  Future<void> _loadTournamentData() async {
    try {
      await _resolveMyTeam();

      String tId = effectiveTournamentId;
      Map<String, dynamic>? res;

      if (tId.isNotEmpty) {
        try {
          res = await SupabaseService.client
              .from('tournaments')
              .select()
              .eq('id', tId)
              .maybeSingle();
        } catch (_) {}
      }

      final rawTitle = (_tournament?['title'] ??
              _tournament?['name'] ??
              widget.tournament?['title'] ??
              widget.initialData?['title'] ??
              '')
          .toString();
      final cleanTitle = rawTitle
          .replaceAll(
            RegExp(
              r'🏆\s*Tournament\s*Champion!\s*\([^)]*\)\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      final searchTitle = cleanTitle.isNotEmpty ? cleanTitle : rawTitle;

      if (res == null && tId.isEmpty && searchTitle.isNotEmpty) {
        try {
          res = await SupabaseService.client
              .from('tournaments')
              .select()
              .ilike('title', searchTitle)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
        } catch (_) {}
      }

      if (res != null) {
        _tournament = Map<String, dynamic>.from(res);
        _isTournamentUnavailable = false;
        tId = _tournament!['id']?.toString() ?? tId;
      } else if (!_isFullTournamentRecord(_tournament)) {
        // The requested tournament record does not exist in Supabase (deleted or expired)
        _tournament = null;
        _isTournamentUnavailable = true;
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: const Text(
                  'This tournament has already ended or is no longer available.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: const Color(0xFFFF4655),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
        }
        return;
      }

      if (tId.isEmpty && res == null && _tournament == null) {
        if (mounted) {
          setState(() {
            _isTournamentUnavailable = true;
            _isLoading = false;
          });
        }
        return;
      }

      // Load registrations with team info (bounded to max 50 slots)
      try {
        List<dynamic>? regRes;
        if (tId.isNotEmpty) {
          try {
            regRes = await SupabaseService.client
                .from('tournament_registrations')
                .select('*, teams(id, name, tag, logo_url, leader_id)')
                .eq('tournament_id', tId)
                .order('slot_number', ascending: true)
                .limit(50);
          } catch (_) {
            regRes = await SupabaseService.client
                .from('tournament_registrations')
                .select()
                .eq('tournament_id', tId)
                .limit(50);
          }
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

      // Check if current user or user's team is registered, and sync any team-level proof submission
      final uid = currentUid;
      if (_registrations.isNotEmpty) {
        for (final r in _registrations) {
          final rLeader = (r['leader_id'] ?? r['user_id'] ?? '').toString();
          final rTeam = (r['team_id'] ?? '').toString();
          final bool isMyReg = (uid.isNotEmpty && rLeader == uid) ||
              (_myTeamId != null &&
                  _myTeamId!.isNotEmpty &&
                  rTeam == _myTeamId);
          if (isMyReg) {
            _isUserRegistered = true;
            if ((_myTeamId == null || _myTeamId!.isEmpty) && rTeam.isNotEmpty) {
              _myTeamId = rTeam;
            }
            final tMap = r['teams'] as Map?;
            if ((_myTeamName == null || _myTeamName!.isEmpty) &&
                tMap != null &&
                tMap['name'] != null) {
              _myTeamName = tMap['name'].toString();
            }
          }

          // Sync existing proof from tournament_registrations if tournament proof_url is empty
          final regProofUrl = (r['proof_url'] ?? '').toString().trim();
          final regProofStatus =
              (r['proof_status'] ?? '').toString().trim().toLowerCase();
          if (_tournament != null &&
              _isActiveProofStatus(regProofStatus, regProofUrl)) {
            final curTProofUrl =
                (_tournament!['proof_url'] ?? '').toString().trim();
            final curTProofStatus = (_tournament!['proof_status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            if (!_isActiveProofStatus(curTProofStatus, curTProofUrl)) {
              _tournament!['proof_url'] = regProofUrl;
              _tournament!['proof_status'] =
                  regProofStatus.isEmpty ? 'under_review' : regProofStatus;
              if (rTeam.isNotEmpty) {
                _tournament!['proof_team_id'] = rTeam;
              }
              final regTeamName =
                  (r['teams'] as Map?)?['name']?.toString() ?? _myTeamName;
              if (regTeamName != null && regTeamName.isNotEmpty) {
                _tournament!['proof_team_name'] = regTeamName;
              }
            }
          }
        }
      }

      // Check Entry Lock & Minimum 2 Teams Rule (15 minutes before match start in UTC)
      if (_tournament != null && tId.isNotEmpty) {
        final rawStatusPre = (_tournament?['status'] ?? 'upcoming')
            .toString()
            .trim()
            .toLowerCase();
        final matchTimeUtc = _parseMatchTimeUtc(_tournament?['match_time']);
        final bool isEntryWindowClosed = _isWithin15MinEntryLock(matchTimeUtc);
        final joinedCount = _registrations.isNotEmpty
            ? _registrations.length
            : (int.tryParse((_tournament?['current_teams'] ??
                            _tournament?['joined_teams_count'] ??
                            0)
                        .toString()) ??
                    0);

        // If a future tournament before the 15m entry lock cutoff was mistakenly marked 'cancelled', restore it to 'upcoming'
        if (rawStatusPre == 'cancelled' &&
            matchTimeUtc != null &&
            !isEntryWindowClosed) {
          _tournament!['status'] = 'upcoming';
          try {
            await SupabaseService.client
                .from('tournaments')
                .update({'status': 'upcoming'})
                .eq('id', tId);
          } catch (_) {}
        } else if (rawStatusPre != 'completed' &&
            isEntryWindowClosed &&
            joinedCount < 2) {
          if (rawStatusPre != 'cancelled') {
            _tournament!['status'] = 'cancelled';
            try {
              await SupabaseService.client
                  .from('tournaments')
                  .update({'status': 'cancelled'})
                  .eq('id', tId);
            } catch (_) {}
          }

          final entryFeeCoins = _parseEntryFeeCoins(_tournament?['entry_fee']);
          if (entryFeeCoins > 0 && _registrations.isNotEmpty) {
            try {
              final prefs = await SharedPreferences.getInstance();
              for (final r in _registrations) {
                final regUid =
                    (r['leader_id'] ?? r['user_id'] ?? '').toString().trim();
                if (regUid.isEmpty) continue;
                final refundKey =
                    'refunded_cancelled_tournament_${tId}_$regUid';
                if (prefs.getBool(refundKey) == true) continue;

                await prefs.setBool(refundKey, true);
                await CoinWalletService.updateCoins(
                  userId: regUid,
                  amount: entryFeeCoins,
                  type: 'refund',
                  title: 'Tournament Cancelled Refund',
                  description:
                      'Auto-refunded $entryFeeCoins G-Coins: fewer than 2 teams joined "${_tournament?['title'] ?? 'Tournament'}" before entry lock (15m rule).',
                  roomId: tId,
                );
              }
            } catch (e) {
              debugPrint('[TournamentDetail] Auto-refund error: $e');
            }
          }
        }
      }

      // Check winning team info ONLY when the tournament row itself is genuinely completed/approved
      final rawStatus =
          (_tournament?['status'] ?? 'upcoming').toString().trim().toLowerCase();
      final proofStatus =
          (_tournament?['proof_status'] ?? '').toString().trim().toLowerCase();
      final bool isApproved = rawStatus == 'completed' ||
          proofStatus == 'approved' ||
          proofStatus == 'accepted';

      _winnerTeamName = null;
      _winnerTeamTag = null;
      _winnerLeaderId = null;
      _winnerMemberIds = [];

      if (isApproved) {
        String? winnerTeamId = (_tournament?['winner_team_id'] ??
                _tournament?['proof_team_id'] ??
                _tournament?['submitted_team_id'])
            ?.toString()
            .trim();

        if (_tournament?['winner_team_name'] != null &&
            _tournament!['winner_team_name'].toString().trim().isNotEmpty) {
          _winnerTeamName = _tournament!['winner_team_name'].toString().trim();
        } else if (_tournament?['proof_team_name'] != null &&
            _tournament!['proof_team_name'].toString().trim().isNotEmpty) {
          _winnerTeamName = _tournament!['proof_team_name'].toString().trim();
        }

        if ((winnerTeamId == null || winnerTeamId.isEmpty) &&
            _winnerTeamName != null &&
            _winnerTeamName!.isNotEmpty) {
          try {
            final foundTeam = await SupabaseService.client
                .from('teams')
                .select('id, name, tag, leader_id')
                .ilike('name', _winnerTeamName!)
                .maybeSingle();
            if (foundTeam != null) {
              winnerTeamId = foundTeam['id']?.toString();
              _winnerTeamName =
                  foundTeam['name']?.toString() ?? _winnerTeamName;
              _winnerTeamTag = foundTeam['tag']?.toString();
              _winnerLeaderId = foundTeam['leader_id']?.toString();
            }
          } catch (_) {}
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
              _winnerTeamTag = tRes['tag']?.toString() ?? _winnerTeamTag;
              _winnerLeaderId =
                  tRes['leader_id']?.toString() ?? _winnerLeaderId;
            }

            final memberRows = await SupabaseService.client
                .from('team_members')
                .select('user_id')
                .or('team_id.eq.$tUuid,team_id.eq.$winnerTeamId');

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

          if (res != null && rawStatus == 'completed') {
            try {
              TeamService().syncAllTeamsTournamentWins(force: true);
            } catch (_) {}
          }
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

  Future<void> _registerForTournament() async {
    if (_tournament == null || _isRegistering) return;

    final tId = effectiveTournamentId;
    if (tId.isEmpty) return;

    final format = (_tournament?['game_mode'] ??
            _tournament?['match_format'] ??
            _tournament?['format'] ??
            'Squad 4v4')
        .toString();
    final isSoloMatch = format.toLowerCase().contains('solo') ||
        format.toLowerCase().contains('single');

    final maxTeams = int.tryParse(
            (_tournament?['max_teams'] ?? _tournament?['max_slots'] ?? 16)
                .toString()) ??
        16;
    final currentTeams = _registrations.isNotEmpty
        ? _registrations.length
        : (int.tryParse((_tournament?['current_teams'] ??
                        _tournament?['joined_teams_count'] ??
                        0)
                    .toString()) ??
                0);

    final matchTimeStr = _tournament?['match_time']?.toString();
    final matchTime =
        matchTimeStr != null ? DateTime.tryParse(matchTimeStr)?.toLocal() : null;
    final rawStatus =
        (_tournament?['status'] ?? 'upcoming').toString().trim().toLowerCase();

    if (maxTeams > 0 && currentTeams >= maxTeams) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slots Full! Registration is locked.'),
          backgroundColor: Color(0xFFFF8A00),
        ),
      );
      return;
    }

    final entryFeeCoins = _parseEntryFeeCoins(_tournament?['entry_fee']);

    if (_isWithin15MinEntryLock(matchTime) || rawStatus == 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentTeams < 2
                ? (entryFeeCoins > 0
                    ? 'Tournament cancelled (< 2 teams joined 15m before start). Entry fees auto-refunded.'
                    : 'Tournament cancelled (< 2 teams joined 15m before start).')
                : 'Entry Locked! Registrations close 15 minutes before match start.',
          ),
          backgroundColor: const Color(0xFFFF4655),
        ),
      );
      await _loadTournamentData();
      return;
    }

    final uid = currentUid;
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in first to register!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isRegistering = true);

    try {
      if (!isSoloMatch) {
        if (_myTeamId == null || _myTeamId!.isEmpty) {
          await _resolveMyTeam();
        }
        if (_myTeamId == null || _myTeamId!.isEmpty) {
          if (mounted) {
            setState(() => _isRegistering = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You need an active Squad/Team to join! Create or join a team in the "Teams" tab first.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Color(0xFFFF8A00),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      if (entryFeeCoins > 0) {
        final wallet = await CoinWalletService().getOrCreateWallet(uid);
        final availableGCoins = WalletRepository.instance.currentGCoins > 0
            ? WalletRepository.instance.currentGCoins
            : wallet.gCoins;
        if (availableGCoins < entryFeeCoins) {
          if (mounted) {
            setState(() => _isRegistering = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Insufficient G-Coins! Entry fee is $entryFeeCoins G-Coins (Your balance: $availableGCoins G-Coins).',
                ),
                backgroundColor: const Color(0xFFFF4655),
              ),
            );
          }
          return;
        }

        await CoinWalletService.updateCoins(
          userId: uid,
          amount: -entryFeeCoins,
          type: 'tournament_entry',
          title: 'Tournament Entry Fee',
          description:
              'Entry fee for "${_tournament?['title'] ?? 'Tournament'}"',
          roomId: tId,
        );
      }

      final nextSlot = currentTeams + 1;
      if (isSoloMatch) {
        await SupabaseService.client.from('tournament_registrations').insert({
          'tournament_id': tId,
          'leader_id': uid,
          'slot_number': nextSlot,
        });
      } else {
        try {
          await SupabaseService.client.from('tournament_registrations').insert({
            'tournament_id': tId,
            'team_id': _myTeamId,
            'leader_id': uid,
            'slot_number': nextSlot,
          });
        } catch (e) {
          if (e.toString().contains('leader_id') ||
              e.toString().contains('slot_number')) {
            await SupabaseService.client
                .from('tournament_registrations')
                .insert({
              'tournament_id': tId,
              'team_id': _myTeamId,
              'user_id': uid,
            });
          } else {
            rethrow;
          }
        }
      }

      try {
        await SupabaseService.client
            .rpc('increment_tournament_teams', params: {'t_id': tId});
      } catch (_) {
        try {
          await SupabaseService.client.from('tournaments').update({
            'current_teams': nextSlot,
            'joined_teams_count': nextSlot,
          }).eq('id', tId);
        } catch (_) {}
      }

      // Defensive guard so registration never prematurely marks an upcoming tournament completed
      try {
        if (rawStatus != 'completed') {
          final fresh = await SupabaseService.client
              .from('tournaments')
              .select('status, winner_team_id, proof_url')
              .eq('id', tId)
              .maybeSingle();
          if (fresh != null) {
            final postStatus =
                (fresh['status'] ?? '').toString().trim().toLowerCase();
            final postWinner =
                (fresh['winner_team_id'] ?? '').toString().trim();
            final postProof = (fresh['proof_url'] ?? '').toString().trim();
            if (postStatus == 'completed' &&
                postWinner.isEmpty &&
                postProof.isEmpty) {
              await SupabaseService.client.from('tournaments').update({
                'status': rawStatus.isNotEmpty ? rawStatus : 'upcoming',
              }).eq('id', tId);
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _isUserRegistered = true;
        _isRegistering = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSoloMatch
                ? 'Registered Successfully! 🎉'
                : 'Squad Registered Successfully! 🎉',
          ),
          backgroundColor: const Color(0xFF00FF88),
        ),
      );

      await _loadTournamentData();
    } catch (e) {
      debugPrint('[TournamentDetail] Registration error: $e');
      if (!mounted) return;
      setState(() => _isRegistering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration Error: $e'),
          backgroundColor: const Color(0xFFFF4655),
        ),
      );
    }
  }

  void _showChampionsCeremonyDialog(String teamName, int prize) {
    final isDark = ThemeService.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
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
              style: TextStyle(
                color: ThemeService.textPrimary,
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
                border:
                    Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
              ),
              child: Text(
                '🪙 ${NumberFormat('#,###').format(prize)} G-Coins Distributed to Squad Members! 🪙',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      isDark ? const Color(0xFF00FF88) : const Color(0xFF00A855),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '+25 Points added to Team Profile and Top 100 Leaderboard!',
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Claim Glory',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isActiveProofStatus(String status, String url) {
    final s = status.trim().toLowerCase();
    final u = url.trim();
    if (s == 'rejected') return false;
    if (s == 'under_review' ||
        s == 'pending' ||
        s == 'approved' ||
        s == 'accepted') {
      return u.isNotEmpty || s == 'approved' || s == 'accepted';
    }
    return u.isNotEmpty;
  }

  bool _doesProofBelongToMyTeam(Map<String, dynamic>? tournamentData) {
    if (tournamentData == null) return false;
    final myTid = (_myTeamId ?? '').trim();
    final myTName = (_myTeamName ?? '').trim().toLowerCase();
    final proofTid = (tournamentData['proof_team_id'] ??
            tournamentData['submitted_team_id'] ??
            tournamentData['winner_team_id'] ??
            '')
        .toString()
        .trim();
    final proofTName = (tournamentData['proof_team_name'] ??
            tournamentData['winner_team_name'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    if (myTid.isNotEmpty && proofTid.isNotEmpty && myTid == proofTid) {
      return true;
    }
    if (myTName.isNotEmpty && proofTName.isNotEmpty && myTName == proofTName) {
      return true;
    }
    if (currentUid.isNotEmpty && _winnerMemberIds.contains(currentUid)) {
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> _fetchExistingProofState({
    required String tournamentId,
    required String teamId,
  }) async {
    if (tournamentId.isEmpty) return null;

    // 1. Check tournament_registrations for this (tournament_id, team_id) first
    if (teamId.isNotEmpty) {
      try {
        final regRow = await SupabaseService.client
            .from('tournament_registrations')
            .select()
            .eq('tournament_id', tournamentId)
            .eq('team_id', teamId)
            .maybeSingle();
        if (regRow != null) {
          final regProofUrl = (regRow['proof_url'] ?? '').toString().trim();
          final regProofStatus =
              (regRow['proof_status'] ?? '').toString().trim().toLowerCase();
          if (_isActiveProofStatus(regProofStatus, regProofUrl)) {
            return {
              'proof_url': regProofUrl,
              'proof_status':
                  regProofStatus.isEmpty ? 'under_review' : regProofStatus,
              'proof_team_id': teamId,
              'proof_team_name': _myTeamName ?? 'Your Team',
            };
          }
        }
      } catch (_) {}
    }

    // 2. Check the tournaments row for tournament_id
    try {
      final latestTournament = await SupabaseService.client
          .from('tournaments')
          .select()
          .eq('id', tournamentId)
          .maybeSingle();
      if (latestTournament != null) {
        final tProofUrl =
            (latestTournament['proof_url'] ?? '').toString().trim();
        final tProofStatus = (latestTournament['proof_status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final tStatus =
            (latestTournament['status'] ?? '').toString().trim().toLowerCase();
        final bool isCompletedOrActiveProof = tStatus == 'completed' ||
            _isActiveProofStatus(tProofStatus, tProofUrl);
        if (isCompletedOrActiveProof) {
          return Map<String, dynamic>.from(latestTournament);
        }
      }
    } catch (_) {}

    return null;
  }

  void _openProofImagePreview(String imageUrl, String teamLabel) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.5,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: cleanUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00FF88),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              left: 16,
              right: 72,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  teamLabel.isNotEmpty
                      ? 'Win Proof • $teamLabel'
                      : 'Winning Match Proof',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              right: 16,
              child: Material(
                color: Colors.black.withOpacity(0.65),
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.white24),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(ctx).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadProof() async {
    final rawStatus =
        (_tournament?['status'] ?? 'upcoming').toString().trim().toLowerCase();
    final matchTimeStr = _tournament?['match_time']?.toString();
    final matchTime =
        matchTimeStr != null ? DateTime.tryParse(matchTimeStr)?.toLocal() : null;

    if (!_hasMatchStarted(matchTime, rawStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Win Proof upload unlocks after the match starts or completes.',
          ),
          backgroundColor: Color(0xFFFF8A00),
        ),
      );
      return;
    }

    final tId = effectiveTournamentId;
    String teamId = _myTeamId ?? '';
    String teamName = _myTeamName ?? 'Gamer Squad';
    if (teamId.isEmpty && currentUid.isNotEmpty) {
      await _resolveMyTeam();
      teamId = _myTeamId ?? '';
      teamName = _myTeamName ?? teamName;
    }

    if (teamId.isEmpty && _registrations.isNotEmpty) {
      for (final r in _registrations) {
        final rLeader = (r['leader_id'] ?? r['user_id'] ?? '').toString();
        final tMap = r['teams'] as Map?;
        if (currentUid.isNotEmpty &&
            rLeader == currentUid &&
            r['team_id'] != null) {
          teamId = r['team_id'].toString();
          teamName = tMap?['name']?.toString() ?? teamName;
          break;
        }
      }
      if (teamId.isEmpty) {
        for (final r in _registrations) {
          final tMap = r['teams'] as Map?;
          if (tMap != null && r['team_id'] != null) {
            teamId = r['team_id'].toString();
            teamName = tMap['name']?.toString() ?? teamName;
            break;
          }
        }
      }
    }

    // Check existing proof submissions for current tournament_id and team_id before opening picker
    final existingBeforePick = await _fetchExistingProofState(
      tournamentId: tId,
      teamId: teamId,
    );
    if (existingBeforePick != null) {
      if (mounted) {
        setState(() {
          if (_tournament != null) {
            _tournament!.addAll(existingBeforePick);
          }
        });
        final existingStatus = (existingBeforePick['proof_status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final isApprovedAlready = existingStatus == 'approved' ||
            existingStatus == 'accepted' ||
            (existingBeforePick['status'] ?? '').toString().toLowerCase() ==
                'completed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isApprovedAlready
                  ? 'Proof Submitted by Team has already been approved!'
                  : 'Proof Submitted by Team! Another team member already uploaded the win proof (pending review).',
            ),
            backgroundColor: const Color(0xFFFF8A00),
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;

    setState(() => _isUploadingProof = true);

    try {
      // Re-verify right before uploading in case a teammate submitted while the gallery picker was open
      final existingAfterPick = await _fetchExistingProofState(
        tournamentId: tId,
        teamId: teamId,
      );
      if (existingAfterPick != null) {
        if (mounted) {
          setState(() {
            if (_tournament != null) {
              _tournament!.addAll(existingAfterPick);
            }
            _isUploadingProof = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Proof Submitted by Team! A teammate just submitted the win proof — no duplicate upload needed.',
              ),
              backgroundColor: Color(0xFFFF8A00),
            ),
          );
        }
        return;
      }

      final file = File(picked.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'tournament_${tId}_$timestamp.jpg';

      String? uploadedUrl;
      try {
        await SupabaseService.client.storage.from('match_proofs').upload(
              fileName,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
        uploadedUrl = SupabaseService.client.storage
            .from('match_proofs')
            .getPublicUrl(fileName);
      } catch (_) {
        try {
          uploadedUrl = await SupabaseService.uploadFile(
            file: file,
            bucket: 'match_proofs',
            customFileName: fileName,
          );
        } catch (_) {}
      }

      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        throw 'Image upload failed. Please try again.';
      }

      final nowIso = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.client.from('tournaments').update({
        'proof_url': uploadedUrl,
        'proof_status': 'under_review',
        if (teamId.isNotEmpty) 'proof_team_id': teamId,
        'proof_team_name': teamName,
        'submitted_at': nowIso,
      }).eq('id', tId);

      // Clear any previous rejection reason best-effort
      try {
        await SupabaseService.client.from('tournaments').update({
          'rejection_reason': null,
          'proof_reject_reason': null,
        }).eq('id', tId);
      } catch (_) {}

      // Also sync proof submission on tournament_registrations for (tournament_id, team_id) best-effort
      if (teamId.isNotEmpty) {
        try {
          await SupabaseService.client
              .from('tournament_registrations')
              .update({
                'proof_url': uploadedUrl,
                'proof_status': 'under_review',
              })
              .eq('tournament_id', tId)
              .eq('team_id', teamId);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          if (_tournament != null) {
            _tournament!['proof_url'] = uploadedUrl;
            _tournament!['proof_status'] = 'under_review';
            if (teamId.isNotEmpty) {
              _tournament!['proof_team_id'] = teamId;
            }
            _tournament!['proof_team_name'] = teamName;
            _tournament!['rejection_reason'] = null;
            _tournament!['proof_reject_reason'] = null;
          }
          _isUploadingProof = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Proof Submitted by Team! Now under admin review. 🚀',
            ),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TournamentDetail] Error uploading proof: $e');
      if (mounted) {
        setState(() => _isUploadingProof = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload proof: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        final isDark = ThemeService.isDarkMode;
        final bg = ThemeService.bg;
        final appBarBg = ThemeService.appBarBg;
        final cardBg = ThemeService.card;
        final cardSec = ThemeService.cardSecondary;
        final borderCol = ThemeService.border;
        final textPri = ThemeService.textPrimary;
        final textSec = ThemeService.textSecondary;
        final accentGreen =
            isDark ? const Color(0xFF00FF88) : const Color(0xFF00A855);
        final accentSky =
            isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

        final title = (_tournament?['title'] ?? 'Tournament').toString();
        final game =
            (_tournament?['game'] ?? _tournament?['game_name'] ?? 'Free Fire')
                .toString()
                .toUpperCase();
        final mode = (_tournament?['game_mode'] ??
                _tournament?['match_format'] ??
                'Squad 4v4')
            .toString();
        final isSoloMatch = mode.toLowerCase().contains('solo') ||
            mode.toLowerCase().contains('single');
        final slotMeaning = _getFormatSlotMeaning(mode);
        final mapName =
            (_tournament?['map_name'] ?? _tournament?['map'] ?? 'Bermuda')
                .toString();
        final prizePool = (_tournament?['prize_pool'] is num)
            ? (_tournament?['prize_pool'] as num).toInt()
            : int.tryParse(_tournament?['prize_pool']?.toString() ?? '0') ?? 0;
        final entryFeeRaw = _tournament?['entry_fee'];
        final entryFeeCoins = _parseEntryFeeCoins(entryFeeRaw);
        final entryFeeText = _formatEntryFeeLabel(entryFeeRaw);
        final prizePoolText = prizePool > 0
            ? '${NumberFormat('#,###').format(prizePool)} G-Coins'
            : 'Free Practice • 0 G-Coins';
        final topRightCoinBadgeText = prizePool > 0
            ? 'Prize Pool: ${NumberFormat('#,###').format(prizePool)} G-Coins'
            : (entryFeeCoins > 0
                ? 'Entry: ${NumberFormat('#,###').format(entryFeeCoins)} G-Coins'
                : 'Free Entry • 0 G-Coins');

        final rawStatus =
            (_tournament?['status'] ?? 'upcoming').toString().toLowerCase();
        final rawProofStatus =
            (_tournament?['proof_status'] ?? '').toString().toLowerCase();
        final proofUrl = (_tournament?['proof_url'] ?? '').toString().trim();
        final bool isProofRejected = rawProofStatus == 'rejected';
        final String proofRejectionReason = (_tournament?['rejection_reason'] ??
                _tournament?['proof_reject_reason'] ??
                '')
            .toString()
            .trim();
        final bool hasProofUploaded =
            !isProofRejected && _isActiveProofStatus(rawProofStatus, proofUrl);
        final bool isProofFromMyTeam = _doesProofBelongToMyTeam(_tournament);
        final String proofSubmittingTeamName =
            (_tournament?['proof_team_name'] ??
                    _winnerTeamName ??
                    _myTeamName ??
                    'Winning Team')
                .toString()
                .trim();

        final bool isProofApproved =
            rawProofStatus == 'approved' || rawProofStatus == 'accepted';
        final bool isCompletedWithWinner = rawStatus == 'completed';
        final bool isTournamentCompleted =
            isProofApproved || isCompletedWithWinner;

        final hasValidWinner = isTournamentCompleted &&
            ((_winnerTeamName != null && _winnerTeamName!.isNotEmpty) ||
                (_tournament?['winner_team_name'] != null &&
                    _tournament?['winner_team_name'].toString().isNotEmpty ==
                        true) ||
                (_tournament?['proof_team_name'] != null &&
                    _tournament?['proof_team_name'].toString().isNotEmpty ==
                        true));

        final winnerDisplay = _winnerTeamName ??
            _tournament?['winner_team_name']?.toString() ??
            _tournament?['proof_team_name']?.toString() ??
            'Champions';
        final tagDisplay =
            _winnerTeamTag != null && _winnerTeamTag!.isNotEmpty
                ? ' [$_winnerTeamTag]'
                : '';

        final roomId = (_tournament?['room_id'] ?? '').toString().trim();
        final roomPass = (_tournament?['room_password'] ??
                _tournament?['room_pass'] ??
                '')
            .toString()
            .trim();
        final matchTimeStr = _tournament?['match_time']?.toString();
        DateTime? matchTime;
        if (matchTimeStr != null) {
          try {
            matchTime = DateTime.parse(matchTimeStr).toLocal();
          } catch (_) {}
        }
        final String formattedDate = matchTime != null
            ? DateFormat('dd MMM, hh:mm a').format(matchTime)
            : 'Scheduled';

        final maxTeams = int.tryParse(
                (_tournament?['max_teams'] ?? _tournament?['max_slots'] ?? 16)
                    .toString()) ??
            16;
        final currentTeams = _registrations.isNotEmpty
            ? _registrations.length
            : (int.tryParse((_tournament?['current_teams'] ??
                            _tournament?['joined_teams_count'] ??
                            0)
                        .toString()) ??
                    0);
        final maxSlotsHelperText = _getMaxSlotsHelperText(mode, maxTeams);

        final bool isSlotsFull = maxTeams > 0 && currentTeams >= maxTeams;
        final bool isEntryWindowClosed = _isWithin15MinEntryLock(matchTime);
        final bool isCancelledUnder2 = (!isTournamentCompleted &&
                isEntryWindowClosed &&
                (rawStatus == 'cancelled' || currentTeams < 2)) ||
            (matchTime == null && rawStatus == 'cancelled');
        final bool isEntryLockedProceeding = !isTournamentCompleted &&
            !isCancelledUnder2 &&
            (isSlotsFull || isEntryWindowClosed);
        final bool isRegistrationOpen = !isTournamentCompleted &&
            !isCancelledUnder2 &&
            !isEntryLockedProceeding &&
            !isSlotsFull;

        // Win proof upload is ONLY unlocked after match start/active status (and not cancelled),
        // and ONLY when no active proof exists (or if a previous proof was rejected by admin).
        final bool isMatchActiveOrStarted =
            !isCancelledUnder2 && _hasMatchStarted(matchTime, rawStatus);
        final bool canUploadWinProof = isMatchActiveOrStarted &&
            !isTournamentCompleted &&
            !hasProofUploaded &&
            currentTeams >= 2;

        // Check if current user is part of winning team
        final bool isUserInWinningTeam = isTournamentCompleted &&
            currentUid.isNotEmpty &&
            (_winnerMemberIds.contains(currentUid) ||
                (_winnerLeaderId != null && _winnerLeaderId == currentUid) ||
                isProofFromMyTeam ||
                (_winnerMemberIds.isEmpty &&
                    _winnerLeaderId == null &&
                    _registrations.any((r) =>
                        (r['leader_id']?.toString() == currentUid ||
                            r['user_id']?.toString() == currentUid) &&
                        (r['teams']?['name']
                                ?.toString()
                                .toLowerCase()
                                .trim() ==
                            _winnerTeamName?.toLowerCase().trim()))));

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: appBarBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textPri,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: textPri,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            actions: [
              if (!_isTournamentUnavailable && _tournament != null)
                IconButton(
                  icon: const Icon(Icons.share_rounded, size: 20),
                  color: accentGreen,
                  tooltip: 'Share Tournament',
                  onPressed: () {
                    AppShareService.shareTournament(
                      title: title,
                      game: game,
                      prize: prizePoolText,
                      fee: entryFeeText,
                      map: mapName,
                    );
                  },
                ),
            ],
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: accentGreen))
              : (_isTournamentUnavailable || _tournament == null)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFFF4655).withOpacity(0.45),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFFF4655).withOpacity(0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.event_busy_rounded,
                                  color: Color(0xFFFF4655),
                                  size: 44,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tournament Ended or Unavailable',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textPri,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This tournament has already ended or is no longer available.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textSec,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentGreen,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Go Back',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: accentGreen,
                      onRefresh: _loadTournamentData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Dynamic Top Banner (Non-clipping responsive layout)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF00B4D8),
                                Color(0xFF0077B6),
                                Color(0xFF1B4965),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0077B6)
                                    .withOpacity(isDark ? 0.3 : 0.2),
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
                                  size: 86,
                                  color: Colors.white.withOpacity(0.11),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.35),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFFFFD700)
                                                .withOpacity(0.6),
                                          ),
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.28),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.25),
                                          ),
                                        ),
                                        child: Text(
                                          entryFeeCoins <= 0
                                              ? 'FREE ENTRY (0 G-COINS)'
                                              : 'ENTRY: ${NumberFormat('#,###').format(entryFeeCoins)} G-COINS',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                  const SizedBox(height: 6),
                                  Text(
                                    'Map: $mapName • Mode: $mode ($slotMeaning)',
                                    style: const TextStyle(
                                      color: Color(0xFFCAF0F8),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 2. Info Card (Status chip, Prize Pool G-Coins badge, 4-Grid, Rules, and Registration CTA)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderCol),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (isTournamentCompleted
                                              ? accentGreen
                                              : isCancelledUnder2
                                                  ? const Color(0xFFFF4655)
                                                  : const Color(0xFFFFD700))
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isTournamentCompleted
                                            ? accentGreen
                                            : isCancelledUnder2
                                                ? const Color(0xFFFF4655)
                                                : const Color(0xFFFFD700)
                                                    .withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      isTournamentCompleted
                                          ? 'COMPLETED'
                                          : isCancelledUnder2
                                              ? (entryFeeCoins > 0
                                                  ? 'CANCELLED (REFUNDED)'
                                                  : 'MATCH CANCELLED')
                                              : isSlotsFull
                                                  ? 'SLOTS FULL'
                                                  : isEntryLockedProceeding
                                                      ? 'ENTRY LOCKED'
                                                      : (rawStatus.isNotEmpty
                                                          ? rawStatus
                                                              .toUpperCase()
                                                          : 'UPCOMING'),
                                      style: TextStyle(
                                        color: isTournamentCompleted
                                            ? accentGreen
                                            : isCancelledUnder2
                                                ? const Color(0xFFFF4655)
                                                : (isDark
                                                    ? const Color(0xFFFFD700)
                                                    : const Color(0xFFB45309)),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700)
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFFFD700)
                                            .withOpacity(0.45),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '🪙 ',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                        Flexible(
                                          child: Text(
                                            topRightCoinBadgeText,
                                            style: TextStyle(
                                              color: isDark
                                                  ? const Color(0xFFFFD700)
                                                  : const Color(0xFFB45309),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                title,
                                style: TextStyle(
                                  color: textPri,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      isTournamentCompleted
                                          ? Icons.check_circle_rounded
                                          : isCancelledUnder2
                                              ? Icons.cancel_rounded
                                              : isEntryLockedProceeding
                                                  ? Icons.lock_clock_rounded
                                                  : (rawStatus == 'upcoming'
                                                      ? Icons.schedule_rounded
                                                      : Icons
                                                          .play_circle_filled_rounded),
                                      color: isTournamentCompleted
                                          ? accentGreen
                                          : isCancelledUnder2
                                              ? const Color(0xFFFF4655)
                                              : isEntryLockedProceeding
                                                  ? const Color(0xFFFF8A00)
                                                  : accentSky,
                                      size: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isTournamentCompleted
                                          ? 'Tournament Status: Successfully Completed'
                                          : isCancelledUnder2
                                              ? (entryFeeCoins > 0
                                                  ? 'Tournament Status: Cancelled (< 2 Teams • Entry Fee Auto-Refunded)'
                                                  : 'Tournament Status: Cancelled (< 2 Teams)')
                                              : isSlotsFull
                                                  ? 'Tournament Status: Slots Full ($maxTeams / $maxTeams) • Entries Locked & Match Proceeding'
                                                  : isEntryLockedProceeding
                                                      ? 'Tournament Status: Entry Locked (15m Before Start • Match Proceeding)'
                                                      : (rawStatus == 'upcoming'
                                                          ? 'Tournament Status: Upcoming & Open for Registration'
                                                          : 'Tournament Status: Active & In Progress'),
                                      style: TextStyle(
                                        color: isTournamentCompleted
                                            ? accentGreen
                                            : isCancelledUnder2
                                                ? const Color(0xFFFF4655)
                                                : isEntryLockedProceeding
                                                    ? const Color(0xFFFF8A00)
                                                    : accentSky,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // 4-Grid Mode, Map, Entry Fee, Slots (Non-truncating wrapped layout)
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildGridItem(
                                        icon: Icons.sports_esports_outlined,
                                        label: 'Mode',
                                        value: mode,
                                        subValue: slotMeaning,
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildGridItem(
                                        icon: Icons.map_outlined,
                                        label: 'Map',
                                        value: mapName,
                                        subValue:
                                            'Prize: ${prizePool > 0 ? "${NumberFormat('#,###').format(prizePool)} G-Coins" : "0 G-Coins"}',
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildGridItem(
                                        icon: Icons.monetization_on_outlined,
                                        label: 'Entry Fee',
                                        value: entryFeeText,
                                        subValue: entryFeeCoins <= 0
                                            ? 'No G-Coins deducted'
                                            : 'Deducted from G-Coins Wallet',
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildGridItem(
                                        icon: Icons.group_outlined,
                                        label: 'Slots (Min 2 • Max $maxTeams)',
                                        value: '$currentTeams / $maxTeams',
                                        subValue: maxSlotsHelperText,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Last Team Standing Mode & Min vs Max Squad Rules Banner
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: accentGreen.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: accentGreen.withOpacity(0.35),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 1),
                                          child: Icon(
                                            Icons.emoji_events_rounded,
                                            size: 16,
                                            color: accentGreen,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            kLastTeamStandingRule,
                                            style: TextStyle(
                                              color: textPri,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '• Format ($mode): $slotMeaning ($maxSlotsHelperText).\n'
                                      '• Max Capacity & Entry Lock: Registration caps at $maxTeams slots ($maxSlotsHelperText) and locks 15 minutes before match start or immediately when all $maxTeams slots are full.\n'
                                      '${entryFeeCoins > 0 ? "• Minimum 2 Squads/Teams Rule: At least 2 squads/teams must join before entry lock for the match to proceed. If fewer than 2 join, the tournament cancels and the entry fee auto-refunds to your G-Coins Wallet." : "• Minimum 2 Squads/Teams Rule: At least 2 squads/teams must join before entry lock for the match to proceed. If fewer than 2 join before the 15-minute cutoff, the tournament is cancelled."}',
                                      style: TextStyle(
                                        color: textSec,
                                        fontSize: 11.5,
                                        height: 1.38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Primary Registration CTA Button
                              if (!isTournamentCompleted) ...[
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isUserRegistered
                                          ? accentGreen.withOpacity(0.16)
                                          : isCancelledUnder2
                                              ? const Color(0xFFFF4655)
                                                  .withOpacity(0.15)
                                              : isRegistrationOpen
                                                  ? const Color(0xFF00FF88)
                                                  : cardSec,
                                      foregroundColor: _isUserRegistered
                                          ? accentGreen
                                          : isCancelledUnder2
                                              ? const Color(0xFFFF4655)
                                              : isRegistrationOpen
                                                  ? Colors.black
                                                  : textSec,
                                      elevation: isRegistrationOpen &&
                                              !_isUserRegistered
                                          ? 2
                                          : 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: _isUserRegistered
                                            ? BorderSide(
                                                color: accentGreen,
                                                width: 1.3,
                                              )
                                            : isCancelledUnder2
                                                ? const BorderSide(
                                                    color: Color(0xFFFF4655),
                                                    width: 1.2,
                                                  )
                                                : BorderSide.none,
                                      ),
                                    ),
                                    onPressed: (_isUserRegistered ||
                                            !isRegistrationOpen ||
                                            _isRegistering)
                                        ? null
                                        : _registerForTournament,
                                    icon: _isRegistering
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2.2,
                                            ),
                                          )
                                        : Icon(
                                            _isUserRegistered
                                                ? Icons.verified_rounded
                                                : isCancelledUnder2
                                                    ? Icons.cancel_outlined
                                                    : isRegistrationOpen
                                                        ? Icons
                                                            .group_add_rounded
                                                        : Icons
                                                            .lock_outline_rounded,
                                            size: 19,
                                          ),
                                    label: Text(
                                      _isRegistering
                                          ? 'Registering Squad...'
                                          : _isUserRegistered
                                              ? (isSoloMatch
                                                  ? '✓ You Are Registered for This Match'
                                                  : '✓ Squad Registered for This Tournament')
                                              : isCancelledUnder2
                                                  ? (entryFeeCoins > 0
                                                      ? 'Cancelled (< 2 Teams • Entry Fee Refunded)'
                                                      : 'Cancelled (< 2 Teams)')
                                                  : isSlotsFull
                                                      ? 'Slots Full ($currentTeams / $maxTeams)'
                                                      : isEntryWindowClosed
                                                          ? 'Entry Locked (15m Before Start)'
                                                          : (isSoloMatch
                                                              ? 'Register / Join Match (${entryFeeCoins <= 0 ? "Free Entry" : "$entryFeeCoins G-Coins"})'
                                                              : 'Register / Join Squad (${entryFeeCoins <= 0 ? "Free Entry" : "$entryFeeCoins G-Coins"})'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        color: _isUserRegistered
                                            ? accentGreen
                                            : isCancelledUnder2
                                                ? const Color(0xFFFF4655)
                                                : isRegistrationOpen
                                                    ? Colors.black
                                                    : textSec,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Room Credentials Card (Room ID & Password)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: roomId.isNotEmpty
                                ? const Color(0xFF00FF88).withOpacity(0.12)
                                : const Color(0xFFFF8A00).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: roomId.isNotEmpty
                                  ? const Color(0xFF00FF88).withOpacity(0.4)
                                  : const Color(0xFFFF8A00).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                roomId.isNotEmpty
                                    ? Icons.vpn_key_rounded
                                    : Icons.lock_clock_rounded,
                                size: 20,
                                color: roomId.isNotEmpty
                                    ? const Color(0xFF00FF88)
                                    : const Color(0xFFFF8A00),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Match Time: $formattedDate',
                                      style: TextStyle(
                                        color: textPri,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (roomId.isNotEmpty) ...[
                                      Text(
                                        'Room ID: $roomId • Pass: ${roomPass.isNotEmpty ? roomPass : "No Pass"}',
                                        style: const TextStyle(
                                          color: Color(0xFF00FF88),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        'Room ID will be shared soon (unlocks 10m before match start for registered squads)',
                                        style: TextStyle(
                                          color: textSec,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
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

                        // 3. Match Result & Win Proof (Strictly Gated when UPCOMING / Not Started)
                        if (isTournamentCompleted && hasValidWinner) ...[
                          // Case 1: Approved & Winner Decided
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderCol),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Match Result & Win Proof',
                                        style: TextStyle(
                                          color: textPri,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentGreen.withOpacity(0.16),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: accentGreen),
                                      ),
                                      child: Text(
                                        'PROOF APPROVED',
                                        style: TextStyle(
                                          color: accentGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cardSec,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFFD700)
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            '🏆 ',
                                            style: TextStyle(fontSize: 18),
                                          ),
                                          Text(
                                            'Tournament Completed',
                                            style: TextStyle(
                                              color: isDark
                                                  ? const Color(0xFFFFD700)
                                                  : const Color(0xFFB45309),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  accentGreen.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border:
                                                  Border.all(color: accentGreen),
                                            ),
                                            child: Text(
                                              'WIN',
                                              style: TextStyle(
                                                color: accentGreen,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Champion: $winnerDisplay$tagDisplay',
                                              style: TextStyle(
                                                color: textPri,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14.5,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '• ${NumberFormat('#,###').format(prizePool)} G-Coins Awarded • +25 Points Added to Team Profile & Leaderboard',
                                        style: TextStyle(
                                          color: accentGreen,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accentGreen.withOpacity(0.10),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color:
                                                accentGreen.withOpacity(0.35),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.verified_rounded,
                                              color: accentGreen,
                                              size: 17,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                isUserInWinningTeam
                                                    ? 'Proof Submitted by Team • Approved by Admin'
                                                    : 'Winning Proof Submitted by Team ($winnerDisplay) • Approved',
                                                style: TextStyle(
                                                  color: accentGreen,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (proofUrl.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        GestureDetector(
                                          onTap: () => _openProofImagePreview(
                                            proofUrl,
                                            winnerDisplay,
                                          ),
                                          child: Stack(
                                            alignment: Alignment.bottomRight,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: CachedNetworkImage(
                                                  imageUrl: proofUrl,
                                                  height: 130,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: 720,
                                                  maxWidthDiskCache: 720,
                                                  placeholder: (_, __) =>
                                                      Container(
                                                    height: 130,
                                                    color: isDark
                                                        ? Colors.black26
                                                        : Colors.black12,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: accentGreen,
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (_, __, ___) =>
                                                      const SizedBox.shrink(),
                                                ),
                                              ),
                                              Positioned(
                                                right: 8,
                                                bottom: 8,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.7),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.zoom_in_rounded,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'View Proof',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (isUserInWinningTeam) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFFFD700),
                                              foregroundColor: Colors.black,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              elevation: 3,
                                            ),
                                            icon: const Text(
                                              '✨',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                            label: const Text(
                                              'View Champions Ceremony 👑',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                            ),
                                            onPressed: () =>
                                                _showChampionsCeremonyDialog(
                                              winnerDisplay,
                                              prizePool,
                                            ),
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
                        ] else if (hasProofUploaded) ...[
                          // Case 2: Proof Submitted by Team & Under Admin Review (No duplicate uploads allowed)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderCol),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Match Result & Win Proof',
                                        style: TextStyle(
                                          color: textPri,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF8A00)
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFFF8A00),
                                        ),
                                      ),
                                      child: const Text(
                                        'PENDING REVIEW',
                                        style: TextStyle(
                                          color: Color(0xFFFF8A00),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cardSec,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFF8A00)
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF8A00)
                                                  .withOpacity(0.14),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.fact_check_rounded,
                                              color: Color(0xFFFF8A00),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isProofFromMyTeam
                                                      ? 'Proof Submitted by Team • Pending Review'
                                                      : 'Proof Submitted by Team ($proofSubmittingTeamName)',
                                                  style: const TextStyle(
                                                    color: Color(0xFFFF8A00),
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Submitted by Team: $proofSubmittingTeamName',
                                                  style: TextStyle(
                                                    color: textPri,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Only one proof submission is needed per winning team. Admin is reviewing this screenshot — other team members do not need to submit duplicate proofs.',
                                                  style: TextStyle(
                                                    color: textSec,
                                                    fontSize: 11.5,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (proofUrl.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        GestureDetector(
                                          onTap: () => _openProofImagePreview(
                                            proofUrl,
                                            proofSubmittingTeamName,
                                          ),
                                          child: Stack(
                                            alignment: Alignment.bottomRight,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: CachedNetworkImage(
                                                  imageUrl: proofUrl,
                                                  height: 130,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: 720,
                                                  maxWidthDiskCache: 720,
                                                  placeholder: (_, __) =>
                                                      Container(
                                                    height: 130,
                                                    color: isDark
                                                        ? Colors.black26
                                                        : Colors.black12,
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        color:
                                                            Color(0xFFFF8A00),
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (_, __, ___) =>
                                                      const SizedBox.shrink(),
                                                ),
                                              ),
                                              Positioned(
                                                right: 8,
                                                bottom: 8,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.7),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.zoom_in_rounded,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Tap to Preview',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
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
                        ] else if (canUploadWinProof) ...[
                          // Case 3: Match has started / is active -> Win Proof Upload is unlocked (or previous proof was rejected)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderCol),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Match Result & Win Proof',
                                        style: TextStyle(
                                          color: textPri,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (isProofRejected
                                                ? const Color(0xFFFF4655)
                                                : const Color(0xFF00B4D8))
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isProofRejected
                                              ? const Color(0xFFFF4655)
                                              : const Color(0xFF00B4D8),
                                        ),
                                      ),
                                      child: Text(
                                        isProofRejected
                                            ? 'PROOF REJECTED'
                                            : 'AWAITING PROOF',
                                        style: TextStyle(
                                          color: isProofRejected
                                              ? const Color(0xFFFF4655)
                                              : const Color(0xFF00B4D8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (isProofRejected) ...[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF4655)
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFFF4655)
                                            .withOpacity(0.45),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: Color(0xFFFF4655),
                                          size: 19,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Previous Team Proof Rejected by Admin',
                                                style: TextStyle(
                                                  color: Color(0xFFFF4655),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                proofRejectionReason.isNotEmpty
                                                    ? 'Reason: $proofRejectionReason\nYour team may now submit a new winning screenshot.'
                                                    : 'Your team may now upload a new winning screenshot for admin review.',
                                                style: TextStyle(
                                                  color: textSec,
                                                  fontSize: 11.5,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cardSec,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF38BDF8)
                                              .withOpacity(0.3)
                                          : const Color(0xFF0284C7)
                                              .withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        color: accentSky,
                                        size: 36,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        isProofRejected
                                            ? 'Re-Submit Team Winning Screenshot'
                                            : 'Submit Winning Match Screenshot',
                                        style: TextStyle(
                                          color: textPri,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Only one proof submission is needed per winning team. Once any member of your team uploads the winning screenshot, all teammates will see the submitted status.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textSec,
                                          fontSize: 11.5,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF00B4D8),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            elevation: 2,
                                          ),
                                          icon: _isUploadingProof
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons
                                                      .add_photo_alternate_rounded,
                                                  size: 18,
                                                ),
                                          label: Text(
                                            _isUploadingProof
                                                ? 'Uploading Proof...'
                                                : (isProofRejected
                                                    ? 'Re-Upload Team Win Proof 📸'
                                                    : 'Upload Win Proof 📸'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          onPressed: _isUploadingProof
                                              ? null
                                              : _pickAndUploadProof,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ] else ...[
                          // Case 4: UPCOMING or Cancelled -> Locked State (No "PENDING PROOF" or active upload button!)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderCol),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Match Result & Win Proof',
                                        style: TextStyle(
                                          color: textPri,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (isCancelledUnder2
                                                ? const Color(0xFFFF4655)
                                                : const Color(0xFFFFD700))
                                            .withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: (isCancelledUnder2
                                                  ? const Color(0xFFFF4655)
                                                  : const Color(0xFFFFD700))
                                              .withOpacity(0.5),
                                        ),
                                      ),
                                      child: Text(
                                        isCancelledUnder2
                                            ? 'MATCH CANCELLED'
                                            : 'LOCKED • UPCOMING',
                                        style: TextStyle(
                                          color: isCancelledUnder2
                                              ? const Color(0xFFFF4655)
                                              : (isDark
                                                  ? const Color(0xFFFFD700)
                                                  : const Color(0xFFB45309)),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cardSec,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderCol),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: (isCancelledUnder2
                                                  ? const Color(0xFFFF4655)
                                                  : const Color(0xFFFF8A00))
                                              .withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isCancelledUnder2
                                              ? Icons.cancel_outlined
                                              : Icons.lock_clock_rounded,
                                          color: isCancelledUnder2
                                              ? const Color(0xFFFF4655)
                                              : const Color(0xFFFF8A00),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isCancelledUnder2
                                                  ? 'Tournament Cancelled (< 2 Squads Joined)'
                                                  : 'Win Proof Unlocks After Match Starts',
                                              style: TextStyle(
                                                color: textPri,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isCancelledUnder2
                                                  ? (entryFeeCoins > 0
                                                      ? 'This tournament did not reach the minimum 2 squads requirement before entry lock. Your entry fee has been auto-refunded to your G-Coins Wallet.'
                                                      : 'This tournament did not reach the minimum 2 squads requirement before entry lock.')
                                                  : 'This tournament is currently UPCOMING ($formattedDate). Win proof submission will unlock automatically once the match begins and completes.',
                                              style: TextStyle(
                                                color: textSec,
                                                fontSize: 11.5,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 4. Registered Squads
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderCol),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Registered Squads',
                                          style: TextStyle(
                                            color: textPri,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Min 2 required to start • Max $maxTeams ($maxSlotsHelperText)',
                                          style: TextStyle(
                                            color: textSec,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accentGreen.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: accentGreen.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      '$currentTeams / $maxTeams',
                                      style: TextStyle(
                                        color: accentGreen,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_registrations.isEmpty) ...[
                                if (isTournamentCompleted &&
                                    _winnerTeamName != null &&
                                    _winnerTeamName!.isNotEmpty) ...[
                                  _buildSquadItem(
                                    index: 1,
                                    name: _winnerTeamName!,
                                    slotNumber: 1,
                                    isWinner: true,
                                    teamId: _tournament?['winner_team_id']
                                            ?.toString() ??
                                        '',
                                    isDark: isDark,
                                  ),
                                ] else ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cardSec,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderCol),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.groups_outlined,
                                          color: textSec,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'No registered squads yet (0 / $maxTeams)',
                                          style: TextStyle(
                                            color: textPri,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isRegistrationOpen
                                              ? 'Be the first squad to claim Slot #1! At least 2 squads are needed before the 15-minute entry lock.'
                                              : 'Registration is closed for this tournament.',
                                          style: TextStyle(
                                            color: textSec,
                                            fontSize: 11.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ] else ...[
                                ..._registrations.asMap().entries.map((entry) {
                                  final idx = entry.key + 1;
                                  final reg = entry.value;
                                  final teamObj =
                                      reg['teams'] as Map<String, dynamic>?;
                                  final teamName =
                                      teamObj?['name']?.toString() ??
                                          reg['team_name']?.toString() ??
                                          'Squad #$idx';
                                  final slotNum = reg['slot_number'] ?? idx;
                                  final teamId =
                                      reg['team_id']?.toString() ?? '';
                                  final isWinner = isTournamentCompleted &&
                                      ((teamId.isNotEmpty &&
                                              (teamId ==
                                                      _tournament?[
                                                              'winner_team_id']
                                                          ?.toString() ||
                                                  teamId ==
                                                      (_tournament?[
                                                              'proof_team_id']
                                                          ?.toString()))) ||
                                          (_winnerTeamName != null &&
                                              teamName.toLowerCase().trim() ==
                                                  _winnerTeamName!
                                                      .toLowerCase()
                                                      .trim()));

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildSquadItem(
                                      index: idx,
                                      name: teamName,
                                      slotNumber: slotNum,
                                      isWinner: isWinner,
                                      teamId: teamId,
                                      isDark: isDark,
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
                ),
        );
      },
    );
  }

  Widget _buildGridItem({
    required IconData icon,
    IconData? fallbackIcon,
    required String label,
    required String value,
    String? subValue,
    required bool isDark,
  }) {
    final effectiveIcon = fallbackIcon ?? icon;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ThemeService.cardSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ThemeService.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  effectiveIcon,
                  size: 14,
                  color: isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: ThemeService.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
              height: 1.2,
            ),
          ),
          if (subValue != null && subValue.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subValue,
              style: TextStyle(
                color: ThemeService.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ],
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
    required bool isDark,
  }) {
    final cardColor = isWinner
        ? (isDark
            ? const Color(0xFFFFD700).withOpacity(0.12)
            : const Color(0xFFFFF9C4))
        : ThemeService.cardSecondary;
    final borderColor =
        isWinner ? const Color(0xFFFFD700) : ThemeService.border;
    final nameColor = isWinner
        ? (isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309))
        : ThemeService.textPrimary;

    return InkWell(
      onTap: teamId != null && teamId.isNotEmpty
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeamProfileScreen(teamId: teamId),
                ),
              )
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
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
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF00FF88)
                      : const Color(0xFF00A855),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: nameColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isWinner) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
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
              style: TextStyle(
                color: ThemeService.textSecondary,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.shield_outlined,
              size: 16,
              color: ThemeService.textSecondary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
