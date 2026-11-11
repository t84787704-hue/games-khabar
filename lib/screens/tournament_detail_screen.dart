import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/team_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/theme_service.dart';
import '../constants/gamer_theme.dart';
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
  Map<String, dynamic>? _tournament;
  List<Map<String, dynamic>> _registrations = [];
  bool _isLoading = true;
  bool _isUploadingProof = false;
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
    if (initData != null && initData['status'] != null && initData['game_mode'] != null) {
      _tournament = Map<String, dynamic>.from(initData);
      _isLoading = false;
    } else {
      if (initData != null) {
        _tournament = Map<String, dynamic>.from(initData);
      }
      _isLoading = true;
    }
    _loadTournamentData();
  }

  Future<void> _loadTournamentData() async {
    try {
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
            RegExp(r'🏆\s*Tournament\s*Champion!\s*\([^)]*\)\s*', caseSensitive: false),
            '',
          )
          .trim();
      final searchTitle = cleanTitle.isNotEmpty ? cleanTitle : rawTitle;

      // Only look up by exact title if no tournament ID was provided at all
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
        tId = _tournament!['id']?.toString() ?? tId;
      }

      if (tId.isEmpty && res == null && _tournament == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Load registrations with team info
      try {
        List<dynamic>? regRes;
        if (tId.isNotEmpty) {
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

      // Check winning team info ONLY when the tournament row itself is genuinely completed/approved
      final rawStatus = (_tournament?['status'] ?? 'upcoming').toString().trim().toLowerCase();
      final proofStatus = (_tournament?['proof_status'] ?? '').toString().trim().toLowerCase();
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
              _winnerTeamName = foundTeam['name']?.toString() ?? _winnerTeamName;
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
              _winnerLeaderId = tRes['leader_id']?.toString() ?? _winnerLeaderId;
            }

            // Fetch member IDs for winning team
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

          // Sync wins/points/coins ONLY when DB confirms this exact tournament is completed
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
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
              ),
              child: Text(
                '🪙 $prize G-Coins Distributed to Squad Members! 🪙',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFF00FF88) : const Color(0xFF00A855),
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

  Future<void> _pickAndUploadProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;

    setState(() => _isUploadingProof = true);

    try {
      final file = File(picked.path);
      final tId = effectiveTournamentId;
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

      // Determine team info for the submitting gamer
      String teamId = '';
      String teamName = 'Gamer Squad';
      if (currentUid.isNotEmpty) {
        try {
          final tRow = await SupabaseService.client
              .from('teams')
              .select('id, name')
              .eq('leader_id', currentUid)
              .maybeSingle();
          if (tRow != null) {
            teamId = tRow['id']?.toString() ?? '';
            teamName = tRow['name']?.toString() ?? teamName;
          } else {
            final mRow = await SupabaseService.client
                .from('team_members')
                .select('team_id, teams(name)')
                .eq('user_id', currentUid)
                .maybeSingle();
            if (mRow != null) {
              teamId = mRow['team_id']?.toString() ?? '';
              teamName = (mRow['teams'] as Map?)?['name']?.toString() ?? teamName;
            }
          }
        } catch (_) {}
      }

      if (teamId.isEmpty && _registrations.isNotEmpty) {
        for (final r in _registrations) {
          final tMap = r['teams'] as Map?;
          if (tMap != null && r['team_id'] != null) {
            teamId = r['team_id'].toString();
            teamName = tMap['name']?.toString() ?? teamName;
            break;
          }
        }
      }

      final nowIso = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.client.from('tournaments').update({
        'proof_url': uploadedUrl,
        'proof_status': 'under_review',
        if (teamId.isNotEmpty) 'proof_team_id': teamId,
        'proof_team_name': teamName,
        'submitted_at': nowIso,
      }).eq('id', tId);

      if (mounted) {
        setState(() {
          if (_tournament != null) {
            _tournament!['proof_url'] = uploadedUrl;
            _tournament!['proof_status'] = 'under_review';
            _tournament!['proof_team_name'] = teamName;
          }
          _isUploadingProof = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match Proof uploaded! Now under admin review. 🚀'),
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
        final accentGreen = isDark ? const Color(0xFF00FF88) : const Color(0xFF00A855);
        final accentSky = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

        final title = (_tournament?['title'] ?? 'Tournament').toString();
        final game = (_tournament?['game'] ?? _tournament?['game_name'] ?? 'Free Fire').toString().toUpperCase();
        final mode = (_tournament?['game_mode'] ?? _tournament?['match_format'] ?? 'Squad (4v4)').toString();
        final mapName = (_tournament?['map_name'] ?? _tournament?['map'] ?? 'Erangel').toString();
        final prizePool = (_tournament?['prize_pool'] is num)
            ? (_tournament?['prize_pool'] as num).toInt()
            : int.tryParse(_tournament?['prize_pool']?.toString() ?? '1000') ?? 1000;
        final entryFee = _tournament?['entry_fee'] ?? 0;
        final entryFeeText = entryFee == 0 ? 'Free Coins' : '$entryFee Coins';
        final rawStatus = (_tournament?['status'] ?? 'upcoming').toString().toLowerCase();
        final rawProofStatus = (_tournament?['proof_status'] ?? '').toString().toLowerCase();
        final proofUrl = (_tournament?['proof_url'] ?? '').toString().trim();
        final bool hasProofUploaded = proofUrl.isNotEmpty;

        // Exact user requirement: Proof upload ke baad approve ho chuka ho tabhi rewards aur win show hon
        final bool isProofApproved = rawProofStatus == 'approved' || rawProofStatus == 'accepted';
        final bool isCompletedWithWinner = rawStatus == 'completed';
        final bool isTournamentCompleted = isProofApproved || isCompletedWithWinner;

        final hasValidWinner = isTournamentCompleted &&
            ((_winnerTeamName != null && _winnerTeamName!.isNotEmpty) ||
             (_tournament?['winner_team_name'] != null && _tournament?['winner_team_name'].toString().isNotEmpty == true) ||
             (_tournament?['proof_team_name'] != null && _tournament?['proof_team_name'].toString().isNotEmpty == true));

        final winnerDisplay = _winnerTeamName ??
            _tournament?['winner_team_name']?.toString() ??
            _tournament?['proof_team_name']?.toString() ??
            'Champions';
        final tagDisplay = _winnerTeamTag != null && _winnerTeamTag!.isNotEmpty ? ' [$_winnerTeamTag]' : '';

        final maxTeams = _tournament?['max_teams'] ?? _tournament?['max_slots'] ?? 16;
        final currentTeams = _registrations.isNotEmpty
            ? _registrations.length
            : (_tournament?['current_teams'] ?? _tournament?['joined_teams_count'] ?? 0);

        // Check if current user is part of winning team
        final bool isUserInWinningTeam = isTournamentCompleted &&
            currentUid.isNotEmpty &&
            (_winnerMemberIds.contains(currentUid) ||
                (_winnerLeaderId != null && _winnerLeaderId == currentUid) ||
                (_winnerMemberIds.isEmpty &&
                    _winnerLeaderId == null &&
                    _registrations.any((r) =>
                        (r['leader_id']?.toString() == currentUid ||
                            r['user_id']?.toString() == currentUid) &&
                        (r['teams']?['name']?.toString().toLowerCase().trim() ==
                            _winnerTeamName?.toLowerCase().trim()))));

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: appBarBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPri, size: 20),
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
              IconButton(
                icon: const Icon(Icons.share_rounded, size: 20),
                color: accentGreen,
                tooltip: 'Share Tournament',
                onPressed: () {
                  AppShareService.shareTournament(
                    title: title,
                    game: game,
                    prize: '$prizePool Coins',
                    fee: entryFeeText,
                    map: mapName,
                  );
                },
              ),
            ],
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: accentGreen))
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
                              color: const Color(0xFF0077B6).withOpacity(isDark ? 0.3 : 0.2),
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
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isTournamentCompleted
                                            ? accentGreen
                                            : const Color(0xFFFFD700))
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isTournamentCompleted
                                          ? accentGreen
                                          : const Color(0xFFFFD700).withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    isTournamentCompleted ? 'COMPLETED' : (rawStatus.isNotEmpty ? rawStatus.toUpperCase() : 'UPCOMING'),
                                    style: TextStyle(
                                      color: isTournamentCompleted
                                          ? accentGreen
                                          : (isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309)),
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
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309),
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
                              style: TextStyle(
                                color: textPri,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  isTournamentCompleted
                                      ? Icons.check_circle_rounded
                                      : (rawStatus == 'upcoming'
                                          ? Icons.schedule_rounded
                                          : Icons.play_circle_filled_rounded),
                                  color: isTournamentCompleted
                                      ? accentGreen
                                      : accentSky,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    isTournamentCompleted
                                        ? 'Tournament Status: Successfully Completed'
                                        : (rawStatus == 'upcoming'
                                            ? 'Tournament Status: Upcoming & Open for Registration'
                                            : 'Tournament Status: Active & In Progress'),
                                    style: TextStyle(
                                      color: isTournamentCompleted
                                          ? accentGreen
                                          : accentSky,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildGridItem(
                                    icon: Icons.map_outlined,
                                    label: 'Map',
                                    value: mapName,
                                    isDark: isDark,
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
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildGridItem(
                                    icon: Icons.group_outlined,
                                    label: 'Slots',
                                    value: '$currentTeams / $maxTeams Teams',
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. Match Result & Win Proof
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
                              Text(
                                'Match Result & Win Proof',
                                style: TextStyle(
                                  color: textPri,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cardSec,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('🏆 ', style: TextStyle(fontSize: 18)),
                                        Text(
                                          'Tournament Completed',
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const Spacer(),
                                        // WIN Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: accentGreen.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: accentGreen),
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

                                    // Winning Team Name Displayed Prominently
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
                                      '• $prizePool Coins Awarded • +25 Points Added to Team Profile & Leaderboard',
                                      style: TextStyle(
                                        color: accentGreen,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                    // View Champions Ceremony Button
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
                      ] else if (hasProofUploaded) ...[
                        // Case 2: Proof Uploaded & Under Admin Review
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Match Result & Win Proof',
                                    style: TextStyle(
                                      color: textPri,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF8A00).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFF8A00)),
                                    ),
                                    child: const Text(
                                      'UNDER REVIEW',
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
                                  border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.5)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF8A00), size: 22),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Proof submitted and under admin review.',
                                                style: TextStyle(
                                                  color: Color(0xFFFF8A00),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Submitted by: ${(_tournament?['proof_team_name'] ?? 'Squad').toString()}',
                                                style: TextStyle(color: textSec, fontSize: 11.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (proofUrl.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: proofUrl,
                                          height: 130,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            height: 130,
                                            color: isDark ? Colors.black26 : Colors.black12,
                                            child: const Center(
                                              child: CircularProgressIndicator(color: Color(0xFFFF8A00), strokeWidth: 2),
                                            ),
                                          ),
                                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
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
                      ] else ...[
                        // Case 3: Proof NOT Uploaded Yet -> Option to Upload Match Proof
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Match Result & Win Proof',
                                    style: TextStyle(
                                      color: textPri,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00B4D8).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF00B4D8)),
                                    ),
                                    child: const Text(
                                      'PENDING PROOF',
                                      style: TextStyle(
                                        color: Color(0xFF00B4D8),
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
                                    color: isDark
                                        ? const Color(0xFF38BDF8).withOpacity(0.3)
                                        : const Color(0xFF0284C7).withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.cloud_upload_outlined, color: accentSky, size: 36),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No match proof uploaded yet',
                                      style: TextStyle(
                                        color: textPri,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'After match completes, submit winning screenshot for admin verification & prize rewards.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: textSec,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF00B4D8),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 2,
                                        ),
                                        icon: _isUploadingProof
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                              )
                                            : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                                        label: Text(
                                          _isUploadingProof ? 'Uploading Proof...' : 'Upload Win Proof 📸',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        onPressed: _isUploadingProof ? null : _pickAndUploadProof,
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Registered Squads',
                                  style: TextStyle(
                                    color: textPri,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  '$currentTeams / $maxTeams',
                                  style: TextStyle(
                                    color: accentGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_registrations.isEmpty) ...[
                              if (isTournamentCompleted && _winnerTeamName != null && _winnerTeamName!.isNotEmpty) ...[
                                _buildSquadItem(
                                  index: 1,
                                  name: _winnerTeamName!,
                                  slotNumber: 1,
                                  isWinner: true,
                                  teamId: _tournament?['winner_team_id']?.toString() ?? '',
                                  isDark: isDark,
                                ),
                              ] else ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'No registered squads found for this tournament',
                                    style: TextStyle(color: textSec, fontSize: 13),
                                  ),
                                ),
                              ],
                            ] else ...[
                              ..._registrations.asMap().entries.map((entry) {
                                final idx = entry.key + 1;
                                final reg = entry.value;
                                final teamObj = reg['teams'] as Map<String, dynamic>?;
                                final teamName = teamObj?['name']?.toString() ?? reg['team_name']?.toString() ?? 'Squad #$idx';
                                final slotNum = reg['slot_number'] ?? idx;
                                final teamId = reg['team_id']?.toString() ?? '';
                                final isWinner = isTournamentCompleted &&
                                    ((teamId.isNotEmpty &&
                                      (teamId == _tournament?['winner_team_id']?.toString() ||
                                       teamId == (_tournament?['proof_team_id']?.toString()))) ||
                                     (_winnerTeamName != null &&
                                      teamName.toLowerCase().trim() == _winnerTeamName!.toLowerCase().trim()));

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
        );
      },
    );
  }

  Widget _buildGridItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ThemeService.cardSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ThemeService.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: ThemeService.textPrimary,
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
    required bool isDark,
  }) {
    final cardColor = isWinner
        ? (isDark ? const Color(0xFFFFD700).withOpacity(0.12) : const Color(0xFFFFF9C4))
        : ThemeService.cardSecondary;
    final borderColor = isWinner ? const Color(0xFFFFD700) : ThemeService.border;
    final nameColor = isWinner
        ? (isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309))
        : ThemeService.textPrimary;

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
                  color: isDark ? const Color(0xFF00FF88) : const Color(0xFF00A855),
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
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
            ),
            const SizedBox(width: 8),
            Icon(Icons.shield_outlined, size: 16, color: ThemeService.textSecondary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
