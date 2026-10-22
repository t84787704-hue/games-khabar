// ═══════════════════════════════════════════════════════════════════════════════
// ADMIN TEAM MATCHES SCREEN — Unified Live Proofs & Disputes
// File: lib/screens/admin/admin_team_matches_screen.dart
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../constants/gamer_theme.dart';
import '../../models/team_match_model.dart';
import '../../services/team_match_service.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';
import '../team_match_room_screen.dart';

class _AdminMatchUnifiedData {
  final List<TeamMatch> matches;
  final List<Map<String, dynamic>> disputeReports;

  const _AdminMatchUnifiedData({
    this.matches = const [],
    this.disputeReports = const [],
  });
}

class AdminTeamMatchesScreen extends StatefulWidget {
  const AdminTeamMatchesScreen({super.key});

  @override
  State<AdminTeamMatchesScreen> createState() => _AdminTeamMatchesScreenState();
}

class _AdminTeamMatchesScreenState extends State<AdminTeamMatchesScreen> {
  final TeamMatchService _matchService = TeamMatchService();
  String _selectedFilter = 'All';

  final List<String> _filterOptions = [
    'All',
    'Disputed',
    'Proof Submitted',
    'Live',
    'Accepted',
    'Pending',
    'Verified',
    'Rejected',
  ];

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFB020);
      case 'accepted':
        return const Color(0xFF00FF88);
      case 'live':
        return const Color(0xFFFF4655);
      case 'proof submitted':
      case 'proof_submitted':
      case 'review_pending':
        return const Color(0xFF38BDF8);
      case 'verified':
      case 'completed':
        return const Color(0xFF00FF88);
      case 'disputed':
      case 'under_review':
        return const Color(0xFFFF4655);
      case 'rejected':
        return Colors.grey;
      default:
        return const Color(0xFFFF6B00);
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (c, u) => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
                  errorWidget: (c, u, e) => const SizedBox(height: 220, child: Center(child: Icon(Icons.broken_image, color: Colors.white30))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerifyDecisionDialog(BuildContext context, TeamMatch match) {
    String? selectedWinner = match.team1Id;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161F2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF00FF88), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text('Verify Match Winner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select the winning team after verifying screenshot proofs:',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
                ),
                const SizedBox(height: 14),

                RadioListTile<String>(
                  value: match.team1Id,
                  groupValue: selectedWinner,
                  activeColor: const Color(0xFF00FF88),
                  title: Text(
                    match.team1Name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Claim: ${match.team1Claim ?? "None"}',
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                  onChanged: (val) => setDialogState(() => selectedWinner = val),
                ),

                RadioListTile<String>(
                  value: match.team2Id,
                  groupValue: selectedWinner,
                  activeColor: const Color(0xFF00FF88),
                  title: Text(
                    match.team2Name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Claim: ${match.team2Claim ?? "None"}',
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                  onChanged: (val) => setDialogState(() => selectedWinner = val),
                ),

                RadioListTile<String>(
                  value: 'DRAW',
                  groupValue: selectedWinner,
                  activeColor: const Color(0xFFFFB020),
                  title: const Text('Draw / Tie Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onChanged: (val) => setDialogState(() => selectedWinner = val),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Admin Note (Optional)',
                    labelStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    filled: true,
                    fillColor: Color(0xFF10141D),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                if (selectedWinner == null) return;
                final winner = selectedWinner!;
                Navigator.pop(ctx);

                try {
                  await _matchService.adminVerifyMatch(
                    matchId: match.matchId,
                    winnerTeamId: winner,
                    adminId: 'Admin',
                    adminIdentifier: 'Admin',
                    note: notesController.text.trim(),
                    notes: notesController.text.trim(),
                  );

                  if (winner == 'DRAW') {
                    for (final tId in [match.team1Id, match.team2Id]) {
                      if (tId.isNotEmpty) {
                        final res = await SupabaseService.client
                            .from('teams')
                            .select('draws')
                            .eq('id', tId)
                            .maybeSingle();
                        final int cur = (res?['draws'] as num?)?.toInt() ?? 0;
                        await SupabaseService.client
                            .from('teams')
                            .update({'draws': cur + 1})
                            .eq('id', tId);
                      }
                    }
                  } else {
                    final winnerRes = await SupabaseService.client
                        .from('teams')
                        .select('wins')
                        .eq('id', winner)
                        .maybeSingle();
                    final int curWins = (winnerRes?['wins'] as num?)?.toInt() ?? 0;
                    await SupabaseService.client
                        .from('teams')
                        .update({'wins': curWins + 1})
                        .eq('id', winner);

                    final loserId = (winner == match.team1Id) ? match.team2Id : match.team1Id;
                    if (loserId.isNotEmpty) {
                      final loserRes = await SupabaseService.client
                          .from('teams')
                          .select('losses')
                          .eq('id', loserId)
                          .maybeSingle();
                      final int curLosses = (loserRes?['losses'] as num?)?.toInt() ?? 0;
                      await SupabaseService.client
                          .from('teams')
                          .update({'losses': curLosses + 1})
                          .eq('id', loserId);
                    }
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Match verified and stats updated on leaderboard!'),
                        backgroundColor: Color(0xFF00FF88),
                      ),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  debugPrint('Error updating teams table stats: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating leaderboard: $e'),
                        backgroundColor: const Color(0xFFFF4655),
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirm Winner', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, TeamMatch match) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFFF4655), size: 22),
            SizedBox(width: 8),
            Text('Reject Match Proof', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              match.proofAttempts >= 1
                  ? 'Proof rejected on attempt ${match.proofAttempts + 1}.'
                  : 'Reject submitted proof and request team to re-upload clear screenshot.',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'e.g. Screenshot blurry, scores mismatch...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                labelStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                filled: true,
                fillColor: Color(0xFF10141D),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = reasonController.text.trim().isEmpty
                  ? 'Screenshot proof is invalid or unclear. Please re-upload.'
                  : reasonController.text.trim();
              Navigator.pop(ctx);
              await _matchService.adminRejectMatch(
                match.matchId,
                'Admin',
                reason: reason,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Match proof rejected. Teams notified to re-upload.'),
                    backgroundColor: Color(0xFFFF4655),
                  ),
                );
              }
            },
            child: const Text('Reject Proof', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRequestNewProofDialog(BuildContext context, TeamMatch match) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.replay_rounded, color: Color(0xFFFF6B00), size: 22),
            SizedBox(width: 8),
            Text('Request New Proof', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ask teams to provide another screenshot proof with full scoreboard visible.',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Reason for request',
                hintText: 'e.g. Please show the final results screen',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                labelStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                filled: true,
                fillColor: Color(0xFF10141D),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              await _matchService.adminRequestNewProof(
                match.matchId,
                'Admin',
                reason: reason,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request for new proof sent to team captains.'),
                    backgroundColor: Color(0xFFFF6B00),
                  ),
                );
              }
            },
            child: const Text('Send Request', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Stream<_AdminMatchUnifiedData> _getUnifiedMatchesStream() async* {
    while (true) {
      try {
        final List<TeamMatch> matches = [];

        // 1. Fetch from team_matches table
        try {
          final res = await SupabaseService.client
              .from('team_matches')
              .select()
              .order('created_at', ascending: false);
          if (res is List) {
            for (final m in res) {
              try {
                matches.add(TeamMatch.fromMap(m));
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('[AdminTeamMatches] Error loading team_matches: $e');
        }

        // 2. Fetch team rooms / 2v2 / 4v4 format rooms from rooms table
        try {
          final roomRes = await SupabaseService.client
              .from('rooms')
              .select()
              .or('mode.ilike.%2v2%,mode.ilike.%4v4%,mode.ilike.%team%,total_slots.gte.4')
              .order('created_at', ascending: false);

          if (roomRes is List) {
            for (final r in roomRes) {
              final rId = (r['id'] ?? '').toString();
              if (matches.any((m) => m.matchId == rId)) continue;

              final winProof = (r['win_proof_url'] ?? r['proof_url'])?.toString() ?? '';
              final rawStatus = (r['status'] ?? 'active').toString();
              final isDisputed = r['disputed'] == true || rawStatus == 'disputed' || rawStatus == 'under_review';
              final isProofSubmitted = winProof.isNotEmpty;

              String mappedStatus = 'Live';
              if (isDisputed) {
                mappedStatus = 'Disputed';
              } else if (isProofSubmitted || rawStatus == 'review_pending' || rawStatus == 'proof_submitted') {
                mappedStatus = 'Proof Submitted';
              } else if (rawStatus == 'completed') {
                mappedStatus = 'Verified';
              } else if (rawStatus == 'rejected') {
                mappedStatus = 'Rejected';
              }

              final Map<String, dynamic> matchMap = {
                'match_id': rId,
                'id': rId,
                'team1_id': (r['host_id'] ?? '').toString(),
                'team1_name': (r['host_name'] ?? 'Host Team').toString(),
                'team1_leader_id': (r['host_id'] ?? '').toString(),
                'team1_leader_name': (r['host_name'] ?? 'Host').toString(),
                'team2_id': (r['winner_id'] ?? 'opponent').toString(),
                'team2_name': (r['winner_name'] ?? 'Opponent Team').toString(),
                'team2_leader_id': (r['winner_id'] ?? '').toString(),
                'team2_leader_name': (r['winner_name'] ?? 'Opponent').toString(),
                'game': (r['game'] ?? 'BGMI').toString(),
                'mode': (r['mode'] ?? 'TDM').toString(),
                'status': mappedStatus,
                'match_status': mappedStatus,
                'match_time': r['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'created_at': r['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'team1_proof': winProof,
                'proof_url': winProof,
                'team2_proof': (r['dispute_proof_url'] ?? r['second_proof_url'])?.toString() ?? '',
                'dispute_reason': (r['dispute_reason'] ?? '').toString(),
                'winner_name': r['winner_name']?.toString() ?? '',
              };

              try {
                matches.add(TeamMatch.fromMap(matchMap));
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('[AdminTeamMatches] Error loading rooms: $e');
        }

        // 3. Fetch dispute reports
        List<Map<String, dynamic>> reports = [];
        try {
          final reportsRes = await SupabaseService.client
              .from('reports')
              .select()
              .eq('target_type', 'match')
              .eq('status', 'pending')
              .order('created_at', ascending: false);
          if (reportsRes is List) {
            reports = List<Map<String, dynamic>>.from(reportsRes);
          }
        } catch (e) {
          debugPrint('[AdminTeamMatches] Error loading reports: $e');
        }

        yield _AdminMatchUnifiedData(
          matches: matches,
          disputeReports: reports,
        );
      } catch (_) {
        yield const _AdminMatchUnifiedData(matches: [], disputeReports: []);
      }
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Future<void> _resolveDisputeReport(Map<String, dynamic> report) async {
    final reportId = report['id']?.toString() ?? '';
    final targetId = report['target_id']?.toString() ?? '';

    try {
      if (!reportId.startsWith('active_dispute_')) {
        await SupabaseService.client
            .from('reports')
            .update({'status': 'resolved'})
            .eq('id', reportId);
      }

      if (targetId.isNotEmpty) {
        try {
          await SupabaseService.client
              .from('active_matches')
              .update({'status': 'under_review'})
              .eq('id', targetId);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispute marked as resolved!'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resolving dispute: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  Widget _buildDisputeReportCard(Map<String, dynamic> report) {
    final targetId = report['target_id']?.toString() ?? '';
    final reporterName = report['reporter_username']?.toString() ??
        report['reporter_name']?.toString() ??
        'Gamer';
    final reason = report['reason']?.toString() ??
        report['target_content']?.toString() ??
        'Match outcome disputed';
    final proofUrl = report['proof_url']?.toString() ??
        report['dispute_proof_url']?.toString() ??
        '';
    final rawDate = report['created_at']?.toString();
    DateTime? dt;
    if (rawDate != null && rawDate.isNotEmpty) {
      dt = DateTime.tryParse(rawDate)?.toLocal();
    }
    final formattedTime = dt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(dt)
        : 'Recently';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1522),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4655).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFF4655)),
                    SizedBox(width: 4),
                    Text(
                      'MATCH DISPUTE',
                      style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4655).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF4655)),
                ),
                child: const Text(
                  'PRIORITY',
                  style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.w900, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 16, color: Color(0xFF8B949E)),
              const SizedBox(width: 6),
              Text(
                'Reporter: $reporterName',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (targetId.isNotEmpty) ...[
                const Spacer(),
                Text(
                  'ID: ${targetId.length > 8 ? targetId.substring(0, 8) : targetId}',
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4655).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFFF4655), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reason: $reason',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reported: $formattedTime',
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF2A3447), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (proofUrl.isNotEmpty) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                  icon: const Icon(Icons.image_outlined, size: 14),
                  label: const Text('View Proof', style: TextStyle(fontSize: 11)),
                  onPressed: () => _showImageDialog(context, proofUrl, 'Dispute Proof Screenshot'),
                ),
                const SizedBox(width: 8),
              ],
              if (targetId.isNotEmpty) ...[
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Match Room', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamMatchRoomScreen(matchId: targetId),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 30),
                  elevation: 0,
                ),
                onPressed: () => _resolveDisputeReport(report),
                child: const Text('Resolve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Chips Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFF131A29),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((f) {
                final isSel = _selectedFilter == f;
                final isDisputed = f == 'Disputed';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      isDisputed ? 'disputed_chip_priority'.tr() : f,
                      style: TextStyle(
                        color: isSel ? Colors.black : (isDisputed ? const Color(0xFFFF4655) : Colors.white),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: isDisputed ? const Color(0xFFFF4655) : const Color(0xFF00FF88),
                    backgroundColor: const Color(0xFF1A2234),
                    onSelected: (val) {
                      setState(() => _selectedFilter = f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Stream List of Matches & Reports
        Expanded(
          child: StreamBuilder<_AdminMatchUnifiedData>(
            stream: _getUnifiedMatchesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
              }

              final unifiedData = snapshot.data ?? const _AdminMatchUnifiedData(matches: [], disputeReports: []);
              final allMatches = unifiedData.matches;
              final showDisputes = _selectedFilter == 'All' || _selectedFilter == 'Disputed';
              final visibleReports = showDisputes ? unifiedData.disputeReports : <Map<String, dynamic>>[];

              // Filter matching logic (tolerant case & multi-status)
              final visibleMatches = allMatches.where((m) {
                if (_selectedFilter == 'All') return true;
                if (_selectedFilter == 'Disputed') return m.isDisputed;
                if (_selectedFilter == 'Proof Submitted') {
                  return m.isProofSubmitted ||
                      (m.team1Proof != null && m.team1Proof!.isNotEmpty) ||
                      (m.team2Proof != null && m.team2Proof!.isNotEmpty);
                }
                return m.status.toLowerCase() == _selectedFilter.toLowerCase();
              }).toList();

              if (visibleReports.isEmpty && visibleMatches.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sports_esports_rounded, size: 48, color: Color(0xFF8B949E)),
                      const SizedBox(height: 12),
                      Text(
                        'no_matches_found_filter'.tr(args: [_selectedFilter]),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: visibleReports.length + visibleMatches.length,
                itemBuilder: (context, index) {
                  if (index < visibleReports.length) {
                    return _buildDisputeReportCard(visibleReports[index]);
                  }

                  final match = visibleMatches[index - visibleReports.length];
                  final statusColor = _getStatusColor(match.status);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: match.isDisputed ? const Color(0xFF1F1522) : const Color(0xFF131A29),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: match.isDisputed ? const Color(0xFFFF4655) : const Color(0xFF2A3447),
                        width: match.isDisputed ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header: Game, Mode, Status
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${match.game} • ${match.mode}',
                                style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.w900, fontSize: 11),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                match.status.toUpperCase(),
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Match Teams
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    match.team1Name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text('Leader: ${match.team1LeaderName}', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('VS', style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.w900, fontSize: 14)),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    match.team2Name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                  ),
                                  Text('Leader: ${match.team2LeaderName}', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(match.matchTime)}',
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5),
                        ),

                        if (match.team1Proof != null || match.team2Proof != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Color(0xFF38BDF8), size: 16),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Screenshot proof available for review',
                                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (match.disputeReason.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4655).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFFFF4655), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    match.disputeReason,
                                    style: const TextStyle(color: Color(0xFFFF4655), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (match.isVerified && match.winnerName != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '🏆 Winner: ${match.winnerName} (${match.verifiedBy ?? "Admin"})',
                            style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],

                        const SizedBox(height: 12),
                        const Divider(color: Color(0xFF2A3447), height: 1),
                        const SizedBox(height: 10),

                        // Action Buttons & Proof Viewers
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (match.team1Proof != null && match.team1Proof!.isNotEmpty) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF38BDF8),
                                  side: const BorderSide(color: Color(0xFF38BDF8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 30),
                                ),
                                icon: const Icon(Icons.image_outlined, size: 14),
                                label: Text(
                                  '${match.team1Name} Proof',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () => _showImageDialog(
                                  context,
                                  match.team1Proof!,
                                  '${match.team1Name} Match Proof',
                                ),
                              ),
                            ],

                            if (match.team2Proof != null && match.team2Proof!.isNotEmpty) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF38BDF8),
                                  side: const BorderSide(color: Color(0xFF38BDF8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 30),
                                ),
                                icon: const Icon(Icons.image_outlined, size: 14),
                                label: Text(
                                  '${match.team2Name} Proof',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () => _showImageDialog(
                                  context,
                                  match.team2Proof!,
                                  '${match.team2Name} Match Proof',
                                ),
                              ),
                            ],

                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 30),
                              ),
                              icon: const Icon(Icons.open_in_new_rounded, size: 14),
                              label: const Text('Room & Chat', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TeamMatchRoomScreen(matchId: match.matchId),
                                  ),
                                );
                              },
                            ),

                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!match.isRejected) ...[
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFFF4655),
                                      side: const BorderSide(color: Color(0xFFFF4655)),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 30),
                                    ),
                                    onPressed: () => _showRejectDialog(context, match),
                                    child: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 6),
                                ],

                                if (!match.isVerified && match.proofAttempts < 2) ...[
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFFF6B00),
                                      side: const BorderSide(color: Color(0xFFFF6B00)),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 30),
                                    ),
                                    icon: const Icon(Icons.replay_rounded, size: 13),
                                    label: const Text('Request Proof', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    onPressed: () => _showRequestNewProofDialog(context, match),
                                  ),
                                  const SizedBox(width: 6),
                                ],

                                if (!match.isVerified) ...[
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00FF88),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(0, 30),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _showVerifyDecisionDialog(context, match),
                                    child: const Text('Verify Winner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
