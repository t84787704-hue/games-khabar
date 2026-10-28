// ===============================================================================
// ADMIN PROOFS TABS — Dual-Proof Display & Adaptive Day/Night Theme (With Tournaments)
// File: lib/screens/admin/admin_proofs_tabs.dart
// ===============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/team_model.dart';
import '../../services/supabase_service.dart';
import '../../services/team_service.dart';
import '../../services/notification_service.dart';
import '../../services/coin_wallet_service.dart';
import '../../services/theme_service.dart';

// ============================================================
// TAB 1: UNDER REVIEW
// ============================================================
class AdminUnderReviewTab extends StatelessWidget {
  const AdminUnderReviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('active_matches')
          .stream(primaryKey: ['id']),
      builder: (context, matchSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.client
              .from('rooms')
              .stream(primaryKey: ['id']),
          builder: (context, roomSnap) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.client
                  .from('tournaments')
                  .stream(primaryKey: ['id']),
              builder: (context, tournamentSnap) {
                if (matchSnap.hasError && roomSnap.hasError && tournamentSnap.hasError) {
                  return _buildErrorState(
                    'could_not_load_under_review'.tr(),
                    matchSnap.error ?? roomSnap.error ?? tournamentSnap.error,
                  );
                }

                if (matchSnap.connectionState == ConnectionState.waiting &&
                    !matchSnap.hasData &&
                    roomSnap.connectionState == ConnectionState.waiting &&
                    !roomSnap.hasData &&
                    tournamentSnap.connectionState == ConnectionState.waiting &&
                    !tournamentSnap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                  );
                }

                // 1. Team Matches Under Review
                final matchData = matchSnap.data ?? [];
                final underReviewMatches = matchData.where((m) {
                  final st = (m['status'] ?? '').toString().toLowerCase();
                  final pst = (m['proof_status'] ?? '').toString().toLowerCase();
                  return st == 'under_review' && (pst == 'pending' || pst.isEmpty);
                }).map((m) => {...m, 'is_room': false, 'is_tournament': false}).toList();

                // 2. Custom Game Rooms Under Review
                final roomData = roomSnap.data ?? [];
                final underReviewRooms = roomData.where((r) {
                  final st = (r['status'] ?? '').toString().toLowerCase();
                  final rst = (r['reward_status'] ?? '').toString().toLowerCase();
                  final proof = (r['win_proof_url'] ?? '').toString();
                  final hasProofs = (r['proofs'] is List && (r['proofs'] as List).isNotEmpty) ||
                      ((r['host_proof_url'] ?? '').toString().isNotEmpty) ||
                      ((r['opponent_proof_url'] ?? '').toString().isNotEmpty);

                  final isPending = st == 'review_pending' ||
                      st == 'under_review' ||
                      st == 'proof_submitted' ||
                      st == 'disputed' ||
                      rst == 'pending_approval';

                  return isPending && (proof.isNotEmpty || hasProofs) && st != 'completed';
                }).map((r) => {...r, 'is_room': true, 'is_tournament': false}).toList();

                // 3. Tournaments Under Review
                final tournamentData = tournamentSnap.data ?? [];
                final underReviewTournaments = tournamentData.where((t) {
                  final proof = (t['proof_url'] ?? '').toString();
                  final proofStatus = (t['proof_status'] ?? '').toString().toLowerCase();
                  final status = (t['status'] ?? '').toString().toLowerCase();
                  return proof.isNotEmpty && (proofStatus == 'pending' || proofStatus.isEmpty) && status != 'completed';
                }).map((t) => {
                      ...t,
                      'is_room': false,
                      'is_tournament': true,
                      'id': t['id'],
                      'game': t['game_mode'] ?? 'Tournament',
                      'mode': t['title'] ?? 'Match',
                      'prize_pool': t['prize_pool'] ?? 0,
                      'win_proof_url': t['proof_url'],
                      'win_proof_uploaded_at': t['submitted_at'] ?? t['created_at'],
                    }).toList();

                final underReview = [...underReviewMatches, ...underReviewRooms, ...underReviewTournaments];

                underReview.sort((a, b) {
                  final aDate = a['win_proof_uploaded_at'] ?? a['submitted_at'] ?? a['ended_at'] ?? a['created_at'] ?? '';
                  final bDate = b['win_proof_uploaded_at'] ?? b['submitted_at'] ?? b['ended_at'] ?? b['created_at'] ?? '';
                  return bDate.toString().compareTo(aDate.toString());
                });

                if (underReview.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.fact_check_rounded,
                    title: 'no_proofs_under_review_title'.tr(),
                    subtitle: 'all_proofs_reviewed_desc'.tr(),
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
          },
        );
      },
    );
  }
}

