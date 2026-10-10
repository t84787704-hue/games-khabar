import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/team_model.dart';
import '../../services/supabase_service.dart';
import '../../services/team_service.dart';

// ============================================================
// TAB 1: UNDER REVIEW
// Jo proofs abhi review mein hain
// ============================================================
class AdminUnderReviewTab extends StatelessWidget {
  const AdminUnderReviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('active_matches')
          .stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Could not load under-review proofs', snapshot.error);
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00FF88)),
          );
        }

        final all = snapshot.data ?? [];
        final underReview = all.where((m) {
          final st = (m['status'] ?? '').toString().toLowerCase();
          final pst = (m['proof_status'] ?? '').toString().toLowerCase();
          return st == 'under_review' && (pst == 'pending' || pst.isEmpty);
        }).toList();

        underReview.sort((a, b) {
          final aDate = a['ended_at'] ?? a['created_at'] ?? '';
          final bDate = b['ended_at'] ?? b['created_at'] ?? '';
          return bDate.toString().compareTo(aDate.toString());
        });

        if (underReview.isEmpty) {
          return _buildEmptyState(
            icon: Icons.fact_check_rounded,
            title: 'No Proofs Under Review',
            subtitle: 'All match proofs have been reviewed.',
            color: const Color(0xFF00FF88),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          itemCount: underReview.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return AdminProofCard(
              match: underReview[index],
              showActions: true,
              showDelete: false,
            );
          },
        );
      },
    );
  }
}

// ============================================================
// TAB 2: HISTORY (Accepted + Rejected)
// Jo proofs accept ya reject ho chuke
// ============================================================
class AdminProofHistoryTab extends StatefulWidget {
  const AdminProofHistoryTab({super.key});

  @override
  State<AdminProofHistoryTab> createState() => _AdminProofHistoryTabState();
}

