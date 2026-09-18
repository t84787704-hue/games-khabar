import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/gamer_theme.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../widgets/team_card.dart';
import '../widgets/create_team_dialog.dart';
import 'my_team_matches_screen.dart';
import 'team_leaderboard_screen.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A29),
        elevation: 0,
        title: const Row(
          children: [
            Text('🛡️', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'TEAMS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          // Matches Quick Icon
          IconButton(
            tooltip: 'Team Matches',
            icon: const Icon(Icons.sports_esports_rounded, color: Color(0xFFFF6B00)),
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
            icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700)),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: const Color(0xFF131A29),
            child: Column(
              children: [
                // "Create Team" Primary Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openCreateTeamDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.shield_rounded, color: Colors.black, size: 20),
                    label: const Text(
                      'CREATE TEAM (ٹیم بنائیں) 🛡️',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Search Box
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2234),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A3447)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by team name or tag...',
                      hintStyle: const TextStyle(color: Color(0xFF555E6D), fontSize: 12.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8B949E), size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
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
                              color: isSel ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: const Color(0xFF00FF88),
                          backgroundColor: const Color(0xFF161F2E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: BorderSide(
                            color: isSel ? const Color(0xFF00FF88) : const Color(0xFF2A3447),
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

          // 2. All Teams List
          Expanded(
            child: StreamBuilder<List<TeamModel>>(
              stream: _teamService.getTeamsStream(
                gameFilter: _selectedGameFilter,
                searchQuery: _searchQuery,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
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
                              color: const Color(0xFF161F2E),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF2A3447)),
                            ),
                            child: const Text('🛡️', style: TextStyle(fontSize: 44)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedGameFilter != 'All'
                                ? 'No teams found for $_selectedGameFilter'
                                : 'No Teams Registered Yet',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'سب سے پہلے اپنی ٹیم بنائیں اور دوسری ٹیموں کے ساتھ مقابلہ کریں!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _openCreateTeamDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B00),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add, color: Colors.black),
                            label: const Text('Create First Team', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
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
