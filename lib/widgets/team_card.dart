import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../services/supabase_service.dart';
import '../services/gamer_auth_service.dart';
import '../screens/team_profile_screen.dart';

class TeamCard extends StatefulWidget {
  final TeamModel team;
  final String myTeamId;
  final String myTeamName;
  final Map<String, dynamic>? pendingChallenge;
  final Future<void> Function(String challengeId)? onCancelChallenge;

  const TeamCard({
    super.key,
    required this.team,
    this.myTeamId = '',
    this.myTeamName = '',
    this.pendingChallenge,
    this.onCancelChallenge,
  });

  @override
  State<TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<TeamCard> {
  final TeamService _teamService = TeamService();
  bool _isRequesting = false;

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

    final effectiveMyTeam = myLeaderTeams.firstWhere(
      (t) => t.id == widget.myTeamId,
      orElse: () => myLeaderTeams.first,
    );
    final effectiveMyTeamId = SupabaseService.toUuid(effectiveMyTeam.id);
    final effectiveTargetId = SupabaseService.toUuid(widget.team.id);
    final effectiveMyTeamName = widget.myTeamName.isNotEmpty ? widget.myTeamName : effectiveMyTeam.name;

    try {
      // 1. Challenge button click pe pehle check karo:
      List<dynamic> existing = [];
      try {
        existing = await SupabaseService.client
            .from('challenges')
            .select()
            .eq('from_team_id', effectiveMyTeamId)
            .eq('to_team_id', effectiveTargetId)
            .inFilter('status', ['pending', 'requested', 'active', 'under_review']);
      } catch (_) {
        existing = [];
      }

      // 3. IF existing NOT empty hai (complete/cancel kiye baghair dubara bhej raha hai):
      //    - Insert MAT karo, block karo
      //    - Show ERROR Banner Red: "⚠️ Aap ne pehle hi challenge bheja hai - Aap Jf19 ko pehle se challenge bhej chuke hain, isko complete ya cancel kiye baghair dubara nahi bhej sakte" + CANCEL button
      if (existing.isNotEmpty) {
        final cId = existing[0]['id']?.toString() ?? '';
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF131A29),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655), size: 24),
                  SizedBox(width: 8),
                  Text('Challenge Already Sent', style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Text(
                '⚠️ Aap ne pehle hi challenge bheja hai - Aap ${widget.team.name} ko pehle se challenge bhej chuke hain, isko complete ya cancel kiye baghair dubara nahi bhej sakte',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF8B949E))),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (widget.onCancelChallenge != null && cId.isNotEmpty) {
                      widget.onCancelChallenge!(cId);
                    } else if (cId.isNotEmpty) {
                      _cancelChallengeLocally(cId);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4655),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 2. IF existing empty hai (koi pending nahi):
      //    - Insert karo into challenges
      //    - Show SUCCESS Banner Green/Blue: "✅ Aapka challenge bhej diya gaya hai - Jf19 ko challenge bhej diya gaya hai, jawab ka intezar hai" + CANCEL CHALLENGE button
      //    - Button ko "Requested" + "Cancel" me change karo
      try {
        await SupabaseService.client.from('challenges').insert({
          'from_team_id': effectiveMyTeamId,
          'to_team_id': effectiveTargetId,
          'from_team_name': effectiveMyTeamName,
          'to_team_name': widget.team.name,
          'status': 'pending',
          'game': 'BGMI',
        });
      } catch (_) {
        await SupabaseService.client.from('challenges').insert({
          'from_team_id': effectiveMyTeamId,
          'to_team_id': effectiveTargetId,
          'from_team_name': effectiveMyTeamName,
          'to_team_name': widget.team.name,
          'status': 'pending',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Aapka challenge bhej diya gaya hai - ${widget.team.name} ko challenge bhej diya gaya hai, jawab ka intezar hai'),
            backgroundColor: const Color(0xFF1877F2),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamCard] Error sending challenge via Supabase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending challenge: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  final Set<String> _localCancelledIds = {};

  Future<void> _cancelChallengeLocally(String challengeId) async {
    setState(() {
      _localCancelledIds.add(challengeId);
    });
    try {
      await SupabaseService.client.from('challenges').delete().eq('id', challengeId);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge Cancel ho gaya'),
            backgroundColor: Color(0xFF1877F2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamCard] Error cancelling challenge: $e');
    }
  }

  Widget _buildRedBanner(String challengeId) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1877F2).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: Color(0xFF1877F2), size: 14),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Challenge bhej diya hai - Jawab ka intezar hai',
              style: TextStyle(color: Color(0xFF1877F2), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: () {
              if (widget.onCancelChallenge != null) {
                widget.onCancelChallenge!(challengeId);
              } else {
                _cancelChallengeLocally(challengeId);
              }
            },
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
  }

  Widget _buildRequestedButton(String challengeId) {
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
          onPressed: () {
            if (widget.onCancelChallenge != null) {
              widget.onCancelChallenge!(challengeId);
            } else {
              _cancelChallengeLocally(challengeId);
            }
          },
        ),
      ],
    );
  }

  Widget _buildChallengeButton(String currentUid) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      icon: const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
      label: const Text('CHALLENGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      onPressed: () => _handleChallenge(currentUid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isLeader = team.isLeader(currentUid);
    final isMember = team.isMember(currentUid);
    final hasRequested = team.hasRequestedJoin(currentUid);
    final bool isMyOwnTeam = isLeader ||
        (widget.myTeamId.isNotEmpty &&
            (team.id.toLowerCase() == widget.myTeamId.toLowerCase() ||
             SupabaseService.toUuid(team.id).toLowerCase() == SupabaseService.toUuid(widget.myTeamId).toLowerCase()));

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
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamProfileScreen(teamId: team.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Logo, Name, Tag & Leader
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

                // 2. RED BANNER: Realtime Supabase check if pending challenge already sent to this team
                if (!isMyOwnTeam && currentUid.isNotEmpty && widget.myTeamId.isNotEmpty) ...[
                  if (widget.onCancelChallenge != null) ...[
                    if (widget.pendingChallenge != null)
                      _buildRedBanner(widget.pendingChallenge!['id']?.toString() ?? ''),
                  ] else ...[
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: SupabaseService.client
                          .from('challenges')
                          .stream(primaryKey: ['id'])
                          .eq('from_team_id', SupabaseService.toUuid(widget.myTeamId)),
                      builder: (context, cSnap) {
                        final challenges = cSnap.data ?? [];
                        final targetUuid = SupabaseService.toUuid(team.id).toLowerCase();
                        final rawTeamId = team.id.toLowerCase();
                        final pendingDoc = challenges.firstWhere(
                          (d) {
                            final toId = d['to_team_id']?.toString().toLowerCase();
                            final st = (d['status'] ?? '').toString().toLowerCase();
                            final id = d['id']?.toString() ?? '';
                            return (toId == targetUuid || toId == rawTeamId) &&
                                st == 'pending' &&
                                !_localCancelledIds.contains(id);
                          },
                          orElse: () => {},
                        );

                        if (pendingDoc.isEmpty) return const SizedBox.shrink();
                        return _buildRedBanner(pendingDoc['id']?.toString() ?? '');
                      },
                    ),
                  ],
                ],

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

                    // Join / Challenge / Active Match / Manage Button
                    if (isMyOwnTeam) ...[
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
                    ] else ...[
                      // 3. ACTIVE MATCH CONNECTION CHECK VIA REALTIME
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: widget.myTeamId.isNotEmpty
                            ? SupabaseService.client
                                .from('active_matches')
                                .stream(primaryKey: ['id'])
                                .eq('status', 'active')
                            : Stream.value([]),
                        builder: (context, activeSnap) {
                          final activeMatches = activeSnap.data ?? [];
                          final myUuid = SupabaseService.toUuid(widget.myTeamId).toLowerCase();
                          final myRawId = widget.myTeamId.toLowerCase();
                          final targetUuid = SupabaseService.toUuid(team.id).toLowerCase();
                          final targetRawId = team.id.toLowerCase();

                          final activeMatchWithOpponent = activeMatches.firstWhere(
                            (m) {
                              if (m['status'] != 'active') return false;
                              final participants = m['participants'];
                              final List<String> pList = [];
                              if (participants is List) {
                                pList.addAll(participants.map((p) => p.toString().toLowerCase()));
                              }
                              pList.add(m['team1_id']?.toString().toLowerCase() ?? '');
                              pList.add(m['team2_id']?.toString().toLowerCase() ?? '');
                              final hasMe = pList.contains(myUuid) || pList.contains(myRawId);
                              final hasTarget = pList.contains(targetUuid) || pList.contains(targetRawId);
                              return hasMe && hasTarget;
                            },
                            orElse: () => {},
                          );

                          // If active match found with opponent: show "LIVE" badge + "View Match" button
                          if (activeMatchWithOpponent.isNotEmpty) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00FF88),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.black),
                                      SizedBox(width: 4),
                                      Text(
                                        'LIVE',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.sports_esports_rounded, size: 14),
                                  label: const Text('View Match', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TeamProfileScreen(teamId: team.id),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          }

                          // 2. SENDER SIDE: CHECK PENDING CHALLENGE VIA REALTIME
                          if (widget.onCancelChallenge != null) {
                            if (widget.pendingChallenge != null) {
                              return _buildRequestedButton(widget.pendingChallenge!['id']?.toString() ?? '');
                            }
                            return _buildChallengeButton(currentUid);
                          }

                          return StreamBuilder<List<Map<String, dynamic>>>(
                            stream: widget.myTeamId.isNotEmpty
                                ? SupabaseService.client
                                    .from('challenges')
                                    .stream(primaryKey: ['id'])
                                    .eq('from_team_id', SupabaseService.toUuid(widget.myTeamId))
                                : Stream.value([]),
                            builder: (context, cSnap) {
                              final challenges = cSnap.data ?? [];
                              final targetUuid = SupabaseService.toUuid(team.id).toLowerCase();
                              final rawTeamId = team.id.toLowerCase();
                              final pendingDoc = challenges.firstWhere(
                                (d) {
                                  final toId = d['to_team_id']?.toString().toLowerCase();
                                  final st = (d['status'] ?? '').toString().toLowerCase();
                                  final id = d['id']?.toString() ?? '';
                                  return (toId == targetUuid || toId == rawTeamId) &&
                                      st == 'pending' &&
                                      !_localCancelledIds.contains(id);
                                },
                                orElse: () => {},
                              );

                              if (pendingDoc.isNotEmpty) {
                                return _buildRequestedButton(pendingDoc['id']?.toString() ?? '');
                              }

                              return _buildChallengeButton(currentUid);
                            },
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