class _AdminProofHistoryTabState extends State<AdminProofHistoryTab> {
  String _filter = 'All'; // All, Accepted, Rejected

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _buildFilterChip('All', Icons.list_alt_rounded, const Color(0xFF8B949E)),
              const SizedBox(width: 8),
              _buildFilterChip('Accepted', Icons.check_circle_rounded, const Color(0xFF00FF88)),
              const SizedBox(width: 8),
              _buildFilterChip('Rejected', Icons.cancel_rounded, const Color(0xFFFF4655)),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.client
                .from('active_matches')
                .stream(primaryKey: ['id']),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorState('Could not load proof history', snapshot.error);
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                );
              }

              final all = snapshot.data ?? [];
              var history = all.where((m) {
                final st = (m['status'] ?? '').toString().toLowerCase();
                final pst = (m['proof_status'] ?? '').toString().toLowerCase();
                final isAccepted = pst == 'accepted' || st == 'completed';
                final isRejected = pst == 'rejected' || st == 'rejected';
                return isAccepted || isRejected;
              }).toList();

              // Apply filter
              if (_filter == 'Accepted') {
                history = history.where((m) {
                  final st = (m['status'] ?? '').toString().toLowerCase();
                  final pst = (m['proof_status'] ?? '').toString().toLowerCase();
                  return pst == 'accepted' || st == 'completed';
                }).toList();
              } else if (_filter == 'Rejected') {
                history = history.where((m) {
                  final st = (m['status'] ?? '').toString().toLowerCase();
                  final pst = (m['proof_status'] ?? '').toString().toLowerCase();
                  return pst == 'rejected' || st == 'rejected';
                }).toList();
              }

              history.sort((a, b) {
                final aDate = a['ended_at'] ?? a['created_at'] ?? '';
                final bDate = b['ended_at'] ?? b['created_at'] ?? '';
                return bDate.toString().compareTo(aDate.toString());
              });

              if (history.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.history_rounded,
                  title: _filter == 'All'
                      ? 'No Proof History'
                      : 'No $_filter Proofs',
                  subtitle: _filter == 'All'
                      ? 'Accepted and rejected proofs will appear here.'
                      : 'No proofs match this filter.',
                  color: const Color(0xFF38BDF8),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return AdminProofCard(
                    match: history[index],
                    showActions: false,
                    showDelete: true,
                    onDelete: () => _confirmDelete(context, history[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon, Color color) {
    final isSelected = _filter == label;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.black : color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: const Color(0xFF161B26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? color : const Color(0xFF1F2B3E)),
      ),
      onSelected: (val) {
        if (val) setState(() => _filter = label);
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Map<String, dynamic> match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655)),
            SizedBox(width: 8),
            Text('Delete Proof?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will permanently delete this proof from history. This action cannot be undone.',
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final matchId = match['id']?.toString() ?? '';
      if (matchId.isEmpty) return;

      await SupabaseService.client
          .from('active_matches')
          .delete()
          .eq('id', matchId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proof deleted from history'),
            backgroundColor: Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting proof: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }
}

// ============================================================
// REUSABLE CARD: AdminProofCard
// Dono tabs mein use hota hai
// ============================================================
class AdminProofCard extends StatefulWidget {
  final Map<String, dynamic> match;
  final bool showActions; // Accept/Reject buttons
  final bool showDelete; // Delete button
  final VoidCallback? onDelete;

  const AdminProofCard({
    super.key,
    required this.match,
    this.showActions = false,
    this.showDelete = false,
    this.onDelete,
  });

  @override
  State<AdminProofCard> createState() => _AdminProofCardState();
}

class _AdminProofCardState extends State<AdminProofCard> {
  final TextEditingController _reasonController = TextEditingController();
  final TeamService _teamService = TeamService();
  bool _isProcessing = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ---- Full-screen proof viewer ----
  void _showProofViewer(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF131A29),
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Proof Screenshot 📸',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(
                          color: Color(0xFF00FF88)),
                    ),
                    errorWidget: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Icon(Icons.broken_image_rounded,
                          color: Colors.red, size: 48),
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

  // ---- Accept handler ----
  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final matchId = widget.match['id'];
      final submittedByRaw =
          (widget.match['submitted_by_team_id'] ??
                  widget.match['winner_team_id'])
              ?.toString();
      final winnerId = (submittedByRaw != null && submittedByRaw.isNotEmpty)
          ? submittedByRaw
          : (widget.match['winner_team_id'] ?? '').toString();
      final winnerUuid =
          winnerId.isNotEmpty ? SupabaseService.toUuid(winnerId) : '';

      final ok = await SupabaseService.approveProof(
        matchId: matchId.toString(),
        winnerTeamId: winnerUuid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? '✅ Proof accepted! Moved to History.'
                : 'Error accepting proof'),
            backgroundColor:
                ok ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting proof: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ---- Reject handler ----
  Future<void> _handleReject() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final matchId = widget.match['id'];
      final reason = _reasonController.text.trim();
      final finalReason = reason.isNotEmpty
          ? reason
          : 'Proof screenshot was unclear or invalid';

      final ok = await SupabaseService.rejectProof(
        matchId: matchId.toString(),
        reason: finalReason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? '❌ Proof rejected. Moved to History.'
                : 'Error rejecting proof'),
            backgroundColor:
                ok ? const Color(0xFFFF4655) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting proof: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ---- Status badge ----
  Widget _buildStatusBadge(String status, String proofStatus) {
    Color color;
    String label;
    IconData icon;

    if (proofStatus == 'accepted' || status == 'completed') {
      color = const Color(0xFF00FF88);
      label = 'ACCEPTED';
      icon = Icons.check_circle_rounded;
    } else if (proofStatus == 'rejected' || status == 'rejected') {
      color = const Color(0xFFFF4655);
      label = 'REJECTED';
      icon = Icons.cancel_rounded;
    } else {
      color = const Color(0xFFFFB800);
      label = 'UNDER REVIEW';
      icon = Icons.hourglass_top_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t1 = (widget.match['team1_id'] ?? '').toString();
    final t2 = (widget.match['team2_id'] ?? '').toString();
    final result = (widget.match['result'] ?? 'WIN').toString().toUpperCase();
    final proofUrl = widget.match['proof_url']?.toString();
    final status = (widget.match['status'] ?? '').toString().toLowerCase();
    final proofStatus =
        (widget.match['proof_status'] ?? '').toString().toLowerCase();
    final adminNote = widget.match['admin_note']?.toString() ?? '';

    final dateRaw = widget.match['ended_at'] ?? widget.match['created_at'];
    String formattedDate = '';
    if (dateRaw != null) {
      try {
        final dt = DateTime.parse(dateRaw.toString()).toLocal();
        formattedDate = DateFormat('dd MMM, hh:mm a').format(dt);
      } catch (_) {
        formattedDate = dateRaw.toString();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2436),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3447)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teams row + Status
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<TeamModel?>>(
                  future: Future.wait([
                    _teamService.getTeam(t1),
                    _teamService.getTeam(t2),
                  ]),
                  builder: (context, snap) {
                    final t1Name = snap.data?[0]?.name ??
                        widget.match['team1_name'] ??
                        'Team 1';
                    final t2Name = snap.data?[1]?.name ??
                        widget.match['team2_name'] ??
                        'Team 2';
                    return Text(
                      '$t1Name  ⚔️  $t2Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
              _buildStatusBadge(status, proofStatus),
            ],
          ),

          // Date + Claim
          if (formattedDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Claim: $result',
                    style: const TextStyle(
                        color: Color(0xFF00FF88),
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5),
                  ),
                ),
                Text(
                  'Date: $formattedDate',
                  style: const TextStyle(
                      color: Color(0xFF8B949E), fontSize: 11),
                ),
              ],
            ),
          ],

          // Reject reason (if rejected)
          if (adminNote.isNotEmpty && proofStatus == 'rejected') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4655).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFFFF4655).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFFF4655), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reason: $adminNote',
                      style: const TextStyle(
                          color: Color(0xFFFF4655), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Proof thumbnail + actions
          if (proofUrl != null && proofUrl.isNotEmpty) ...[
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showProofViewer(context, proofUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: proofUrl,
                      height: 56,
                      width: 56,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => Container(
                        height: 56,
                        width: 56,
                        color: const Color(0xFF10141D),
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF00FF88)),
                          ),
                        ),
                      ),
                      errorWidget: (c, u, e) => Container(
                        height: 56,
                        width: 56,
                        color: const Color(0xFF10141D),
                        child: const Icon(Icons.broken_image,
                            color: Colors.white30, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Proof Screenshot',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () => _showProofViewer(context, proofUrl),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded,
                                color: Color(0xFF38BDF8), size: 14),
                            SizedBox(width: 4),
                            Text('Tap to View Full',
                                style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button (History tab)
                if (widget.showDelete && widget.onDelete != null)
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFFF4655), size: 22),
                    tooltip: 'Delete from history',
                  ),
              ],
            ),
          ] else ...[
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF10141D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('No screenshot attached',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ),
          ],

          // Actions (Under Review tab)
          if (widget.showActions) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Reject reason (ضروری اگر Reject کرنا ہو)...',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF10141D),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2A3447)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2A3447)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF4655)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child:
                      CircularProgressIndicator(color: Color(0xFF00FF88)),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4655),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text(
                          'Reject ❌',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: _handleReject,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF88),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_rounded,
                            size: 16, color: Colors.black),
                        label: const Text(
                          'Accept ✅',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                        onPressed: _handleAccept,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// HELPER: Empty State
// ============================================================
Widget _buildEmptyState({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 40),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
// HELPER: Error State
// ============================================================
Widget _buildErrorState(String title, Object error) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFFF4655), size: 48),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}