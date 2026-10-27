// ===============================================================================
// TOURNAMENT DETAIL SCREEN — Match Info, Room Credentials, Win Proof & Squads
// File: lib/screens/tournament_detail_screen.dart
// ===============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'admin_bracket_screen.dart';
import '../widgets/victory_celebration_dialog.dart';
import '../services/theme_service.dart';

class TournamentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tournament;
  final bool isRegistered;

  const TournamentDetailScreen({
    super.key,
    required this.tournament,
    required this.isRegistered,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isUploadingProof = false;
  bool _hasShownCelebration = false;
  bool _isAdmin = false;
  List<Map<String, dynamic>> _registeredTeams = [];
  Map<String, dynamic>? _tournamentData;
  String _winnerTeamName = 'Champions Squad';
  String _runnerUpTeamName = 'Finalist Squad';

  @override
  void initState() {
    super.initState();
    _tournamentData = widget.tournament;
    _checkAdminStatus();
    _fetchDetails();
  }

  Future<void> _checkAdminStatus() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final userRes = await _supabase
          .from('users')
          .select('role')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (userRes != null && mounted) {
        final role = (userRes['role'] ?? '').toString().toLowerCase().trim();
        if (role == 'admin') {
          setState(() => _isAdmin = true);
          return;
        }
      }

      final email = currentUser.email?.toLowerCase() ?? '';
      if (email.contains('admin') && mounted) {
        setState(() => _isAdmin = true);
      }
    } catch (_) {
      final email = currentUser.email?.toLowerCase() ?? '';
      if (email.contains('admin') && mounted) {
        setState(() => _isAdmin = true);
      }
    }
  }

  Future<void> _fetchDetails() async {
    final tId = (_tournamentData?['id'] ?? widget.tournament['id'] ?? '').toString().trim();

    if (tId.isEmpty || tId == 'null' || tId.length < 10) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tRes = await _supabase
          .from('tournaments')
          .select()
          .eq('id', tId)
          .maybeSingle();

      if (tRes != null) {
        _tournamentData = Map<String, dynamic>.from(tRes);
      }

      final regRes = await _supabase
          .from('tournament_registrations')
          .select('id, registered_at, team_id, teams:teams(id, name, logo_url, leader_id, team_members(user_id))')
          .eq('tournament_id', tId)
          .order('registered_at', ascending: true);

      final registeredList = List<Map<String, dynamic>>.from(regRes);

      final winnerId = _tournamentData?['winner_team_id']?.toString();
      String resolvedWinner = 'Champions Squad';
      String resolvedRunnerUp = 'Finalist Squad';

      if (winnerId != null && winnerId.isNotEmpty) {
        for (final reg in registeredList) {
          final team = reg['teams'] as Map<String, dynamic>?;
          if (team != null) {
            if (team['id']?.toString() == winnerId) {
              resolvedWinner = team['name']?.toString() ?? 'Champions Squad';
            } else if (resolvedRunnerUp == 'Finalist Squad') {
              resolvedRunnerUp = team['name']?.toString() ?? 'Finalist Squad';
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _registeredTeams = registeredList;
          _winnerTeamName = resolvedWinner;
          _runnerUpTeamName = resolvedRunnerUp;
          _isLoading = false;
        });

        final status = (_tournamentData?['status'] ?? '').toString().toLowerCase();
        if (status == 'completed' && !_hasShownCelebration) {
          _hasShownCelebration = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showCelebrationPopup();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Error loading details: $e');
      }
    }
  }

  void _showCelebrationPopup() {
    final t = _tournamentData ?? widget.tournament;
    final title = (t['title'] ?? 'Tournament Match').toString();
    final prize = (t['prize_pool'] as num?)?.toInt() ?? 500;

    VictoryCelebrationDialog.show(
      context,
      tournamentTitle: title,
      winningTeamName: _winnerTeamName,
      prizeCoins: prize,
      runnerUpTeamName: _runnerUpTeamName,
      mvpPlayerName: 'Top Fragger',
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: const Color(0xFF00FF88),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleUploadWinProof() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    Map<String, dynamic>? myRegisteredTeam;
    for (final reg in _registeredTeams) {
      final t = reg['teams'] as Map<String, dynamic>?;
      if (t != null && t['leader_id']?.toString() == currentUserId) {
        myRegisteredTeam = t;
        break;
      }
    }

    if (myRegisteredTeam == null && !widget.isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only registered team leaders can submit win proof!'),
          backgroundColor: Color(0xFFFF4655),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    setState(() => _isUploadingProof = true);

    try {
      final tId = (_tournamentData?['id'] ?? widget.tournament['id']).toString();
      final bytes = await File(picked.path).readAsBytes();
      final ext = picked.path.split('.').last;
      final fileName = 'proof_${tId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from('posts').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = _supabase.storage.from('posts').getPublicUrl(fileName);

      final teamId = myRegisteredTeam?['id']?.toString() ??
          (_registeredTeams.isNotEmpty ? _registeredTeams.first['team_id']?.toString() : null);

      String teamName = 'Registered Squad';
      if (myRegisteredTeam != null && myRegisteredTeam['name'] != null) {
        teamName = myRegisteredTeam['name'].toString();
      } else if (_registeredTeams.isNotEmpty) {
        final firstTeam = _registeredTeams.first['teams'];
        if (firstTeam is Map && firstTeam['name'] != null) {
          teamName = firstTeam['name'].toString();
        }
      }

      final leaderIdentifier = _supabase.auth.currentUser?.email ?? 'Leader';

      await _supabase.from('tournaments').update({
        'proof_url': publicUrl,
        'proof_status': 'pending',
        'proof_reject_reason': null,
        'rejection_reason': null,
        'submitted_team_id': teamId,
        'proof_team_id': teamId,
        'proof_team_name': teamName,
        'proof_leader_name': leaderIdentifier,
        'submitted_at': DateTime.now().toIso8601String(),
      }).eq('id', tId);

      await _fetchDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Victory proof uploaded successfully! Admin will verify soon.'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload proof: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingProof = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        final currentUserId = _supabase.auth.currentUser?.id;

        bool isUserInRegisteredSquad = false;
        int assignedSlotNumber = 0;
        Map<String, dynamic>? myRegisteredTeam;

        for (int i = 0; i < _registeredTeams.length; i++) {
          final reg = _registeredTeams[i];
          final team = reg['teams'] as Map<String, dynamic>?;
          if (team != null) {
            final leaderId = team['leader_id']?.toString();
            final membersList = (team['team_members'] as List?) ?? [];
            final isMember = membersList.any((m) => m['user_id']?.toString() == currentUserId);

            if (leaderId == currentUserId || isMember) {
              isUserInRegisteredSquad = true;
              assignedSlotNumber = i + 2;
              myRegisteredTeam = team;
              break;
            }
          }
        }

        final bool hasSquadAccess = widget.isRegistered || isUserInRegisteredSquad;

        final t = _tournamentData ?? widget.tournament;
        final title = (t['title'] ?? 'Tournament Match').toString();
        final gameMode = (t['game_mode'] ?? 'Squad (4v4)').toString();
        final mapName = (t['map_name'] ?? 'Erangel').toString();
        final fee = (t['entry_fee'] ?? 0).toString();
        final prize = (t['prize_pool'] ?? 0).toString();
        final maxTeams = (t['max_teams'] ?? 16) as int;
        final currentTeams = (t['current_teams'] ?? _registeredTeams.length) as int;
        final status = (t['status'] ?? 'upcoming').toString().toUpperCase();
        final roomId = (t['room_id'] ?? '').toString().trim();
        final roomPass = (t['room_password'] ?? '').toString().trim();
        final proofUrl = (t['proof_url'] ?? '').toString().trim();
        final proofRejectReason = (t['rejection_reason'] ?? t['proof_reject_reason'] ?? '').toString().trim();
        final submittedTeamId = (t['submitted_team_id'] ?? t['proof_team_id'] ?? '').toString();
        final isCompleted = status.toLowerCase() == 'completed';

        String matchTimeStr = 'TBD';
        if (t['match_time'] != null && t['match_time'].toString().isNotEmpty) {
          try {
            final parsed = DateTime.parse(t['match_time'].toString()).toLocal();
            matchTimeStr = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
          } catch (_) {
            matchTimeStr = t['match_time'].toString();
          }
        }

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
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ThemeService.textPrimary),
            ),
            actions: [
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.account_tree_rounded, color: Color(0xFF00FF88)),
                  tooltip: 'Manage Tournament Bracket',
                  onPressed: () {
                    final tId = (_tournamentData?['id'] ?? widget.tournament['id']).toString();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminBracketScreen(tournamentId: tId),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _fetchDetails,
            color: const Color(0xFF00FF88),
            backgroundColor: ThemeService.card,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ThemeService.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? const Color(0xFFFFD700).withOpacity(0.15)
                                    : const Color(0xFF00FF88).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCompleted
                                      ? const Color(0xFFFFD700).withOpacity(0.4)
                                      : const Color(0xFF00FF88).withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: isCompleted ? const Color(0xFFFFD700) : const Color(0xFF00FF88),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '$prize Coins',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, color: ThemeService.textSecondary, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              'Match Time: $matchTimeStr',
                              style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildInfoTile(Icons.sports_esports_rounded, 'Mode', gameMode)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildInfoTile(Icons.map_rounded, 'Map', mapName)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildInfoTile(Icons.payments_rounded, 'Entry Fee', '$fee Coins')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildInfoTile(Icons.groups_rounded, 'Slots', '$currentTeams / $maxTeams Teams')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Custom Room Credentials',
                    style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (!hasSquadAccess)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ThemeService.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ThemeService.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_rounded, color: Color(0xFFFF8A00), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Room ID & Password will be unlocked once your squad is registered.',
                              style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (roomId.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ThemeService.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ThemeService.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, color: Color(0xFF38BDF8), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Host has not shared Room ID yet. Check back 10-15 minutes before match time.',
                              style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ThemeService.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ROOM ID', style: TextStyle(color: ThemeService.textSecondary, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    roomId,
                                    style: const TextStyle(
                                      color: Color(0xFF00FF88),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: Color(0xFF00FF88), size: 20),
                                onPressed: () => _copyToClipboard(roomId, 'Room ID'),
                              ),
                            ],
                          ),
                          Divider(color: ThemeService.border, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PASSWORD', style: TextStyle(color: ThemeService.textSecondary, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    roomPass.isNotEmpty ? roomPass : 'No Password',
                                    style: TextStyle(
                                      color: ThemeService.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              if (roomPass.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.copy_rounded, color: ThemeService.textSecondary, size: 20),
                                  onPressed: () => _copyToClipboard(roomPass, 'Password'),
                                ),
                            ],
                          ),
                          if (assignedSlotNumber > 0) ...[
                            Divider(color: ThemeService.border, height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF88).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.pin_drop_rounded, color: Color(0xFF00FF88), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(color: ThemeService.textPrimary, fontSize: 12),
                                        children: [
                                          const TextSpan(text: 'Assigned Spot: '),
                                          TextSpan(
                                            text: 'SLOT #$assignedSlotNumber',
                                            style: const TextStyle(
                                              color: Color(0xFF00FF88),
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' (Room me poori squad yahan baithe)',
                                            style: TextStyle(
                                              color: ThemeService.textSecondary,
                                              fontSize: 10.5,
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
                  const SizedBox(height: 24),
                  Text(
                    'Match Result & Win Proof',
                    style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (isCompleted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ThemeService.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.military_tech_rounded, color: Color(0xFFFFD700), size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tournament Completed 🏆',
                                      style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Champion: $_winnerTeamName • $prize Coins Awarded',
                                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD700),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.celebration_rounded, color: Colors.black, size: 20),
                              label: const Text(
                                'View Champions Ceremony 👑',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                              onPressed: _showCelebrationPopup,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (proofRejectReason.isNotEmpty && proofUrl.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ThemeService.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.cancel_rounded, color: Color(0xFFFF4655), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Proof Rejected by Admin',
                                style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Reason: $proofRejectReason',
                            style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          if (hasSquadAccess)
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: _isUploadingProof ? null : _handleUploadWinProof,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF4655),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.upload_file_rounded, size: 16),
                                label: const Text(
                                  'Re-upload Valid Screenshot',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else if (proofUrl.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ThemeService.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF8A00), size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Proof Under Review',
                                    style: TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              // 🔒 SECURE FIX: Sirf Admin ya wahi submitting team members/leader "Change Proof" dekh sakein ge
                              if (_isAdmin || (() {
                                bool isTeamMatch = false;
                                if (submittedTeamId.isNotEmpty) {
                                  for (final reg in _registeredTeams) {
                                    final team = reg['teams'] as Map<String, dynamic>?;
                                    if (team != null && team['id']?.toString() == submittedTeamId) {
                                      final leaderId = team['leader_id']?.toString();
                                      final membersList = (team['team_members'] as List?) ?? [];
                                      final isMember = membersList.any((m) => m['user_id']?.toString() == currentUserId);
                                      if (leaderId == currentUserId || isMember) {
                                        isTeamMatch = true;
                                      }
                                      break;
                                    }
                                  }
                                }
                                return isTeamMatch;
                              })())
                                TextButton.icon(
                                  onPressed: _isUploadingProof ? null : _handleUploadWinProof,
                                  icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF38BDF8)),
                                  label: const Text('Change Proof', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: proofUrl,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const SizedBox(
                                height: 140,
                                child: Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
                              ),
                              errorWidget: (_, __, ___) => Center(
                                child: Icon(Icons.broken_image_rounded, color: ThemeService.textSecondary.withOpacity(0.4), size: 36),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Admin is verifying this screenshot. Prize will be sent once approved.',
                            style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    )
                  else if (hasSquadAccess)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ThemeService.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ThemeService.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Did your squad win this match?',
                            style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upload your end-game victory (#1 Winner) screenshot here to claim the prize pool.',
                            style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _isUploadingProof ? null : _handleUploadWinProof,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FF88),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: _isUploadingProof
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.emoji_events_rounded, size: 18),
                              label: Text(
                                _isUploadingProof ? 'Uploading Proof...' : 'Upload Win Screenshot 🏆',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ThemeService.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ThemeService.border),
                      ),
                      child: Text(
                        'Win proof submissions are only open for participating squad leaders.',
                        style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Registered Squads',
                        style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_registeredTeams.length} / $maxTeams',
                        style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                      ),
                    )
                  else if (_registeredTeams.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ThemeService.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text('No squads registered yet.', style: TextStyle(color: ThemeService.textSecondary)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _registeredTeams.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _registeredTeams[index];
                        final team = item['teams'] as Map<String, dynamic>?;
                        final teamName = team?['name']?.toString() ?? 'Squad #${index + 1}';
                        final isThisWinner = isCompleted && team?['id']?.toString() == _tournamentData?['winner_team_id']?.toString();
                        final slotForThisSquad = index + 2;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: ThemeService.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isThisWinner ? const Color(0xFFFFD700).withOpacity(0.6) : ThemeService.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isThisWinner
                                      ? const Color(0xFFFFD700).withOpacity(0.2)
                                      : const Color(0xFF00FF88).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isThisWinner ? '👑' : '#${index + 1}',
                                  style: TextStyle(
                                    color: isThisWinner ? const Color(0xFFFFD700) : const Color(0xFF00FF88),
                                    fontWeight: FontWeight.bold,
                                    fontSize: isThisWinner ? 14 : 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      teamName,
                                      style: TextStyle(
                                        color: isThisWinner ? const Color(0xFFFFD700) : ThemeService.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Slot: #$slotForThisSquad',
                                      style: TextStyle(
                                        color: ThemeService.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isThisWinner)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFFD700)),
                                  ),
                                  child: const Text(
                                    'CHAMPION',
                                    style: TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                )
                              else
                                Icon(Icons.shield_outlined, color: ThemeService.textSecondary.withOpacity(0.5), size: 18),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeService.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: ThemeService.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