// ============================================================
// TAB 2: HISTORY (Accepted + Rejected)
// ============================================================
class AdminProofHistoryTab extends StatefulWidget {
  const AdminProofHistoryTab({super.key});

  @override
  State<AdminProofHistoryTab> createState() => _AdminProofHistoryTabState();
}

class _AdminProofHistoryTabState extends State<AdminProofHistoryTab> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _buildFilterChip('All', 'filter_all'.tr(), Icons.list_alt_rounded, const Color(0xFF8B949E)),
              const SizedBox(width: 8),
              _buildFilterChip('Accepted', 'status_accepted'.tr(), Icons.check_circle_rounded, const Color(0xFF00FF88)),
              const SizedBox(width: 8),
              _buildFilterChip('Rejected', 'status_rejected'.tr(), Icons.cancel_rounded, const Color(0xFFFF4655)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.client
                .from('active_matches')
                .stream(primaryKey: ['id']),
            builder: (context, matchSnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: SupabaseService.client
                    .from('rooms')
                    .stream(primaryKey: ['id']),
                builder: (context, roomSnap) {
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: SupabaseService.client
                        .from('tournaments')
                        .stream(primaryKey: ['id']),
                    builder: (context, tournamentSnap) {
                      if (matchSnap.hasError && roomSnap.hasError && tournamentSnap.hasError) {
                        return _buildErrorState(
                          'could_not_load_history'.tr(),
                          matchSnap.error ?? roomSnap.error ?? tournamentSnap.error,
                        );
                      }

                      if (matchSnap.connectionState == ConnectionState.waiting &&
                          !matchSnap.hasData &&
                          roomSnap.connectionState == ConnectionState.waiting &&
                          !roomSnap.hasData &&
                          tournamentSnap.connectionState == ConnectionState.waiting &&
                          !tournamentSnap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                        );
                      }

                      final matchData = matchSnap.data ?? [];
                      final matchHistory = matchData.where((m) {
                        final st = (m['status'] ?? '').toString().toLowerCase();
                        final pst = (m['proof_status'] ?? '').toString().toLowerCase();
                        final isAccepted = pst == 'accepted' || st == 'completed';
                        final isRejected = pst == 'rejected' || st == 'rejected';
                        return isAccepted || isRejected;
                      }).map((m) => {...m, 'is_room': false, 'is_tournament': false}).toList();

                      final roomData = roomSnap.data ?? [];
                      final roomHistory = roomData.where((r) {
                        final st = (r['status'] ?? '').toString().toLowerCase();
                        final rst = (r['reward_status'] ?? '').toString().toLowerCase();
                        final isAccepted = st == 'completed' || rst == 'sent';
                        final isRejected = st == 'proof_rejected' || rst == 'rejected';
                        return isAccepted || isRejected;
                      }).map((r) => {...r, 'is_room': true, 'is_tournament': false}).toList();

                      final tournamentData = tournamentSnap.data ?? [];
                      final tournamentHistory = tournamentData.where((t) {
                        final proofStatus = (t['proof_status'] ?? '').toString().toLowerCase();
                        final status = (t['status'] ?? '').toString().toLowerCase();
                        final isAccepted = proofStatus == 'accepted' || status == 'completed';
                        final isRejected = proofStatus == 'rejected' || status == 'rejected';
                        return isAccepted || isRejected;
                      }).map((t) => {
                            ...t,
                            'is_room': false,
                            'is_tournament': true,
                            'id': t['id'],
                            'game': t['game_mode'] ?? 'Tournament',
                            'mode': t['title'] ?? 'Match',
                            'prize_pool': t['prize_pool'] ?? 0,
                            'win_proof_url': t['proof_url'],
                            'proof_status': t['proof_status'] ?? (t['status'] == 'completed' ? 'accepted' : 'pending'),
                          }).toList();

                      var history = [...matchHistory, ...roomHistory, ...tournamentHistory];

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
                          return pst == 'rejected' || st == 'rejected' || st == 'proof_rejected';
                        }).toList();
                      }

                      history.sort((a, b) {
                        final aDate = a['ended_at'] ?? a['completed_at'] ?? a['created_at'] ?? '';
                        final bDate = b['ended_at'] ?? b['completed_at'] ?? b['created_at'] ?? '';
                        return bDate.toString().compareTo(aDate.toString());
                      });

                      if (history.isEmpty) {
                        return _buildEmptyState(
                          icon: Icons.history_rounded,
                          title: _filter == 'All' ? 'no_proof_history_title'.tr() : 'No $_filter Proofs',
                          subtitle: 'proof_history_empty_desc'.tr(),
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
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, Color color) {
    final isSelected = _filter == key;
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
      backgroundColor: ThemeService.cardSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? color : ThemeService.border),
      ),
      onSelected: (val) {
        if (val) setState(() => _filter = key);
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655)),
            const SizedBox(width: 8),
            Text('delete_proof_title'.tr(),
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'delete_proof_confirm_desc'.tr(),
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('btn_cancel'.tr(), style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            child: Text('btn_delete'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final matchId = match['id']?.toString() ?? '';
      if (matchId.isEmpty) return;

      final isRoom = match['is_room'] == true;
      final isTournament = match['is_tournament'] == true;

      if (isTournament) {
        await SupabaseService.client.from('tournaments').update({
          'proof_url': null,
          'proof_status': null,
        }).eq('id', matchId);
      } else if (isRoom) {
        await SupabaseService.client.from('rooms').delete().eq('id', matchId);
      } else {
        await SupabaseService.client.from('active_matches').delete().eq('id', matchId);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('proof_deleted_from_history'.tr()),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'error_deleting_proof'.tr()}: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }
}

// ============================================================
// REUSABLE CARD: AdminProofCard (Auto Multi-Proof Resolver)
// ============================================================
class AdminProofCard extends StatefulWidget {
  final Map<String, dynamic> match;
  final bool showActions;
  final bool showDelete;
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
  List<Map<String, dynamic>> _fetchedProofs = [];
  bool _isLoadingProofs = false;

  @override
  void initState() {
    super.initState();
    _loadAllProofs();
  }

  Future<void> _loadAllProofs() async {
    final isTournament = widget.match['is_tournament'] == true;
    if (isTournament) {
      final proofUrl = (widget.match['proof_url'] ?? widget.match['win_proof_url'] ?? '').toString();
      if (proofUrl.isNotEmpty) {
        setState(() {
          _fetchedProofs = [{
            'user_id': widget.match['submitted_team_id'] ?? '',
            'user_name': widget.match['proof_team_name'] ?? widget.match['proof_leader_name'] ?? 'Tournament Team',
            'is_host': false,
            'proof_url': proofUrl,
          }];
        });
      }
      return;
    }

    final isRoom = widget.match['is_room'] == true;
    final targetId = widget.match['id']?.toString() ?? '';
    if (targetId.isEmpty) return;

    setState(() => _isLoadingProofs = true);

    try {
      final proofRows = await SupabaseService.client
          .from('match_proofs')
          .select()
          .or('room_id.eq.$targetId,match_id.eq.$targetId')
          .order('created_at', ascending: true);

      if (proofRows.isNotEmpty) {
        final List<Map<String, dynamic>> entries = [];
        for (final r in proofRows) {
          final url = (r['proof_url'] ?? r['image_url'] ?? '').toString();
          if (url.isNotEmpty) {
            entries.add({
              'user_id': r['user_id'] ?? '',
              'user_name': r['user_name'] ?? r['uploader_name'] ?? 'Player',
              'is_host': r['is_host'] == true,
              'proof_url': url,
            });
          }
        }
        if (mounted && entries.isNotEmpty) {
          setState(() {
            _fetchedProofs = entries;
            _isLoadingProofs = false;
          });
          return;
        }
      }

      if (isRoom) {
        final rData = await SupabaseService.client
            .from('rooms')
            .select('proofs, host_proof_url, opponent_proof_url, win_proof_url, host_name, winner_name, host_id, winner_id')
            .eq('id', targetId)
            .maybeSingle();

        if (rData != null && mounted) {
          final List<Map<String, dynamic>> entries = [];
          final rawProofs = rData['proofs'];
          if (rawProofs is List) {
            for (final p in rawProofs) {
              if (p is Map && (p['proof_url'] ?? '').toString().isNotEmpty) {
                entries.add(Map<String, dynamic>.from(p));
              }
            }
          }
          if (entries.isEmpty) {
            if ((rData['host_proof_url'] ?? '').toString().isNotEmpty) {
              entries.add({
                'user_id': rData['host_id'] ?? '',
                'user_name': rData['host_name'] ?? 'Host',
                'is_host': true,
                'proof_url': rData['host_proof_url'],
              });
            }
            if ((rData['opponent_proof_url'] ?? '').toString().isNotEmpty) {
              entries.add({
                'user_id': rData['winner_id'] ?? '',
                'user_name': rData['winner_name'] ?? 'Opponent',
                'is_host': false,
                'proof_url': rData['opponent_proof_url'],
              });
            }
          }
          if (entries.isNotEmpty) {
            setState(() {
              _fetchedProofs = entries;
              _isLoadingProofs = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoadingProofs = false);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _showProofViewer(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ThemeService.card,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title 📸',
                      style: TextStyle(
                          color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: ThemeService.textSecondary, size: 20),
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
                      child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                    ),
                    errorWidget: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Icon(Icons.broken_image_rounded, color: Colors.red, size: 48),
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

  Future<void> _handleAcceptTournament() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final tournamentId = widget.match['id']?.toString() ?? '';
      final teamId = widget.match['submitted_team_id'] ?? widget.match['proof_team_id'];
      final prize = (widget.match['prize_pool'] is num)
          ? (widget.match['prize_pool'] as num).toInt()
          : int.tryParse(widget.match['prize_pool']?.toString() ?? '0') ?? 0;

      // 1. Mark Tournament as completed and set winner team
      await SupabaseService.client.from('tournaments').update({
        'status': 'completed',
        'proof_status': 'accepted',
        'winner_team_id': teamId,
      }).eq('id', tournamentId);

      // 2. If teamId is present, reward coins to team members (Equal Split)
      if (teamId != null && teamId.toString().isNotEmpty) {
        try {
          final teamData = await SupabaseService.client
              .from('teams')
              .select('id, name, leader_id, team_members(user_id)')
              .eq('id', teamId)
              .maybeSingle();

          if (teamData != null) {
            final teamName = teamData['name']?.toString() ?? 'Winner Team';
            
            final List<String> memberIds = [];
            final leaderId = teamData['leader_id']?.toString();
            if (leaderId != null && leaderId.isNotEmpty) {
              memberIds.add(leaderId);
            }

            final membersList = (teamData['team_members'] as List?) ?? [];
            for (final m in membersList) {
              final uid = m['user_id']?.toString();
              if (uid != null && uid.isNotEmpty && !memberIds.contains(uid)) {
                memberIds.add(uid);
              }
            }

            if (memberIds.isNotEmpty && prize > 0) {
              final int sharePerPerson = (prize / memberIds.length).floor();

              for (final memberId in memberIds) {
                if (sharePerPerson > 0) {
                  await CoinWalletService.updateCoins(
                    userId: memberId,
                    amount: sharePerPerson,
                    type: 'tournament_split_win',
                    roomId: tournamentId,
                    description: 'Tournament Win Split ($sharePerPerson coins): ${widget.match['title'] ?? 'Tournament'}',
                  );

                  await NotificationService().sendNotification(
                    userId: memberId,
                    type: 'tournament_result',
                    title: '🏆 Tournament Win Split Approved!',
                    body: 'Your team won ${widget.match['title'] ?? 'Tournament'}! $sharePerPerson coins (equal split) added to your wallet.',
                    data: {'tournament_id': tournamentId, 'prize': sharePerPerson},
                    priority: 'high',
                  );
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[AdminProofs] Tournament reward error: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tournament proof accepted & prize split distributed! 🎉'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRejectTournament() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final tournamentId = widget.match['id']?.toString() ?? '';
      final reason = _reasonController.text.trim();
      final finalReason = reason.isNotEmpty ? reason : 'Tournament proof was unclear or invalid';

      await SupabaseService.client.from('tournaments').update({
        'proof_status': 'rejected',
        'rejection_reason': finalReason,
        'proof_reject_reason': finalReason,
        'proof_url': null, // Clear so they can re-upload
      }).eq('id', tournamentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tournament proof rejected successfully.'),
            backgroundColor: Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleAcceptDefault() async {
    final isTournament = widget.match['is_tournament'] == true;
    if (isTournament) {
      await _handleAcceptTournament();
      return;
    }

    final isRoom = widget.match['is_room'] == true;
    if (isRoom) {
      final winnerId = widget.match['winner_id']?.toString() ?? '';
      final winnerName = widget.match['winner_name']?.toString() ?? 'Winner';
      return;
    }
  }

  Future<void> _handleReject() async {
    final isTournament = widget.match['is_tournament'] == true;
    if (isTournament) {
      await _handleRejectTournament();
      return;
    }
  }

  Widget _buildStatusBadge(String status, String proofStatus) {
    Color color;
    String label;
    IconData icon;

    if (proofStatus == 'accepted' || status == 'completed') {
      color = const Color(0xFF00FF88);
      label = 'status_accepted'.tr().toUpperCase();
      icon = Icons.check_circle_rounded;
    } else if (proofStatus == 'rejected' || status == 'rejected' || status == 'proof_rejected') {
      color = const Color(0xFFFF4655);
      label = 'status_rejected'.tr().toUpperCase();
      icon = Icons.cancel_rounded;
    } else {
      color = const Color(0xFFFFB800);
      label = 'status_under_review'.tr().toUpperCase();
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
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTournament = widget.match['is_tournament'] == true;
    final isRoom = widget.match['is_room'] == true;
    final status = (widget.match['status'] ?? '').toString().toLowerCase();
    final proofStatus = (widget.match['proof_status'] ?? '').toString().toLowerCase();
    final adminNote = widget.match['rejection_reason'] ?? widget.match['proof_reject_reason'] ?? widget.match['admin_note']?.toString() ?? '';

    final dateRaw = widget.match['submitted_at'] ?? widget.match['ended_at'] ?? widget.match['win_proof_uploaded_at'] ?? widget.match['created_at'];
    String formattedDate = '';
    if (dateRaw != null) {
      try {
        final dt = DateTime.parse(dateRaw.toString()).toLocal();
        formattedDate = DateFormat('dd MMM, hh:mm a').format(dt);
      } catch (_) {
        formattedDate = dateRaw.toString();
      }
    }

    final List<Map<String, dynamic>> proofEntries = [];
    if (_fetchedProofs.isNotEmpty) {
      proofEntries.addAll(_fetchedProofs);
    } else {
      final proofUrl = (widget.match['proof_url'] ?? widget.match['win_proof_url'] ?? '').toString();
      if (proofUrl.isNotEmpty) {
        proofEntries.add({
          'user_id': widget.match['submitted_team_id'] ?? '',
          'user_name': widget.match['proof_team_name'] ?? widget.match['proof_leader_name'] ?? 'Team Leader',
          'is_host': false,
          'proof_url': proofUrl,
        });
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeService.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isTournament
                      ? '🏆 Tournament: ${widget.match['title'] ?? 'Match'}'
                      : isRoom
                          ? '🎮 Room Match'
                          : '⚔️ Team Match',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(status, proofStatus),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prize: ${widget.match['prize_pool'] ?? 0} Coins',
                style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 11),
              ),
              if (formattedDate.isNotEmpty)
                Text(
                  formattedDate,
                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                ),
            ],
          ),
          if (adminNote.isNotEmpty && (proofStatus == 'rejected' || status == 'proof_rejected')) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4655).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Reason: $adminNote',
                style: const TextStyle(color: Color(0xFFFF4655), fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (proofEntries.isNotEmpty)
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showProofViewer(context, proofEntries.first['proof_url'], proofEntries.first['user_name']),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: proofEntries.first['proof_url'],
                      height: 56,
                      width: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uploaded by: ${proofEntries.first['user_name']}',
                        style: TextStyle(color: ThemeService.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Text('Tap to view full screenshot', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5)),
                    ],
                  ),
                ),
                if (widget.showDelete && widget.onDelete != null)
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4655), size: 22),
                  ),
              ],
            ),
          if (widget.showActions) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              style: TextStyle(color: ThemeService.textPrimary, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Rejection reason (if rejecting)...',
                hintStyle: TextStyle(color: ThemeService.textSecondary.withOpacity(0.6), fontSize: 12),
                filled: true,
                fillColor: ThemeService.cardSecondary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ThemeService.border)),
              ),
            ),
            const SizedBox(height: 10),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655), foregroundColor: Colors.white),
                        onPressed: isTournament ? _handleRejectTournament : _handleReject,
                        child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
                        onPressed: isTournament ? _handleAcceptTournament : _handleAcceptDefault,
                        child: const Text('Accept & Reward', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
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
// HELPERS
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
          Text(title, style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
        ],
      ),
    ),
  );
}

Widget _buildErrorState(String title, Object? error) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4655), size: 48),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('${error ?? "Unknown error"}', textAlign: TextAlign.center, style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
        ],
      ),
    ),
  );
}
