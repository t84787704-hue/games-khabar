import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/gamer_theme.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../services/team_match_service.dart';
import '../widgets/team_card.dart';
import '../widgets/create_team_dialog.dart';
import 'my_team_matches_screen.dart';
import 'team_leaderboard_screen.dart';
import 'team_match_room_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TeamService _teamService = TeamService();
  final TeamMatchService _matchService = TeamMatchService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  void _openCreateTeamDialog() async {
    final created = await CreateTeamDialog.show(context);
    if (created == true) {
      setState(() {});
    }
  }

  Future<void> _acceptChallenge(String challengeId, Map<String, dynamic> data) async {
    try {
      final success = await _matchService.acceptChallenge(challengeId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ چیلنج قبول کر لیا گیا ہے! میچ روم تیار ہے۔'),
              backgroundColor: Color(0xFF1877F2),
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TeamMatchRoomScreen(matchId: challengeId)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('چیلنج قبول کرنے میں خرابی پیش آئی'),
              backgroundColor: Color(0xFFFF4655),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[TeamsScreen] Error accepting challenge: $e');
    }
  }

  Future<void> _rejectChallenge(String challengeId, Map<String, dynamic> data) async {
    try {
      final success = await _matchService.rejectChallenge(challengeId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('چیلنج مسترد کر دیا گیا ہے'),
              backgroundColor: Color(0xFF65676B),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[TeamsScreen] Error rejecting challenge: $e');
    }
  }

  Future<void> _cancelChallenge(String challengeId) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final success = await _matchService.cancelChallenge(challengeId, cancelledByUid: currentUid);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚫 چیلنج کامیابی سے Cancel کر دیا گیا ہے'),
              backgroundColor: Color(0xFF1877F2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[TeamsScreen] Error cancelling challenge: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // Matches Quick Icon
          IconButton(
            tooltip: 'Team Matches',
            icon: const Icon(Icons.sports_esports_rounded, color: Color(0xFF65676B)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyTeamMatchesScreen()),
              );
            },
          ),
          // Leaderboard Quick Icon
          IconButton(
            tooltip: 'Team Leaderboard',
            icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFF65676B)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeamLeaderboardScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Top Bar: Create Team Action & Quick Navigation
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
                // "Create Team" Primary Action Button
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

          // Incoming & Sent Challenges Section for Team Leaders
          StreamBuilder<List<TeamModel>>(
            stream: (FirebaseAuth.instance.currentUser?.uid.isNotEmpty == true)
                ? _teamService.getUserTeamsStream(FirebaseAuth.instance.currentUser!.uid)
                : Stream.value([]),
            builder: (context, userTeamsSnap) {
              final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
              if (currentUid.isEmpty) return const SizedBox.shrink();

              final userTeams = userTeamsSnap.data ?? [];
              final myLeaderTeams = userTeams.where((t) => t.isLeader(currentUid)).toList();
              final myLeaderTeamIds = myLeaderTeams.map((t) => t.id).toSet();

              // Listen to challenges collection where status is pending
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('challenges').snapshots(),
                builder: (context, challengesSnap) {
                  if (!challengesSnap.hasData) return const SizedBox.shrink();
                  final allChallengeDocs = challengesSnap.data!.docs;

                  // 1. Incoming Challenges where toTeamId is one of myLeaderTeamIds OR toTeamLeaderId == currentUid
                  final incomingChallenges = allChallengeDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = (data['status'] ?? '').toString().toLowerCase();
                    if (status != 'pending') return false;
                    final toTeamId = data['toTeamId']?.toString() ?? '';
                    final toTeamLeaderId = data['toTeamLeaderId']?.toString() ?? '';
                    return myLeaderTeamIds.contains(toTeamId) || (toTeamLeaderId.isNotEmpty && toTeamLeaderId == currentUid);
                  }).toList();

                  // 2. Sent Challenges where fromTeamId is one of myLeaderTeamIds OR fromTeamLeaderId == currentUid
                  final sentChallenges = allChallengeDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = (data['status'] ?? '').toString().toLowerCase();
                    if (status != 'pending') return false;
                    final fromTeamId = data['fromTeamId']?.toString() ?? '';
                    final fromTeamLeaderId = data['fromTeamLeaderId']?.toString() ?? '';
                    return myLeaderTeamIds.contains(fromTeamId) || (fromTeamLeaderId.isNotEmpty && fromTeamLeaderId == currentUid);
                  }).toList();

                  if (incomingChallenges.isEmpty && sentChallenges.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sent Challenges: Red Banner "Aap ne pehle hi challenge bheja hai"
                          if (sentChallenges.isNotEmpty)
                            ...sentChallenges.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final challengeId = doc.id;
                              final toTeamName = data['toTeamName']?.toString() ?? 'Opponent Team';
                              final game = data['game']?.toString() ?? '';
                              final mode = data['mode']?.toString() ?? '';

                              return Container(
                                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFF4655), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF4655).withOpacity(0.08),
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
                                            color: const Color(0xFFFF4655).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655), size: 18),
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Aap ne pehle hi challenge bheja hai',
                                            style: TextStyle(
                                              color: Color(0xFFFF4655),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'آپ نے $toTeamName کو ${game.isNotEmpty ? "$game " : ""}${mode.isNotEmpty ? "($mode) " : ""}میں چیلنج بھیجا ہوا ہے۔ جواب کا انتظار ہے یا چیلنج واپس لے سکتے ہیں۔',
                                      style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _cancelChallenge(challengeId),
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
                                          'CANCEL CHALLENGE (چیلنج منسوخ کریں)',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                          // Incoming Challenges Section
                          if (incomingChallenges.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                                            fontSize: 14.5,
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
                                          '${incomingChallenges.length} New',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ...incomingChallenges.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    final challengeId = doc.id;
                                    final fromTeamName = data['fromTeamName']?.toString() ?? 'Opponent Team';
                                    final fromTeamLeaderName = data['fromTeamLeaderName']?.toString() ?? '';
                                    final fromTeamAvatar = data['fromTeamAvatar']?.toString() ?? '';
                                    final toTeamName = data['toTeamName']?.toString() ?? 'Your Team';
                                    final game = data['game']?.toString() ?? 'Game';
                                    final mode = data['mode']?.toString() ?? '4v4';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
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
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: const Color(0xFFCED0D4),
                                                backgroundImage: fromTeamAvatar.isNotEmpty ? NetworkImage(fromTeamAvatar) : null,
                                                child: fromTeamAvatar.isEmpty
                                                    ? const Icon(Icons.shield_rounded, color: Color(0xFF1877F2), size: 20)
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      fromTeamName,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF050505)),
                                                    ),
                                                    Text(
                                                      fromTeamLeaderName.isNotEmpty
                                                          ? 'Leader: $fromTeamLeaderName • $game ($mode)'
                                                          : '$game ($mode)',
                                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF65676B)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'آپ کی ٹیم "$toTeamName" کو چیلنج موصول ہوا ہے!',
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF1877F2), fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () => _rejectChallenge(challengeId, data),
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
                                                  onPressed: () => _acceptChallenge(challengeId, data),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF1877F2),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                                    minimumSize: const Size(0, 34),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    elevation: 0,
                                                  ),
                                                  child: const Text('ACCEPT CHALLENGE ✅', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // 2. All Teams List
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
                    return TeamCard(team: team);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
