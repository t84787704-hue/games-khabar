import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../services/gamer_auth_service.dart';
import '../widgets/send_team_match_challenge_dialog.dart';
import '../screens/team_profile_screen.dart';

class TeamCard extends StatefulWidget {
  final TeamModel team;

  const TeamCard({super.key, required this.team});

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
            backgroundColor: Color(0xFF00FF88),
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
          backgroundColor: Color(0xFFFF6B00),
        ),
      );
      return;
    }

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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131A29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3447)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamProfileScreen(teamId: team.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
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
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A2234),
                        border: Border.all(color: const Color(0xFFFF6B00), width: 1.5),
                        image: team.logo.isNotEmpty
                            ? DecorationImage(image: NetworkImage(team.logo), fit: BoxFit.cover)
                            : null,
                      ),
                      child: team.logo.isEmpty
                          ? const Center(child: Icon(Icons.shield_rounded, color: Colors.white70, size: 28))
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
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B00).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.4)),
                                ),
                                child: Text(
                                  team.tag,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Leader: ${team.leaderName}',
                            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FF88).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  team.game,
                                  style: const TextStyle(
                                    color: Color(0xFF00FF88),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  const Icon(Icons.group_rounded, size: 14, color: Color(0xFF8B949E)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${team.memberCount} Members',
                                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontWeight: FontWeight.bold),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(color: Color(0xFF2A3447), height: 1),
                const SizedBox(height: 10),

                // Bottom Action Buttons
                Row(
                  children: [
                    // Win/Loss record mini badge
                    Text(
                      'W: ${team.wins} | L: ${team.losses} | Pts: ${team.points}',
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),

                    // View Team Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF2A3447)),
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
                          color: const Color(0xFFFF6B00).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF6B00)),
                        ),
                        child: const Text(
                          'YOUR TEAM',
                          style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ] else if (isMember) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00FF88)),
                        ),
                        child: const Text(
                          'MEMBER',
                          style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ] else ...[
                      // Challenge Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF4655),
                          side: const BorderSide(color: Color(0xFFFF4655)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.flash_on_rounded, size: 13, color: Color(0xFFFF4655)),
                        label: const Text('Challenge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _handleChallenge(currentUid),
                      ),
                      const SizedBox(width: 8),

                      // Join Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasRequested ? Colors.white24 : const Color(0xFF00FF88),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: const Size(0, 32),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(
                          hasRequested ? Icons.hourglass_top_rounded : Icons.person_add_rounded,
                          size: 14,
                          color: Colors.black,
                        ),
                        label: Text(
                          hasRequested ? 'Requested' : 'Join',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, color: Colors.black),
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
