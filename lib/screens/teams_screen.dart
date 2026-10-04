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

    // 1. Immediately setState: isAccepting=true, disable both Accept and Reject buttons
    setState(() {
      _acceptingChallengeIds.add(cId);
    });

    try {
      // 2. Do operations with await in order:
      // Update challenge status to accepted
      await SupabaseService.client
          .from('challenges')
          .update({'status': 'accepted'})
          .eq('id', cId);

      // Check duplicate first: existing = await supabase.from('active_matches').select().eq('status','active').or('and(team1_id.eq.${from},team2_id.eq.${to}),and(team1_id.eq.${to},team2_id.eq.${from})')
      final t1 = SupabaseService.toUuid(fromTeamId);
      final t2 = SupabaseService.toUuid(toTeamId);

      final existing = await SupabaseService.client
          .from('active_matches')
          .select()
          .eq('status', 'active')
          .or('and(team1_id.eq.$t1,team2_id.eq.$t2),and(team1_id.eq.$t2,team2_id.eq.$t1)');

      final bool hasExisting = (existing as List).isNotEmpty;

      // If existing empty: insert
      if (!hasExisting) {
        final newMatch = await SupabaseService.client.from('active_matches').insert({
          'team1_id': t1,
          'team2_id': t2,
          'participants': [t1, t2],
          'status': 'active',
          'game': 'BGMI',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }).select().maybeSingle();

        if (newMatch != null) {
          _optimisticActiveMatches.add(newMatch);
        }
      }

      // 3. Optimistic UI: Immediately after await, setState hide Incoming banner and show Active Match banner (don't wait for stream). Show snackbar "Match Started! Live ho gaya"
      if (mounted) {
        setState(() {
          _acceptedChallengeIds.add(cId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasExisting ? 'Already Active' : 'Match Started! Live ho gaya'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 3),
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
      // 4. On success: isAccepting=false
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
    // 1. First: hide instantly for UX
    setState(() {
      _hasPending = false;
      _pendingChallengeId = null;
      _showRedBanner = false;
      _cancelledChallengeIds.add(challengeId);
    });

    try {
      // 2. Then: delete from Supabase
      await SupabaseService.client
          .from('challenges')
          .delete()
          .eq('id', challengeId);

      // 3. Small delay 500ms then refetch to confirm
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() {});

      // 4. Show snackbar "Challenge Cancel ho gaya"
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
      // 1. Get myTeamId first via real-time stream of user teams
      body: StreamBuilder<List<TeamModel>>(
        stream: currentUid.isNotEmpty
            ? _teamService.getUserTeamsStream(currentUid)
            : Stream.value([]),
        builder: (context, userTeamsSnap) {
          final userTeams = userTeamsSnap.data ?? [];
          final myLeaderTeams = userTeams.where((t) => t.isLeader(currentUid)).toList();
          final myTeam = myLeaderTeams.isNotEmpty ? myLeaderTeams.first : null;
          final String myTeamId = myTeam?.id ?? '';
          final String myTeamName = myTeam?.name ?? '';
          final String myTeamUuid = SupabaseService.toUuid(myTeamId);

          return Column(
            children: [
              // Top Bar: Create Team Action & Game Filter
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

                    // Search Box
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

                    // Game Filter Chips
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
                                  color: isSel ? Colors.white : const Color(0xFF050505),
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              selected: isSel,
                              selectedColor: const Color(0xFF1877F2),
                              backgroundColor: const Color(0xFFE4E6EB),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(
                                color: isSel ? const Color(0xFF1877F2) : const Color(0xFFCED0D4),
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

              // 1. INCOMING CHALLENGES: Supabase Realtime stream
              if (myTeamId.isNotEmpty)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client
                      .from('challenges')
                      .stream(primaryKey: ['id'])
                      .eq('to_team_id', myTeamUuid),
                  builder: (context, challengesSnap) {
                    if (!challengesSnap.hasData) return const SizedBox.shrink();
                    final docs = challengesSnap.data!
                        .where((d) => (d['status'] ?? '').toString().toLowerCase() == 'pending')
                        .where((d) => !_acceptedChallengeIds.contains(d['id']?.toString()))
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
                            final fromTeamName = doc['from_team_name']?.toString() ?? 'Opponent Team';
                            final fromTeamId = doc['from_team_id']?.toString() ?? '';
                            final toTeamId = doc['to_team_id']?.toString() ?? myTeamId;
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
                                          onPressed: isAccepting ? null : () => _handleRejectChallenge(challengeId.toString()),
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

              // 3. ACTIVE MATCH CONNECTION BANNER: Supabase Realtime stream
              if (myTeamId.isNotEmpty)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client
                      .from('active_matches')
                      .stream(primaryKey: ['id']),
                  builder: (context, activeSnap) {
                    final streamMatches = activeSnap.data ?? [];
                    final combinedMatches = [
                      ..._optimisticActiveMatches,
                      ...streamMatches,
                    ].where((m) {
                      final st = (m['status'] ?? '').toString().toLowerCase();
                      return (st == 'active' || st == 'under_review') &&
                          !_completedMatchIds.contains(m['id']?.toString());
                    }).toList();

                    final myActiveMatches = combinedMatches.where((m) {
                      final participants = m['participants'];
                      final List<String> pList = [];
                      if (participants is List) {
                        pList.addAll(participants.map((p) => p.toString().toLowerCase()));
                      }
                      pList.add(m['team1_id']?.toString().toLowerCase() ?? '');
                      pList.add(m['team2_id']?.toString().toLowerCase() ?? '');
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
                        final t1 = match['team1_id']?.toString() ?? '';
                        final t2 = match['team2_id']?.toString() ?? '';
                        final opponentId = (t1.toLowerCase() == myTeamUuid.toLowerCase() || t1.toLowerCase() == myTeamId.toLowerCase())
                            ? t2
                            : t1;
                        final status = (match['status'] ?? '').toString().toLowerCase();
                        final proofStatus = (match['proof_status'] ?? '').toString().toLowerCase();
                        final adminNote = match['admin_note']?.toString() ?? 'Invalid proof screenshot';

                        // Case 3: under_review & accepted -> 3 second auto-hide
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
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2E7D32).withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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

                        // Case 4: under_review & rejected -> Red banner + "Add Proof Again" button
                        if (status == 'under_review' && proofStatus == 'rejected') {
                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF4655).withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF4655),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('REJECTED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
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

                        // Case 2: under_review & pending -> Yellow banner "⏳ Your Proof Under Review - Admin confirmation ka wait hai" + View Proof
                        if (status == 'under_review') {
                          final proofUrl = match['proof_url']?.toString();
                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFB300).withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
                                          final opponentName = opSnap.data?.name ?? match['opponent_name']?.toString() ?? 'Opponent';
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
                                if (proofUrl != null && proofUrl.isNotEmpty) ...[
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
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFB300),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('REVIEW', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        // Case 1: status == 'active' -> Green banner "Active Match vs Opponent - Match is Live" (already hai)
                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E7D32).withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
                                        final opponentName = opSnap.data?.name ?? match['opponent_name']?.toString() ?? 'Opponent';
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
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TeamProfileScreen(teamId: opponentId),
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
                                  // 4. END MATCH button for leaders
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
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Proof bhej diya gaya! Under Review.'),
                                              backgroundColor: Color(0xFF2E7D32),
                                              duration: Duration(seconds: 4),
                                            ),
                                          );
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

              // 2. SENDER SIDE: Pending challenge red banner & All Teams List
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: myTeamId.isNotEmpty
                      ? SupabaseService.client
                          .from('challenges')
                          .stream(primaryKey: ['id'])
                          .eq('from_team_id', myTeamUuid)
                      : Stream.value([]),
                  builder: (context, sentSnap) {
                    final sentDocs = sentSnap.data ?? [];
                    final activePendingList = sentDocs
                        .where((d) => (d['status'] ?? '').toString().toLowerCase() == 'pending')
                        .where((d) => !_cancelledChallengeIds.contains(d['id']?.toString()))
                        .toList();

                    final bool hasPending = activePendingList.isNotEmpty;

                    return Column(
                      children: [
                        if (hasPending)
                          ...activePendingList.map((doc) {
                            final challengeId = doc['id']?.toString() ?? '';
                            final toTeamName = doc['to_team_name']?.toString() ?? 'Opponent Team';

                            return Container(
                              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F4FD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF1877F2), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1877F2).withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
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

                        // All Teams List
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

                              final teams = snapshot.data ?? [];

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
                                          _selectedGameFilter != 'All'
                                              ? 'No teams found for $_selectedGameFilter'
                                              : 'No Teams Registered Yet',
                                          style: const TextStyle(color: Color(0xFF050505), fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'سب سے پہلے اپنی ٹیم بنائیں اور دوسری ٹیموں کے ساتھ مقابلہ کریں!',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Color(0xFF65676B), fontSize: 13),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          onPressed: _openCreateTeamDialog,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1877F2),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.add, color: Colors.white),
                                          label: const Text('Create First Team', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                    pendingChallenge: matchingPending.isNotEmpty ? matchingPending : null,
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