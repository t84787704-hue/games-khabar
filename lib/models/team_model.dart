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

  // Optional fields (populated from joins if needed)
  final String leaderName;
  final String leaderAvatar;
  final List<String> members;
  final List<Map<String, dynamic>> memberDetails;
  final List<String> pendingJoinRequests;

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
    this.leaderName = '',
    this.leaderAvatar = '',
    this.members = const [],
    this.memberDetails = const [],
    this.pendingJoinRequests = const [],
  });

  int get memberCount => members.length;
  int get totalMatches => wins + losses + draws;
  double get winRate => totalMatches > 0 ? (wins / totalMatches) * 100 : 0.0;

  bool isLeader(String userId) => leaderId == userId;
  bool isMember(String userId) => members.contains(userId) || leaderId == userId;
  bool hasRequestedJoin(String userId) => pendingJoinRequests.contains(userId);

  factory TeamModel.fromSupabase(Map<String, dynamic> row) {
    final rawMembers = row['members'];
    final List<String> membersList = [];
    if (rawMembers is List) {
      for (final m in rawMembers) {
        if (m != null) membersList.add(m.toString());
      }
    }

    final rawRequests = row['pendingJoinRequests'];
    final List<String> reqList = [];
    if (rawRequests is List) {
      for (final r in rawRequests) {
        if (r != null) reqList.add(r.toString());
      }
    }

    final rawMemberDetails = row['memberDetails'];
    final List<Map<String, dynamic>> detailsList = [];
    if (rawMemberDetails is List) {
      for (final item in rawMemberDetails) {
        if (item is Map) {
          detailsList.add(Map<String, dynamic>.from(item));
        }
      }
    }

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
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ?? DateTime.now(),
      leaderName: (row['leader_name'] ?? '').toString(),
      leaderAvatar: (row['leader_avatar'] ?? '').toString(),
      members: membersList,
      memberDetails: detailsList,
      pendingJoinRequests: reqList,
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
    String? leaderName,
    String? leaderAvatar,
    List<String>? members,
    List<Map<String, dynamic>>? memberDetails,
    List<String>? pendingJoinRequests,
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
      leaderName: leaderName ?? this.leaderName,
      leaderAvatar: leaderAvatar ?? this.leaderAvatar,
      members: members ?? this.members,
      memberDetails: memberDetails ?? this.memberDetails,
      pendingJoinRequests: pendingJoinRequests ?? this.pendingJoinRequests,
    );
  }
}