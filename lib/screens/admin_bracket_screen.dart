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
  bool showFullHistory = false;

  @override
  void initState() {
    super.initState();
    fetchMatches();
  }

  // 1. Matches load karne ka function
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

  // Active Stage Filter: Quarter -> Semi -> Final
  List<Map<String, dynamic>> _getActiveMatches() {
    if (showFullHistory) return matches;

    // 1. Agar Final match ban chuka hai (2 teams), toh screen par sirf Final aayega
    final finalMatches = matches.where((m) {
      final round = (m['round_name'] ?? '').toString().toLowerCase();
      return round.contains('final') && !round.contains('semi') && !round.contains('quarter');
    }).toList();

    if (finalMatches.isNotEmpty) {
      return finalMatches;
    }

    // 2. Agar Semi-Finals ban chuke hain (4 teams), toh Quarter-Finals gayab, sirf Semi-Finals aayenge
    final semiMatches = matches.where((m) {
      final round = (m['round_name'] ?? '').toString().toLowerCase();
      return round.contains('semi');
    }).toList();

    if (semiMatches.isNotEmpty) {
      return semiMatches;
    }

    // 3. Shuru mein jab tak agla round nahi banta, sirf Quarter-Finals (8 teams) aayenge
    final quarterMatches = matches.where((m) {
      final round = (m['round_name'] ?? '').toString().toLowerCase();
      return round.contains('quarter');
    }).toList();

    if (quarterMatches.isNotEmpty) {
      return quarterMatches;
    }

    return matches;
  }

  void showRoomDialog(String matchId, String? currentRoom, String? currentPass) {
    final roomController = TextEditingController(text: currentRoom ?? '');
    final passController = TextEditingController(text: currentPass ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Set Match Room Details', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Room ID',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Room Password',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              updateRoomCredentials(matchId, roomController.text.trim(), passController.text.trim());
            },
            child: const Text('Save Room', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayMatches = _getActiveMatches();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A22),
        elevation: 0,
        title: const Text('Tournament Bracket Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(
              showFullHistory ? Icons.visibility_off_rounded : Icons.history_rounded,
              color: const Color(0xFF38BDF8),
            ),
            tooltip: showFullHistory ? 'Hide Previous Rounds' : 'View Full Bracket History',
            onPressed: () {
              setState(() => showFullHistory = !showFullHistory);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00FF88)),
            onPressed: fetchMatches,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : matches.isEmpty
              ? Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.sports_esports_rounded),
                    onPressed: generateQuarterFinals,
                    label: const Text('Generate 8-Team Quarter Finals', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: displayMatches.length,
                  itemBuilder: (ctx, index) {
                    final match = displayMatches[index];
                    final team1 = match['team1']?['name'] ?? 'TBD';
                    final team2 = match['team2']?['name'] ?? 'TBD';
                    final team1Id = match['team1']?['id']?.toString();
                    final team2Id = match['team2']?['id']?.toString();
                    final winnerId = match['winner_team_id']?.toString();
                    final isCompleted = (winnerId != null && winnerId.isNotEmpty) || match['status'] == 'completed';

                    String winnerName = '';
                    if (winnerId != null) {
                      if (winnerId == team1Id) winnerName = team1;
                      if (winnerId == team2Id) winnerName = team2;
                    }

                    return Card(
                      color: const Color(0xFF161A22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isCompleted ? Colors.white10 : const Color(0xFF00FF88).withOpacity(0.4),
                        ),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${match['round_name']} - Match ${match['match_number']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                if (isCompleted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00FF88).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
                                    ),
                                    child: const Text(
                                      'FINISHED',
                                      style: TextStyle(color: Color(0xFF00FF88), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 16),
                            Text(
                              'Team 1: $team1',
                              style: TextStyle(
                                color: winnerId == team1Id ? const Color(0xFF00FF88) : Colors.white70,
                                fontWeight: winnerId == team1Id ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Team 2: $team2',
                              style: TextStyle(
                                color: winnerId == team2Id ? const Color(0xFF00FF88) : Colors.white70,
                                fontWeight: winnerId == team2Id ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Room ID: ${match['room_id'] ?? 'Not Set'} | Pass: ${match['room_password'] ?? 'Not Set'}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 12),

                            // Agar match mukammal ho gaya toh sirf Winner ka badge aayega, Set Room Details nahi
                            if (isCompleted)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Winner: $winnerName',
                                  style: const TextStyle(
                                    color: Color(0xFF00FF88),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF38BDF8),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.vpn_key_rounded, size: 14),
                                    onPressed: () => showRoomDialog(match['id'], match['room_id'], match['room_password']),
                                    label: const Text('Set Room Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  if (team1Id != null)
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF00FF88),
                                        side: const BorderSide(color: Color(0xFF00FF88)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      onPressed: () => declareWinner(match['id'], team1Id),
                                      child: Text('$team1 Won', style: const TextStyle(fontSize: 11)),
                                    ),
                                  if (team2Id != null)
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF00FF88),
                                        side: const BorderSide(color: Color(0xFF00FF88)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      onPressed: () => declareWinner(match['id'], team2Id),
                                      child: Text('$team2 Won', style: const TextStyle(fontSize: 11)),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
