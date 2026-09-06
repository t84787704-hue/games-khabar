import 'package:cloud_firestore/cloud_firestore.dart';

class GamerChallenge {
  final String id;
  final String challengerId;
  final String challengerName;
  final String challengerAvatar;
  final String challengedId;
  final String challengedName;
  final String challengedAvatar;
  final String game; // e.g. BGMI
  final String mode; // e.g. TDM 1v1 Warehouse
  final String weaponRule; // e.g. M416 Only, Sniper Only
  final String status; // 'pending', 'accepted', 'declined', 'completed'
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

  factory GamerChallenge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? created;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is String) {
      created = DateTime.tryParse(raw);
    }

    return GamerChallenge(
      id: data['id'] ?? doc.id,
      challengerId: data['challengerId'] ?? '',
      challengerName: data['challengerName'] ?? 'Challenger',
      challengerAvatar: data['challengerAvatar'] ?? '',
      challengedId: data['challengedId'] ?? '',
      challengedName: data['challengedName'] ?? 'Opponent',
      challengedAvatar: data['challengedAvatar'] ?? '',
      game: data['game'] ?? 'BGMI',
      mode: data['mode'] ?? 'TDM 1v1 Warehouse',
      weaponRule: data['weaponRule'] ?? 'M416 Only',
      status: data['status'] ?? 'pending',
      winnerId: data['winnerId'],
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'challengerId': challengerId,
      'challengerName': challengerName,
      'challengerAvatar': challengerAvatar,
      'challengedId': challengedId,
      'challengedName': challengedName,
      'challengedAvatar': challengedAvatar,
      'game': game,
      'mode': mode,
      'weaponRule': weaponRule,
      'status': status,
      'winnerId': winnerId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
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
