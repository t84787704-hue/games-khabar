class TeamModel {
  final String id;
  final String name;
  final String tag;
  final String logo;
  final String game;
  final String description;
  final String requirements;
  final String leaderId;
  final int wins;
  final int losses;
  final int draws;
  final int points;
  final DateTime createdAt;

  const TeamModel({
    required this.id,
    required this.name,
    required this.tag,
    this.logo = '',
    required this.game,
    this.description = '',
    this.requirements = '',
    required this.leaderId,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.points = 0,
    required this.createdAt,
  });

  int get totalMatches => wins + losses + draws;
  double get winRate =>
      totalMatches > 0 ? (wins / totalMatches) * 100 : 0.0;

  factory TeamModel.fromSupabase(Map<String, dynamic> row) {
    return TeamModel(
      id: (row['id'] ?? '').toString(),
      name: (row['name'] ?? 'Gamer Team').toString(),
      tag: (row['tag'] ?? 'TEAM').toString().toUpperCase(),
      logo: (row['logo_url'] ?? '').toString(),
      game: (row['game'] ?? 'BGMI').toString(),
      description: (row['description'] ?? '').toString(),
      requirements: (row['requirements'] ?? '').toString(),
      leaderId: (row['leader_id'] ?? '').toString(),
      wins: (row['wins'] as num?)?.toInt() ?? 0,
      losses: (row['losses'] as num?)?.toInt() ?? 0,
      draws: (row['draws'] as num?)?.toInt() ?? 0,
      points: (row['points'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(
            (row['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'name': name.trim(),
      'tag': tag.trim().toUpperCase(),
      'logo_url': logo,
      'game': game,
      'description': description.trim(),
      'requirements': requirements.trim(),
      'leader_id': leaderId,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'points': points,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TeamModel copyWith({
    String? name,
    String? tag,
    String? logo,
    String? game,
    String? description,
    String? requirements,
    int? wins,
    int? losses,
    int? draws,
    int? points,
  }) {
    return TeamModel(
      id: id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      logo: logo ?? this.logo,
      game: game ?? this.game,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      leaderId: leaderId,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      points: points ?? this.points,
      createdAt: createdAt,
    );
  }
}