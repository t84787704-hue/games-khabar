import 'package:flutter/material.dart';
import 'package:games_khabar/compat/firebase_auth.dart';
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
        final u = sbProfile['username']?.toString() ?? sbProfile['display_name']?.toString();
        if (u != null && u.isNotEmpty) {
          username = u;
        }
        final g = sbProfile['gamer_id']?.toString() ?? sbProfile['game_id']?.toString();
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
        debugPrint('[TeamProfileScreen] accept_challenge_safe RPC notice: $rpcErr');
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
          final matchPayload = <String, dynamic>{
            'team1_id': t1Uuid,
            'team2_id': t2Uuid,
            'participants': [t1Uuid, t2Uuid],
            'status': 'active',
          };
          try {
            await SupabaseService.client.from('active_matches').insert(matchPayload).select().maybeSingle();
          } catch (insertErr) {
            debugPrint('[TeamProfileScreen] Insert with participants notice: $insertErr');
            await SupabaseService.client.from('active_matches').insert({
              'team1_id': t1Uuid,
              'team2_id': t2Uuid,
              'status': 'active',
            }).select().maybeSingle();
          }
        }
      }

      if (mounted) {
        setState(() {
          _acceptedChallengeIds.add(cId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match Started! Live ho gaya'),
            backgroundColor: Color(0xFF00FF88),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamProfileScreen] Error accepting challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFFF4655)),
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
          .update({'status': 'rejected'})
          .eq('id', cId);
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
          const SnackBar(
            content: Text('Challenge Cancel ho gaya'),
            backgroundColor: Color(0xFF1877F2),
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
        : (FirebaseAuth.instance.currentUser?.uid ??
            (GamerAuthService().currentUid ??
                (SupabaseService.client.auth.currentUser?.id ?? '')));

    if (effectiveUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('براہ کرم پہلے لاگ ان کریں'),
            backgroundColor: Color(0xFFFF4655),
          ),
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
      if (success) {
        _hasRequestedLocally = true;
      }
    });

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
              content: Text('⚠️ Aap ne pehle hi challenge bheja hai!'),
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
            content: Text('⚔️ Challenge sent to ${opponentTeam.name}!'),
            backgroundColor: const Color(0xFF1877F2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamProfileScreen] Error sending challenge: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ??
        (GamerAuthService().currentUid ??
            (SupabaseService.client.auth.currentUser?.id ?? ''));

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

        return StreamBuilder<List<TeamModel>>(
          stream: currentUid.isNotEmpty
              ? _teamService.getUserTeamsStream(currentUid)
              : Stream.value([]),
          builder: (context, userTeamsSnap) {
            final userTeams = userTeamsSnap.data ?? [];
            final myLeaderTeams = userTeams.where((t) => t.isLeader(currentUid)).toList();
            final myTeamId = myLeaderTeams.isNotEmpty ? myLeaderTeams.first.id : (userTeams.isNotEmpty ? userTeams.first.id : '');

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
                  return (st == 'active' || st == 'under_review' || st == 'rejected') &&
                      !_completedMatchIds.contains(m['id']?.toString());
                }).toList();

                final targetUuid = SupabaseService.toUuid(widget.teamId).toLowerCase();
                final targetRawId = widget.teamId.toLowerCase();
                final myUuid = myTeamId.isNotEmpty ? SupabaseService.toUuid(myTeamId).toLowerCase() : '';
                final myRawId = myTeamId.toLowerCase();

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
                final bool isViewedMyTeam = isLeader ||
                    (myTeamId.isNotEmpty &&
                        (widget.teamId.toLowerCase() == myTeamId.toLowerCase() ||
                         targetUuid == SupabaseService.toUuid(myTeamId).toLowerCase()));
                final bool isMyOwnTeam = isViewedMyTeam;

                // ============================================
                // FIXED: Correctly determine MY team vs OPPONENT team
                // Priority: MY team ID (from team_members) > viewed team ID.
                // ============================================
                final t1 = activeMatch['team1_id']?.toString() ?? '';
                final t2 = activeMatch['team2_id']?.toString() ?? '';

                final bool isMyTeamT1 = myUuid.isNotEmpty &&
                    (t1.toLowerCase() == myUuid || t1.toLowerCase() == myRawId);
                final bool isMyTeamT2 = myUuid.isNotEmpty &&
                    (t2.toLowerCase() == myUuid || t2.toLowerCase() == myRawId);

                final String myTeamIdInMatch = isMyTeamT1
                    ? t1
                    : (isMyTeamT2 ? t2 : (myTeamId.isNotEmpty ? myTeamId : widget.teamId));

                final String opponentTeamId = isMyTeamT1
                    ? t2
                    : (isMyTeamT2 ? t1 : '');

                final bool isMatchLeader = hasActiveMatch && (
                  isLeader ||
                  myLeaderTeams.any((t) {
                    final tUuid = SupabaseService.toUuid(t.id).toLowerCase();
                    final tRaw = t.id.toLowerCase();
                    final t1 = activeMatch['team1_id']?.toString().toLowerCase();
                    final t2 = activeMatch['team2_id']?.toString().toLowerCase();
                    return t1 == tUuid || t1 == tRaw || t2 == tUuid || t2 == tRaw;
                  })
                );

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
                      if (hasActiveMatch) ...[
                        IconButton(
                          tooltip: 'Team DM 💬',
                          icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF00FF88), size: 22),
                          onPressed: () {
                            final activeMatchId = activeMatch['id']?.toString() ?? '';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PrivateMatchRoomScreen(
                                  matchId: activeMatchId,
                                  myTeamId: myTeamIdInMatch,
                                  myTeamName: isMyOwnTeam
                                      ? team.name
                                      : (myLeaderTeams.isNotEmpty ? myLeaderTeams.first.name : 'My Team'),
                                  opponentId: opponentTeamId,
                                  opponentName: isMyOwnTeam
                                      ? (activeMatch['opponent_name'] ?? 'Opponent')
                                      : team.name,
                                ),
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF88).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF00FF88)),
                              ),
                              child: const Text('MATCH LIVE', style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ),
                        ),
                      ]
                      else if (!isMyOwnTeam) ...[
                        IconButton(
                          tooltip: 'Challenge Team',
                          icon: const Icon(Icons.flash_on_rounded, color: Color(0xFF1877F2)),
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
                        if (hasActiveMatch)
                          Builder(
                            builder: (context) {
                              final activeMatchId = activeMatch['id']?.toString() ?? '';
                              final matchStatus = (activeMatch['status'] ?? '').toString().toLowerCase();
                              final proofStatus = (activeMatch['proof_status'] ?? '').toString().toLowerCase();
                              final adminNote = activeMatch['admin_note']?.toString() ?? 'Invalid proof screenshot';

                              if (matchStatus == 'under_review' && proofStatus == 'accepted') {
                                if (!_autoCompletingMatchIds.contains(activeMatchId)) {
                                  _autoCompletingMatchIds.add(activeMatchId);
                                  Future.delayed(const Duration(seconds: 3), () async {
                                    try {
                                      await SupabaseService.client.from('active_matches').update({
                                        'status': 'completed',
                                      }).eq('id', activeMatchId);
                                    } catch (_) {}
                                    if (mounted) {
                                      setState(() {
                                        _completedMatchIds.add(activeMatchId);
                                      });
                                    }
                                  });
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B5E20).withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF00FF88), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00FF88).withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.emoji_events_rounded, color: Color(0xFF00FF88), size: 24),
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

                              if (matchStatus == 'rejected' || (matchStatus == 'under_review' && proofStatus == 'rejected')) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B151A).withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF4655).withOpacity(0.15),
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
                                          const Icon(Icons.cancel_rounded, color: Color(0xFFFF4655), size: 22),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '❌ Proof Rejected - $adminNote - Dubara Proof Add Karo',
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
                                            backgroundColor: const Color(0xFFFF4655),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                                          label: const Text('Add Proof Again', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          onPressed: () async {
                                            final ended = await EndMatchBottomSheet.show(
                                              context,
                                              activeMatchId: activeMatchId,
                                              myTeamId: myTeamIdInMatch,
                                              opponentId: opponentTeamId,
                                              myTeamName: isMyOwnTeam
                                                  ? team.name
                                                  : (myLeaderTeams.isNotEmpty ? myLeaderTeams.first.name : 'My Team'),
                                              opponentName: isMyOwnTeam
                                                  ? (activeMatch['opponent_name'] ?? 'Opponent')
                                                  : team.name,
                                            );
                                            if (ended == true && mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Naya proof bhej diya gaya! Under Review.'),
                                                  backgroundColor: Color(0xFFFFB800),
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
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF332A00).withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFFFB800), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFB800).withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFFB800), size: 22),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                              style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB800),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text('REVIEW', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B5E20).withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF00FF88), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00FF88).withOpacity(0.12),
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
                                        const Icon(Icons.local_fire_department_rounded, color: Color(0xFF00FF88), size: 22),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FutureBuilder<TeamModel?>(
                                            future: _teamService.getTeam(opponentTeamId),
                                            builder: (context, opSnap) {
                                              final opName = opSnap.data?.name ??
                                                  activeMatch['opponent_name']?.toString() ??
                                                  (!isMyOwnTeam ? team.name : 'Opponent Team');
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
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00FF88),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text('LIVE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1877F2),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.chat_bubble_rounded, size: 15),
                                          label: const Text('Team DM 💬', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PrivateMatchRoomScreen(
                                                  matchId: activeMatchId,
                                                  myTeamId: myTeamIdInMatch,
                                                  myTeamName: isMyOwnTeam
                                                      ? team.name
                                                      : (myLeaderTeams.isNotEmpty ? myLeaderTeams.first.name : 'My Team'),
                                                  opponentId: opponentTeamId,
                                                  opponentName: isMyOwnTeam
                                                      ? (activeMatch['opponent_name'] ?? 'Opponent')
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
                                              backgroundColor: const Color(0xFFFF4655),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.stop_circle_rounded, size: 16),
                                            label: const Text('End Match', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            onPressed: () async {
                                              final ended = await EndMatchBottomSheet.show(
                                                context,
                                                activeMatchId: activeMatchId,
                                                myTeamId: myTeamIdInMatch,
                                                opponentId: opponentTeamId,
                                                myTeamName: isMyOwnTeam
                                                    ? team.name
                                                    : (myLeaderTeams.isNotEmpty ? myLeaderTeams.first.name : 'My Team'),
                                                opponentName: isMyOwnTeam
                                                    ? (activeMatch['opponent_name'] ?? 'Opponent')
                                                    : team.name,
                                              );
                                              if (ended == true) {
                                                if (mounted) {
                                                  setState(() {
                                                    _completedMatchIds.add(activeMatchId);
                                                    _optimisticActiveMatches.clear();
                                                  });
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Proof bhej diya gaya! Under Review.'),
                                                      backgroundColor: Color(0xFF00FF88),
                                                      duration: Duration(seconds: 4),
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

                        if (isMyOwnTeam)
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: SupabaseService.client
                                .from('challenges')
                                .stream(primaryKey: ['id'])
                                .eq('from_team_id', SupabaseService.toUuid(widget.teamId)),
                            builder: (context, outSnap) {
                              if (!outSnap.hasData) return const SizedBox.shrink();
                              final outgoingList = outSnap.data!
                                  .where((d) => (d['status'] ?? '').toString().toLowerCase() == 'pending')
                                  .where((d) => !_cancelledChallengeIds.contains(d['id']?.toString()))
                                  .toList();
                              if (outgoingList.isEmpty) return const SizedBox.shrink();

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131A29),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.6), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B00).withOpacity(0.08),
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
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF6B00).withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.send_rounded, color: Color(0xFFFF6B00), size: 18),
                                        ),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF6B00),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${outgoingList.length} Sent',
                                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ...outgoingList.map((doc) {
                                      final challengeId = doc['id'];
                                      final toTeamName = doc['to_team_name']?.toString() ?? 'Opponent Team';

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1B2436),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF2A3447)),
                                        ),
                                        child: Row(
                                          children: [
                                            const CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Color(0xFF26334D),
                                              child: Icon(Icons.shield_rounded, color: Color(0xFFFF6B00), size: 18),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Aap ne $toTeamName ko challenge bheja hai',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  const Text(
                                                    'جواب کا انتظار ہے (Waiting for response)',
                                                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white12,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.white24),
                                              ),
                                              child: const Text(
                                                'REQUESTED',
                                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            ElevatedButton(
                                              onPressed: () => _cancelChallenge(challengeId.toString()),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFFF4655),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                minimumSize: const Size(0, 32),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                elevation: 0,
                                              ),
                                              child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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

                        if (isMyOwnTeam)
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: SupabaseService.client
                                .from('challenges')
                                .stream(primaryKey: ['id'])
                                .eq('to_team_id', SupabaseService.toUuid(widget.teamId)),
                            builder: (context, incSnap) {
                              if (!incSnap.hasData) return const SizedBox.shrink();
                              final incomingList = incSnap.data!
                                  .where((d) => (d['status'] ?? '').toString().toLowerCase() == 'pending')
                                  .where((d) => !_acceptedChallengeIds.contains(d['id']?.toString()))
                                  .toList();
                              if (incomingList.isEmpty) return const SizedBox.shrink();

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131A29),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00FF88).withOpacity(0.08),
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
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00FF88).withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.flash_on_rounded, color: Color(0xFF00FF88), size: 18),
                                        ),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF4655),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${incomingList.length} New',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ...incomingList.map((doc) {
                                      final challengeId = doc['id'];
                                      final fromTeamName = doc['from_team_name']?.toString() ?? 'Opponent Team';
                                      final fromTeamId = doc['from_team_id']?.toString() ?? '';
                                      final toTeamId = doc['to_team_id']?.toString() ?? widget.teamId;
                                      final isAccepting = _acceptingChallengeIds.contains(challengeId.toString());

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1B2436),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF2A3447)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: Color(0xFF26334D),
                                                  child: Icon(Icons.shield_rounded, color: Color(0xFF00FF88), size: 20),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    '$fromTeamName ne aap ko challenge bheja hai',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: isAccepting ? null : () => _handleRejectChallenge(challengeId.toString()),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: const Color(0xFFFF4655),
                                                      side: const BorderSide(color: Color(0xFFFF4655)),
                                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                                      minimumSize: const Size(0, 34),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                    child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: isAccepting
                                                        ? null
                                                        : () => _handleAcceptChallenge(
                                                              challengeId: challengeId.toString(),
                                                              fromTeamId: fromTeamId,
                                                              toTeamId: toTeamId,
                                                              fromTeamName: fromTeamName,
                                                              challengeData: doc,
                                                            ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF00FF88),
                                                      foregroundColor: Colors.black,
                                                      disabledBackgroundColor: const Color(0xFF00FF88).withOpacity(0.6),
                                                      disabledForegroundColor: Colors.black87,
                                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                                      minimumSize: const Size(0, 34),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                      elevation: 0,
                                                    ),
                                                    child: isAccepting
                                                        ? const Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              SizedBox(
                                                                width: 14,
                                                                height: 14,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth: 2,
                                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                                                ),
                                                              ),
                                                              SizedBox(width: 8),
                                                              Text('Accepting...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                            ],
                                                          )
                                                        : const Text('ACCEPT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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

                        if (!isMyOwnTeam && myTeamId.isNotEmpty)
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: SupabaseService.client
                                .from('challenges')
                                .stream(primaryKey: ['id'])
                                .eq('from_team_id', SupabaseService.toUuid(myTeamId)),
                            builder: (context, cSnap) {
                              final challenges = cSnap.data ?? [];
                              final targetUuid = SupabaseService.toUuid(widget.teamId).toLowerCase();
                              final rawTeamId = widget.teamId.toLowerCase();
                              final pendingDoc = challenges.firstWhere(
                                (d) {
                                  final toId = d['to_team_id']?.toString().toLowerCase();
                                  final st = (d['status'] ?? '').toString().toLowerCase();
                                  final id = d['id']?.toString() ?? '';
                                  return (toId == targetUuid || toId == rawTeamId) &&
                                      st == 'pending' &&
                                      !_cancelledChallengeIds.contains(id);
                                },
                                orElse: () => {},
                              );

                              if (pendingDoc.isEmpty) return const SizedBox.shrink();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFF4655), width: 1.2),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655), size: 18),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Aap ne pehle hi challenge bheja hai',
                                        style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF4655).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.4)),
                                      ),
                                      child: const Text(
                                        'REQUESTED',
                                        style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF4655),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: const Size(0, 30),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        elevation: 0,
                                      ),
                                      onPressed: () => _cancelChallenge(pendingDoc['id']?.toString() ?? ''),
                                      child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

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
                                return FutureBuilder<Map<String, String>>(
                                  future: _fetchUserProfile(uid),
                                  builder: (context, snap) {
                                    final userData = snap.data;
                                    final isLoading = snap.connectionState == ConnectionState.waiting;
                                    final gamerId = userData?['gamerId'];
                                    final displayGamerId = isLoading
                                        ? 'Loading...'
                                        : 'Gamer ID: ${gamerId != null && gamerId.isNotEmpty ? gamerId : 'ID not set'}';
                                    final displayUsername = userData?['username'] ?? 'Player';

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
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  displayGamerId,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                if (!isLoading && displayUsername != 'Player') ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    displayUsername,
                                                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                                                  ),
                                                ],
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
                              final bool isDefaultName = memberName == 'Player' || memberName == 'Member' || memberName.isEmpty;

                              return FutureBuilder<Map<String, String>>(
                                future: isDefaultName ? _fetchUserProfile(memberId) : Future.value({'username': memberName, 'avatar': memberAvatar}),
                                builder: (context, snap) {
                                  final resolvedName = (snap.data?['username'] != null && snap.data!['username'] != 'Player')
                                      ? snap.data!['username']!
                                      : (isDefaultName ? (snap.connectionState == ConnectionState.waiting ? '...' : memberName) : memberName);
                                  final resolvedAvatar = (snap.data?['avatar'] != null && snap.data!['avatar']!.isNotEmpty)
                                      ? snap.data!['avatar']!
                                      : memberAvatar;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFF26334D),
                                      backgroundImage: resolvedAvatar.isNotEmpty ? NetworkImage(resolvedAvatar) : null,
                                      child: resolvedAvatar.isEmpty
                                          ? Text(resolvedName.isNotEmpty ? resolvedName[0].toUpperCase() : 'M',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                          : null,
                                    ),
                                    title: Text(
                                      resolvedName,
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
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildMatchHistorySection(team, currentUid),
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
                      border: Border(top: BorderSide(color: Color(0xFF2A3447), width: 1)),
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
                              border: Border.all(color: const Color(0xFF1877F2), width: 1.2),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shield_rounded, color: Color(0xFF1877F2), size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'YOUR TEAM (آپ کی اپنی ٹیم)',
                                    style: TextStyle(
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

                        if (hasActiveMatch) {
                          return Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      final activeMatchId = activeMatch['id']?.toString() ?? '';
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PrivateMatchRoomScreen(
                                            matchId: activeMatchId,
                                            myTeamId: myTeamIdInMatch,
                                            myTeamName: isMyOwnTeam
                                                ? team.name
                                                : (myLeaderTeams.isNotEmpty ? myLeaderTeams.first.name : 'My Team'),
                                            opponentId: opponentTeamId,
                                            opponentName: isMyOwnTeam
                                                ? (activeMatch['opponent_name'] ?? 'Opponent')
                                                : team.name,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1877F2),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                                    label: const Text(
                                      'Team DM 💬',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (isMatchLeader)
                                Expanded(
                                  child: SizedBox(
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF4655),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(Icons.stop_circle_rounded, size: 16),
                                      label: const Text(
                                        'End Match',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      onPressed: () async {
                                        final activeMatchId = activeMatch['id']?.toString() ?? '';
                                        final ended = await EndMatchBottomSheet.show(
                                          context,
                                          activeMatchId: activeMatchId,
                                          myTeamId: myTeamIdInMatch,
                                          opponentId: opponentTeamId,
                                          myTeamName: isMyOwnTeam
                                              ? team.name
                                              : (myLeaderTeams.isNotEmpty ? myLeaderTeams.first.name : 'My Team'),
                                          opponentName: isMyOwnTeam
                                              ? (activeMatch['opponent_name'] ?? 'Opponent')
                                              : team.name,
                                        );
                                        if (ended == true) {
                                          if (mounted) {
                                            setState(() {
                                              _completedMatchIds.add(activeMatchId);
                                              _optimisticActiveMatches.clear();
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Proof bhej diya gaya, opponent confirmation ka wait karo'),
                                                backgroundColor: Color(0xFF00FF88),
                                                duration: Duration(seconds: 4),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }

                        return StreamBuilder<List<Map<String, dynamic>>>(
                          stream: myTeamId.isNotEmpty
                              ? SupabaseService.client
                                  .from('challenges')
                                  .stream(primaryKey: ['id'])
                                  .eq('from_team_id', SupabaseService.toUuid(myTeamId))
                              : Stream.value([]),
                          builder: (context, cSnap) {
                            final challenges = cSnap.data ?? [];
                            final rawTeamId = widget.teamId.toLowerCase();
                            final pendingDoc = challenges.firstWhere(
                              (d) {
                                final toId = d['to_team_id']?.toString().toLowerCase();
                                final st = (d['status'] ?? '').toString().toLowerCase();
                                final id = d['id']?.toString() ?? '';
                                return (toId == targetUuid || toId == rawTeamId) &&
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
                                    final bool isRequested = hasRequested || _hasRequestedLocally;
                                    return Expanded(
                                      flex: 2,
                                      child: SizedBox(
                                        height: 46,
                                        child: OutlinedButton.icon(
                                          onPressed: (isRequested || _isActionLoading)
                                              ? null
                                              : () => _handleJoinRequest(team, currentUid),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: BorderSide(
                                              color: isRequested ? const Color(0xFFFFB800).withOpacity(0.5) : const Color(0xFF2A3447),
                                            ),
                                            backgroundColor: const Color(0xFF1B2436),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: Icon(
                                            isRequested ? Icons.hourglass_top_rounded : Icons.person_add_rounded,
                                            size: 16,
                                            color: isRequested ? const Color(0xFFFFB800) : const Color(0xFF00FF88),
                                          ),
                                          label: Text(
                                            isRequested ? 'Requested ⏳' : 'Join Team',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isRequested ? const Color(0xFFFFB800) : Colors.white,
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
                                                    color: const Color(0xFF1B2436),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: const Color(0xFFFFB800)),
                                                  ),
                                                  child: const Center(
                                                    child: Text(
                                                      'REQUESTED ⏳',
                                                      style: TextStyle(
                                                        color: Color(0xFFFFB800),
                                                        fontWeight: FontWeight.w900,
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
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFFF4655),
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    elevation: 0,
                                                  ),
                                                  onPressed: () => _cancelChallenge(pendingDoc['id']?.toString() ?? ''),
                                                  child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                                ),
                                              ),
                                            ],
                                          )
                                        : ElevatedButton.icon(
                                            onPressed: () => _handleChallenge(team, currentUid),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF1877F2),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              elevation: 0,
                                            ),
                                            icon: const Icon(Icons.flash_on_rounded, size: 18, color: Colors.white),
                                            label: const Text(
                                              'Challenge Karo - چیلنج کریں',
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
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (c, u) => const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
                  ),
                  errorWidget: (c, u, e) => const SizedBox(
                    height: 180,
                    child: Center(
                      child: Icon(Icons.broken_image, color: Colors.white30, size: 40),
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

  Widget _buildMatchHistorySection(TeamModel team, String currentUid) {
    final targetUuid = SupabaseService.toUuid(widget.teamId).toLowerCase();
    final targetRawId = widget.teamId.toLowerCase();

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
                pList.addAll(participants.map((p) => p.toString().toLowerCase()));
              }
              pList.add((m['team1_id'] ?? '').toString().toLowerCase());
              pList.add((m['team2_id'] ?? '').toString().toLowerCase());
              return pList.contains(targetUuid) || pList.contains(targetRawId);
            }).toList();

            completedMatches.sort((a, b) {
              final aDate = a['ended_at'] ?? a['created_at'] ?? '';
              final bDate = b['ended_at'] ?? b['created_at'] ?? '';
              return bDate.toString().compareTo(aDate.toString());
            });

            if (completedMatches.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A29),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A3447)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.history_rounded, color: Colors.white24, size: 36),
                    SizedBox(height: 8),
                    Text(
                      'No Match History Yet',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Completed matches with verified proofs will appear here.',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
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
                final isT1 = t1.toLowerCase() == targetUuid || t1.toLowerCase() == targetRawId;
                final opId = isT1 ? t2 : t1;

                final winnerId = (m['winner_team_id'] ?? '').toString().toLowerCase();
                final resultStr = (m['result'] ?? '').toString().toLowerCase();
                final isDraw = resultStr == 'draw';
                final isWon = !isDraw && (winnerId == targetUuid || winnerId == targetRawId);

                final proofUrl = m['proof_url']?.toString();
                final dateRaw = m['ended_at'] ?? m['created_at'];
                String formattedDate = '';
                if (dateRaw != null) {
                  try {
                    final dt = DateTime.parse(dateRaw.toString()).toLocal();
                    formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
                  } catch (_) {
                    formattedDate = dateRaw.toString();
                  }
                }

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
                        onTap: (proofUrl != null && proofUrl.isNotEmpty)
                            ? () => _showProofDialog(context, proofUrl)
                            : null,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B2436),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2A3447)),
                          ),
                          child: (proofUrl != null && proofUrl.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: proofUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF88)),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.image_not_supported_rounded,
                                      color: Colors.white30,
                                      size: 20,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.shield_outlined, color: Colors.white30, size: 24),
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
                                  final name = m['team1']['name']?.toString() ?? '';
                                  final tag = m['team1']['tag']?.toString() ?? '';
                                  if (name.isNotEmpty) return {'name': name, 'tag': tag};
                                } else if (isT1 && m['team2'] is Map) {
                                  final name = m['team2']['name']?.toString() ?? '';
                                  final tag = m['team2']['tag']?.toString() ?? '';
                                  if (name.isNotEmpty) return {'name': name, 'tag': tag};
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
                                  final fTeam = await _teamService.getTeam(opId);
                                  if (fTeam != null) {
                                    return {'name': fTeam.name, 'tag': fTeam.tag};
                                  }
                                } catch (_) {}

                                final fallbackName = m['opponent_name']?.toString() ?? 'Opponent';
                                return {'name': fallbackName, 'tag': ''};
                              }(),
                              builder: (context, opSnap) {
                                final opData = opSnap.data;
                                final opName = opData?['name'] ?? 'Opponent';
                                final opTag = opData?['tag'] ?? '';
                                final tagStr = opTag.isNotEmpty ? ' [$opTag]' : '';

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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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