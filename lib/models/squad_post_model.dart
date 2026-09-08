import 'package:cloud_firestore/cloud_firestore.dart';

class SquadPost {
  final String id;
  final String userId; // also accessible as ownerId
  String get ownerId => userId;
  final String ownerEmail;
  String get bgmiUidToCopy => inGameUid;
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
  final String inGameUid;
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
    this.inGameUid = '',
    this.joinRequests = const [],
    this.members = const [],
    this.membersCount = 1,
    this.requestedCount = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory SquadPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? created;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is String) {
      created = DateTime.tryParse(raw);
    }
    created ??= DateTime.now();

    final membersList = List<String>.from(data['members'] ?? []);
    final joinReqList = List<String>.from(data['joinRequests'] ?? []);

    return SquadPost(
      id: data['postId'] ?? data['id'] ?? doc.id,
      userId: data['ownerId'] ?? data['userId'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      username: data['ownerTag'] ?? data['tag'] ?? data['username'] ?? 'gamer',
      displayName: data['ownerBgmiName'] ?? data['bgmiName'] ?? data['displayName'] ?? 'Squad Leader',
      userAvatar: data['userAvatar'] ?? data['avatar'] ?? '',
      userRank: data['tier'] ?? data['userRank'] ?? 'Ace',
      game: data['game'] ?? 'BGMI',
      tierNeeded: data['tier'] ?? data['tierNeeded'] ?? 'Ace+',
      kdNeeded: (data['kd'] as num?)?.toDouble() ?? (data['kdNeeded'] as num?)?.toDouble() ?? 3.0,
      micOn: data['micMandatory'] ?? data['micOn'] ?? true,
      language: data['lang'] ?? data['language'] ?? 'Hindi',
      mode: data['mode'] ?? 'Classic Squad',
      description: data['description'] ?? '',
      inGameUid: data['bgmiUidToCopy'] ?? data['bgmiUid'] ?? data['inGameUid'] ?? '',
      joinRequests: joinReqList,
      members: membersList,
      membersCount: (data['membersCount'] as num?)?.toInt() ?? (membersList.isNotEmpty ? membersList.length : 1),
      requestedCount: ((data['requestedCount'] as num?)?.toInt() ?? joinReqList.length).clamp(0, 999),
      isActive: data['isActive'] ?? true,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': id,
      'id': id,
      'ownerId': userId,
      'userId': userId,
      'ownerEmail': ownerEmail,
      'ownerBgmiName': displayName,
      'displayName': displayName,
      'ownerTag': username,
      'username': username,
      'userAvatar': userAvatar,
      'avatar': userAvatar,
      'tier': tierNeeded,
      'userRank': userRank,
      'tierNeeded': tierNeeded,
      'kd': kdNeeded,
      'kdNeeded': kdNeeded,
      'micMandatory': micOn,
      'micOn': micOn,
      'lang': language,
      'language': language,
      'mode': mode,
      'bgmiUid': inGameUid.trim(),
      'inGameUid': inGameUid.trim(),
      'bgmiUidToCopy': inGameUid.trim(),
      'description': description.trim(),
      'joinRequests': joinRequests,
      'members': members.isNotEmpty ? members : [userId],
      'membersCount': membersCount,
      'requestedCount': requestedCount,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
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
      inGameUid: inGameUid ?? this.inGameUid,
      joinRequests: joinRequests ?? this.joinRequests,
      members: members ?? this.members,
      membersCount: membersCount ?? this.membersCount,
      requestedCount: requestedCount ?? this.requestedCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
