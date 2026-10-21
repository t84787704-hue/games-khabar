import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/team_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/team_service.dart';
import '../services/supabase_service.dart';
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
      final sbProfile = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', cleanUid)
          .maybeSingle();

      if (sbProfile != null) {
        final u = sbProfile['username']?.toString() ??
            sbProfile['display_name']?.toString();
        if (u != null && u.isNotEmpty) {
          username = u;
        }
        final g = sbProfile['gamer_id']?.toString() ??
            sbProfile['game_id']?.toString();
        if (g != null && g.isNotEmpty) {
          gamerId = g;
        }
        final a = sbProfile['avatar_url']?.toString();
        if (a != null && a.isNotEmpty) {
          avatar = a;
        }
      }
    } catch (e) {
      debugPrint('[TeamProfileScreen] Supabase profile query error: $e');
    }

    if (gamerId == 'ID not set' || username == 'Player') {
      try {
        final gUser = await GamerAuthService().getUserProfile(cleanUid);
        if (gUser != null) {
          if (username == 'Player') {
            if (gUser.username.isNotEmpty) {
              username = gUser.username;
            } else if (gUser.displayName.isNotEmpty) {
              username = gUser.displayName;
            }
          }
          if (gamerId == 'ID not set' && gUser.gameId.isNotEmpty) {
            gamerId = gUser.gameId;
          }
          if (avatar.isEmpty && gUser.photoUrl.isNotEmpty) {
            avatar = gUser.photoUrl;
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

    setState(() {
      _acceptingChallengeIds.add(cId);
    });

    try {
      final targetChallengeId = challengeData?['id']?.toString() ?? cId;
      bool rpcSuccess = false;
      try {
        await SupabaseService.client.rpc(
          'accept_challenge_safe',
          params: {'p_challenge_id': targetChallengeId},
        );
        rpcSuccess = true;
      } catch (rpcErr) {
        debugPrint(
            '[TeamProfileScreen] accept_challenge_safe RPC notice: $rpcErr');
      }

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
            await SupabaseService.client
                .from('active_matches')
                .insert(matchPayload)
                .select()
                .maybeSingle();
          } catch (insertErr) {
            debugPrint(
                '[TeamProfileScreen] Insert with participants notice: $insertErr');
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
        setState(() {
          _acceptedChallengeIds.add(cId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('match_started_live'.tr()),
            backgroundColor: const Color(0xFF00FF88),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamProfileScreen] Error accepting challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _acceptingChallengeIds.remove(cId);
        });
      }
    }
  }

  Future<void> _handleRejectChallenge(String challengeId) async {
    final cId = challengeId.trim();
    setState(() {
      _acceptedChallengeIds.add(cId);
    });
    try {
      await SupabaseService.client
          .from('challenges')
          .update({'status': 'rejected'}).eq('id', cId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge rejected')),
        );
      }
    } catch (e) {
      debugPrint('[TeamProfileScreen] Error rejecting challenge: $e');
    }
  }

  Future<void> _cancelChallenge(String challengeId) async {
    setState(() {
      _cancelledChallengeIds.add(challengeId);
    });
    try {
      await SupabaseService.client
          .from('challenges')
          .delete()
          .eq('id', challengeId);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('challenge_cancelled'.tr()),
            backgroundColor: const Color(0xFF1877F2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamProfileScreen] Error cancelling challenge: $e');
    }
  }

  Future<void> _handleJoinRequest(TeamModel team, String currentUid) async {
    final effectiveUid = currentUid.trim().isNotEmpty
        ? currentUid.trim()
        : (GamerAuthService().currentUid ??
            (SupabaseService.client.auth.currentUser?.id ?? ''));

    if (effectiveUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login first'),
            backgroundColor: Color(0xFFFF4655),
          ),
        );
      }
      return;
    }

    final currentGamer = GamerAuthService().currentGamer;
    final userName =
        currentGamer?.displayName ?? currentGamer?.username ?? 'Gamer';

    setState(() => _isActionLoading = true);
    final success = await _teamService.requestToJoinTeam(
      teamId: team.id,
      userId: effectiveUid,
      userName: userName,
      teamName: team.name,
    );
    setState(() {
      _isActionLoading = false;
      if (success) {
        _hasRequestedLocally = true;
      }
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Join request sent to team leader!'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to send join request'),
              backgroundColor: Color(0xFFFF4655)),
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
        SnackBar(
          content: Text('leader_required_to_challenge'.tr()),
          backgroundColor: const Color(0xFFFF6B00),
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
            SnackBar(
              content: Text('challenge_already_sent'.tr()),
              backgroundColor: const Color(0xFFFF4655),
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
            content: Text('⚔️ Challenge sent to ${opponentTeam.name}!'),
            backgroundColor: const Color(0xFF1877F2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamProfileScreen] Error sending challenge: $e');
    }
  }

  Future<void> _handleDeleteTeam(TeamModel team, String currentUserId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        title: const Text('Delete Team?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to delete ${team.name}? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4655)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await _teamService.deleteTeam(
        teamId: team.id, currentUserId: currentUserId);
    if (res == 'ok') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Team deleted successfully'),
              backgroundColor: Color(0xFF2E7D32)),
        );
        Navigator.pop(context);
      }
    } else if (res == 'active_match') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cannot delete team during an active match!'),
              backgroundColor: Color(0xFFFF4655)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to delete team'),
              backgroundColor: Color(0xFFFF4655)),
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
        backgroundColor: const Color(0xFF161F2E),
        title: const Text('Edit Team',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Team Name',
                    labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tagCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Tag',
                    labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reqCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Requirements',
                    labelStyle: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2)),
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
                  const SnackBar(
                      content: Text('Team updated successfully'),
                      backgroundColor: Color(0xFF2E7D32)),
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
    final currentUid = GamerAuthService().currentUid ??
        (SupabaseService.client.auth.currentUser?.id ?? '');

    return StreamBuilder<TeamModel?>(
      stream: _teamService.getTeamStream(widget.teamId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0F17),
            body: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
          );
        }

        final team = snapshot.data;
        if (team == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0F17),
            body: Center(
                child: Text('Team not found',
                    style: TextStyle(color: Colors.white))),
          );
        }

        final isLeader = team.isLeader(currentUid);
        final isMember = team.isMember(currentUid);
        final hasRequested = team.hasRequestedJoin(currentUid);

        return StreamBuilder<List<TeamModel>>(
          stream: currentUid.isNotEmpty
              ? _teamService.getUserTeamsStream(currentUid)
              : Stream.value([]),
          builder: (context, userTeamsSnap) {
            final userTeams = userTeamsSnap.data ?? [];
            final myLeaderTeams =
                userTeams.where((t) => t.isLeader(currentUid)).toList();
            final myTeamId = myLeaderTeams.isNotEmpty
                ? myLeaderTeams.first.id
                : (userTeams.isNotEmpty ? userTeams.first.id : '');

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.client
                  .from('active_matches')
                  .stream(primaryKey: ['id']),
              builder: (context, activeSnap) {
                final streamMatches = activeSnap.data ?? [];
                final activeMatches = [
                  ..._optimisticActiveMatches,
                  ...streamMatches,
                ].where((m) {
                  final st = (m['status'] ?? '').toString().toLowerCase();
                  return (st == 'active' ||
                          st == 'under_review' ||
                          st == 'rejected') &&
                      !_completedMatchIds.contains(m['id']?.toString());
                }).toList();

                final targetUuid =
                    SupabaseService.toUuid(widget.teamId).toLowerCase();
                final targetRawId = widget.teamId.toLowerCase();

                final activeMatch = activeMatches.firstWhere(
                  (m) {
                    final participants = m['participants'];
                    final List<String> pList = [];
                    if (participants is List) {
                      pList.addAll(
                          participants.map((p) => p.toString().toLowerCase()));
                    }
                    pList.add(m['team1_id']?.toString().toLowerCase() ?? '');
                    pList.add(m['team2_id']?.toString().toLowerCase() ?? '');
                    return pList.contains(targetUuid) ||
                        pList.contains(targetRawId);
                  },
                  orElse: () => {},
                );
                final bool hasActiveMatch = activeMatch.isNotEmpty;

                final t1 = activeMatch['team1_id']?.toString() ?? '';
                final t2 = activeMatch['team2_id']?.toString() ?? '';

                final bool isUserInThisTeam = isLeader ||
                    isMember ||
                    userTeams.any((t) {
                      final tUuid =
                          SupabaseService.toUuid(t.id).toLowerCase();
                      final tRaw = t.id.toLowerCase();
                      return tUuid == targetUuid || tRaw == targetRawId;
                    });
                final bool isMyOwnTeam = isUserInThisTeam;
                final bool isViewedMyTeam = isUserInThisTeam;

                TeamModel? userMatchTeam;
                for (final ut in userTeams) {
                  final uRaw = ut.id.toLowerCase();
                  final uUuid = SupabaseService.toUuid(ut.id).toLowerCase();
                  if (t1.toLowerCase() == uRaw || t1.toLowerCase() == uUuid ||
                      t2.toLowerCase() == uRaw || t2.toLowerCase() == uUuid) {
                    userMatchTeam = ut;
                    break;
                  }
                }

                final bool isCurrentUserInMatch = hasActiveMatch && userMatchTeam != null;
                final bool isMatchOpponent = hasActiveMatch && !isUserInThisTeam && isCurrentUserInMatch;
                final bool canAccessMatch = hasActiveMatch && (isUserInThisTeam || isMatchOpponent);

                final int privacyLevel =
                    isUserInThisTeam ? 1 : (isMatchOpponent ? 3 : 2);

                final String userMatchTeamId = userMatchTeam?.id ?? myTeamId;
                final String userMatchTeamUuid = userMatchTeamId.isNotEmpty
                    ? SupabaseService.toUuid(userMatchTeamId).toLowerCase()
                    : '';

                final bool isUserT1 = userMatchTeamUuid.isNotEmpty &&
                    (t1.toLowerCase() == userMatchTeamUuid ||
                        t1.toLowerCase() == userMatchTeamId.toLowerCase());

                final String myTeamIdInMatch = isUserT1 ? t1 : t2;
                final String opponentTeamId = isUserT1 ? t2 : t1;

                final bool isMatchLeader = canAccessMatch &&
                    (isLeader ||
                        (userMatchTeam != null && userMatchTeam.isLeader(currentUid)));

                return Scaffold(
                  backgroundColor: const Color(0xFF0B0F17),
                  appBar: AppBar(
                    backgroundColor: const Color(0xFF131A29),
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      '${team.name} [${team.tag}]',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16),
                    ),
                    actions: [
                      if (privacyLevel == 1) ...[
                        if (canAccessMatch) ...[
                          IconButton(
                            tooltip: 'Team DM 💬',
                            icon: const Icon(Icons.chat_bubble_rounded,
                                color: Color(0xFF00FF88), size: 22),
                            onPressed: () {
                              final activeMatchId =
                                  activeMatch['id']?.toString() ?? '';
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PrivateMatchRoomScreen(
                                    matchId: activeMatchId,
                                    myTeamId: myTeamIdInMatch,
                                    myTeamName: team.name,
                                    opponentId: opponentTeamId,
                                    opponentName:
                                        activeMatch['opponent_name'] ??
                                            'Opponent',
                                  ),
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FF88)
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF00FF88)),
                                ),
                                child: const Text('MATCH LIVE',
                                    style: TextStyle(
                                        color: Color(0xFF00FF88),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11)),
                              ),
                            ),
                          ),
                        ],
                        if (isLeader)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded,
                                color: Colors.white70),
                            color: const Color(0xFF161F2E),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _showEditTeamDialog(team);
                              } else if (val == 'delete') {
                                _handleDeleteTeam(team, currentUid);
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        color: Colors.white70, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit Team',
                                        style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_forever_rounded,
                                        color: Color(0xFFFF4655), size: 18),
                                    SizedBox(width: 8),
                                    Text('Delete Team',
                                        style:
                                            TextStyle(color: Color(0xFFFF4655))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ] else if (privacyLevel == 3) ...[
                        if (canAccessMatch) ...[
                          IconButton(
                            tooltip: 'Team DM 💬',
                            icon: const Icon(Icons.chat_bubble_rounded,
                                color: Color(0xFF00FF88), size: 22),
                            onPressed: () {
                              final activeMatchId =
                                  activeMatch['id']?.toString() ?? '';
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PrivateMatchRoomScreen(
                                    matchId: activeMatchId,
                                    myTeamId: myTeamIdInMatch,
                                    myTeamName: userMatchTeam?.name ?? 'My Team',
                                    opponentId: opponentTeamId,
                                    opponentName: team.name,
                                  ),
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FF88)
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF00FF88)),
                                ),
                                child: const Text('MATCH LIVE',
                                    style: TextStyle(
                                        color: Color(0xFF00FF88),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11)),
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        if (myLeaderTeams.isNotEmpty)
                          IconButton(
                            tooltip: 'Challenge Team',
                            icon: const Icon(Icons.flash_on_rounded,
                                color: Color(0xFF1877F2)),
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
                        if (canAccessMatch)
                          Builder(
                            builder: (context) {
                              final activeMatchId =
                                  activeMatch['id']?.toString() ?? '';
                              final matchStatus = (activeMatch['status'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final proofStatus =
                                  (activeMatch['proof_status'] ?? '')
                                      .toString()
                                      .toLowerCase();
                              final adminNote = activeMatch['admin_note']
                                      ?.toString() ??
                                  'Invalid proof screenshot';

                              final submittedBy = (activeMatch[
                                          'submitted_by_team_id'] ??
                                      activeMatch['winner_team_id'] ??
                                      activeMatch['submitted_by'] ??
                                      '')
                                  .toString()
                                  .trim()
                                  .toLowerCase();
                              final myIdLower = myTeamIdInMatch.toLowerCase();
                              final myUuidLower = SupabaseService.toUuid(
                                      myTeamIdInMatch)
                                  .toLowerCase();
                              final isSubmitter = isMyOwnTeam &&
                                  submittedBy.isNotEmpty &&
                                  (submittedBy == targetUuid ||
                                      submittedBy == targetRawId ||
                                      submittedBy == myIdLower ||
                                      submittedBy == myUuidLower);

                              if (matchStatus == 'under_review' &&
                                  proofStatus == 'accepted') {
                                if (!isSubmitter)
                                  return const SizedBox.shrink();

                                if (!_autoCompletingMatchIds
                                    .contains(activeMatchId)) {
                                  _autoCompletingMatchIds.add(activeMatchId);
                                  Future.delayed(
                                      const Duration(seconds: 3), () async {
                                    try {
                                      await SupabaseService.client
                                          .from('active_matches')
                                          .update({'status': 'completed'}).eq(
                                              'id', activeMatchId);
                                    } catch (_) {}
                                    if (mounted) {
                                      setState(() {
                                        _completedMatchIds
                                            .add(activeMatchId);
                                      });
                                    }
                                  });
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B5E20)
                                        .withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xFF00FF88),
                                        width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00FF88)
                                            .withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.emoji_events_rounded,
                                          color: Color(0xFF00FF88), size: 24),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '✅ Proof Accepted - You Are Win! 🏆',
                                          style: TextStyle(
                                            color: Color(0xFF00FF88),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final proofCount =
                                  (activeMatch['proof_upload_count'] as num?)
                                          ?.toInt() ??
                                      0;
                              final canAddMore = proofCount < 3;

                              if (matchStatus == 'rejected' ||
                                  (matchStatus == 'under_review' &&
                                      proofStatus == 'rejected')) {
                                if (!isSubmitter)
                                  return const SizedBox.shrink();

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B151A)
                                        .withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xFFFF4655),
                                        width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF4655)
                                            .withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.cancel_rounded,
                                              color: Color(0xFFFF4655),
                                              size: 22),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '❌ Proof Rejected - $adminNote - Dubara Proof Add Karo (Attempts: $proofCount/3)',
                                              style: const TextStyle(
                                                color: Color(0xFFFF4655),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: canAddMore
                                                ? const Color(0xFFFF4655)
                                                : Colors.grey.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          icon: Icon(
                                              canAddMore
                                                  ? Icons.upload_file_rounded
                                                  : Icons.block_rounded,
                                              size: 16),
                                          label: Text(
                                              canAddMore
                                                  ? 'Add Proof Again ($proofCount/3)'
                                                  : '❌ Proof Limit Reached (3/3)',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
                                          onPressed: !canAddMore
                                              ? null
                                              : () async {
                                                  final ended =
                                                      await EndMatchBottomSheet.show(
                                                    context,
                                                    activeMatchId: activeMatchId,
                                                    myTeamId: myTeamIdInMatch,
                                                    opponentId: opponentTeamId,
                                                    myTeamName: isMyOwnTeam
                                                        ? team.name
                                                        : (userMatchTeam?.name ?? 'My Team'),
                                                    opponentName: isMyOwnTeam
                                                        ? (activeMatch[
                                                                'opponent_name'] ??
                                                            'Opponent')
                                                        : team.name,
                                                  );
                                                  if (ended == true && mounted) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            'proof_submitted_under_review'.tr()),
                                                        backgroundColor:
                                                            const Color(0xFFFFB800),
                                                      ),
                                                    );
                                                  }
                                                },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (matchStatus == 'under_review') {
                                if (!isSubmitter)
                                  return const SizedBox.shrink();

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF332A00)
                                        .withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xFFFFB800),
                                        width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFB800)
                                            .withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                          Icons.hourglass_top_rounded,
                                          color: Color(0xFFFFB800),
                                          size: 22),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '⏳ Your Proof Under Review',
                                              style: TextStyle(
                                                color: Color(0xFFFFB800),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Admin is reviewing your submitted match proof.',
                                              style: TextStyle(
                                                  color: Color(0xFF8B949E),
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFFFB800),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text('REVIEW',
                                            style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B5E20)
                                      .withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFF00FF88),
                                      width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00FF88)
                                          .withOpacity(0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                            Icons
                                                .local_fire_department_rounded,
                                            color: Color(0xFF00FF88),
                                            size: 22),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FutureBuilder<TeamModel?>(
                                            future: _teamService
                                                .getTeam(opponentTeamId),
                                            builder: (context, opSnap) {
                                              final opName = opSnap.data?.name ??
                                                  activeMatch['opponent_name']
                                                      ?.toString() ??
                                                  (!isMyOwnTeam
                                                      ? team.name
                                                      : 'Opponent Team');
                                              return Text(
                                                '🔥 Active Match vs $opName - Match is Live',
                                                style: const TextStyle(
                                                  color: Color(0xFF00FF88),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00FF88),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Text('LIVE',
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 10)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF1877F2),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(
                                              Icons.chat_bubble_rounded,
                                              size: 15),
                                          label: const Text('Team DM 💬',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PrivateMatchRoomScreen(
                                                  matchId: activeMatchId,
                                                  myTeamId: myTeamIdInMatch,
                                                  myTeamName: isMyOwnTeam
                                                      ? team.name
                                                      : (userMatchTeam?.name ?? 'My Team'),
                                                  opponentId: opponentTeamId,
                                                  opponentName: isMyOwnTeam
                                                      ? (activeMatch[
                                                              'opponent_name'] ??
                                                          'Opponent')
                                                      : team.name,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        if (isMatchLeader) ...[
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFFF4655),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(
                                                Icons.stop_circle_rounded,
                                                size: 16),
                                            label: const Text('End Match',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12)),
                                            onPressed: () async {
                                              final ended =
                                                  await EndMatchBottomSheet
                                                      .show(
                                                context,
                                                activeMatchId: activeMatchId,
                                                myTeamId: myTeamIdInMatch,
                                                opponentId: opponentTeamId,
                                                myTeamName: isMyOwnTeam
                                                    ? team.name
                                                    : (userMatchTeam?.name ?? 'My Team'),
                                                opponentName: isMyOwnTeam
                                                    ? (activeMatch[
                                                            'opponent_name'] ??
                                                        'Opponent')
                                                    : team.name,
                                              );
                                              if (ended == true) {
                                                if (mounted) {
                                                  setState(() {
                                                    _completedMatchIds
                                                        .add(
                                                            activeMatchId);
                                                    _optimisticActiveMatches
                                                        .clear();
                                                  });
                                                  ScaffoldMessenger.of(
                                                          context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                          'Proof submitted! Under Review.'),
                                                      backgroundColor:
                                                          Color(0xFF00FF88),
                                                      duration:
                                                          Duration(seconds: 4),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        if (isMyOwnTeam) ...[
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: SupabaseService.client
                                .from('challenges')
                                .stream(primaryKey: ['id'])
                                .eq('from_team_id',
                                    SupabaseService.toUuid(widget.teamId)),
                            builder: (context, outSnap) {
                              if (!outSnap.hasData)
                                return const SizedBox.shrink();
                              final outgoingList = outSnap.data!
                                  .where((d) =>
                                      (d['status'] ?? '')
                                          .toString()
                                          .toLowerCase() ==
                                      'pending')
                                  .where((d) => !_cancelledChallengeIds
                                      .contains(d['id']?.toString()))
                                  .toList();
                              if (outgoingList.isEmpty)
                                return const SizedBox.shrink();

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131A29),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFFF6B00)
                                          .withOpacity(0.6),
                                      width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.send_rounded,
                                            color: Color(0xFFFF6B00), size: 18),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'My Outgoing Requests',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Text('${outgoingList.length} Sent',
                                            style: const TextStyle(
                                                color: Color(0xFFFF6B00),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ...outgoingList.map((doc) {
                                      final challengeId = doc['id'];
                                      final toTeamName = doc['to_team_name']
                                              ?.toString() ??
                                          'Opponent Team';

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1B2436),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Challenge sent to $toTeamName',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => _cancelChallenge(
                                                  challengeId.toString()),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFFFF4655),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 4),
                                                minimumSize: const Size(0, 30),
                                              ),
                                              child: const Text('CANCEL',
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            },
                          ),

                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: SupabaseService.client
                                .from('challenges')
                                .stream(primaryKey: ['id'])
                                .eq('to_team_id',
                                    SupabaseService.toUuid(widget.teamId)),
                            builder: (context, incSnap) {
                              if (!incSnap.hasData)
                                return const SizedBox.shrink();
                              final incomingList = incSnap.data!
                                  .where((d) =>
                                      (d['status'] ?? '')
                                          .toString()
                                          .toLowerCase() ==
                                      'pending')
                                  .where((d) => !_acceptedChallengeIds
                                      .contains(d['id']?.toString()))
                                  .toList();
                              if (incomingList.isEmpty)
                                return const SizedBox.shrink();

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131A29),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFF00FF88)
                                          .withOpacity(0.5),
                                      width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.flash_on_rounded,
                                            color: Color(0xFF00FF88), size: 18),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Incoming Challenges',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Text('${incomingList.length} New',
                                            style: const TextStyle(
                                                color: Color(0xFF00FF88),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ...incomingList.map((doc) {
                                      final challengeId = doc['id'];
                                      final fromTeamName =
                                          doc['from_team_name']?.toString() ??
                                              'Opponent Team';
                                      final fromTeamId =
                                          doc['from_team_id']?.toString() ??
                                              '';
                                      final toTeamId =
                                          doc['to_team_id']?.toString() ??
                                              widget.teamId;
                                      final isAccepting =
                                          _acceptingChallengeIds.contains(
                                              challengeId.toString());

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1B2436),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$fromTeamName challenged your team!',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: Colors.white),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: isAccepting
                                                        ? null
                                                        : () =>
                                                            _handleRejectChallenge(
                                                                challengeId
                                                                    .toString()),
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          const Color(
                                                              0xFFFF4655),
                                                      side: const BorderSide(
                                                          color: Color(
                                                              0xFFFF4655)),
                                                    ),
                                                    child: const Text('REJECT'),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: isAccepting
                                                        ? null
                                                        : () =>
                                                            _handleAcceptChallenge(
                                                                challengeId:
                                                                    challengeId
                                                                        .toString(),
                                                                fromTeamId:
                                                                    fromTeamId,
                                                                toTeamId:
                                                                    toTeamId,
                                                                fromTeamName:
                                                                    fromTeamName,
                                                                challengeData: doc,
                                                            ),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFF00FF88),
                                                      foregroundColor:
                                                          Colors.black,
                                                    ),
                                                    child: isAccepting
                                                        ? const Text('Accepting...')
                                                        : const Text('ACCEPT'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

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
                              GestureDetector(
                                onTap: () => _showLogoDialog(
                                    context, team.logo, team.name),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF26334D),
                                    border: Border.all(
                                        color: const Color(0xFFFF6B00),
                                        width: 2),
                                    image: team.logo.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(team.logo),
                                            fit: BoxFit.cover)
                                        : null,
                                  ),
                                  child: team.logo.isEmpty
                                      ? const Center(
                                          child: Icon(Icons.shield_rounded,
                                              color: Colors.white70, size: 36))
                                      : null,
                                ),
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
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 18),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF6B00)
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            team.tag,
                                            style: const TextStyle(
                                                color: Color(0xFFFF6B00),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00FF88)
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Game: ${team.game}',
                                        style: const TextStyle(
                                            color: Color(0xFF00FF88),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '👑 Team Leader: ${team.leaderName}',
                                      style: const TextStyle(
                                          color: Color(0xFF8B949E),
                                          fontSize: 12),
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
                            color: const Color(0xFF161F2E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2A3447)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildRecordStat('WINS', '${team.wins}',
                                  const Color(0xFF00FF88)),
                              _buildDivider(),
                              _buildRecordStat('LOSSES', '${team.losses}',
                                  const Color(0xFFFF4655)),
                              _buildDivider(),
                              _buildRecordStat('DRAWS', '${team.draws}',
                                  const Color(0xFFFFB020)),
                              _buildDivider(),
                              _buildRecordStat('POINTS', '${team.points}',
                                  const Color(0xFFFF6B00)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (team.description.isNotEmpty) ...[
                          _buildSectionHeader('Description'),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161F2E),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              team.description,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (team.requirements.isNotEmpty) ...[
                          _buildSectionHeader('Requirements'),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161F2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFFFB020)
                                      .withOpacity(0.3)),
                            ),
                            child: Text(
                              team.requirements,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (isLeader && team.pendingJoinRequests.isNotEmpty) ...[
                          _buildSectionHeader(
                              'Pending Requests (${team.pendingJoinRequests.length})'),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1F2C),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      const Color(0xFF00FF88).withOpacity(0.4)),
                            ),
                            child: Column(
                              children:
                                  team.pendingJoinRequests.map((uid) {
                                return FutureBuilder<Map<String, String>>(
                                  future: _fetchUserProfile(uid),
                                  builder: (context, snap) {
                                    final userData = snap.data;
                                    final isLoading = snap.connectionState ==
                                        ConnectionState.waiting;
                                    final gamerId = userData?['gamerId'];
                                    final displayGamerId = isLoading
                                        ? 'Loading...'
                                        : 'Gamer ID: ${gamerId != null && gamerId.isNotEmpty ? gamerId : 'ID not set'}';
                                    final displayUsername =
                                        userData?['username'] ?? 'Player';

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 16,
                                            backgroundColor:
                                                Color(0xFF26334D),
                                            child: Icon(Icons.person,
                                                color: Colors.white70,
                                                size: 18),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  displayGamerId,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13),
                                                ),
                                                if (!isLoading &&
                                                    displayUsername !=
                                                        'Player') ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    displayUsername,
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFF8B949E),
                                                        fontSize: 11),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.close_rounded,
                                                color: Color(0xFFFF4655),
                                                size: 20),
                                            onPressed: () =>
                                                _teamService.rejectJoinRequest(
                                                    teamId: team.id,
                                                    userId: uid),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.check_rounded,
                                                color: Color(0xFF00FF88),
                                                size: 22),
                                            onPressed: () =>
                                                _teamService.acceptJoinRequest(
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

                        _buildSectionHeader('Team Members (${team.memberCount})'),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF161F2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2A3447)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: team.memberDetails.isNotEmpty
                                ? team.memberDetails.length
                                : team.members.length,
                            separatorBuilder: (c, i) => const Divider(
                                color: Color(0xFF2A3447), height: 1),
                            itemBuilder: (context, index) {
                              String memberId = '';
                              String memberName = 'Member';
                              String memberAvatar = '';
                              String role = 'Member';

                              if (team.memberDetails.isNotEmpty &&
                                  index < team.memberDetails.length) {
                                final d = team.memberDetails[index];
                                memberId = (d['id'] ?? '').toString();
                                memberName =
                                    (d['name'] ?? 'Member').toString();
                                memberAvatar =
                                    (d['avatar'] ?? '').toString();
                                role = (d['role'] ?? 'Member').toString();
                              } else {
                                memberId = team.members[index];
                                memberName = memberId == team.leaderId
                                    ? team.leaderName
                                    : 'Member';
                                role = memberId == team.leaderId
                                    ? 'Leader'
                                    : 'Member';
                              }

                              final isThisLeader = memberId == team.leaderId;
                              final bool isDefaultName = memberName == 'Player' ||
                                  memberName == 'Member' ||
                                  memberName.isEmpty;

                              return FutureBuilder<Map<String, String>>(
                                future: isDefaultName
                                    ? _fetchUserProfile(memberId)
                                    : Future.value({
                                        'username': memberName,
                                        'avatar': memberAvatar
                                      }),
                                builder: (context, snap) {
                                  final resolvedName =
                                      (snap.data?['username'] != null &&
                                              snap.data!['username'] !=
                                                  'Player')
                                          ? snap.data!['username']!
                                          : (isDefaultName
                                              ? (snap.connectionState ==
                                                      ConnectionState.waiting
                                                  ? '...'
                                                  : memberName)
                                              : memberName);
                                  final resolvedAvatar =
                                      (snap.data?['avatar'] != null &&
                                              snap.data!['avatar']!.isNotEmpty)
                                          ? snap.data!['avatar']!
                                          : memberAvatar;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor:
                                          const Color(0xFF26334D),
                                      backgroundImage: resolvedAvatar.isNotEmpty
                                          ? NetworkImage(resolvedAvatar)
                                          : null,
                                      child: resolvedAvatar.isEmpty
                                          ? Text(
                                              resolvedName.isNotEmpty
                                                  ? resolvedName[0]
                                                      .toUpperCase()
                                                  : 'M',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.bold))
                                          : null,
                                    ),
                                    title: Text(
                                      resolvedName,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isThisLeader
                                            ? const Color(0xFFFF6B00)
                                                .withOpacity(0.2)
                                            : Colors.white10,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isThisLeader
                                            ? '👑 LEADER'
                                            : role.toUpperCase(),
                                        style: TextStyle(
                                          color: isThisLeader
                                              ? const Color(0xFFFF6B00)
                                              : Colors.white70,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildMatchHistorySection(team, currentUid, userTeams),
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
                    decoration: const BoxDecoration(
                      color: Color(0xFF131A29),
                      border: Border(
                          top:
                              BorderSide(color: Color(0xFF2A3447), width: 1)),
                    ),
                    child: Builder(
                      builder: (context) {
                        if (isViewedMyTeam) {
                          return Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1877F2).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF1877F2), width: 1.2),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.shield_rounded,
                                      color: Color(0xFF1877F2), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'your_own_team'.tr(),
                                    style: const TextStyle(
                                      color: Color(0xFF1877F2),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (canAccessMatch && isMatchOpponent) {
                          return Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      final activeMatchId =
                                          activeMatch['id']?.toString() ?? '';
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PrivateMatchRoomScreen(
                                            matchId: activeMatchId,
                                            myTeamId: myTeamIdInMatch,
                                            myTeamName: userMatchTeam?.name ?? 'My Team',
                                            opponentId: opponentTeamId,
                                            opponentName: team.name,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1877F2),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(
                                        Icons.chat_bubble_rounded,
                                        size: 16),
                                    label: const Text(
                                      'Team DM 💬',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                  ),
                                ),
                              ),
                              if (isMatchLeader) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFFF4655),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(
                                          Icons.stop_circle_rounded,
                                          size: 16),
                                      label: const Text(
                                        'End Match',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      onPressed: () async {
                                        final activeMatchId =
                                            activeMatch['id']?.toString() ??
                                                '';
                                        final ended =
                                            await EndMatchBottomSheet.show(
                                          context,
                                          activeMatchId: activeMatchId,
                                          myTeamId: myTeamIdInMatch,
                                          opponentId: opponentTeamId,
                                          myTeamName: userMatchTeam?.name ?? 'My Team',
                                          opponentName: team.name,
                                        );
                                        if (ended == true && mounted) {
                                          setState(() {
                                            _completedMatchIds
                                                .add(activeMatchId);
                                            _optimisticActiveMatches.clear();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        }

                        return StreamBuilder<List<Map<String, dynamic>>>(
                          stream: myTeamId.isNotEmpty
                              ? SupabaseService.client
                                  .from('challenges')
                                  .stream(primaryKey: ['id'])
                                  .eq('from_team_id',
                                      SupabaseService.toUuid(myTeamId))
                              : Stream.value([]),
                          builder: (context, cSnap) {
                            final challenges = cSnap.data ?? [];
                            final rawTeamId = widget.teamId.toLowerCase();
                            final pendingDoc = challenges.firstWhere(
                              (d) {
                                final toId =
                                    d['to_team_id']?.toString().toLowerCase();
                                final st = (d['status'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final id = d['id']?.toString() ?? '';
                                return (toId == targetUuid ||
                                        toId == rawTeamId) &&
                                    st == 'pending' &&
                                    !_cancelledChallengeIds.contains(id);
                              },
                              orElse: () => {},
                            );

                            final bool isPending = pendingDoc.isNotEmpty;

                            return Row(
                              children: [
                                if (!team.isMember(currentUid)) ...[
                                  Builder(builder: (context) {
                                    final bool isRequested =
                                        hasRequested || _hasRequestedLocally;
                                    return Expanded(
                                      flex: 2,
                                      child: SizedBox(
                                        height: 46,
                                        child: OutlinedButton.icon(
                                          onPressed: (isRequested ||
                                                  _isActionLoading)
                                              ? null
                                              : () => _handleJoinRequest(
                                                  team, currentUid),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: BorderSide(
                                              color: isRequested
                                                  ? const Color(0xFFFFB800)
                                                      .withOpacity(0.5)
                                                  : const Color(0xFF2A3447),
                                            ),
                                            backgroundColor:
                                                const Color(0xFF1B2436),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                          icon: Icon(
                                            isRequested
                                                ? Icons.hourglass_top_rounded
                                                : Icons.person_add_rounded,
                                            size: 16,
                                            color: isRequested
                                                ? const Color(0xFFFFB800)
                                                : const Color(0xFF00FF88),
                                          ),
                                          label: Text(
                                            isRequested
                                                ? 'Requested ⏳'
                                                : 'Join Team',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isRequested
                                                  ? const Color(0xFFFFB800)
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 46,
                                    child: isPending
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  height: 46,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                        0xFF1B2436),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFFFFB800)),
                                                  ),
                                                  child: const Center(
                                                    child: Text(
                                                      'REQUESTED ⏳',
                                                      style: TextStyle(
                                                        color: Color(
                                                            0xFFFFB800),
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                height: 46,
                                                child: ElevatedButton(
                                                  style: ElevatedButton
                                                      .styleFrom(
                                                    backgroundColor:
                                                        const Color(
                                                            0xFFFF4655),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10)),
                                                    elevation: 0,
                                                  ),
                                                  onPressed: () =>
                                                      _cancelChallenge(
                                                          pendingDoc['id']
                                                                  ?.toString() ??
                                                              ''),
                                                  child: const Text('CANCEL',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 11)),
                                                ),
                                              ),
                                            ],
                                          )
                                        : ElevatedButton.icon(
                                            onPressed: () => _handleChallenge(
                                                team, currentUid),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF1877F2),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              elevation: 0,
                                            ),
                                            icon: const Icon(
                                                Icons.flash_on_rounded,
                                                size: 18,
                                                color: Colors.white),
                                            label: const Text(
                                              'Challenge Team',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
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
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5),
      ),
    );
  }

  Widget _buildRecordStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 24, width: 1, color: const Color(0xFF2A3447));
  }

  void _showProofDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Match Proof Screenshot 📸',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.vertical(bottom: const Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (c, u) => const SizedBox(
                    height: 220,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF00FF88))),
                  ),
                  errorWidget: (c, u, e) => const SizedBox(
                    height: 180,
                    child: Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white30, size: 40),
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

  void _showLogoDialog(BuildContext context, String logoUrl, String teamName) {
    if (logoUrl.isEmpty) return;
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
                  Expanded(
                    child: Text(
                      '$teamName • Team Logo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: logoUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF6B00)),
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

  Widget _buildMatchHistorySection(
      TeamModel team, String currentUid, List<TeamModel> userTeams) {
    final targetUuid = SupabaseService.toUuid(widget.teamId).toLowerCase();
    final targetRawId = widget.teamId.toLowerCase();

    final Set<String> myTeamIds = {};
    for (final ut in userTeams) {
      myTeamIds.add(ut.id.toLowerCase());
      myTeamIds.add(SupabaseService.toUuid(ut.id).toLowerCase());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Match History 📜'),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.client
              .from('active_matches')
              .stream(primaryKey: ['id']),
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];
            final completedMatches = all.where((m) {
              final st = (m['status'] ?? '').toString().toLowerCase();
              if (st != 'completed') return false;
              final participants = m['participants'];
              final List<String> pList = [];
              if (participants is List) {
                pList.addAll(
                    participants.map((p) => p.toString().toLowerCase()));
              }
              pList.add((m['team1_id'] ?? '').toString().toLowerCase());
              pList.add((m['team2_id'] ?? '').toString().toLowerCase());
              return pList.contains(targetUuid) ||
                  pList.contains(targetRawId);
            }).toList();

            completedMatches.sort((a, b) {
              final aDate = a['ended_at'] ?? a['created_at'] ?? '';
              final bDate = b['ended_at'] ?? b['created_at'] ?? '';
              return bDate.toString().compareTo(aDate.toString());
            });

            if (completedMatches.isEmpty) {
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A29),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A3447)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.history_rounded,
                        color: Colors.white24, size: 36),
                    SizedBox(height: 8),
                    Text(
                      'No Match History Yet',
                      style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Completed matches with verified proofs will appear here.',
                      style:
                          TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: completedMatches.map((m) {
                final t1 = (m['team1_id'] ?? '').toString();
                final t2 = (m['team2_id'] ?? '').toString();
                final isT1 = t1.toLowerCase() == targetUuid ||
                    t1.toLowerCase() == targetRawId;
                final opId = isT1 ? t2 : t1;

                final winnerId =
                    (m['winner_team_id'] ?? '').toString().toLowerCase();
                final resultStr = (m['result'] ?? '').toString().toLowerCase();
                final isDraw = resultStr == 'draw';
                final isWon = !isDraw &&
                    (winnerId == targetUuid || winnerId == targetRawId);

                final proofUrl = m['proof_url']?.toString();
                final dateRaw = m['ended_at'] ?? m['created_at'];
                String formattedDate = '';
                if (dateRaw != null) {
                  try {
                    final dt = DateTime.parse(dateRaw.toString()).toLocal();
                    formattedDate =
                        DateFormat('dd MMM yyyy, hh:mm a').format(dt);
                  } catch (_) {
                    formattedDate = dateRaw.toString();
                  }
                }

                final bool canViewProof = team.isMember(currentUid) ||
                    team.isLeader(currentUid) ||
                    myTeamIds.contains(t1.toLowerCase()) ||
                    myTeamIds.contains(t2.toLowerCase());

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A29),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A3447)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: (canViewProof && proofUrl != null && proofUrl.isNotEmpty)
                            ? () => _showProofDialog(context, proofUrl)
                            : null,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B2436),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: const Color(0xFF2A3447)),
                          ),
                          child: (canViewProof && proofUrl != null && proofUrl.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: proofUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF00FF88)),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.image_not_supported_rounded,
                                      color: Colors.white30,
                                      size: 20,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.verified_user_rounded,
                                    color: Color(0xFF00FF88),
                                    size: 24,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<Map<String, dynamic>>(
                              future: () async {
                                if (!isT1 && m['team1'] is Map) {
                                  final name =
                                      m['team1']['name']?.toString() ?? '';
                                  final tag =
                                      m['team1']['tag']?.toString() ?? '';
                                  if (name.isNotEmpty)
                                    return {'name': name, 'tag': tag};
                                } else if (isT1 && m['team2'] is Map) {
                                  final name =
                                      m['team2']['name']?.toString() ?? '';
                                  final tag =
                                      m['team2']['tag']?.toString() ?? '';
                                  if (name.isNotEmpty)
                                    return {'name': name, 'tag': tag};
                                }

                                try {
                                  final tUuid = SupabaseService.toUuid(opId);
                                  final sRes = await SupabaseService.client
                                      .from('teams')
                                      .select('name, tag')
                                      .eq('id', tUuid)
                                      .maybeSingle();
                                  if (sRes != null && sRes['name'] != null) {
                                    return {
                                      'name': sRes['name'].toString(),
                                      'tag': sRes['tag']?.toString() ?? '',
                                    };
                                  }
                                } catch (_) {}

                                try {
                                  final fTeam =
                                      await _teamService.getTeam(opId);
                                  if (fTeam != null) {
                                    return {
                                      'name': fTeam.name,
                                      'tag': fTeam.tag
                                    };
                                  }
                                } catch (_) {}

                                final fallbackName =
                                    m['opponent_name']?.toString() ??
                                        'Opponent';
                                return {'name': fallbackName, 'tag': ''};
                              }(),
                              builder: (context, opSnap) {
                                final opData = opSnap.data;
                                final opName = opData?['name'] ?? 'Opponent';
                                final opTag = opData?['tag'] ?? '';
                                final tagStr =
                                    opTag.isNotEmpty ? ' [$opTag]' : '';

                                return Text(
                                  'vs $opName$tagStr',
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
                            const SizedBox(height: 4),
                            if (formattedDate.isNotEmpty)
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  color: Color(0xFF8B949E),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isWon
                              ? const Color(0xFF00FF88).withOpacity(0.18)
                              : isDraw
                                  ? const Color(0xFFFFB800).withOpacity(0.18)
                                  : const Color(0xFFFF4655).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isWon
                                ? const Color(0xFF00FF88)
                                : isDraw
                                    ? const Color(0xFFFFB800)
                                    : const Color(0xFFFF4655),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          isWon
                              ? 'WON 🏆'
                              : isDraw
                                  ? 'DRAW 🤝'
                                  : 'LOST ❌',
                          style: TextStyle(
                            color: isWon
                                ? const Color(0xFF00FF88)
                                : isDraw
                                    ? const Color(0xFFFFB800)
                                    : const Color(0xFFFF4655),
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            letterSpacing: 0.5,
                          ),
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
