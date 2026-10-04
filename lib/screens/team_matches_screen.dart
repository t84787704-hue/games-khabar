import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/team_service.dart';
import '../models/team_model.dart';
import 'match_chat_screen.dart';

class TeamMatchesScreen extends StatefulWidget {
  const TeamMatchesScreen({super.key});

  @override
  State<TeamMatchesScreen> createState() => _TeamMatchesScreenState();
}

class _TeamMatchesScreenState extends State<TeamMatchesScreen> {
  final TeamService _teamService = TeamService();

  Future<void> _refresh() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A29),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('⚔️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'TEAM MATCHES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF6B00),
        backgroundColor: const Color(0xFF131A29),
        onRefresh: _refresh,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.client
              .from('active_matches')
              .stream(primaryKey: ['id']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
              );
            }

            final allMatches = snapshot.data ?? [];
            // Filter strictly: status in ['active', 'under_review']
            final activeMatches = allMatches.where((m) {
              final status = (m['status'] ?? '').toString().toLowerCase();
              return status == 'active' || status == 'under_review';
            }).toList();

            // Sort by created_at ascending (desc: false)
            activeMatches.sort((a, b) {
              final aDate = a['created_at']?.toString() ?? '';
              final bDate = b['created_at']?.toString() ?? '';
              return aDate.compareTo(bDate);
            });

            if (activeMatches.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                          child: const Text('⚔️', style: TextStyle(fontSize: 40)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Active Matches',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'فی الوقت کوئی ایکٹو چیلنج یا لائیو میچ نہیں ہے۔ نئی ٹیموں کو چیلنج بھیجیں!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: activeMatches.length,
              itemBuilder: (context, index) {
                final match = activeMatches[index];
                return _buildSimpleMatchCard(match);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSimpleMatchCard(Map<String, dynamic> match) {
    final matchId = match['id']?.toString() ?? '';
    final t1 = (match['team1_id'] ?? '').toString();
    final t2 = (match['team2_id'] ?? '').toString();

    // Check if joined team object exists in record
    String? t1Joined;
    String? t2Joined;
    if (match['team1'] is Map) {
      t1Joined = match['team1']['name']?.toString();
    }
    if (match['team2'] is Map) {
      t2Joined = match['team2']['name']?.toString();
    }

    return FutureBuilder<List<TeamModel?>>(
      future: Future.wait([
        _teamService.getTeam(t1),
        _teamService.getTeam(t2),
      ]),
      builder: (context, snap) {
        final t1Name = t1Joined ?? snap.data?[0]?.name ?? match['team1_name'] ?? 'Team 1';
        final t2Name = t2Joined ?? snap.data?[1]?.name ?? match['team2_name'] ?? 'Team 2';

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MatchChatScreen(
                  matchId: matchId,
                  team1Id: t1,
                  team2Id: t2,
                  team1Name: t1Name,
                  team2Name: t2Name,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF131A29),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A3447)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Team 1 Name
                Expanded(
                  child: Text(
                    t1Name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // VS
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Color(0xFFFF4655),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                // Team 2 Name
                Expanded(
                  child: Text(
                    t2Name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
