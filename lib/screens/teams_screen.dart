import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/supabase_service.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../widgets/team_card.dart';
import '../widgets/create_team_dialog.dart';
import 'my_team_matches_screen.dart';
import 'team_leaderboard_screen.dart';
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
                MaterialPageRoute(builder: (_) => const MyTeamMatchesScreen()),
              );
            },
          ),
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
      // 1. Get myTeamId first via real-time stream of user teams
      body: StreamBuilder<List<TeamModel>>(
        stream: currentUid.isNotEmpty
            ? _teamService.getUserTeamsStream(currentUid)
            : Stream.value([]),
        builder: (context, userTeamsSnap) {
          final userTeams = userTeamsSnap.data ?? [];
          final myLeaderTeams = userTeams.where((t) => t.isLeader(currentUid)).toList();
          final myTeam = myLeaderTeams.isNotEmpty
              ? myLeaderTeams.first
              : (userTeams.isNotEmpty ? userTeams.first : null);
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
                      .eq('to_team_id', myTeamUuid)
                      .eq('status', 'pending'),
                  builder: (context, challengesSnap) {
                    if (!challengesSnap.hasData) return const SizedBox.shrink();
                    final docs = challengesSnap.data!
                        .where((d) => (d['status'] ?? '').toString().toLowerCase() == 'pending')
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
                                          onPressed: () async {
                                            await SupabaseService.client
                                                .from('challenges')
                                                .update({'status': 'rejected'})
                                                .eq('id', challengeId);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Challenge rejected')),
                                              );
                                            }
                                          },
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
                                          onPressed: () async {
                                            await SupabaseService.client
                                                .from('challenges')
                                                .update({'status': 'accepted'})
                                                .eq('id', challengeId);
                                            final t1 = SupabaseService.toUuid(fromTeamId);
                                            final t2 = SupabaseService.toUuid(toTeamId);
                                            await SupabaseService.client
                                                .from('active_matches')
                                                .insert({
                                                  'team1_id': t1,
                                                  'team2_id': t2,
                                                  'participants': [t1, t2],
                                                  'status': 'active',
                                                });
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('✅ Challenge Accepted! Active Match is Live.'),
                                                  backgroundColor: Color(0xFF2E7D32),
                                                ),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1877F2),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            minimumSize: const Size(0, 34),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                      .stream(primaryKey: ['id'])
                      .eq('status', 'active'),
                  builder: (context, activeSnap) {
                    if (!activeSnap.hasData) return const SizedBox.shrink();
                    final myActiveMatches = activeSnap.data!.where((m) {
                      if (m['status'] != 'active') return false;
                      final participants = m['participants'];
                      final List<String> pList = [];
                      if (participants is List) {
                        pList.addAll(participants.map((p) => p.toString().toLowerCase()));
                      }
                      pList.add(m['team1_id']?.toString().toLowerCase() ?? '');
                      pList.add(m['team2_id']?.toString().toLowerCase() ?? '');
                      return pList.contains(myTeamUuid.toLowerCase()) || pList.contains(myTeamId.toLowerCase());
                    }).toList();

                    if (myActiveMatches.isEmpty) return const SizedBox.shrink();

                    return Column(
                      children: myActiveMatches.map((match) {
                        final matchId = match['id'];
                        final t1 = match['team1_id']?.toString() ?? '';
                        final t2 = match['team2_id']?.toString() ?? '';
                        final opponentId = (t1.toLowerCase() == myTeamUuid.toLowerCase() || t1.toLowerCase() == myTeamId.toLowerCase())
                            ? t2
                            : t1;

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
                                  const Expanded(
                                    child: Text(
                                      '🔥 Active Match in Progress - Match is Live',
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
                                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (opponentId != null && opponentId.isNotEmpty)
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
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('End Match?'),
                                          content: const Text('Are you sure you want to end this active match?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655)),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('End Match', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await SupabaseService.client
                                            .from('active_matches')
                                            .update({'status': 'completed'})
                                            .eq('id', matchId);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Match marked as completed!'), backgroundColor: Color(0xFF2E7D32)),
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

              // 2. SENDER SIDE: Pending challenge red banner
              if (myTeamId.isNotEmpty)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client
                      .from('challenges')
                      .stream(primaryKey: ['id'])
                      .eq('from_team_id', myTeamUuid),
                  builder: (context, sentSnap) {
                    if (!sentSnap.hasData) return const SizedBox.shrink();
                    final sentDocs = sentSnap.data!
                        .where((d) => (d['status'] ?? '').toString().toLowerCase() == 'pending')
                        .toList();
                    if (sentDocs.isEmpty) return const SizedBox.shrink();

                    return Column(
                      children: sentDocs.map((doc) {
                        final challengeId = doc['id'];
                        final toTeamName = doc['to_team_name']?.toString() ?? 'Opponent Team';

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
                                'آپ نے $toTeamName کو چیلنج بھیجا ہوا ہے۔ جواب کا انتظار ہے یا چیلنج واپس لے سکتے ہیں۔',
                                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await SupabaseService.client
                                        .from('challenges')
                                        .delete()
                                        .eq('id', challengeId);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('🚫 چیلنج کامیابی سے Cancel کر دیا گیا ہے'),
                                          backgroundColor: Color(0xFF1877F2),
                                        ),
                                      );
                                    }
                                  },
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
                      }).toList(),
                    );
                  },
                ),

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
                        return TeamCard(
                          team: team,
                          myTeamId: myTeamId,
                          myTeamName: myTeamName,
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
    );
  }
}
