import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';

class TournamentBracketScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentTitle;

  const TournamentBracketScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentTitle,
  });

  @override
  State<TournamentBracketScreen> createState() => _TournamentBracketScreenState();
}

class _TournamentBracketScreenState extends State<TournamentBracketScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _matches = [];

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    setState(() => _isLoading = true);
    try {
      final res = await SupabaseService.client
          .from('tournament_matches')
          .select()
          .eq('tournament_id', widget.tournamentId)
          .order('match_number', ascending: true);

      setState(() {
        _matches = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching matches: $e');
      setState(() => _isLoading = false);
    }
  }

  // Agar matches pehle se nahi bane, toh 8 teams ke liye automatic generate karne ka function
  Future<void> _generateBrackets() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> newMatches = [];

      // 4 Quarter Finals
      for (int i = 1; i <= 4; i++) {
        newMatches.add({
          'tournament_id': widget.tournamentId,
          'round_name': 'Quarter-Final',
          'match_number': i,
          'team1_name': 'Team ${i * 2 - 1}',
          'team2_name': 'Team ${i * 2}',
          'status': 'upcoming',
        });
      }

      // 2 Semi Finals
      for (int i = 1; i <= 2; i++) {
        newMatches.add({
          'tournament_id': widget.tournamentId,
          'round_name': 'Semi-Final',
          'match_number': i + 4,
          'team1_name': 'Winner of QF ${i * 2 - 1}',
          'team2_name': 'Winner of QF ${i * 2}',
          'status': 'upcoming',
        });
      }

      // 1 Final Match
      newMatches.add({
        'tournament_id': widget.tournamentId,
        'round_name': 'Final',
        'match_number': 7,
        'team1_name': 'Winner of SF 1',
        'team2_name': 'Winner of SF 2',
        'status': 'upcoming',
      });

      await SupabaseService.client.from('tournament_matches').insert(newMatches);
      _fetchMatches();
    } catch (e) {
      debugPrint('Error generating brackets: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeService.bg,
      appBar: AppBar(
        backgroundColor: ThemeService.card,
        title: Text(widget.tournamentTitle, style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: ThemeService.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : _matches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No Brackets Found for this Tournament', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _generateBrackets,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
                        child: const Text('Generate 8-Team Bracket 🏆', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('🏆 Quarter-Finals (8 Teams ➔ 4 Winners)', style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ..._matches.where((m) => m['round_name'] == 'Quarter-Final').map((m) => _buildMatchCard(m)),

                    const SizedBox(height: 20),
                    const Text('🥈 Semi-Finals (4 Teams ➔ 2 Winners)', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ..._matches.where((m) => m['round_name'] == 'Semi-Final').map((m) => _buildMatchCard(m)),

                    const SizedBox(height: 20),
                    const Text('🥇 Grand Final (2 Teams ➔ 1 Champion)', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ..._matches.where((m) => m['round_name'] == 'Final').map((m) => _buildMatchCard(m)),
                  ],
                ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final matchId = match['id'].toString();
    final matchNum = match['match_number'];
    final t1 = match['team1_name'] ?? 'TBD';
    final t2 = match['team2_name'] ?? 'TBD';
    final winner = match['winner_name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeService.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: ThemeService.cardSecondary,
            child: Text('$matchNum', style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$t1  vs  $t2', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(winner.isNotEmpty ? '👑 Winner: $winner' : 'Status: Pending', style: TextStyle(color: winner.isNotEmpty ? const Color(0xFF00FF88) : Colors.grey, fontSize: 11.5)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF38BDF8), size: 18),
            onPressed: () => _updateWinnerDialog(matchId, t1, t2),
          ),
        ],
      ),
    );
  }

  void _updateWinnerDialog(String matchId, String t1, String t2) {
    String selectedWinner = t1;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        title: const Text('Declare Match Winner 🏆', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(t1, style: const TextStyle(fontSize: 13)),
                value: t1,
                groupValue: selectedWinner,
                onChanged: (val) => setDialogState(() => selectedWinner = val!),
              ),
              RadioListTile<String>(
                title: Text(t2, style: const TextStyle(fontSize: 13)),
                value: t2,
                groupValue: selectedWinner,
                onChanged: (val) => setDialogState(() => selectedWinner = val!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await SupabaseService.client.from('tournament_matches').update({
                'winner_name': selectedWinner,
                'status': 'completed',
              }).eq('id', matchId);
              Navigator.pop(ctx);
              _fetchMatches();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
            child: const Text('Save Winner'),
          ),
        ],
      ),
