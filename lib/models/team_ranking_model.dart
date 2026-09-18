import 'package:cloud_firestore/cloud_firestore.dart';

class TeamRanking {
  final String teamId;
  final String teamName;
  final String leaderId;
  final String leaderName;
  final String avatar;
  final String game;
  final int wins;
  final int losses;
  final int draws;
  final int totalMatches;
  final int points; // wins * 3 + draws * 1

  const TeamRanking({
    required this.teamId,
    required this.teamName,
    required this.leaderId,
    required this.leaderName,
    this.avatar = '',
    this.game = 'All',
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.totalMatches = 0,
    this.points = 0,
  });

  double get winRate => totalMatches > 0 ? (wins / totalMatches) * 100 : 0.0;

  factory TeamRanking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final w = (data['wins'] as num?)?.toInt() ?? 0;
    final l = (data['losses'] as num?)?.toInt() ?? 0;
    final d = (data['draws'] as num?)?.toInt() ?? 0;
    final tm = (data['totalMatches'] as num?)?.toInt() ?? (w + l + d);
    final pts = (data['points'] as num?)?.toInt() ?? (w * 3 + d);

    return TeamRanking(
      teamId: data['teamId'] ?? doc.id,
      teamName: data['teamName'] ?? 'Gamer Team',
      leaderId: data['leaderId'] ?? '',
      leaderName: data['leaderName'] ?? 'Leader',
      avatar: data['avatar'] ?? '',
      game: data['game'] ?? 'All',
      wins: w,
      losses: l,
      draws: d,
      totalMatches: tm,
      points: pts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'leaderId': leaderId,
      'leaderName': leaderName,
      'avatar': avatar,
      'game': game,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'totalMatches': totalMatches,
      'points': points,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
