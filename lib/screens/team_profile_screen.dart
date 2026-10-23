// ===============================================================================
// TEAM PROFILE SCREEN — Day/Night Theme Adaptive & Tournaments History Connected
// File: lib/screens/team_profile_screen.dart
// ===============================================================================

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/team_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/team_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../widgets/send_team_match_challenge_dialog.dart';
import '../widgets/end_match_dialog.dart';
import 'gamer_profile_screen.dart';
import 'teams_screen.dart';
import 'private_match_room_screen.dart';

class TeamProfileScreen extends StatefulWidget {
  final String teamId;

  const TeamProfileScreen({super.key, required this.teamId});

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  final TeamService _teamService = TeamService();
  bool _isActionLoading = false;
  bool _hasRequestedLocally = false;
  final Set<String> _cancelledChallengeIds = {};
  final Set<String> _acceptingChallengeIds = {};
  final Set<String> _acceptedChallengeIds = {};
  final Set<String> _completedMatchIds = {};
  final Set<String> _autoCompletingMatchIds = {};
  final List<Map<String, dynamic>> _optimisticActiveMatches = [];
  final Map<String, Map<String, String>> _profileCache = {};

  Future<Map<String, String>> _fetchUserProfile(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) {
      return {'username': 'Player', 'gamerId': 'ID not set', 'avatar': ''};
    }
    if (_profileCache.containsKey(cleanUid)) {
      return _profileCache[cleanUid]!;
    }

    String username = 'Player';
    String gamerId = 'ID not set';
    String avatar = '';

    try {
      final userRow = await SupabaseService.client
          .from('users')
          .select('display_name, username, game_id, gamer_id, photo_url, avatar_url')
          .or('id.eq.$cleanUid,uid.eq.$cleanUid')
          .maybeSingle();

      if (userRow != null) {
        final dName = userRow['display_name']?.toString() ?? '';
        final uName = userRow['username']?.toString() ?? '';
        if (dName.isNotEmpty && dName != 'gamer_id_display') {
          username = dName;
        } else if (uName.isNotEmpty) {
          username = '@$uName';
        }

        final gId = (userRow['game_id'] ?? userRow['gamer_id'])?.toString() ?? '';
        if (gId.isNotEmpty && gId != 'gamer_id_display') gamerId = gId;

        final pic = (userRow['avatar_url'] ?? userRow['photo_url'])?.toString() ?? '';
        if (pic.isNotEmpty) avatar = pic;
      }
    } catch (_) {}

    if (username == 'Player' || gamerId == 'ID not set') {
      try {
        final sbProfile = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('id', cleanUid)
            .maybeSingle();

        if (sbProfile != null) {
          final u = sbProfile['display_name']?.toString() ?? sbProfile['username']?.toString();
          if (u != null && u.isNotEmpty && u != 'gamer_id_display') {
            username = u;
          }
          final g = sbProfile['gamer_id']?.toString() ?? sbProfile['game_id']?.toString();
          if (g != null && g.isNotEmpty && g != 'gamer_id_display') {
            gamerId = g;
          }
          final a = sbProfile['avatar_url']?.toString();
          if (a != null && a.isNotEmpty) {
            avatar = a;
          }
        }
      } catch (_) {}
    }

