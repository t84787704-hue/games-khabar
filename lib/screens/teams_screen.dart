import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/supabase_service.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../widgets/team_card.dart';
import '../widgets/create_team_dialog.dart';
import '../widgets/end_match_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'my_team_matches_screen.dart';
import 'team_matches_screen.dart';
import 'team_leaderboard_screen.dart';
import 'leaderboard_screen.dart';
import 'team_profile_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TeamService _teamService = TeamService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedGameFilter = 'All';
  String _searchQuery = '';

  final List<String> _gameFilterOptions = [
    'All',
    'BGMI',
    'Free Fire',
    'PUBG',
    'COD',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _hasPending = false;
  String? _pendingChallengeId;
  bool _showRedBanner = false;
  final Set<String> _cancelledChallengeIds = {};
  final Set<String> _acceptingChallengeIds = {};
  final Set<String> _acceptedChallengeIds = {};
  final Set<String> _completedMatchIds = {};
  final Set<String> _autoCompletingMatchIds = {};
  final List<Map<String, dynamic>> _optimisticActiveMatches = [];

  void _showProofImageDialog(BuildContext context, String imageUrl) {
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
                  const Text('Match Proof 📸', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
                  placeholder: (c, u) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))),
                  errorWidget: (c, u, e) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image, color: Colors.white30))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAcceptChallenge({
    required String challengeId,
    required String fromTeamId,
    required String toTeamId,
  }) async {
    final cId = challengeId.trim();
    if (_acceptingChallengeIds.contains(cId)) return;

    setState(() {
      _acceptingChallengeIds.add(cId);
    });

    try {
      // NEW SAFE RPC - 100 teams ek sath bhi duplicate nahi banega
      final result = await SupabaseService.client
         .rpc('accept_challenge_safe', params: {'p_challenge_id': cId});

      final newMatchId = result?.toString();
      if (newMatchId!= null && newMatchId.isNotEmpty) {
        final fetched = await SupabaseService.client
           .from('active_matches')
           .select()
           .eq('id', newMatchId)
           .maybeSingle();
        if (fetched!= null) {
          _optimisticActiveMatches.add(fetched);
        }
      }

      if (mounted) {
        setState(() {
          _acceptedChallengeIds.add(cId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match Started! Live ho gaya'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamsScreen] Error accepting challenge: $e');
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
      debugPrint('[TeamsScreen] Error rejecting challenge: $e');
    }
  }

  Future<void> _handleCancelChallenge(String challengeId) async {
    setState(() {
      _hasPending = false;
      _pendingChallengeId = null;
      _showRedBanner = false;
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
      debugPrint('[TeamsScreen] Error cancelling challenge: $e');
    }
  }

  void _openCreateTeamDialog() async {
    final created = await CreateTeamDialog.show(context);
    if (created == true) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Teams',
          style: TextStyle(
            color: Color(0xFF1877F2),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Team Matches',
            icon: const Icon(Icons.sports_esports_rounded, color: Color(0xFF65676B)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeamMatchesScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'TOP 100 TEAMS Leaderboard',
            icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFF65676B)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<TeamModel>>(
        stream: currentUid.isNotEmpty
           ? _teamService.getUserTeamsStream(currentUid)
            : Stream.value([]),
        builder: (context, userTeamsSnap) {
          final userTeams = userTeamsSnap.data?? [];
          final myLeaderTeams = userTeams.where((t) => t.isLeader(currentUid)).toList();
          final myTeam = myLeaderTeams.isNotEmpty? myLeaderTeams.first : null;
          final String myTeamId = myTeam?.id?? '';
          final String myTeamName = myTeam?.name?? '';
          final String myTeamUuid = SupabaseService.toUuid(myTeamId);

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE4E6EB), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openCreateTeamDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1877F2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          'CREATE TEAM (ٹیم بنائیں)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE4E6EB)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Color(0xFF050505), fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search by team name or tag...',
                          hintStyle: const TextStyle(color: Color(0xFF65676B), fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF65676B), size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                             ? IconButton(
                                  icon: const Icon(Icons.clear, color: Color(0xFF65676B), size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _gameFilterOptions.map((game) {
                          final isSel = _selectedGameFilter == game;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                game,
                                style: TextStyle(
                                  color: isSel? Colors.white : const Color(0xFF050505),
                                  fontWeight: isSel? FontWeight.bold : FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              selected: isSel,
                              selectedColor: const Color(0xFF1877F2),
                              backgroundColor: const Color(0xFFE4E6EB),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(
                                color: isSel? const Color(0xFF1877F2) : const Color(0xFFCED0D4),
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _selectedGameFilter = game);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              if (myTeamId.isNotEmpty)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client
                     .from('challenges')
                     .stream(primaryKey: ['id'])
                     .eq('to_team_id', myTeamUuid),
                  builder: (context, challengesSnap) {
                    if (!challengesSnap.hasData) return const SizedBox.shrink();
                    final docs = challengesSnap.data!
                       .where((d) => (d['status']?? '').toString().toLowerCase() == 'pending')
                       .where((d) =>!_acceptedChallengeIds.contains(d['id']?.toString()))
                       .toList();
                    if (docs.isEmpty) return const SizedBox.shrink();

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1877F2).withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1877F2).withOpacity(0.08),
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
                                  color: const Color(0xFFE7F3FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.flash_on_rounded, color: Color(0xFF1877F2), size: 18),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Incoming Challenges',
                                  style: TextStyle(
                                    color: Color(0xFF050505),
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
                                  '${docs.length} New',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                         ...docs.map((doc) {
                            final challengeId = doc['id'];
                            final fromTeamName = doc['from_team_name']?.toString()?? 'Opponent Team';
                            final fromTeamId = doc['from_team_id']?.toString()?? '';
                            final toTeamId = doc['to_team_id']?.toString()?? myTeamId;
                            final isAccepting = _acceptingChallengeIds.contains(challengeId.toString());

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F2F5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCED0D4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Color(0xFFCED0D4),
                                        child: Icon(Icons.shield_rounded, color: Color(0xFF1877F2), size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Challenge from $fromTeamName',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF050505)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: isAccepting? null : () => _handleRejectChallenge(challengeId.toString()),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFFF4655),
                                            side: const BorderSide(color: Color(0xFFFF4655)),
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            minimumSize: const Size(0, 34),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                                                  ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1877F2),
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: const Color(0xFF1877F2).withOpacity(0.6),
                                            disabledForegroundColor: Colors.white70,
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
                                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text('Accepting...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                  ],
                                                )
                                              : const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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

              if (myTeamId.isNotEmpty)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client
                     .from('active_matches')
                     .stream(primaryKey: ['id']),
                  builder: (context, activeSnap) {
                    final streamMatches = activeSnap.data?? [];
                    final combinedMatches = [
                     ..._optimisticActiveMatches,
                     ...streamMatches,
                    ].where((m) {
                      final st = (m['status']?? '').toString().toLowerCase();
                      return (st == 'active' || st == 'under_review') &&
                         !_completedMatchIds.contains(m['id']?.toString());
                    }).toList();

                    final myActiveMatches = combinedMatches.where((m) {
                      final participants = m['participants'];
                      final List<String> pList = [];
                      if (participants is List) {
                        pList.addAll(participants.map((p) => p.toString().toLowerCase()));
                      }
                      pList.add(m['team1_id']?.toString().toLowerCase()?? '');
                      pList.add(m['team2_id']?.toString().toLowerCase()?? '');
                      return pList.contains(myTeamUuid.toLowerCase()) || pList.contains(myTeamId.toLowerCase());
                    }).fold<List<Map<String, dynamic>>>([], (uniqueList, item) {
                      final t1 = item['team1_id']?.toString().toLowerCase();
                      final t2 = item['team2_id']?.toString().toLowerCase();
                      final alreadyAdded = uniqueList.any((u) {
                        final u1 = u['team1_id']?.toString().toLowerCase();
                        final u2 = u['team2_id']?.toString().toLowerCase();
                        return (u1 == t1 && u2 == t2) || (u1 == t2 && u2 == t1);
                      });
                      if (!alreadyAdded) uniqueList.add(item);
                      return uniqueList;
                    });

                    if (myActiveMatches.isEmpty) return const SizedBox.shrink();

                    return Column(
                      children: myActiveMatches.map((match) {
                        final matchId = match['id'];
                        final t1 = match['team1_id']?.toString()?? '';
                        final t2 = match['team2_id']?.toString()?? '';
                        final opponentId = (t1.toLowerCase() == myTeamUuid.toLowerCase() || t1.toLowerCase() == myTeamId.toLowerCase())
                           ? t2
                            : t1;
                        final status = (match['status']?? '').toString().toLowerCase();
                        final proofStatus = (match['proof_status']?? '').toString().toLowerCase();
                        final adminNote = match['admin_note']?.toString()?? 'Invalid proof screenshot';

                        if (status == 'under_review' && proofStatus == 'accepted') {
                          if (!_autoCompletingMatchIds.contains(matchId.toString())) {
                            _autoCompletingMatchIds.add(matchId.toString());
                            Future.delayed(const Duration(seconds: 3), () async {
                              try {
                                await SupabaseService.client.from('active_matches').update({
                                  'status': 'completed',
                                }).eq('id', matchId);
                              } catch (_) {}
                              if (mounted) {
                                setState(() {
                                  _completedMatchIds.add(matchId.toString());
                                });
                              }
                            });
                          }

                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.emoji_events_rounded, color: Color(0xFF2E7D32), size: 22),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    '✅ Your Proof Accepted - You Are Win! 🏆',
                                    style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D32),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text('WON 🏆', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                                ),
                              ],
                            ),
                          );
                        }

                        if (status == 'under_review' && proofStatus == 'rejected') {
                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.cancel_rounded, color: Color(0xFFFF4655), size: 20),
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
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final ended = await EndMatchBottomSheet.show(
                                          context,
                                          activeMatchId: matchId.toString(),
                                          myTeamId: myTeamId,
                                          opponentId: opponentId,
                                          myTeamName: myTeamName,
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
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF4655),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: const Size(0, 32),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(Icons.upload_file_rounded, size: 14),
                                      label: const Text('Add Proof Again', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }

                        if (status == 'under_review') {
                          final proofUrl = match['proof_url']?.toString();
                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF8F00), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '⏳ Your Proof Under Review - Admin confirmation ka wait hai',
                                        style: TextStyle(
                                          color: Color(0xFFB78103),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      FutureBuilder<TeamModel?>(
                                        future: _teamService.getTeam(opponentId),
                                        builder: (context, opSnap) {
                                          final opponentName = opSnap.data?.name?? match['opponent_name']?.toString()?? 'Opponent';
                                          return Text(
                                            'vs $opponentName • Admin confirmation ka wait hai',
                                            style: const TextStyle(
                                              color: Color(0xFF8D6E63),
                                              fontSize: 11,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (proofUrl!= null && proofUrl.isNotEmpty)...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _showProofImageDialog(context, proofUrl),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFB300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.visibility_rounded, size: 13, color: Colors.black),
                                          SizedBox(width: 3),
                                          Text(
                                            'View Proof',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        // ACTIVE - View Opponent = Personal Link (Private Room)
                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFF2E7D32), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FutureBuilder<TeamModel?>(
                                      future: _teamService.getTeam(opponentId),
                                      builder: (context, opSnap) {
                                        final opponentName = opSnap.data?.name?? match['opponent_name']?.toString()?? 'Opponent';
                                        return Text(
                                          '🔥 Active Match vs $opponentName - Match is Live',
                                          style: const TextStyle(
                                            color: Color(0xFF2E7D32),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (opponentId.isNotEmpty)
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        // PERSONAL LINK ADDED HERE - View Opponent = Private Room
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PrivateMatchRoomScreen(
                                              matchId: matchId.toString(),
                                              opponentId: opponentId,
                                              myTeamId: myTeamId,
                                              myTeamName: myTeamName,
                                            ),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF2E7D32),
                                        side: const BorderSide(color: Color(0xFF2E7D32)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: const Size(0, 32),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.visibility_rounded, size: 14),
                                      label: const Text('View Opponent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final ended = await EndMatchBottomSheet.show(
                                        context,
                                        activeMatchId: matchId.toString(),
                                        myTeamId: myTeamId,
                                        opponentId: opponentId,
                                        myTeamName: myTeamName,
                                      );
                                      if (ended == true) {
                                        if (mounted) {
                                          setState(() {
                                            _completedMatchIds.add(matchId.toString());
                                            _optimisticActiveMatches.clear();
                                          });
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF4655),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(0, 32),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.stop_circle_rounded, size: 14),
                                    label: const Text('End Match', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: myTeamId.isNotEmpty
                     ? SupabaseService.client
                         .from('challenges')
                         .stream(primaryKey: ['id'])
                         .eq('from_team_id', myTeamUuid)
                      : Stream.value([]),
                  builder: (context, sentSnap) {
                    final sentDocs = sentSnap.data?? [];
                    final activePendingList = sentDocs
                       .where((d) => (d['status']?? '').toString().toLowerCase() == 'pending')
                       .where((d) =>!_cancelledChallengeIds.contains(d['id']?.toString()))
                       .toList();

                    final bool hasPending = activePendingList.isNotEmpty;

                    return Column(
                      children: [
                        if (hasPending)
                         ...activePendingList.map((doc) {
                            final challengeId = doc['id']?.toString()?? '';
                            final toTeamName = doc['to_team_name']?.toString()?? 'Opponent Team';
                            return Container(
                              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F4FD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF1877F2), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1877F2).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF1877F2), size: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '✅ Aapka challenge bhej diya gaya hai - $toTeamName ko challenge bhej diya gaya hai, jawab ka intezar hai',
                                          style: const TextStyle(
                                            color: Color(0xFF1877F2),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _handleCancelChallenge(challengeId),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFFF4655),
                                        side: const BorderSide(color: Color(0xFFFF4655), width: 1.2),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        minimumSize: const Size(0, 32),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        backgroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.close_rounded, size: 15),
                                      label: const Text(
                                        'CANCEL CHALLENGE',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        Expanded(
                          child: StreamBuilder<List<TeamModel>>(
                            stream: _teamService.getTeamsStream(
                              gameFilter: _selectedGameFilter,
                              searchQuery: _searchQuery,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)));
                              }
                              final teams = snapshot.data?? [];
                              if (teams.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE4E6EB),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFFCED0D4)),
                                          ),
                                          child: const Icon(Icons.shield_rounded, size: 44, color: Color(0xFF65676B)),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _selectedGameFilter!= 'All'
                                             ? 'No teams found for $_selectedGameFilter'
                                              : 'No Teams Registered Yet',
                                          style: const TextStyle(color: Color(0xFF050505), fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                itemCount: teams.length,
                                itemBuilder: (context, index) {
                                  final team = teams[index];
                                  final targetUuid = SupabaseService.toUuid(team.id).toLowerCase();
                                  final rawTeamId = team.id.toLowerCase();
                                  final matchingPending = activePendingList.firstWhere(
                                    (d) {
                                      final toId = d['to_team_id']?.toString().toLowerCase();
                                      return toId == targetUuid || toId == rawTeamId;
                                    },
                                    orElse: () => {},
                                  );
                                  return TeamCard(
                                    team: team,
                                    myTeamId: myTeamId,
                                    myTeamName: myTeamName,
                                    pendingChallenge: matchingPending.isNotEmpty? matchingPending : null,
                                    onCancelChallenge: _handleCancelChallenge,
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
              ),
            ],
          );
        },
      ),
    );
  }
}

// PRIVATE ROOM - PERSONAL LINK SCREEN (View Opponent ke andar)
class PrivateMatchRoomScreen extends StatefulWidget {
  final String matchId;
  final String opponentId;
  final String myTeamId;
  final String myTeamName;
  const PrivateMatchRoomScreen({
    super.key,
    required this.matchId,
    required this.opponentId,
    required this.myTeamId,
    required this.myTeamName,
  });

  @override
  State<PrivateMatchRoomScreen> createState() => _PrivateMatchRoomScreenState();
}

class _PrivateMatchRoomScreenState extends State<PrivateMatchRoomScreen> {
  final TeamService _teamService = TeamService();
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    final text = _msgController.text.trim();
    _msgController.clear();
    try {
      await SupabaseService.client.from('match_messages').insert({
        'match_id': widget.matchId,
        'sender_team_id': SupabaseService.toUuid(widget.myTeamId),
        'message': text,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Send error: $e');
    }
  }

  void _showUidDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A29),
        title: const Text('UID / Password Share Karo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _uidController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Room UID / ID', hintStyle: TextStyle(color: Colors.white54))),
            const SizedBox(height: 10),
            TextField(controller: _passController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Password (if any)', hintStyle: TextStyle(color: Colors.white54))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final uid = _uidController.text.trim();
              final pass = _passController.text.trim();
              if (uid.isEmpty) return;
              Navigator.pop(ctx);
              await SupabaseService.client.from('match_messages').insert({
                'match_id': widget.matchId,
                'sender_team_id': SupabaseService.toUuid(widget.myTeamId),
                'message': '🎮 ROOM UID: $uid | PASS: ${pass.isEmpty? 'No Pass' : pass}',
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'is_uid_share': true,
              });
              _uidController.clear();
              _passController.clear();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600)),
            child: const Text('Share', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A29),
        iconTheme: const IconThemeData(color: Colors.white),
        title: FutureBuilder<TeamModel?>(
          future: _teamService.getTeam(widget.opponentId),
          builder: (context, snap) {
            final oppName = snap.data?.name?? 'Opponent';
            return Text('${widget.myTeamName} VS $oppName', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold));
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131A29),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A3245)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Private Room • UID / Password Share', style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD600)),
                  ),
                  child: const Text('Ye chat bilkul private hai. Sirf tum aur opponent dekh sakte ho. Yahan Room UID/Password share karo.',
                      style: TextStyle(color: Color(0xFF5D4037), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showUidDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    icon: const Icon(Icons.vpn_key_rounded, size: 16),
                    label: const Text('UID / Password Share Karo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.client.from('match_messages').stream(primaryKey: ['id']).eq('match_id', widget.matchId),
              builder: (context, snap) {
                final msgs = (snap.data?? [])..sort((a, b) => (a['created_at']?? '').toString().compareTo(b['created_at']?? '').toString());
                if (msgs.isEmpty) {
                  return const Center(child: Text('No messages yet. UID share karo! 🎮', style: TextStyle(color: Colors.white54, fontSize: 12)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final isMe = m['sender_team_id']?.toString().toLowerCase() == SupabaseService.toUuid(widget.myTeamId).toLowerCase();
                    final isUid = m['is_uid_share'] == true;
                    return Align(
                      alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isUid? const Color(0xFFFFD600) : (isMe? const Color(0xFF1877F2) : const Color(0xFF2A3245)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(m['message']?.toString()?? '', style: TextStyle(color: isUid? Colors.black : Colors.white, fontSize: 12, fontWeight: isUid? FontWeight.bold : FontWeight.w500)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(color: Color(0xFF131A29), border: Border(top: BorderSide(color: Color(0xFF2A3245)))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Message likho...',
                      hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF1E2538),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF1877F2),
                  child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}