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

  factory TeamRanking.fromFirestore(dynamic doc) => TeamRanking.fromSupabase(doc);
  factory TeamRanking.fromSupabase(dynamic doc) {
    if (doc == null) return TeamRanking.fromMap({}, '');
    try {
      final data = (doc as dynamic).data();
      if (data is Map<String, dynamic>) {
        return TeamRanking.fromMap(data, (doc as dynamic).id?.toString());
      }
    } catch (_) {}
    if (doc is Map<String, dynamic>) {
      return TeamRanking.fromMap(doc, doc['id']?.toString());
    }
    return TeamRanking.fromMap({}, '');
  }

  factory TeamRanking.fromMap(Map<String, dynamic> data, [String? docId]) {
    final w = (data['wins'] as num?)?.toInt() ?? 0;
    final l = (data['losses'] as num?)?.toInt() ?? 0;
    final d = (data['draws'] as num?)?.toInt() ?? 0;
    final tm = (data['totalMatches'] ?? data['total_matches'] as num?)?.toInt() ?? (w + l + d);
    final pts = (data['points'] as num?)?.toInt() ?? (w * 3 + d);

    return TeamRanking(
      teamId: (data['teamId'] ?? data['team_id'] ?? data['id'] ?? docId ?? '').toString(),
      teamName: (data['teamName'] ?? data['team_name'] ?? 'Gamer Team').toString(),
      leaderId: (data['leaderId'] ?? data['leader_id'] ?? '').toString(),
      leaderName: (data['leaderName'] ?? data['leader_name'] ?? 'Leader').toString(),
      avatar: (data['avatar'] ?? data['avatar_url'] ?? '').toString(),
      game: (data['game'] ?? 'All').toString(),
      wins: w,
      losses: l,
      draws: d,
      totalMatches: tm,
      points: pts,
    );
  }

  Map<String, dynamic> toMap() {
    final nowStr = DateTime.now().toIso8601String();
    return {
      'teamId': teamId,
      'team_id': teamId,
      'teamName': teamName,
      'team_name': teamName,
      'leaderId': leaderId,
      'leader_id': leaderId,
      'leaderName': leaderName,
      'leader_name': leaderName,
      'avatar': avatar,
      'game': game,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'totalMatches': totalMatches,
      'total_matches': totalMatches,
      'points': points,
      'updatedAt': nowStr,
      'updated_at': nowStr,
    };
  }
}
