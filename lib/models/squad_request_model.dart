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
  final bool micOn;
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
    this.micOn = true,
    this.status = 'pending',
    this.createdAt,
  });

  factory SquadJoinRequest.fromFirestore(dynamic doc, [String? postId]) {
    if (doc == null) return SquadJoinRequest.fromMap({}, '', postId);
    try {
      final data = (doc as dynamic).data();
      if (data is Map<String, dynamic>) {
        return SquadJoinRequest.fromMap(data, (doc as dynamic).id?.toString(), postId);
      }
    } catch (_) {}
    if (doc is Map<String, dynamic>) {
      return SquadJoinRequest.fromMap(doc, doc['id']?.toString(), postId);
    }
    return SquadJoinRequest.fromMap({}, '', postId);
  }

  factory SquadJoinRequest.fromMap(Map<String, dynamic> data, [String? docId, String? postId]) {
    DateTime? created;
    final raw = data['createdAt'] ?? data['created_at'];
    if (raw is DateTime) {
      created = raw;
    } else if (raw is String) {
      created = DateTime.tryParse(raw);
    } else if (raw is int) {
      created = DateTime.fromMillisecondsSinceEpoch(raw);
    } else {
      try {
        created = (raw as dynamic)?.toDate();
      } catch (_) {}
    }

    final String resolvedId = docId ?? data['id']?.toString() ?? '';
    final String userId = data['userId']?.toString() ??
        data['user_id']?.toString() ??
        data['applicantUid']?.toString() ??
        data['applicant_uid']?.toString() ??
        resolvedId;

    final String name = data['bgmiName']?.toString() ??
        data['name']?.toString() ??
        data['applicantName']?.toString() ??
        data['displayName']?.toString() ??
        data['display_name']?.toString() ??
        'Gamer';

    final String username = data['tag']?.toString() ?? data['username']?.toString() ?? '';
    final String userAvatar = data['avatar']?.toString() ??
        data['userAvatar']?.toString() ??
        data['user_avatar']?.toString() ??
        data['photoUrl']?.toString() ??
        data['avatar_url']?.toString() ??
        '';

    final String tier = data['tier']?.toString() ??
        data['userRank']?.toString() ??
        data['user_rank']?.toString() ??
        data['rank']?.toString() ??
        'Ace';

    final double kd = (data['kd'] as num?)?.toDouble() ??
        (data['kdRatio'] as num?)?.toDouble() ??
        (data['kd_ratio'] as num?)?.toDouble() ??
        3.0;

    final String inGameUid = data['bgmiUid']?.toString() ??
        data['bgmi_uid']?.toString() ??
        data['inGameUid']?.toString() ??
        data['in_game_uid']?.toString() ??
        data['gameId']?.toString() ??
        '';

    final bool micOn = data['micMandatory'] ?? data['mic_mandatory'] ?? data['micOn'] ?? data['mic_on'] ?? data['mic'] ?? true;

    final String status = data['status']?.toString() ?? 'pending';

    return SquadJoinRequest(
      id: resolvedId,
      postId: postId ?? data['postId']?.toString() ?? data['post_id']?.toString() ?? '',
      userId: userId,
      name: name,
      username: username,
      userAvatar: userAvatar,
      tier: tier,
      kd: kd,
      inGameUid: inGameUid,
      micOn: micOn,
      status: status,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    final timeStr = (createdAt ?? DateTime.now()).toIso8601String();
    return {
      'id': id,
      'postId': postId,
      'post_id': postId,
      'userId': userId,
      'user_id': userId,
      'applicantUid': userId,
      'applicant_uid': userId,
      'name': name,
      'displayName': name,
      'display_name': name,
      'applicantName': name,
      'applicant_name': name,
      'username': username,
      'userAvatar': userAvatar,
      'user_avatar': userAvatar,
      'photoUrl': userAvatar,
      'avatar_url': userAvatar,
      'tier': tier,
      'userRank': tier,
      'user_rank': tier,
      'kd': kd,
      'kdRatio': kd,
      'kd_ratio': kd,
      'inGameUid': inGameUid,
      'in_game_uid': inGameUid,
      'gameId': inGameUid,
      'game_id': inGameUid,
      'micOn': micOn,
      'mic_on': micOn,
      'status': status,
      'createdAt': timeStr,
      'created_at': timeStr,
    };
  }
}
