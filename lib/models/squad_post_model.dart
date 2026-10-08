class SquadPost {
  final String id;
  final String userId; // also accessible as ownerId
  String get ownerId => userId;
  final String ownerEmail;
  final String gameUid;
  String get inGameUid => gameUid;
  String get bgmiUidToCopy => gameUid;
  String get leaderUid => gameUid;
  String get ownerBgmiName => displayName;
  String get ownerTag => username;
  /// Title getter for backward compatibility with older chat screen versions
  String get title => displayName.isNotEmpty ? "$displayName's Squad" : (description.isNotEmpty ? description : "Squad Chat");
  final String username;
  final String displayName;
  final String userAvatar;
  final String userRank;
  final String game; // e.g. BGMI
  final String tierNeeded; // 'Any Tier', 'Diamond+', 'Crown+', 'Ace+', 'Conqueror'
  final double kdNeeded; // e.g. 2.5, 3.0, 4.0, 5.0
  final bool micOn;
  final String language; // 'Hindi', 'English', 'Telugu', 'Tamil', 'Punjabi', 'All'
  final String mode; // 'Classic Squad', 'Rank Push', 'Payload', 'TDM Tourney'
  final String description;
  final List<String> joinRequests; // userIds
  final List<String> members; // userIds in squad
  final int membersCount;
  final int requestedCount;
  final bool isActive;
  final DateTime? createdAt;

  const SquadPost({
    required this.id,
    required this.userId,
    this.ownerEmail = '',
    required this.username,
    required this.displayName,
    this.userAvatar = '',
    this.userRank = 'Ace',
    this.game = 'BGMI',
    this.tierNeeded = 'Ace+',
    this.kdNeeded = 3.0,
    this.micOn = true,
    this.language = 'Hindi',
    this.mode = 'Classic Squad',
    this.description = '',
    String? gameUid,
    String? inGameUid,
    this.joinRequests = const [],
    this.members = const [],
    this.membersCount = 1,
    this.requestedCount = 0,
    this.isActive = true,
    this.createdAt,
  }) : gameUid = gameUid ?? inGameUid ?? '';

  factory SquadPost.fromFirestore(dynamic doc) {
    if (doc == null) return SquadPost.fromMap({}, '');
    try {
      final data = (doc as dynamic).data();
      if (data is Map<String, dynamic>) {
        return SquadPost.fromMap(data, (doc as dynamic).id?.toString());
      }
    } catch (_) {}
    if (doc is Map<String, dynamic>) {
      return SquadPost.fromMap(doc, doc['id']?.toString());
    }
    return SquadPost.fromMap({}, '');
  }

  factory SquadPost.fromMap(Map<String, dynamic> data, [String? docId]) {
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
    created ??= DateTime.now();

    final ownerId = (data['hostId'] ?? data['host_id'] ?? data['ownerId'] ?? data['owner_id'] ?? data['userId'] ?? data['user_id'] ?? '').toString();
    final rawMembers = List<String>.from(data['members'] ?? []);
    final membersList = rawMembers.isNotEmpty
        ? rawMembers
        : (ownerId.isNotEmpty ? [ownerId] : <String>[]);
    final joinReqList = List<String>.from(data['joinRequests'] ?? data['join_requests'] ?? []);
    final int count = (data['memberCount'] as num?)?.toInt() ?? 
        (data['membersCount'] as num?)?.toInt() ?? 
        (data['members_count'] as num?)?.toInt() ?? 
        membersList.length;

    final resolvedUid = (data['gameUid'] ??
        data['game_uid'] ??
        data['bgmiUidToCopy'] ??
        data['bgmiUid'] ??
        data['inGameUid'] ??
        data['leaderUid'] ??
        data['gameId'] ??
        '').toString();

    return SquadPost(
      id: data['squadId'] ?? data['squad_id'] ?? data['postId'] ?? data['post_id'] ?? data['id'] ?? docId ?? '',
      userId: ownerId,
      ownerEmail: data['hostEmail'] ?? data['host_email'] ?? data['ownerEmail'] ?? data['owner_email'] ?? '',
      username: data['ownerTag'] ?? data['owner_tag'] ?? data['tag'] ?? data['username'] ?? 'gamer',
      displayName: data['ownerBgmiName'] ?? data['owner_bgmi_name'] ?? data['bgmiName'] ?? data['displayName'] ?? data['display_name'] ?? (data['title'] ?? 'Squad Leader'),
      userAvatar: data['userAvatar'] ?? data['user_avatar'] ?? data['avatar'] ?? '',
      userRank: data['tier'] ?? data['userRank'] ?? data['user_rank'] ?? 'Ace',
      game: data['game'] ?? 'BGMI',
      tierNeeded: data['tier'] ?? data['tierNeeded'] ?? data['tier_needed'] ?? 'Ace+',
      kdNeeded: (data['kd'] as num?)?.toDouble() ?? (data['kdNeeded'] as num?)?.toDouble() ?? (data['kd_needed'] as num?)?.toDouble() ?? 3.0,
      micOn: data['micMandatory'] ?? data['mic_mandatory'] ?? data['micOn'] ?? data['mic_on'] ?? true,
      language: data['lang'] ?? data['language'] ?? 'Hindi',
      mode: data['mode'] ?? 'Classic Squad',
      description: data['description'] ?? '',
      gameUid: resolvedUid,
      joinRequests: joinReqList,
      members: membersList,
      membersCount: count > 0 ? count : (membersList.isNotEmpty ? membersList.length : 1),
      requestedCount: joinReqList.length,
      isActive: data['isActive'] ?? data['is_active'] ?? true,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    final actualMembers = members.isNotEmpty ? members : (userId.isNotEmpty ? [userId] : <String>[]);
    final resolvedUid = gameUid.trim();
    final timeStr = (createdAt ?? DateTime.now()).toIso8601String();
    return {
      'squadId': id,
      'squad_id': id,
      'postId': id,
      'post_id': id,
      'id': id,
      'hostId': userId,
      'host_id': userId,
      'hostEmail': ownerEmail,
      'host_email': ownerEmail,
      'ownerId': userId,
      'owner_id': userId,
      'userId': userId,
      'user_id': userId,
      'ownerEmail': ownerEmail,
      'owner_email': ownerEmail,
      'ownerBgmiName': displayName,
      'owner_bgmi_name': displayName,
      'displayName': displayName,
      'display_name': displayName,
      'ownerTag': username,
      'owner_tag': username,
      'username': username,
      'userAvatar': userAvatar,
      'user_avatar': userAvatar,
      'avatar': userAvatar,
      'tier': tierNeeded,
      'userRank': userRank,
      'user_rank': userRank,
      'tierNeeded': tierNeeded,
      'tier_needed': tierNeeded,
      'kd': kdNeeded,
      'kdNeeded': kdNeeded,
      'kd_needed': kdNeeded,
      'micMandatory': micOn,
      'mic_mandatory': micOn,
      'micOn': micOn,
      'mic_on': micOn,
      'lang': language,
      'language': language,
      'mode': mode,
      'game': game,
      'gameUid': resolvedUid,
      'game_uid': resolvedUid,
      'leaderUid': resolvedUid,
      'leader_uid': resolvedUid,
      'bgmiUid': resolvedUid,
      'bgmi_uid': resolvedUid,
      'inGameUid': resolvedUid,
      'in_game_uid': resolvedUid,
      'bgmiUidToCopy': resolvedUid,
      'description': description.trim(),
      'joinRequests': joinRequests,
      'join_requests': joinRequests,
      'members': actualMembers,
      'memberCount': actualMembers.length,
      'membersCount': actualMembers.length,
      'members_count': actualMembers.length,
      'requestedCount': joinRequests.length,
      'requested_count': joinRequests.length,
      'isActive': isActive,
      'is_active': isActive,
      'createdAt': timeStr,
      'created_at': timeStr,
    };
  }

  SquadPost copyWith({
    String? id,
    String? userId,
    String? ownerEmail,
    String? username,
    String? displayName,
    String? userAvatar,
    String? userRank,
    String? game,
    String? tierNeeded,
    double? kdNeeded,
    bool? micOn,
    String? language,
    String? mode,
    String? description,
    String? gameUid,
    String? inGameUid,
    List<String>? joinRequests,
    List<String>? members,
    int? membersCount,
    int? requestedCount,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SquadPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      userAvatar: userAvatar ?? this.userAvatar,
      userRank: userRank ?? this.userRank,
      game: game ?? this.game,
      tierNeeded: tierNeeded ?? this.tierNeeded,
      kdNeeded: kdNeeded ?? this.kdNeeded,
      micOn: micOn ?? this.micOn,
      language: language ?? this.language,
      mode: mode ?? this.mode,
      description: description ?? this.description,
      gameUid: gameUid ?? inGameUid ?? this.gameUid,
      joinRequests: joinRequests ?? this.joinRequests,
      members: members ?? this.members,
      membersCount: membersCount ?? this.membersCount,
      requestedCount: requestedCount ?? this.requestedCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
