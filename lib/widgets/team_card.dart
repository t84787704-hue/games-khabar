import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../services/team_match_service.dart';
import '../services/gamer_auth_service.dart';
import '../widgets/send_team_match_challenge_dialog.dart';
import '../screens/team_profile_screen.dart';

class TeamCard extends StatefulWidget {
  final TeamModel team;
  final String myTeamId;

  const TeamCard({
    super.key,
    required this.team,
    this.myTeamId = '',
  });

  @override
  State<TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<TeamCard> {
  final TeamService _teamService = TeamService();
  final TeamMatchService _matchService = TeamMatchService();
  bool _isRequesting = false;

  Future<void> _deleteChallenge(DocumentReference docRef, String challengeId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      // Delete challenge document directly so red banner disappears instantly!
      await docRef.delete();
      try {
        await FirebaseFirestore.instance.collection('team_matches').doc(challengeId).delete();
      } catch (_) {}
      try {
        await _matchService.cancelChallenge(challengeId, cancelledByUid: currentUid);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚫 چیلنج کامیابی سے Cancel کر دیا گیا ہے'),
            backgroundColor: Color(0xFF1877F2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamCard] Error deleting challenge: $e');
    }
  }

  Future<void> _handleCancelChallenge(String challengeId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await FirebaseFirestore.instance.collection('challenges').doc(challengeId).delete();
      try {
        await FirebaseFirestore.instance.collection('team_matches').doc(challengeId).delete();
      } catch (_) {}
      await _matchService.cancelChallenge(challengeId, cancelledByUid: currentUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚫 چیلنج کامیابی سے Cancel کر دیا گیا ہے'),
            backgroundColor: Color(0xFF1877F2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamCard] Error cancelling challenge: $e');
    }
  }

  Future<void> _handleJoin(String currentUid) async {
    final currentGamer = GamerAuthService().currentGamer;
    final userName = currentGamer?.displayName ?? currentGamer?.username ?? 'Gamer';

    setState(() => _isRequesting = true);
    final success = await _teamService.requestToJoinTeam(
      teamId: widget.team.id,
      userId: currentUid,
      userName: userName,
    );
    setState(() => _isRequesting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ شمولیت کی درخواست بھیج دی گئی ہے!'),
            backgroundColor: Color(0xFF1877F2),
          ),
        );
      }
    }
  }

  Future<void> _handleChallenge(String currentUid) async {
    final myTeams = await _teamService.getUserTeams(currentUid);
    final myLeaderTeams = myTeams.where((t) => t.isLeader(currentUid)).toList();

    if (!mounted) return;

    if (myLeaderTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('چیلنج بھیجنے کے لیے پہلے اپنی ٹیم بنائیں (Create Team)!'),
          backgroundColor: Color(0xFF65676B),
        ),
      );
      return;
    }

    final effectiveMyTeamId = widget.myTeamId.isNotEmpty ? widget.myTeamId : myLeaderTeams.first.id;

    // Check if a pending challenge already exists where fromTeamId == myTeamId && toTeamId == targetId
    try {
      final existingCheck = await FirebaseFirestore.instance
          .collection('challenges')
          .where('fromTeamId', isEqualTo: effectiveMyTeamId)
          .where('toTeamId', isEqualTo: widget.team.id)
          .get();

      for (var doc in existingCheck.docs) {
        final data = doc.data();
        final st = (data['status'] ?? '').toString().toLowerCase();
        if (st == 'pending') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Aap ne pehle hi challenge bheja hai!'),
              backgroundColor: Color(0xFFFF4655),
            ),
          );
          return;
        }
      }
    } catch (_) {}

    SendTeamMatchChallengeDialog.show(
      context,
      opponentTeam: widget.team,
      myTeams: myLeaderTeams,
    );
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isLeader = team.isLeader(currentUid);
    final isMember = team.isMember(currentUid);
    final hasRequested = team.hasRequestedJoin(currentUid);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E6EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamProfileScreen(teamId: team.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Logo, Name, Tag, Game & Members
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team Logo
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE4E6EB),
                        border: Border.all(color: const Color(0xFFCED0D4), width: 1.2),
                        image: team.logo.isNotEmpty
                            ? DecorationImage(image: NetworkImage(team.logo), fit: BoxFit.cover)
                            : null,
                      ),
                      child: team.logo.isEmpty
                          ? const Center(child: Icon(Icons.shield_rounded, color: Color(0xFF1877F2), size: 28))
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // Name, Tag & Leader
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  team.name,
                                  style: const TextStyle(
                                    color: Color(0xFF050505),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7F3FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF1877F2).withOpacity(0.3)),
                                ),
                                child: Text(
                                  team.tag,
                                  style: const TextStyle(
                                    color: Color(0xFF1877F2),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Leader: ${team.leaderName}',
                            style: const TextStyle(color: Color(0xFF65676B), fontSize: 12),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F2F5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE4E6EB)),
                                ),
                                child: Text(
                                  team.game,
                                  style: const TextStyle(
                                    color: Color(0xFF050505),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  const Icon(Icons.group_rounded, size: 14, color: Color(0xFF65676B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${team.memberCount} Members',
                                    style: const TextStyle(color: Color(0xFF65676B), fontSize: 11.5, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (team.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    team.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF1C1E21), fontSize: 12.5),
                  ),
                ],

                // Red banner if current user has already sent a pending challenge to this team
                if (!isLeader && !isMember && currentUid.isNotEmpty)
                  StreamBuilder<QuerySnapshot>(
                    stream: widget.myTeamId.isNotEmpty
                        ? FirebaseFirestore.instance
                            .collection('challenges')
                            .where('fromTeamId', isEqualTo: widget.myTeamId)
                            .where('toTeamId', isEqualTo: team.id)
                            .where('status', isEqualTo: 'pending')
                            .snapshots()
                        : FirebaseFirestore.instance
                            .collection('challenges')
                            .where('toTeamId', isEqualTo: team.id)
                            .where('status', isEqualTo: 'pending')
                            .snapshots(),
                    builder: (context, cSnap) {
                      DocumentSnapshot? pendingDoc;
                      if (cSnap.hasData && cSnap.data!.docs.isNotEmpty) {
                        for (var d in cSnap.data!.docs) {
                          final data = d.data() as Map<String, dynamic>;
                          final st = (data['status'] ?? '').toString().toLowerCase();
                          if (st == 'pending') {
                            final fTeam = data['fromTeamId']?.toString() ?? '';
                            final fLeader = data['fromTeamLeaderId']?.toString() ?? '';
                            if (widget.myTeamId.isNotEmpty && fTeam == widget.myTeamId) {
                              pendingDoc = d;
                              break;
                            } else if (fLeader == currentUid) {
                              pendingDoc = d;
                              break;
                            }
                          }
                        }
                      }

                      if (pendingDoc == null) return const SizedBox.shrink();

                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655), size: 14),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Aap ne pehle hi challenge bheja hai',
                                style: TextStyle(color: Color(0xFFFF4655), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            InkWell(
                              onTap: () => _deleteChallenge(pendingDoc!.reference, pendingDoc.id),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Color(0xFFFF4655),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE4E6EB), height: 1),
                const SizedBox(height: 10),

                // Bottom Action Buttons
                Row(
                  children: [
                    // Win/Loss record mini badge
                    Text(
                      'W: ${team.wins} | L: ${team.losses} | Pts: ${team.points}',
                      style: const TextStyle(color: Color(0xFF65676B), fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),

                    // View Team Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF050505),
                        side: const BorderSide(color: Color(0xFFCED0D4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamProfileScreen(teamId: team.id),
                          ),
                        );
                      },
                      child: const Text('View Team', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),

                    // Join / Challenge / Manage Button
                    if (isLeader) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F3FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1877F2)),
                        ),
                        child: const Text(
                          'YOUR TEAM',
                          style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ] else if (isMember) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4E6EB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCED0D4)),
                        ),
                        child: const Text(
                          'MEMBER',
                          style: TextStyle(color: Color(0xFF050505), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ] else ...[
                      // Challenge / Cancel Challenge Button with real-time stream
                      StreamBuilder<QuerySnapshot>(
                        stream: widget.myTeamId.isNotEmpty
                            ? FirebaseFirestore.instance
                                .collection('challenges')
                                .where('fromTeamId', isEqualTo: widget.myTeamId)
                                .where('toTeamId', isEqualTo: team.id)
                                .where('status', isEqualTo: 'pending')
                                .snapshots()
                            : (currentUid.isNotEmpty
                                ? FirebaseFirestore.instance
                                    .collection('challenges')
                                    .where('toTeamId', isEqualTo: team.id)
                                    .where('status', isEqualTo: 'pending')
                                    .snapshots()
                                : Stream.empty()),
                        builder: (context, cSnap) {
                          DocumentSnapshot? pendingDoc;
                          if (cSnap.hasData && cSnap.data!.docs.isNotEmpty) {
                            for (var d in cSnap.data!.docs) {
                              final data = d.data() as Map<String, dynamic>;
                              final st = (data['status'] ?? '').toString().toLowerCase();
                              if (st == 'pending') {
                                final fTeam = data['fromTeamId']?.toString() ?? '';
                                final fLeader = data['fromTeamLeaderId']?.toString() ?? '';
                                if (widget.myTeamId.isNotEmpty && fTeam == widget.myTeamId) {
                                  pendingDoc = d;
                                  break;
                                } else if (fLeader == currentUid) {
                                  pendingDoc = d;
                                  break;
                                }
                              }
                            }
                          }

                          if (pendingDoc != null) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE4E6EB),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCED0D4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFF65676B)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Requested',
                                        style: TextStyle(
                                          color: Color(0xFF65676B),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFFF4655),
                                    side: const BorderSide(color: Color(0xFFFF4655), width: 1.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    backgroundColor: const Color(0xFFFEF2F2),
                                  ),
                                  icon: const Icon(Icons.close_rounded, size: 13, color: Color(0xFFFF4655)),
                                  label: const Text('Cancel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _deleteChallenge(pendingDoc!.reference, pendingDoc.id),
                                ),
                              ],
                            );
                          }

                          return OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1877F2),
                              side: const BorderSide(color: Color(0xFF1877F2)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.flash_on_rounded, size: 13, color: Color(0xFF1877F2)),
                            label: const Text('Challenge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _handleChallenge(currentUid),
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Join Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasRequested ? const Color(0xFFE4E6EB) : const Color(0xFF1877F2),
                          foregroundColor: hasRequested ? const Color(0xFF65676B) : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: const Size(0, 32),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(
                          hasRequested ? Icons.hourglass_top_rounded : Icons.person_add_rounded,
                          size: 14,
                          color: hasRequested ? const Color(0xFF65676B) : Colors.white,
                        ),
                        label: Text(
                          hasRequested ? 'Requested' : 'Join',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: hasRequested ? const Color(0xFF65676B) : Colors.white,
                          ),
                        ),
                        onPressed: (hasRequested || _isRequesting) ? null : () => _handleJoin(currentUid),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