    final result = {
      'username': username,
      'gamerId': gamerId,
      'avatar': avatar,
    };
    _profileCache[cleanUid] = result;
    return result;
  }

  Future<void> _handleAcceptChallenge({
    required String challengeId,
    required String fromTeamId,
    required String toTeamId,
    required String fromTeamName,
    Map<String, dynamic>? challengeData,
  }) async {
    final cId = challengeId.trim();
    if (_acceptingChallengeIds.contains(cId)) return;

    setState(() => _acceptingChallengeIds.add(cId));

    try {
      final targetChallengeId = challengeData?['id']?.toString() ?? cId;
      bool rpcSuccess = false;
      try {
        await SupabaseService.client.rpc(
          'accept_challenge_safe',
          params: {'p_challenge_id': targetChallengeId},
        );
        rpcSuccess = true;
      } catch (_) {}

      if (!rpcSuccess) {
        await SupabaseService.client
            .from('challenges')
            .update({'status': 'accepted'})
            .eq('id', targetChallengeId);

        final t1 = (challengeData?['from_team_id'] ?? fromTeamId).toString();
        final t2 = (challengeData?['to_team_id'] ?? toTeamId).toString();
        final t1Uuid = SupabaseService.toUuid(t1);
        final t2Uuid = SupabaseService.toUuid(t2);

        final existingMatches = await SupabaseService.client
            .from('active_matches')
            .select()
            .or('and(team1_id.eq.$t1Uuid,team2_id.eq.$t2Uuid),and(team1_id.eq.$t2Uuid,team2_id.eq.$t1Uuid)')
            .inFilter('status', ['active', 'under_review']);

        if (existingMatches.isEmpty) {
          final nowIso = DateTime.now().toUtc().toIso8601String();
          final matchPayload = <String, dynamic>{
            'team1_id': t1Uuid,
            'team2_id': t2Uuid,
            'participants': [t1Uuid, t2Uuid],
            'status': 'active',
            'start_time': nowIso,
            'created_at': nowIso,
          };
          try {
            await SupabaseService.client.from('active_matches').insert(matchPayload).select().maybeSingle();
          } catch (_) {
            await SupabaseService.client.from('active_matches').insert({
              'team1_id': t1Uuid,
              'team2_id': t2Uuid,
              'status': 'active',
              'start_time': nowIso,
              'created_at': nowIso,
            }).select().maybeSingle();
          }
        }
      }

      if (mounted) {
        setState(() => _acceptedChallengeIds.add(cId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match started live!'),
            backgroundColor: Color(0xFF00FF88),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    } finally {
      if (mounted) setState(() => _acceptingChallengeIds.remove(cId));
    }
  }

  Future<void> _handleRejectChallenge(String challengeId) async {
    final cId = challengeId.trim();
    setState(() => _acceptedChallengeIds.add(cId));
    try {
      await SupabaseService.client.from('challenges').update({'status': 'rejected'}).eq('id', cId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match challenge was rejected')),
        );
      }
    } catch (_) {}
  }

  Future<void> _cancelChallenge(String challengeId) async {
    setState(() => _cancelledChallengeIds.add(challengeId));
    try {
      await SupabaseService.client.from('challenges').delete().eq('id', challengeId);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge cancelled'), backgroundColor: Color(0xFF1877F2)),
        );
      }
    } catch (_) {}
  }

  Future<void> _handleJoinRequest(TeamModel team, String currentUid) async {
    final effectiveUid = currentUid.trim().isNotEmpty
        ? currentUid.trim()
        : (GamerAuthService().currentUid ?? (SupabaseService.client.auth.currentUser?.id ?? ''));

    if (effectiveUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first'), backgroundColor: Color(0xFFFF4655)),
        );
      }
      return;
    }

    final currentGamer = GamerAuthService().currentGamer;
    final userName = currentGamer?.displayName ?? currentGamer?.username ?? 'Gamer';

    setState(() => _isActionLoading = true);
    final success = await _teamService.requestToJoinTeam(
      teamId: team.id,
      userId: effectiveUid,
      userName: userName,
      teamName: team.name,
    );
    setState(() {
      _isActionLoading = false;
      if (success) _hasRequestedLocally = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Join request sent successfully!' : 'Failed to send join request'),
          backgroundColor: success ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
        ),
      );
    }
  }

  Future<void> _handleChallenge(TeamModel opponentTeam, String currentUid) async {
    final myTeams = await _teamService.getUserTeams(currentUid);
    final myLeaderTeams = myTeams.where((t) => t.isLeader(currentUid)).toList();

    if (!mounted) return;

    if (myLeaderTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only team leaders can challenge other teams!'),
          backgroundColor: Color(0xFFFF6B00),
        ),
      );
      return;
    }

    final myTeam = myLeaderTeams.first;
    final effectiveMyTeamId = SupabaseService.toUuid(myTeam.id);
    final effectiveTargetId = SupabaseService.toUuid(opponentTeam.id);

    try {
      final existingCheck = await SupabaseService.client
          .from('challenges')
          .select()
          .eq('from_team_id', effectiveMyTeamId)
          .eq('to_team_id', effectiveTargetId)
          .eq('status', 'pending');

      if (existingCheck.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already challenged this team!'),
              backgroundColor: Color(0xFFFF4655),
            ),
          );
        }
        return;
      }

      await SupabaseService.client.from('challenges').insert({
        'from_team_id': effectiveMyTeamId,
        'to_team_id': effectiveTargetId,
        'from_team_name': myTeam.name,
        'to_team_name': opponentTeam.name,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge sent to ${opponentTeam.name}!'),
            backgroundColor: const Color(0xFF1877F2),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _handleDeleteTeam(TeamModel team, String currentUserId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ThemeService.border),
        ),
        title: Text('Delete Team?', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${team.name}? This action cannot be undone.',
            style: TextStyle(color: ThemeService.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await _teamService.deleteTeam(teamId: team.id, currentUserId: currentUserId);
    if (res == 'ok') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team deleted successfully'), backgroundColor: Color(0xFF2E7D32)),
        );
        Navigator.pop(context);
      }
    } else if (res == 'active_match') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete team with an active match in progress!'), backgroundColor: Color(0xFFFF4655)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete team'), backgroundColor: Color(0xFFFF4655)),
        );
      }
    }
  }

  Future<void> _showEditTeamDialog(TeamModel team) async {
    final nameCtrl = TextEditingController(text: team.name);
    final tagCtrl = TextEditingController(text: team.tag);
    final descCtrl = TextEditingController(text: team.description);
    final reqCtrl = TextEditingController(text: team.requirements);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: ThemeService.border)),
        title: Text('Edit Team Info', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, style: TextStyle(color: ThemeService.textPrimary), decoration: InputDecoration(labelText: 'Team Name', labelStyle: TextStyle(color: ThemeService.textSecondary))),
              const SizedBox(height: 8),
              TextField(controller: tagCtrl, style: TextStyle(color: ThemeService.textPrimary), decoration: InputDecoration(labelText: 'Team Tag', labelStyle: TextStyle(color: ThemeService.textSecondary))),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, style: TextStyle(color: ThemeService.textPrimary), maxLines: 2, decoration: InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: ThemeService.textSecondary))),
              const SizedBox(height: 8),
              TextField(controller: reqCtrl, style: TextStyle(color: ThemeService.textPrimary), maxLines: 2, decoration: InputDecoration(labelText: 'Requirements', labelStyle: TextStyle(color: ThemeService.textSecondary))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
            onPressed: () async {
              final ok = await _teamService.updateTeam(
                teamId: team.id,
                name: nameCtrl.text,
                tag: tagCtrl.text,
                game: team.game,
                description: descCtrl.text,
                requirements: reqCtrl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Team updated successfully!'), backgroundColor: Color(0xFF2E7D32)),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = GamerAuthService().currentUid ?? (SupabaseService.client.auth.currentUser?.id ?? '');

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return StreamBuilder<TeamModel?>(
          stream: _teamService.getTeamStream(widget.teamId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: ThemeService.bg,
                body: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
              );
            }

            final team = snapshot.data;
            if (team == null) {
              return Scaffold(
                backgroundColor: ThemeService.bg,
                body: Center(child: Text('Team not found', style: TextStyle(color: ThemeService.textPrimary))),
              );
            }

            final isLeader = team.isLeader(currentUid);
            final isMember = team.isMember(currentUid);
            final hasRequested = team.hasRequestedJoin(currentUid);

            return StreamBuilder<List<TeamModel>>(
              stream: currentUid.isNotEmpty ? _teamService.getUserTeamsStream(currentUid) : Stream.value([]),
              builder: (context, userTeamsSnap) {
                final userTeams = userTeamsSnap.data ?? [];
                final myLeaderTeams = userTeams.where((t) => t.isLeader(currentUid)).toList();
                final myTeamId = myLeaderTeams.isNotEmpty ? myLeaderTeams.first.id : (userTeams.isNotEmpty ? userTeams.first.id : '');

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client.from('active_matches').stream(primaryKey: ['id']),
                  builder: (context, activeSnap) {
                    final streamMatches = activeSnap.data ?? [];
                    final activeMatches = [..._optimisticActiveMatches, ...streamMatches].where((m) {
                      final st = (m['status'] ?? '').toString().toLowerCase();
                      return (st == 'active' || st == 'under_review' || st == 'rejected') && !_completedMatchIds.contains(m['id']?.toString());
                    }).toList();

                    final targetUuid = SupabaseService.toUuid(widget.teamId).toLowerCase();
                    final targetRawId = widget.teamId.toLowerCase();

                    final activeMatch = activeMatches.firstWhere(
                      (m) {
                        final participants = m['participants'];
                        final List<String> pList = [];
                        if (participants is List) {
                          pList.addAll(participants.map((p) => p.toString().toLowerCase()));
                        }
                        pList.add(m['team1_id']?.toString().toLowerCase() ?? '');
                        pList.add(m['team2_id']?.toString().toLowerCase() ?? '');
                        return pList.contains(targetUuid) || pList.contains(targetRawId);
                      },
                      orElse: () => {},
                    );
                    final bool hasActiveMatch = activeMatch.isNotEmpty;
                    final t1 = activeMatch['team1_id']?.toString() ?? '';
                    final t2 = activeMatch['team2_id']?.toString() ?? '';

                    final bool isUserInThisTeam = isLeader ||
                        isMember ||
                        userTeams.any((t) {
                          final tUuid = SupabaseService.toUuid(t.id).toLowerCase();
                          final tRaw = t.id.toLowerCase();
                          return tUuid == targetUuid || tRaw == targetRawId;
                        });
                    final bool isMyOwnTeam = isUserInThisTeam;
                    final bool isViewedMyTeam = isUserInThisTeam;

                    TeamModel? userMatchTeam;
                    for (final ut in userTeams) {
                      final uRaw = ut.id.toLowerCase();
                      final uUuid = SupabaseService.toUuid(ut.id).toLowerCase();
                      if (t1.toLowerCase() == uRaw || t1.toLowerCase() == uUuid || t2.toLowerCase() == uRaw || t2.toLowerCase() == uUuid) {
                        userMatchTeam = ut;
                        break;
                      }
                    }

                    final bool isCurrentUserInMatch = hasActiveMatch && userMatchTeam != null;
                    final bool isMatchOpponent = hasActiveMatch && !isUserInThisTeam && isCurrentUserInMatch;
                    final bool canAccessMatch = hasActiveMatch && (isUserInThisTeam || isMatchOpponent);

                    final int privacyLevel = isUserInThisTeam ? 1 : (isMatchOpponent ? 3 : 2);
                    final String userMatchTeamId = userMatchTeam?.id ?? myTeamId;
                    final String userMatchTeamUuid = userMatchTeamId.isNotEmpty ? SupabaseService.toUuid(userMatchTeamId).toLowerCase() : '';
                    final bool isUserT1 = userMatchTeamUuid.isNotEmpty && (t1.toLowerCase() == userMatchTeamUuid || t1.toLowerCase() == userMatchTeamId.toLowerCase());
                    final String myTeamIdInMatch = isUserT1 ? t1 : t2;
                    final String opponentTeamId = isUserT1 ? t2 : t1;

                    return Scaffold(
                      backgroundColor: ThemeService.bg,
                      appBar: AppBar(
                        backgroundColor: ThemeService.appBarBg,
                        elevation: 0,
                        leading: IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: ThemeService.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: Text(
                          '${team.name} [${team.tag}]',
                          style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        actions: [
                          if (privacyLevel == 1) ...[
                            if (isLeader)
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, color: ThemeService.textSecondary),
                                color: ThemeService.card,
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showEditTeamDialog(team);
                                  } else if (val == 'delete') {
                                    _handleDeleteTeam(team, currentUid);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_rounded, color: ThemeService.textSecondary, size: 18),
                                        const SizedBox(width: 8),
                                        Text('Edit Team', style: TextStyle(color: ThemeService.textPrimary)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete_forever_rounded, color: Color(0xFFFF4655), size: 18),
                                        SizedBox(width: 8),
                                        Text('Delete Team', style: TextStyle(color: Color(0xFFFF4655))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ],
                      ),
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: ThemeService.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: ThemeService.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: ThemeService.cardSecondary,
                                      border: Border.all(color: const Color(0xFFFF6B00), width: 2),
                                      image: team.logo.isNotEmpty ? DecorationImage(image: NetworkImage(team.logo), fit: BoxFit.cover) : null,
                                    ),
                                    child: team.logo.isEmpty ? Icon(Icons.shield_rounded, color: ThemeService.textSecondary, size: 36) : null,
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
                                                style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
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
                                        const SizedBox(height: 6),
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
                                          'Leader: ${team.leaderName}',
                                          style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: ThemeService.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: ThemeService.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildRecordStat('Wins', '${team.wins}', const Color(0xFF00FF88)),
                                  _buildDivider(),
                                  _buildRecordStat('Losses', '${team.losses}', const Color(0xFFFF4655)),
                                  _buildDivider(),
                                  _buildRecordStat('Draws', '${team.draws}', const Color(0xFFFFB020)),
                                  _buildDivider(),
                                  _buildRecordStat('Points', '${team.points}', const Color(0xFFFF6B00)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildSectionHeader('Description'),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ThemeService.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: ThemeService.border),
                              ),
                              child: Text(
                                team.description.isNotEmpty ? team.description : 'No description provided',
                                style: TextStyle(color: ThemeService.textPrimary, fontSize: 13, height: 1.4),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildSectionHeader('Requirements'),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ThemeService.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: ThemeService.border),
                              ),
                              child: Text(
                                team.requirements.isNotEmpty ? team.requirements : 'No special requirements',
                                style: TextStyle(color: ThemeService.textPrimary, fontSize: 13, height: 1.4),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // PENDING REQUESTS BLOCK (Fixed localization label)
                            if (isLeader && team.pendingJoinRequests.isNotEmpty) ...[
                              _buildSectionHeader('Pending Requests (${team.pendingJoinRequests.length})'),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: ThemeService.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
                                ),
                                child: Column(
                                  children: team.pendingJoinRequests.map((uid) {
                                    return FutureBuilder<Map<String, String>>(
                                      future: _fetchUserProfile(uid),
                                      builder: (context, snap) {
                                        final userData = snap.data;
                                        final isLoading = snap.connectionState == ConnectionState.waiting;
                                        final displayUsername = userData?['username'] ?? 'Player';
                                        final gamerId = userData?['gamerId'] ?? 'ID not set';

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: ThemeService.cardSecondary,
                                                child: Icon(Icons.person, color: ThemeService.textSecondary, size: 18),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      isLoading ? 'Loading...' : displayUsername,
                                                      style: TextStyle(
                                                        color: ThemeService.textPrimary,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      gamerId != 'ID not set' ? 'Game ID: $gamerId' : 'UID: ${uid.length > 8 ? uid.substring(0, 8) : uid}',
                                                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                                                    ),
                                                  ],
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
                                                  userName: displayUsername,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // TEAM MEMBERS (Squad limit indicator: 1 / 4)
                            _buildSectionHeader('Team Members (${team.memberCount} / 4)'),
                            Container(
                              decoration: BoxDecoration(
                                color: ThemeService.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: ThemeService.border),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: team.memberDetails.isNotEmpty ? team.memberDetails.length : team.members.length,
                                separatorBuilder: (c, i) => Divider(color: ThemeService.border, height: 1),
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
                                      backgroundColor: ThemeService.cardSecondary,
                                      backgroundImage: memberAvatar.isNotEmpty ? NetworkImage(memberAvatar) : null,
                                      child: memberAvatar.isEmpty
                                          ? Text(
                                              memberName.isNotEmpty ? memberName[0].toUpperCase() : 'M',
                                              style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      memberName,
                                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isThisLeader ? const Color(0xFFFF6B00).withOpacity(0.2) : ThemeService.cardSecondary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isThisLeader ? 'LEADER' : role.toUpperCase(),
                                        style: TextStyle(
                                          color: isThisLeader ? const Color(0xFFFF6B00) : ThemeService.textSecondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // MATCH & TOURNAMENT HISTORY SECTION
                            _buildCombinedHistorySection(team),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                      bottomNavigationBar: Container(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 10,
                          bottom: MediaQuery.of(context).padding.bottom + 10,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeService.card,
                          border: Border(top: BorderSide(color: ThemeService.border, width: 1)),
                        ),
                        child: isViewedMyTeam
                            ? Container(
                                width: double.infinity,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1877F2).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF1877F2), width: 1.2),
                                ),
                                child: const Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shield_rounded, color: Color(0xFF1877F2), size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Your Team',
                                        style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  if (!team.isMember(currentUid)) ...[
                                    Expanded(
                                      child: SizedBox(
                                        height: 46,
                                        child: OutlinedButton.icon(
                                          onPressed: (hasRequested || _hasRequestedLocally || _isActionLoading)
                                              ? null
                                              : () => _handleJoinRequest(team, currentUid),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: ThemeService.textPrimary,
                                            side: BorderSide(color: ThemeService.border),
                                            backgroundColor: ThemeService.cardSecondary,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: Icon(
                                            (hasRequested || _hasRequestedLocally) ? Icons.hourglass_top_rounded : Icons.person_add_rounded,
                                            size: 16,
                                            color: (hasRequested || _hasRequestedLocally) ? const Color(0xFFFFB800) : const Color(0xFF00FF88),
                                          ),
                                          label: Text(
                                            (hasRequested || _hasRequestedLocally) ? 'Requested' : 'Join Team',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ThemeService.textPrimary),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: SizedBox(
                                      height: 46,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _handleChallenge(team, currentUid),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1877F2),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.flash_on_rounded, size: 18),
                                        label: const Text('Challenge', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.w900, fontSize: 13.5),
      ),
    );
  }

  Widget _buildRecordStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: ThemeService.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 24, width: 1, color: ThemeService.border);
  }

  // Combines Tournament Wins & Match Battles
  Widget _buildCombinedHistorySection(TeamModel team) {
    final tId = widget.teamId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Match & Tournament History'),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: SupabaseService.client
              .from('tournaments')
              .select('id, title, winner_team_id, prize_pool, match_time, status')
              .eq('status', 'completed')
              .eq('winner_team_id', tId)
              .order('match_time', ascending: false),
          builder: (context, tourSnap) {
            final wonTournaments = tourSnap.data ?? [];

            if (wonTournaments.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: ThemeService.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history_rounded, color: ThemeService.textSecondary.withOpacity(0.4), size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'No Matches Played Yet',
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Completed team battles and tournament matches will appear here',
                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: wonTournaments.map((t) {
                final title = t['title'] ?? 'Tournament Match';
                final prize = t['prize_pool'] ?? 0;
                String dateStr = 'Recent';
                if (t['match_time'] != null) {
                  try {
                    dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(t['match_time'].toString()).toLocal());
                  } catch (_) {}
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThemeService.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Won $prize Coins • $dateStr',
                              style: const TextStyle(color: Color(0xFF00FF88), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00FF88)),
                        ),
                        child: const Text(
                          'WON #1',
                          style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
