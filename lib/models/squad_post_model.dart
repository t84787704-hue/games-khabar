import 'package:cloud_firestore/cloud_firestore.dart';

class SquadPost {
  final String id;
  final String userId;
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
  final bool isActive;
  final DateTime? createdAt;

  const SquadPost({
    required this.id,
    required this.userId,
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

    return SquadPost(
      id: data['id'] ?? doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'gamer',
      displayName: data['displayName'] ?? 'Squad Leader',
      userAvatar: data['userAvatar'] ?? '',
      userRank: data['userRank'] ?? 'Ace',
      game: data['game'] ?? 'BGMI',
      tierNeeded: data['tierNeeded'] ?? 'Ace+',
      kdNeeded: (data['kdNeeded'] as num?)?.toDouble() ?? 3.0,
      micOn: data['micOn'] ?? true,
      language: data['language'] ?? 'Hindi',
      mode: data['mode'] ?? 'Classic Squad',
      description: data['description'] ?? '',
      inGameUid: data['inGameUid'] ?? '',
      joinRequests: List<String>.from(data['joinRequests'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'userAvatar': userAvatar,
      'userRank': userRank,
      'game': game,
      'tierNeeded': tierNeeded,
      'kdNeeded': kdNeeded,
      'micOn': micOn,
      'language': language,
      'mode': mode,
      'description': description.trim(),
      'inGameUid': inGameUid.trim(),
      'joinRequests': joinRequests,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  SquadPost copyWith({
    String? id,
    String? userId,
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
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SquadPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
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
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
