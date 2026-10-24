import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminBracketScreen extends StatefulWidget {
  final String tournamentId;
  const AdminBracketScreen({Key? key, required this.tournamentId}) : super(key: key);

  @override
  State<AdminBracketScreen> createState() => _AdminBracketScreenState();
}

class _AdminBracketScreenState extends State<AdminBracketScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> matches = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMatches();
  }

  // 1. Matches load karne ka function (Updated with explicit foreign keys)
  Future<void> fetchMatches() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('matches')
          .select('''
            id, round_name, match_number, status, room_id, room_password,
            winner_team_id,
            team1:teams!matches_team_1_id_fkey(id, name),
            team2:teams!matches_team_2_id_fkey(id, name)
          ''')
          .eq('tournament_id', widget.tournamentId)
          .order('match_number', ascending: true);

      setState(() {
        matches = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading matches: $e')),
        );
      }
    }
  }

  // 2. Quarter Finals Generate karne ka RPC call
  Future<void> generateQuarterFinals() async {
    try {
      await supabase.rpc('generate_quarter_finals', params: {
        'target_tournament_id': widget.tournamentId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quarter Finals successfully generated!')),
        );
      }
      fetchMatches();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // 3. Room ID & Password update karna
  Future<void> updateRoomCredentials(String matchId, String roomId, String password) async {
    try {
      await supabase.from('matches').update({
        'room_id': roomId,
        'room_password': password,
        'status': 'ongoing',
      }).eq('id', matchId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room Credentials Saved!')),
        );
      }
      fetchMatches();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving credentials: $e')),
        );
      }
    }
  }

  // 4. Winner declare karna (Automatic agla round banayega)
  Future<void> declareWinner(String matchId, String winnerTeamId) async {
    try {
      await supabase.rpc('declare_match_winner', params: {
        'target_match_id': matchId,
        'winning_team_id': winnerTeamId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Winner updated! Next round generated if ready.')),
        );
      }
      fetchMatches();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating winner: $e')),
        );
      }
    }
  }

  // Credentials input karne ka dialog
  void showRoomDialog(String matchId, String? currentRoom, String? currentPass) {
    final roomController = TextEditingController(text: currentRoom ?? '');
    final passController = TextEditingController(text: currentPass ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Free Fire Room Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomController,
              decoration: const InputDecoration(labelText: 'Room ID'),
            ),
            TextField(
              controller: passController,
              decoration: const InputDecoration(labelText: 'Room Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              updateRoomCredentials(matchId, roomController.text.trim(), passController.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament Bracket Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchMatches,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : matches.isEmpty
              ? Center(
                  child: ElevatedButton(
                    onPressed: generateQuarterFinals,
                    child: const Text('Generate 8-Team Quarter Finals'),
                  ),
                )
              : ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (ctx, index) {
                    final match = matches[index];
                    final team1 = match['team1']?['name'] ?? 'TBD';
                    final team2 = match['team2']?['name'] ?? 'TBD';
                    final team1Id = match['team1']?['id'];
                    final team2Id = match['team2']?['id'];
                    final winnerId = match['winner_team_id'];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${match['round_name']} - Match ${match['match_number']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Divider(),
                            Text('Team 1: $team1', style: TextStyle(color: winnerId == team1Id ? Colors.green : Colors.black)),
                            Text('Team 2: $team2', style: TextStyle(color: winnerId == team2Id ? Colors.green : Colors.black)),
                            const SizedBox(height: 8),
                            Text('Room ID: ${match['room_id'] ?? 'Not Set'} | Pass: ${match['room_password'] ?? 'Not Set'}'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
                                ElevatedButton(
                                  onPressed: () => showRoomDialog(match['id'], match['room_id'], match['room_password']),
                                  child: const Text('Set Room Details'),
                                ),
                                if (match['status'] != 'completed' && team1Id != null && team2Id != null) ...[
                                  OutlinedButton(
                                    onPressed: () => declareWinner(match['id'], team1Id),
                                    child: Text('$team1 Won'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => declareWinner(match['id'], team2Id),
                                    child: Text('$team2 Won'),
                                  ),
                                ],
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
