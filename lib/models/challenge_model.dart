class GamerChallenge {
  final String id;
  final String challengerId;
  final String challengerName;
  final String challengerAvatar;
  final String challengedId;
  final String challengedName;
  final String challengedAvatar;
  final String game;
  final String mode;
  final String weaponRule;
  final String status;
  final String? winnerId;
  final DateTime? createdAt;

  const GamerChallenge({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    this.challengerAvatar = '',
    required this.challengedId,
    required this.challengedName,
    this.challengedAvatar = '',
    this.game = 'BGMI',
    this.mode = 'TDM 1v1 Warehouse',
    this.weaponRule = 'M416 Only',
    this.status = 'pending',
    this.winnerId,
    this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';

  factory GamerChallenge.fromSupabase(Map<String, dynamic> row) {
    DateTime? created;
    final raw = row['created_at'];
    if (raw is String) {
      created = DateTime.tryParse(raw);
    } else if (raw is DateTime) {
      created = raw;
    }

    return GamerChallenge(
      id: (row['id'] ?? '').toString(),
      challengerId: (row['challenger_id'] ?? '').toString(),
      challengerName: (row['challenger_name'] ?? 'Challenger').toString(),
      challengerAvatar: (row['challenger_avatar'] ?? '').toString(),
      challengedId: (row['challenged_id'] ?? '').toString(),
      challengedName: (row['challenged_name'] ?? 'Opponent').toString(),
      challengedAvatar: (row['challenged_avatar'] ?? '').toString(),
      game: (row['game'] ?? 'BGMI').toString(),
      mode: (row['mode'] ?? 'TDM 1v1 Warehouse').toString(),
      weaponRule: (row['weapon_rule'] ?? 'M416 Only').toString(),
      status: (row['status'] ?? 'pending').toString(),
      winnerId: row['winner_id']?.toString(),
      createdAt: created,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'challenger_id': challengerId,
      'challenger_name': challengerName,
      'challenger_avatar': challengerAvatar,
      'challenged_id': challengedId,
      'challenged_name': challengedName,
      'challenged_avatar': challengedAvatar,
      'game': game,
      'mode': mode,
      'weapon_rule': weaponRule,
      'status': status,
      'winner_id': winnerId,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  GamerChallenge copyWith({
    String? id,
    String? challengerId,
    String? challengerName,
    String? challengerAvatar,
    String? challengedId,
    String? challengedName,
    String? challengedAvatar,
    String? game,
    String? mode,
    String? weaponRule,
    String? status,
    String? winnerId,
    DateTime? createdAt,
  }) {
    return GamerChallenge(
      id: id ?? this.id,
      challengerId: challengerId ?? this.challengerId,
      challengerName: challengerName ?? this.challengerName,
      challengerAvatar: challengerAvatar ?? this.challengerAvatar,
      challengedId: challengedId ?? this.challengedId,
      challengedName: challengedName ?? this.challengedName,
      challengedAvatar: challengedAvatar ?? this.challengedAvatar,
      game: game ?? this.game,
      mode: mode ?? this.mode,
      weaponRule: weaponRule ?? this.weaponRule,
      status: status ?? this.status,
      winnerId: winnerId ?? this.winnerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}