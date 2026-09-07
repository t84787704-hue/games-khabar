import 'package:cloud_firestore/cloud_firestore.dart';

class SquadJoinRequest {
  final String id;
  final String postId;
  final String userId;
  final String name;
  final String username;
  final String userAvatar;
  final String tier;
  final double kd;
  final String inGameUid;
  final String status;
  final DateTime? createdAt;

  const SquadJoinRequest({
    required this.id,
    this.postId = '',
    required this.userId,
    required this.name,
    this.username = '',
    this.userAvatar = '',
    this.tier = 'Ace',
    this.kd = 3.0,
    this.inGameUid = '',
    this.status = 'pending',
    this.createdAt,
  });

  factory SquadJoinRequest.fromFirestore(DocumentSnapshot doc, [String? postId]) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? created;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is String) {
      created = DateTime.tryParse(raw);
    }

    final String userId = data['userId']?.toString() ??
        data['applicantUid']?.toString() ??
        doc.id;

    final String name = data['name']?.toString() ??
        data['applicantName']?.toString() ??
        data['displayName']?.toString() ??
        'Gamer';

    final String username = data['username']?.toString() ?? '';
    final String userAvatar = data['userAvatar']?.toString() ??
        data['photoUrl']?.toString() ??
        '';

    final String tier = data['tier']?.toString() ??
        data['userRank']?.toString() ??
        data['rank']?.toString() ??
        'Ace';

    final double kd = (data['kd'] as num?)?.toDouble() ??
        (data['kdRatio'] as num?)?.toDouble() ??
        3.0;

    final String inGameUid = data['inGameUid']?.toString() ??
        data['gameId']?.toString() ??
        '';

    final String status = data['status']?.toString() ?? 'pending';

    return SquadJoinRequest(
      id: doc.id,
      postId: postId ?? data['postId']?.toString() ?? '',
      userId: userId,
      name: name,
      username: username,
      userAvatar: userAvatar,
      tier: tier,
      kd: kd,
      inGameUid: inGameUid,
      status: status,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'applicantUid': userId,
      'name': name,
      'displayName': name,
      'applicantName': name,
      'username': username,
      'userAvatar': userAvatar,
      'photoUrl': userAvatar,
      'tier': tier,
      'userRank': tier,
      'kd': kd,
      'kdRatio': kd,
      'inGameUid': inGameUid,
      'gameId': inGameUid,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
