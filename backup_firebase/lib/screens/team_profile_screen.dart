import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/team_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/team_service.dart';
import '../widgets/send_team_match_challenge_dialog.dart';
import 'gamer_profile_screen.dart';

class TeamProfileScreen extends StatefulWidget {
  final String teamId;

  const TeamProfileScreen({super.key, required this.teamId});

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  final TeamService _teamService = TeamService();
  bool _isActionLoading = false;

  Future<void> _handleJoinRequest(TeamModel team, String currentUid) async {
    final currentGamer = GamerAuthService().currentGamer;
    final userName = currentGamer?.displayName ?? currentGamer?.username ?? 'Gamer';

    setState(() => _isActionLoading = true);
    final success = await _teamService.requestToJoinTeam(
      teamId: team.id,
      userId: currentUid,
      userName: userName,
    );
    setState(() => _isActionLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ شمولیت کی درخواست ٹیم لیڈر کو بھیج دی گئی ہے!'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('درخواست بھیجنے میں خرابی ہوئی'), backgroundColor: Color(0xFFFF4655)),
        );
      }
    }
  }

  Future<void> _handleChallenge(TeamModel opponentTeam, String currentUid) async {
    final myTeams = await _teamService.getUserTeams(currentUid);
    final myLeaderTeams = myTeams.where((t) => t.isLeader(currentUid)).toList();

    if (!mounted) return;

    if (myLeaderTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('چیلنج بھیجنے کے لیے آپ کا کسی ٹیم کا لیڈر ہونا ضروری ہے! پہلے اپنی ٹیم بنائیں۔'),
          backgroundColor: Color(0xFFFF6B00),
        ),
      );
      return;
    }

    SendTeamMatchChallengeDialog.show(
      context,
      opponentTeam: opponentTeam,
      myTeams: myLeaderTeams,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<TeamModel?>(
      stream: _teamService.getTeamStream(widget.teamId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0F17),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
          );
        }

        final team = snapshot.data;
        if (team == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0F17),
            body: Center(child: Text('ٹیم نہیں ملی', style: TextStyle(color: Colors.white))),
          );
        }

        final isLeader = team.isLeader(currentUid);
        final isMember = team.isMember(currentUid);
        final hasRequested = team.hasRequestedJoin(currentUid);

        return Scaffold(
          backgroundColor: const Color(0xFF0B0F17),
          appBar: AppBar(
            backgroundColor: const Color(0xFF131A29),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              '${team.name} [${team.tag}]',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            actions: [
              if (!isLeader && !isMember) ...[
                IconButton(
                  tooltip: 'Challenge Team',
                  icon: const Icon(Icons.flash_on_rounded, color: Color(0xFFFF4655)),
                  onPressed: () => _handleChallenge(team, currentUid),
                ),
              ],
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Header Profile Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B2436), Color(0xFF131A29)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A3447)),
                  ),
                  child: Row(
                    children: [
                      // Team Logo
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF26334D),
                          border: Border.all(color: const Color(0xFFFF6B00), width: 2),
                          image: team.logo.isNotEmpty
                              ? DecorationImage(image: NetworkImage(team.logo), fit: BoxFit.cover)
                              : null,
                        ),
                        child: team.logo.isEmpty
                            ? const Center(child: Icon(Icons.shield_rounded, color: Colors.white70, size: 36))
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    team.name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B00).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    team.tag,
                                    style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.w900, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF88).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Game: ${team.game}',
                                style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '👑 Team Leader: ${team.leaderName}',
                              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Win / Loss Record Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161F2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A3447)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRecordStat('WINS', '${team.wins}', const Color(0xFF00FF88)),
                      _buildDivider(),
                      _buildRecordStat('LOSSES', '${team.losses}', const Color(0xFFFF4655)),
                      _buildDivider(),
                      _buildRecordStat('DRAWS', '${team.draws}', const Color(0xFFFFB020)),
                      _buildDivider(),
                      _buildRecordStat('POINTS', '${team.points}', const Color(0xFFFF6B00)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons (Join Request / Challenge)
                if (!isLeader && !isMember) ...[
                  Row(
                    children: [
                      // Join Request Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (hasRequested || _isActionLoading) ? null : () => _handleJoinRequest(team, currentUid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasRequested ? Colors.white24 : const Color(0xFF00FF88),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(hasRequested ? Icons.hourglass_top_rounded : Icons.person_add_rounded, size: 18),
                          label: Text(
                            hasRequested ? 'REQUESTED' : 'JOIN REQUEST',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Challenge Team Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handleChallenge(team, currentUid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4655),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.flash_on_rounded, size: 18),
                          label: const Text(
                            'CHALLENGE ⚔️',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Team Description
                if (team.description.isNotEmpty) ...[
                  _buildSectionHeader('ٹیم کی تفصیل (Description)'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161F2E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      team.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Team Requirements
                if (team.requirements.isNotEmpty) ...[
                  _buildSectionHeader('شمولیت کی شرائط (Requirements)'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161F2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFB020).withOpacity(0.3)),
                    ),
                    child: Text(
                      team.requirements,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Pending Join Requests (Visible only to Team Leader)
                if (isLeader && team.pendingJoinRequests.isNotEmpty) ...[
                  _buildSectionHeader('نئی شمولیت کی درخواستیں (${team.pendingJoinRequests.length})'),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
                    ),
                    child: Column(
                      children: team.pendingJoinRequests.map((uid) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 16,
                                backgroundColor: Color(0xFF26334D),
                                child: Icon(Icons.person, color: Colors.white70, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Gamer ID: ${uid.substring(0, 8)}...',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFFFF4655), size: 20),
                                onPressed: () => _teamService.rejectJoinRequest(teamId: team.id, userId: uid),
                              ),
                              IconButton(
                                icon: const Icon(Icons.check_rounded, color: Color(0xFF00FF88), size: 22),
                                onPressed: () => _teamService.acceptJoinRequest(
                                  teamId: team.id,
                                  userId: uid,
                                  userName: 'Player',
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Team Members List
                _buildSectionHeader('ٹیم ممبران (${team.memberCount})'),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161F2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A3447)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: team.memberDetails.isNotEmpty ? team.memberDetails.length : team.members.length,
                    separatorBuilder: (c, i) => const Divider(color: Color(0xFF2A3447), height: 1),
                    itemBuilder: (context, index) {
                      String memberId = '';
                      String memberName = 'Member';
                      String memberAvatar = '';
                      String role = 'Member';

                      if (team.memberDetails.isNotEmpty && index < team.memberDetails.length) {
                        final d = team.memberDetails[index];
                        memberId = (d['id'] ?? '').toString();
                        memberName = (d['name'] ?? 'Member').toString();
                        memberAvatar = (d['avatar'] ?? '').toString();
                        role = (d['role'] ?? 'Member').toString();
                      } else {
                        memberId = team.members[index];
                        memberName = memberId == team.leaderId ? team.leaderName : 'Member';
                        role = memberId == team.leaderId ? 'Leader' : 'Member';
                      }

                      final isThisLeader = memberId == team.leaderId;

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF26334D),
                          backgroundImage: memberAvatar.isNotEmpty ? NetworkImage(memberAvatar) : null,
                          child: memberAvatar.isEmpty
                              ? Text(memberName.isNotEmpty ? memberName[0].toUpperCase() : 'M',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        title: Text(
                          memberName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isThisLeader ? const Color(0xFFFF6B00).withOpacity(0.2) : Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isThisLeader ? '👑 LEADER' : role.toUpperCase(),
                            style: TextStyle(
                              color: isThisLeader ? const Color(0xFFFF6B00) : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5),
      ),
    );
  }

  Widget _buildRecordStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 24, width: 1, color: const Color(0xFF2A3447));
  }
}
