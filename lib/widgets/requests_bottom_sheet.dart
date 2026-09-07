import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/squad_post_model.dart';
import '../models/squad_request_model.dart';
import '../screens/gamer_profile_screen.dart';
import '../services/squad_service.dart';
import '../services/lfg_service.dart';
import '../widgets/gamer_avatar.dart';

class RequestsBottomSheet extends StatefulWidget {
  final SquadPost squad;

  const RequestsBottomSheet({
    super.key,
    required this.squad,
  });

  @override
  State<RequestsBottomSheet> createState() => _RequestsBottomSheetState();
}

class _RequestsBottomSheetState extends State<RequestsBottomSheet> {
  final SquadService _squadService = SquadService();
  final LfgService _lfgService = LfgService();
  final Set<String> _processingIds = {};

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd MMM').format(dt);
  }

  Color _getRankColor(String rank) {
    final r = rank.toLowerCase();
    if (r.contains('conqueror')) return const Color(0xFFFF334B);
    if (r.contains('ace')) return const Color(0xFFFF9500);
    if (r.contains('crown')) return const Color(0xFFAF52DE);
    if (r.contains('diamond')) return const Color(0xFF007AFF);
    return GamerTheme.textMuted;
  }

  Future<void> _handleAccept(SquadJoinRequest req) async {
    setState(() => _processingIds.add(req.id));
    try {
      // Use transaction-based acceptRequest on lfg_posts / squads
      await _lfgService.acceptRequest(
        postId: widget.squad.id,
        requesterId: req.userId,
        requesterName: req.name,
        leaderUid: widget.squad.userId,
        inGameUid: widget.squad.inGameUid,
        mode: widget.squad.mode,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: GamerTheme.neonGreen, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${req.name} added to squad! Notification sent.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: GamerTheme.cardDark,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        // Close bottom sheet after accept as requested
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(req.id));
      }
    }
  }

  Future<void> _handleReject(SquadJoinRequest req) async {
    setState(() => _processingIds.add(req.id));
    try {
      await _lfgService.declineRequest(
        postId: widget.squad.id,
        requesterId: req.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Declined request from ${req.name}'),
            backgroundColor: GamerTheme.cardDark,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(req.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final squad = widget.squad;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GamerTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: Title, Count Badge, Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GamerTheme.accentOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.4)),
                    ),
                    child: const Icon(
                      Icons.group_rounded,
                      color: GamerTheme.accentOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Squad Join Requests',
                          style: TextStyle(
                            color: GamerTheme.textWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${squad.mode} • UID: ${squad.inGameUid.isNotEmpty ? squad.inGameUid : squad.game}',
                          style: const TextStyle(
                            color: GamerTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: GamerTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(color: GamerTheme.borderDark, height: 1),

            // Requirements Info Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: GamerTheme.bgDark.withOpacity(0.5),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 14, color: GamerTheme.accentOrange),
                  const SizedBox(width: 6),
                  Text(
                    'Criteria: ${squad.tierNeeded} • ${squad.kdNeeded.toStringAsFixed(1)}+ K/D • ${squad.language}',
                    style: const TextStyle(
                      color: GamerTheme.textGray,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Real-Time Requests List
            Expanded(
              child: StreamBuilder<List<SquadJoinRequest>>(
                stream: _squadService.getSquadRequestsStream(squad.id, squad.joinRequests),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: GamerTheme.accentOrange),
                    );
                  }

                  final requests = snapshot.data ?? [];
                  if (requests.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: GamerTheme.cardElevated,
                                shape: BoxShape.circle,
                                border: Border.all(color: GamerTheme.borderDark),
                              ),
                              child: const Icon(
                                Icons.group_off_rounded,
                                size: 38,
                                color: GamerTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No Pending Requests',
                              style: TextStyle(
                                color: GamerTheme.textWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'When players request to join your squad, their profile, Tier & K/D ratio will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: GamerTheme.textMuted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      final isBusy = _processingIds.contains(req.id);
                      final rankColor = _getRankColor(req.tier);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: GamerTheme.cardElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: GamerTheme.borderDark),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Requester Info Header
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (req.userId.isNotEmpty) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => GamerProfileScreen(userId: req.userId),
                                        ),
                                      );
                                    }
                                  },
                                  child: GamerAvatar(
                                    photoUrl: req.userAvatar,
                                    displayName: req.name,
                                    radius: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              req.name,
                                              style: const TextStyle(
                                                color: GamerTheme.textWhite,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatTime(req.createdAt),
                                            style: const TextStyle(
                                              color: GamerTheme.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (req.username.isNotEmpty)
                                        Text(
                                          '@${req.username.replaceAll('@', '')}',
                                          style: const TextStyle(
                                            color: GamerTheme.accentBlue,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      const SizedBox(height: 6),

                                      // Tier, KD and UID Pills
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          // Tier badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: rankColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: rankColor.withOpacity(0.4)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.shield_rounded, size: 11, color: rankColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  req.tier,
                                                  style: TextStyle(
                                                    color: rankColor,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // KD badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: GamerTheme.accentOrange.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.4)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.local_fire_department_rounded, size: 11, color: GamerTheme.accentOrange),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '${req.kd.toStringAsFixed(1)} K/D',
                                                  style: const TextStyle(
                                                    color: GamerTheme.accentOrange,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // In-game UID
                                          if (req.inGameUid.isNotEmpty)
                                            InkWell(
                                              onTap: () {
                                                Clipboard.setData(ClipboardData(text: req.inGameUid));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Copied UID ${req.inGameUid}'),
                                                    duration: const Duration(seconds: 1),
                                                  ),
                                                );
                                              },
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: GamerTheme.cardDark,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: GamerTheme.borderDark),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.copy_rounded, size: 10, color: GamerTheme.textMuted),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'UID: ${req.inGameUid}',
                                                      style: const TextStyle(
                                                        color: GamerTheme.textGray,
                                                        fontSize: 10.5,
                                                        fontFamily: 'monospace',
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Accept & Reject Action Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Reject Button
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.close_rounded, size: 15),
                                  label: const Text(
                                    'Decline',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  onPressed: isBusy ? null : () => _handleReject(req),
                                ),
                                const SizedBox(width: 10),

                                // Accept Button
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GamerTheme.neonGreen,
                                    foregroundColor: GamerTheme.bgDark,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: isBusy
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: GamerTheme.bgDark,
                                          ),
                                        )
                                      : const Icon(Icons.check_circle_rounded, size: 16, color: GamerTheme.bgDark),
                                  label: Text(
                                    isBusy ? 'Adding...' : 'Accept',
                                    style: const TextStyle(
                                      color: GamerTheme.bgDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: isBusy ? null : () => _handleAccept(req),
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
        ),
      ),
    );
  }
}
