import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../constants/gamer_theme.dart';
import '../../models/team_match_model.dart';
import '../../services/team_match_service.dart';
import '../../services/supabase_service.dart';
import '../team_match_room_screen.dart';

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
    switch (status) {
      case 'Pending':
        return const Color(0xFFFFB020);
      case 'Accepted':
        return const Color(0xFF00FF88);
      case 'Live':
        return const Color(0xFFFF4655);
      case 'Proof Submitted':
        return const Color(0xFF38BDF8);
      case 'Verified':
        return const Color(0xFF00FF88);
      case 'Disputed':
        return const Color(0xFFFF4655);
      case 'Rejected':
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
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (c, u) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                errorWidget: (c, u, e) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image, color: Colors.white30))),
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
          title: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF00FF88), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('verify_match_winner_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'select_winner_after_proof_instruction'.tr(),
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
                ),
                const SizedBox(height: 14),

                // Team 1 Option
                RadioListTile<String>(
                  value: match.team1Id,
                  groupValue: selectedWinner,
                  activeColor: const Color(0xFF00FF88),
                  title: Text(
                    match.team1Name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${'claim_label'.tr()}:${match.team1Claim ?? "none_label".tr()}',
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                  onChanged: (val) => setDialogState(() => selectedWinner = val),
                ),

                // Team 2 Option
                RadioListTile<String>(
                  value: match.team2Id,
                  groupValue: selectedWinner,
                  activeColor: const Color(0xFF00FF88),
                  title: Text(
                    match.team2Name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${'claim_label'.tr()}:${match.team2Claim ?? "none_label".tr()}',
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                  onChanged: (val) => setDialogState(() => selectedWinner = val),
                ),

                // Draw Option
                RadioListTile<String>(
                  value: 'DRAW',
                  groupValue: selectedWinner,
                  activeColor: const Color(0xFFFFB020),
                  title: Text('draw_option_label'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onChanged: (val) => setDialogState(() => selectedWinner = val),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'admin_notes_optional_label'.tr(),
                    labelStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF10141D),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
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
                  // 1. Verify match via existing service
                  await _matchService.adminVerifyMatch(
                    matchId: match.matchId,
                    winnerTeamId: winner,
                    adminId: 'Admin',
                    adminIdentifier: 'Admin',
                    note: notesController.text.trim(),
                    notes: notesController.text.trim(),
                  );

                  // 2. ✅ Auto-update `teams` table (Wins, Losses, Draws)
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
                    // Winner team: wins + 1
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

                    // Loser team: losses + 1
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
                      SnackBar(
                        content: Text('match_verified_leaderboard_success'.tr()),
                        backgroundColor: const Color(0xFF00FF88),
                      ),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  debugPrint('Error updating teams table stats: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${'error_updating_leaderboard'.tr()}:$e'),
                        backgroundColor: const Color(0xFFFF4655),
                      ),
                    );
                  }
                }
              },
              child: Text('confirm_winner_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Color(0xFFFF4655), size: 22),
            const SizedBox(width: 8),
            Text('reject_match_proof_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              match.proofAttempts >= 1
                  ? 'reject_proof_second_attempt_warning'.tr(args: [(match.proofAttempts + 1).toString()])
                  : 'reject_proof_first_attempt_warning'.tr(),
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'write_admin_reason_label'.tr(),
                hintText: 'admin_reason_hint_example'.tr(),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                labelStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF10141D),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = reasonController.text.trim().isEmpty
                  ? 'admin_default_reject_reason'.tr()
                  : reasonController.text.trim();
              Navigator.pop(ctx);
              await _matchService.adminRejectMatch(
                match.matchId,
                'Admin',
                reason: reason,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('match_proof_rejected_snackbar'.tr()),
                    backgroundColor: const Color(0xFFFF4655),
                  ),
                );
              }
            },
            child: Text('reject_proof_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
        title: Row(
          children: [
            const Icon(Icons.replay_rounded, color: Color(0xFFFF6B00), size: 22),
            const SizedBox(width: 8),
            Text('request_new_proof_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'request_new_proof_desc'.tr(),
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'write_admin_reason_label'.tr(),
                hintText: 'request_proof_hint_example'.tr(),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                labelStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF10141D),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
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
                  SnackBar(
                    content: Text('request_new_proof_sent_snackbar'.tr()),
                    backgroundColor: const Color(0xFFFF6B00),
                  ),
                );
              }
            },
            child: Text('send_request_proof_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Stream<_AdminMatchUnifiedData> _getUnifiedMatchesStream() async* {
    while (true) {
      try {
        final matchesList = await SupabaseService.getTeamMatches(status: _selectedFilter);
        final matches = matchesList.map((m) => TeamMatch.fromMap(m)).toList();

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

        try {
          final activeRes = await SupabaseService.client
              .from('active_matches')
              .select()
              .eq('status', 'disputed')
              .order('created_at', ascending: false);
          if (activeRes is List) {
            for (final a in activeRes) {
              final aId = a['id']?.toString() ?? '';
              if (!reports.any((r) => (r['target_id']?.toString() ?? '') == aId)) {
                reports.add({
                  'id': 'active_dispute_$aId',
                  'target_id': aId,
                  'target_type': 'match',
                  'reporter_username': a['disputed_by']?.toString() ?? 'Gamer',
                  'reason': a['dispute_reason']?.toString() ?? 'Room match disputed by player',
                  'proof_url': a['dispute_proof_url']?.toString() ?? a['proof_url']?.toString(),
                  'created_at': a['disputed_at']?.toString() ?? a['created_at']?.toString(),
                  'status': 'pending',
                });
              }
            }
          }
        } catch (e) {
          debugPrint('[AdminTeamMatches] Error loading disputed active_matches: $e');
        }

        yield _AdminMatchUnifiedData(
          matches: matches,
          disputeReports: reports,
        );
      } catch (_) {
        yield _AdminMatchUnifiedData(matches: [], disputeReports: []);
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
          SnackBar(
            content: Text('dispute_report_resolved_snackbar'.tr()),
            backgroundColor: const Color(0xFF00FF88),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'error_resolving_dispute'.tr()}:$e'),
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
        : 'recently_label'.tr();

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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFF4655)),
                    const SizedBox(width: 4),
                    Text(
                      'match_dispute_report_badge'.tr(),
                      style: const TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.w900, fontSize: 11),
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
                child: Text(
                  'disputed_priority_badge'.tr(),
                  style: const TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.w900, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 16, color: Color(0xFF8B949E)),
              const SizedBox(width: 
