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
      final result = await SupabaseService.client.rpc('accept_challenge_safe', params: {'p_challenge_id': cId});
      final newMatchId = result?.toString();
      if (newMatchId!= null && newMatchId.isNotEmpty) {
        final fetched = await SupabaseService.client.from('active_matches').select().eq('id', newMatchId).maybeSingle();
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
      await SupabaseService.client.from('challenges').update({'status': 'rejected'}).eq('id', cId);
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
        stream: currentUid.isNotEmpty? _teamService.getUserTeamsStream(currentUid) : Stream.value([]),
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.3),
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
                              side: BorderSide(color: isSel? const Color(0xFF1877F2) : const Color(0xFFCED0D4)),
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
                  stream: SupabaseService.client.from('challenges').stream(primaryKey: ['id']).eq('to_team_id', myTeamUuid),
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
                        boxShadow: [BoxShadow(color: const Color(0xFF1877F2).withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFE7F3FF), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.flash_on_rounded, color: Color(0xFF1877F2), size: 18)),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('Incoming Challenges', style: TextStyle(color: Color(0xFF050505), fontWeight: FontWeight.bold, fontSize: 15))),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFF4655), borderRadius: BorderRadius.circular(12)), child: Text('${docs.length} New', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
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
                              decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCED0D4))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(radius: 18, backgroundColor: Color(0xFFCED0D4), child: Icon(Icons.shield_rounded, color: Color(0xFF1877F2), size: 20)),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text('Challenge from $fromTeamName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF050505)))),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(child: OutlinedButton(onPressed: isAccepting? null : () => _handleRejectChallenge(challengeId.toString()), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF4655), side: const BorderSide(color: Color(0xFFFF4655)), padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: const Size(0, 34), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                                      const SizedBox(width: 10),
                                      Expanded(child: ElevatedButton(onPressed: isAccepting? null : () => _handleAcceptChallenge(challengeId: challengeId.toString(), fromTeamId: fromTeamId, toTeamId: toTeamId), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFF1877F2).withOpacity(0.6), disabledForegroundColor: Colors.white70, padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: const Size(0, 34), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0), child: isAccepting? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))), SizedBox(width: 8), Text('Accepting...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]) : const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
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
                  stream: SupabaseService.client.from('active_matches').stream(primaryKey: ['id']),
                  builder: (context, activeSnap) {
                    final streamMatches = activeSnap.data?? [];
                    final combinedMatches = [..._optimisticActiveMatches,...streamMatches].where((m) {
                      final st = (m['status']?? '').toString().toLowerCase();
                      return (st == 'active' || st == 'under_review') &&!_completedMatchIds.contains(m['id']?.toString());
                    }).toList();
                    final myActiveMatches = combinedMatches.where((m) {
                      final participants = m['participants'];
                      final List<String> pList = [];
                      if (participants is List) {
                        pList.addAll(participants.map((p) => p.toString().toLowerCase()));
                      }
                      pList.add(m['team1_id']?.toString().toLowerCase()?? '');
                 