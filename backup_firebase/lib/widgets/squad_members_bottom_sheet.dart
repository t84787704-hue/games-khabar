import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/gamer_theme.dart';
import '../models/squad_post_model.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/lfg_service.dart';
import '../widgets/gamer_avatar.dart';

class SquadMembersBottomSheet extends StatefulWidget {
  final SquadPost squad;

  const SquadMembersBottomSheet({super.key, required this.squad});

  static Future<void> show(BuildContext context, SquadPost squad) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SquadMembersBottomSheet(squad: squad),
    );
  }

  @override
  State<SquadMembersBottomSheet> createState() => _SquadMembersBottomSheetState();
}

class _SquadMembersBottomSheetState extends State<SquadMembersBottomSheet> {
  final Map<String, GamerUser?> _userCache = {};
  bool _isActionInProgress = false;

  void _copyToClipboard(BuildContext context, String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: GamerTheme.neonGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleKick(BuildContext context, String memberUid, String memberName, String leaderUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        title: const Text('Kick Member', style: TextStyle(color: GamerTheme.textWhite)),
        content: Text(
          'Are you sure you want to remove $memberName from the squad?',
          style: const TextStyle(color: GamerTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kick'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionInProgress = true);
    try {
      await LfgService().kickMember(
        postId: widget.squad.id,
        memberUid: memberUid,
        leaderUid: leaderUid,
        memberName: memberName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$memberName removed from squad'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _handleLeave(BuildContext context, String memberUid, String leaderUid, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        title: const Text('Leave Squad', style: TextStyle(color: GamerTheme.textWhite)),
        content: const Text(
          'Are you sure you want to leave this squad?',
          style: TextStyle(color: GamerTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.accentOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionInProgress = true);
    try {
      await LfgService().leaveSquad(
        postId: widget.squad.id,
        memberUid: memberUid,
        leaderUid: leaderUid,
        memberName: memberName,
      );
      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You left the squad'),
            backgroundColor: GamerTheme.accentOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? GamerAuthService().currentUid ?? '';
    final leaderUid = widget.squad.ownerId.isNotEmpty ? widget.squad.ownerId : widget.squad.userId;
    final bool isCurrentUserOwner = currentUid.isNotEmpty && (currentUid == leaderUid);

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: const BoxDecoration(
        color: GamerTheme.bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: GamerTheme.accentCyan, width: 1.5)),
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('lfg_posts').doc(widget.squad.id).snapshots(),
        builder: (context, snapshot) {
          List<String> members = List<String>.from(widget.squad.members);
          if (snapshot.hasData && snapshot.data?.exists == true) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final snapMembers = List<String>.from(data['members'] ?? []);
            if (snapMembers.isNotEmpty) {
              members = snapMembers;
            }
          }

          // Ensure leader is always part of members list display
          if (!members.contains(leaderUid) && leaderUid.isNotEmpty) {
            members.insert(0, leaderUid);
          }

          final int filledCount = members.length;

          return Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GamerTheme.textMuted.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: GamerTheme.accentCyan, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Squad Members ($filledCount/4)',
                      style: const TextStyle(
                        color: GamerTheme.textWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    if (filledCount >= 4)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: const Text(
                          'FULL SQUAD',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: GamerTheme.textMuted, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Sub-info banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: GamerTheme.cardElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GamerTheme.borderDark),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.squad.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                      color: widget.squad.micOn ? GamerTheme.neonGreen : GamerTheme.textMuted,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.squad.micOn ? 'Mic Required' : 'Mic Optional',
                      style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.sports_esports_rounded, color: GamerTheme.accentCyan, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      widget.squad.mode,
                      style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      'Min K/D: ${widget.squad.kdNeeded}',
                      style: const TextStyle(
                        color: GamerTheme.accentOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: GamerTheme.borderDark, height: 16),

              // Members List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final uid = members[index];
                    final bool isLeader = uid == leaderUid;
                    final bool isMe = uid == currentUid;

                    return FutureBuilder<GamerUser?>(
                      future: _userCache.containsKey(uid)
                          ? Future.value(_userCache[uid])
                          : GamerAuthService().getUserProfile(uid).then((val) {
                              _userCache[uid] = val;
                              return val;
                            }),
                      builder: (context, userSnap) {
                        final user = userSnap.data;
                        final String displayName = user?.displayName.isNotEmpty == true
                            ? user!.displayName
                            : (isLeader ? widget.squad.displayName : 'Gamer');
                        final String username = user?.username.isNotEmpty == true
                            ? '@${user!.username}'
                            : (isLeader ? '@${widget.squad.username}' : '@gamer');
                        final String photoUrl = user?.photoUrl.isNotEmpty == true
                            ? user!.photoUrl
                            : (isLeader ? widget.squad.userAvatar : '');
                        final double kd = user?.kdRatio ?? (isLeader ? widget.squad.kdNeeded : 3.0);
                        final String inGameUid = user?.gameId.isNotEmpty == true
                            ? user!.gameId
                            : (isLeader ? widget.squad.inGameUid : uid);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isLeader
                                ? GamerTheme.cardElevated.withOpacity(0.9)
                                : GamerTheme.cardDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isLeader
                                  ? GamerTheme.accentOrange.withOpacity(0.6)
                                  : (isMe ? GamerTheme.accentCyan.withOpacity(0.6) : GamerTheme.borderDark),
                              width: (isLeader || isMe) ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Avatar
                                  GamerAvatar(
                                    photoUrl: photoUrl,
                                    displayName: displayName,
                                    radius: 20,
                                  ),
                                  const SizedBox(width: 10),

                                  // Name & Badges
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                displayName,
                                                style: const TextStyle(
                                                  color: GamerTheme.textWhite,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isLeader) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: GamerTheme.accentOrange.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: GamerTheme.accentOrange, width: 1),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.star_rounded, size: 11, color: GamerTheme.accentOrange),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      'LEADER',
                                                      style: TextStyle(
                                                        color: GamerTheme.accentOrange,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ] else if (isMe) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: GamerTheme.accentCyan.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: GamerTheme.accentCyan, width: 1),
                                                ),
                                                child: const Text(
                                                  'YOU',
                                                  style: TextStyle(
                                                    color: GamerTheme.accentCyan,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          username,
                                          style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // K/D & Mic chips
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: GamerTheme.bgDark,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: GamerTheme.borderLight.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      'K/D ${kd.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                        color: GamerTheme.accentCyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    widget.squad.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                                    size: 16,
                                    color: widget.squad.micOn ? GamerTheme.neonGreen : GamerTheme.textMuted,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Bottom action line: In-game UID + Copy button + Kick/Leave button
                              Row(
                                children: [
                                  // In-Game UID chip
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: GamerTheme.bgDark,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text(
                                            'UID: ',
                                            style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                                          ),
                                          Expanded(
                                            child: Text(
                                              inGameUid.isNotEmpty ? inGameUid : 'N/A',
                                              style: const TextStyle(
                                                color: GamerTheme.textWhite,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => _copyToClipboard(context, inGameUid, 'UID'),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 4),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.copy_rounded, size: 12, color: GamerTheme.neonGreen),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'COPY',
                                                    style: TextStyle(
                                                      color: GamerTheme.neonGreen,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Action: Kick (for Owner) or Leave (for Member)
                                  if (isCurrentUserOwner && !isLeader) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        side: const BorderSide(color: Colors.redAccent),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: const Size(0, 30),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(Icons.person_remove_rounded, size: 14),
                                      label: const Text('KICK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: _isActionInProgress
                                          ? null
                                          : () => _handleKick(context, uid, displayName, leaderUid),
                                    ),
                                  ] else if (isMe && !isLeader) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: GamerTheme.accentOrange,
                                        side: const BorderSide(color: GamerTheme.accentOrange),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: const Size(0, 30),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(Icons.exit_to_app_rounded, size: 14),
                                      label: const Text('LEAVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: _isActionInProgress
                                          ? null
                                          : () => _handleLeave(context, uid, leaderUid, displayName),
                                    ),
                                  ],
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
        },
      ),
    );
  }
}
