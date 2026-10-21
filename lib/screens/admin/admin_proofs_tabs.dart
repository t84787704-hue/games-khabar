// ===============================================================================
// ADMIN PROOFS TABS — Dual-Proof Display & Adaptive Day/Night Theme
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
            if (matchSnap.hasError && roomSnap.hasError) {
              return _buildErrorState(
                'could_not_load_under_review'.tr(),
                matchSnap.error ?? roomSnap.error,
              );
            }

            if (matchSnap.connectionState == ConnectionState.waiting &&
                !matchSnap.hasData &&
                roomSnap.connectionState == ConnectionState.waiting &&
                !roomSnap.hasData) {
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
            }).map((m) => {...m, 'is_room': false}).toList();

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
            }).map((r) => {...r, 'is_room': true}).toList();

            final underReview = [...underReviewMatches, ...underReviewRooms];

            underReview.sort((a, b) {
              final aDate = a['win_proof_uploaded_at'] ?? a['ended_at'] ?? a['created_at'] ?? '';
              final bDate = b['win_proof_uploaded_at'] ?? b['ended_at'] ?? b['created_at'] ?? '';
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
                  if (matchSnap.hasError && roomSnap.hasError) {
                    return _buildErrorState(
                      'could_not_load_history'.tr(),
                      matchSnap.error ?? roomSnap.error,
                    );
                  }

                  if (matchSnap.connectionState == ConnectionState.waiting &&
                      !matchSnap.hasData &&
                      roomSnap.connectionState == ConnectionState.waiting &&
                      !roomSnap.hasData) {
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
                  }).map((m) => {...m, 'is_room': false}).toList();

                  final roomData = roomSnap.data ?? [];
                  final roomHistory = roomData.where((r) {
                    final st = (r['status'] ?? '').toString().toLowerCase();
                    final rst = (r['reward_status'] ?? '').toString().toLowerCase();
                    final isAccepted = st == 'completed' || rst == 'sent';
                    final isRejected = st == 'proof_rejected' || rst == 'rejected';
                    return isAccepted || isRejected;
                  }).map((r) => {...r, 'is_room': true}).toList();

                  var history = [...matchHistory, ...roomHistory];

                  if (_filter == 'Accepted') {
                    history = history.where((m) {
                      final st = (m['status'] ?? '').toString().toLowerCase();
                      final pst = (m['proof_status'] ?? '').toString().toLowerCase();
                      final rst = (r) => (r['reward_status'] ?? '').toString().toLowerCase();
                      return pst == 'accepted' || st == 'completed' || rst(m) == 'sent';
                    }).toList();
                  } else if (_filter == 'Rejected') {
                    history = history.where((m) {
                      final st = (m['status'] ?? '').toString().toLowerCase();
                      final pst = (m['proof_status'] ?? '').toString().toLowerCase();
                      final rst = (r) => (r['reward_status'] ?? '').toString().toLowerCase();
                      return pst == 'rejected' || st == 'rejected' || st == 'proof_rejected' || rst(m) == 'rejected';
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
                      subtitle: _filter == 'All'
                          ? 'proof_history_empty_desc'.tr()
                          : 'proof_history_empty_desc'.tr(),
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
      if (isRoom) {
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
    final isRoom = widget.match['is_room'] == true;
    final targetId = widget.match['id']?.toString() ?? '';
    if (targetId.isEmpty) return;

    setState(() => _isLoadingProofs = true);

    try {
      // 1. Try querying 'match_proofs' table
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

      // 2. Fallback: Search messages for win proofs
      if (isRoom) {
        final msgProofs = await SupabaseService.client
            .from('messages')
            .select()
            .eq('room_id', targetId)
            .ilike('message', '%uploaded win proof%');

        if (msgProofs.isNotEmpty) {
          // If messages contain multiple uploads, check room's host_proof_url and opponent_proof_url
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

  Future<void> _handleAcceptSpecificWinner({
    required String winnerId,
    required String winnerName,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final roomId = widget.match['id']?.toString() ?? '';
      final prize = (widget.match['prize_pool'] is num)
          ? (widget.match['prize_pool'] as num).toInt()
          : int.tryParse(widget.match['prize_pool']?.toString() ?? '0') ?? 0;

      if (winnerId.isNotEmpty && winnerId != 'guest') {
        try {
          await CoinWalletService.updateCoins(
            userId: winnerId,
            amount: prize,
            type: 'win_prize',
            roomId: roomId,
            description: 'Room win prize: ${widget.match['game']} ${widget.match['mode']}',
          );
        } catch (e) {
          debugPrint('[AdminProofs] Room updateCoins error: $e');
        }

        try {
          final winnerRow = await SupabaseService.client
              .from('users')
              .select('wins, total_winnings')
              .or('id.eq.$winnerId,uid.eq.$winnerId')
              .maybeSingle();
          if (winnerRow != null) {
            final currentWins = (winnerRow['wins'] as num?)?.toInt() ?? 0;
            final currentWinnings = (winnerRow['total_winnings'] as num?)?.toInt() ?? 0;
            await SupabaseService.client.from('users').update({
              'wins': currentWins + 1,
              'total_winnings': currentWinnings + prize,
            }).or('id.eq.$winnerId,uid.eq.$winnerId');
          }
        } catch (_) {}
      }

      await SupabaseService.client.from('rooms').update({
        'status': 'completed',
        'reward_status': 'sent',
        'winner_id': winnerId,
        'winner_name': winnerName,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', roomId);

      try {
        await SupabaseService.client.from('messages').insert({
          'room_id': roomId,
          'sender_id': 'system',
          'sender_name': 'ADMIN BOT',
          'message': 'admin_bot_approved_room_msg'.tr(args: [winnerName, prize.toString()]),
          'type': 'system_reward',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}

      try {
        if (winnerId.isNotEmpty && winnerId != 'guest') {
          await NotificationService().sendNotification(
            userId: winnerId,
            type: 'match_result',
            title: 'proof_approved_notif_title'.tr(args: [prize.toString()]),
            body: 'proof_approved_notif_body'.tr(args: [
              (widget.match['game'] ?? 'Game').toString(),
              prize.toString(),
            ]),
            data: {'room_id': roomId, 'prize': prize},
            priority: 'high',
          );
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('winner_verified_snackbar'.tr(args: [winnerName])),
            backgroundColor: const Color(0xFF00FF88),
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
    final isRoom = widget.match['is_room'] == true;
    if (isRoom) {
      final winnerId = widget.match['winner_id']?.toString() ?? '';
      final winnerName = widget.match['winner_name']?.toString() ?? 'Winner';
      await _handleAcceptSpecificWinner(winnerId: winnerId, winnerName: winnerName);
      return;
    }

    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final matchId = widget.match['id'];
      final submittedByRaw = (widget.match['submitted_by_team_id'] ?? widget.match['winner_team_id'])?.toString();
      final winnerId = (submittedByRaw != null && submittedByRaw.isNotEmpty)
          ? submittedByRaw
          : (widget.match['winner_team_id'] ?? '').toString();
      final winnerUuid = winnerId.isNotEmpty ? SupabaseService.toUuid(winnerId) : '';

      final ok = await SupabaseService.approveProof(
        matchId: matchId.toString(),
        winnerTeamId: winnerUuid,
      );

      if (ok) {
        try {
          final team = await _teamService.getTeam(winnerUuid);
          if (team != null && team.leaderId.isNotEmpty) {
            await NotificationService().sendProofNotification(
              targetUserId: team.leaderId,
              status: 'accepted',
              roomTitle: 'Team Match',
            );
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'proof_accepted_snackbar'.tr() : 'Error accepting proof'),
            backgroundColor: ok ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
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

  Future<void> _handleReject() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final isRoom = widget.match['is_room'] == true;
      final reason = _reasonController.text.trim();
      final finalReason = reason.isNotEmpty ? reason : 'Proof screenshot was unclear or invalid';

      if (isRoom) {
        final roomId = widget.match['id']?.toString() ?? '';
        await SupabaseService.client.from('rooms').update({
          'status': 'proof_rejected',
          'reward_status': 'rejected',
        }).eq('id', roomId);

        try {
          await SupabaseService.client.from('messages').insert({
            'room_id': roomId,
            'sender_id': 'system',
            'sender_name': 'ADMIN BOT',
            'message': 'admin_bot_rejected_room_msg'.tr(args: [finalReason]),
            'type': 'system',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {}

        final winnerId = widget.match['winner_id']?.toString() ?? '';
        if (winnerId.isNotEmpty && winnerId != 'guest') {
          try {
            await NotificationService().sendNotification(
              userId: winnerId,
              type: 'match_result',
              title: 'proof_rejected_notif_title'.tr(),
              body: 'proof_rejected_notif_body'.tr(args: [finalReason]),
              data: {'room_id': roomId},
            );
          } catch (_) {}
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('room_proof_rejected_snackbar'.tr()),
              backgroundColor: const Color(0xFFFF4655),
            ),
          );
        }
        return;
      }

      final matchId = widget.match['id'];
      final ok = await SupabaseService.rejectProof(
        matchId: matchId.toString(),
        reason: finalReason,
      );

      if (ok) {
        try {
          final submittedByRaw = (widget.match['submitted_by_team_id'] ?? widget.match['winner_team_id'])?.toString();
          if (submittedByRaw != null && submittedByRaw.isNotEmpty) {
            final teamUuid = SupabaseService.toUuid(submittedByRaw);
            final team = await _teamService.getTeam(teamUuid);
            if (team != null && team.leaderId.isNotEmpty) {
              await NotificationService().sendProofNotification(
                targetUserId: team.leaderId,
                status: 'rejected',
                roomTitle: 'Team Match',
                reason: finalReason,
              );
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'proof_rejected_snackbar'.tr() : 'Error rejecting proof'),
            backgroundColor: const Color(0xFFFF4655),
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
    } else if (status == 'disputed') {
      color = Colors.orange;
      label = 'status_disputed'.tr().toUpperCase();
      icon = Icons.warning_amber_rounded;
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

  Widget _buildSingleThumbnail(String url, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _showProofViewer(context, url, label),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: url,
                    height: 70,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 70,
                      color: ThemeService.cardSecondary,
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF88)),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 70,
                      color: ThemeService.cardSecondary,
                      child: Icon(Icons.broken_image, color: ThemeService.textSecondary, size: 24),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRoom = widget.match['is_room'] == true;
    final t1 = (widget.match['team1_id'] ?? '').toString();
    final t2 = (widget.match['team2_id'] ?? '').toString();
    final result = (widget.match['result'] ?? 'WIN').toString().toUpperCase();
    final status = (widget.match['status'] ?? '').toString().toLowerCase();
    final proofStatus = (widget.match['proof_status'] ?? '').toString().toLowerCase();
    final adminNote = widget.match['admin_note']?.toString() ?? '';

    final dateRaw = widget.match['ended_at'] ?? widget.match['win_proof_uploaded_at'] ?? widget.match['created_at'];
    String formattedDate = '';
    if (dateRaw != null) {
      try {
        final dt = DateTime.parse(dateRaw.toString()).toLocal();
        formattedDate = DateFormat('dd MMM, hh:mm a').format(dt);
      } catch (_) {
        formattedDate = dateRaw.toString();
      }
    }

    // Combine static proofs + asynchronously fetched proofs
    final List<Map<String, dynamic>> proofEntries = [];
    if (_fetchedProofs.isNotEmpty) {
      proofEntries.addAll(_fetchedProofs);
    } else {
      final rawProofs = widget.match['proofs'];
      if (rawProofs is List) {
        for (final p in rawProofs) {
          if (p is Map && (p['proof_url'] ?? '').toString().isNotEmpty) {
            proofEntries.add(Map<String, dynamic>.from(p));
          }
        }
      } else if (rawProofs is String && rawProofs.isNotEmpty) {
        try {
          final dec = jsonDecode(rawProofs);
          if (dec is List) {
            for (final p in dec) {
              if (p is Map && (p['proof_url'] ?? '').toString().isNotEmpty) {
                proofEntries.add(Map<String, dynamic>.from(p));
              }
            }
          }
        } catch (_) {}
      }

      if (proofEntries.isEmpty) {
        final hostProof = (widget.match['host_proof_url'] ?? '').toString();
        final opponentProof = (widget.match['opponent_proof_url'] ?? '').toString();
        final legacyProof = (widget.match['win_proof_url'] ?? widget.match['proof_url'])?.toString() ?? '';

        if (hostProof.isNotEmpty) {
          proofEntries.add({
            'user_id': widget.match['host_id'] ?? '',
            'user_name': widget.match['host_name'] ?? 'Host',
            'is_host': true,
            'proof_url': hostProof,
          });
        }
        if (opponentProof.isNotEmpty) {
          proofEntries.add({
            'user_id': widget.match['winner_id'] ?? '',
            'user_name': widget.match['winner_name'] ?? 'Opponent',
            'is_host': false,
            'proof_url': opponentProof,
          });
        }
        if (proofEntries.isEmpty && legacyProof.isNotEmpty) {
          proofEntries.add({
            'user_id': widget.match['winner_id'] ?? '',
            'user_name': widget.match['winner_name'] ?? 'Winner',
            'is_host': false,
            'proof_url': legacyProof,
          });
        }
      }
    }

    final bool isDualProof = proofEntries.length >= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDualProof ? Colors.amber.withOpacity(0.7) : ThemeService.border,
          width: isDualProof ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: isRoom
                    ? Text(
                        '🎮 ${(widget.match['game'] ?? 'Game')} ${(widget.match['mode'] ?? '')} (${'room_label'.tr()})',
                        style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : FutureBuilder<List<TeamModel?>>(
                        future: Future.wait([
                          _teamService.getTeam(t1),
                          _teamService.getTeam(t2),
                        ]),
                        builder: (context, snap) {
                          final t1Name = snap.data?[0]?.name ?? widget.match['team1_name'] ?? 'Team 1';
                          final t2Name = snap.data?[1]?.name ?? widget.match['team2_name'] ?? 'Team 2';
                          return Text(
                            '$t1Name  ⚔️  $t2Name',
                            style: TextStyle(
                              color: ThemeService.textPrimary,
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

          if (isRoom) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDualProof ? Colors.orange.withOpacity(0.18) : Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isDualProof
                        ? 'players_uploaded_proofs_label'.tr(args: [(widget.match['prize_pool'] ?? 0).toString()])
                        : '${'winner_label'.tr()}: ${widget.match['winner_name'] ?? "Gamer"} (${widget.match['prize_pool'] ?? 0} ${'coins_label'.tr()})',
                    style: TextStyle(
                      color: isDualProof ? Colors.orange : Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                if (formattedDate.isNotEmpty)
                  Text(
                    '${'date_label'.tr()}: $formattedDate',
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ] else if (formattedDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${'claim_label'.tr()}: $result',
                    style: const TextStyle(
                        color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 10.5),
                  ),
                ),
                Text(
                  '${'date_label'.tr()}: $formattedDate',
                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],

          if (adminNote.isNotEmpty && (proofStatus == 'rejected' || status == 'proof_rejected')) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4655).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFFF4655), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${'reason_prefix_label'.tr()}: $adminNote',
                      style: const TextStyle(color: Color(0xFFFF4655), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Dynamic Proofs Display
          if (_isLoadingProofs)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Color(0xFF00FF88), strokeWidth: 2),
                ),
              ),
            )
          else if (proofEntries.isNotEmpty) ...[
            if (isDualProof) ...[
              // 2 Proofs: Side-by-Side comparison
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSingleThumbnail(
                    proofEntries[0]['proof_url'],
                    '${proofEntries[0]['user_name']} (${proofEntries[0]['is_host'] == true ? "Host" : "P1"})',
                  ),
                  const SizedBox(width: 10),
                  _buildSingleThumbnail(
                    proofEntries[1]['proof_url'],
                    '${proofEntries[1]['user_name']} (${proofEntries[1]['is_host'] == true ? "Host" : "P2"})',
                  ),
                  if (widget.showDelete && widget.onDelete != null)
                    IconButton(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4655), size: 22),
                      tooltip: 'btn_delete'.tr(),
                    ),
                ],
              ),
            ] else ...[
              // 1 Proof: Standard layout
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _showProofViewer(
                      context,
                      proofEntries.first['proof_url'],
                      proofEntries.first['user_name'] ?? 'Proof Screenshot',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: proofEntries.first['proof_url'],
                        height: 56,
                        width: 56,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(
                          height: 56,
                          width: 56,
                          color: ThemeService.cardSecondary,
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF88)),
                            ),
                          ),
                        ),
                        errorWidget: (c, u, e) => Container(
                          height: 56,
                          width: 56,
                          color: ThemeService.cardSecondary,
                          child: Icon(Icons.broken_image, color: ThemeService.textSecondary, size: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${proofEntries.first['user_name'] ?? "Player"} Proof',
                          style: TextStyle(
                              color: ThemeService.textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: () => _showProofViewer(
                            context,
                            proofEntries.first['proof_url'],
                            proofEntries.first['user_name'] ?? 'Proof Screenshot',
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.zoom_in_rounded, color: Color(0xFF38BDF8), size: 14),
                              const SizedBox(width: 4),
                              Text('tap_to_view_full'.tr(),
                                  style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.showDelete && widget.onDelete != null)
                    IconButton(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4655), size: 22),
                      tooltip: 'btn_delete'.tr(),
                    ),
                ],
              ),
            ],
          ] else ...[
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: ThemeService.cardSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('no_screenshot_attached'.tr(),
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
              ),
            ),
          ],

          // Action Buttons
          if (widget.showActions) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              style: TextStyle(color: ThemeService.textPrimary, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'reject_reason_hint'.tr(),
                hintStyle: TextStyle(color: ThemeService.textSecondary.withOpacity(0.6), fontSize: 12),
                filled: true,
                fillColor: ThemeService.cardSecondary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: ThemeService.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: ThemeService.border),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Color(0xFFFF4655)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                ),
              )
            else if (isDualProof && isRoom) ...[
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FF88),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            onPressed: () => _handleAcceptSpecificWinner(
                              winnerId: proofEntries[0]['user_id'].toString(),
                              winnerName: proofEntries[0]['user_name'].toString(),
                            ),
                            child: Text(
                              'win_player_btn'.tr(args: [proofEntries[0]['user_name'].toString()]),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1877F2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            onPressed: () => _handleAcceptSpecificWinner(
                              winnerId: proofEntries[1]['user_id'].toString(),
                              winnerName: proofEntries[1]['user_name'].toString(),
                            ),
                            child: Text(
                              'win_player_btn'.tr(args: [proofEntries[1]['user_name'].toString()]),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF4655),
                        side: const BorderSide(color: Color(0xFFFF4655)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text('reject_both_btn'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _handleReject,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4655),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: Text(
                          'reject_btn'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 16, color: Colors.black),
                        label: Text(
                          'accept_btn'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                        onPressed: _handleAcceptDefault,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
          Text(
            title,
            style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
          ),
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
          Text(
            title,
            style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${error ?? "Unknown error"}',
            textAlign: TextAlign.center,
            style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
