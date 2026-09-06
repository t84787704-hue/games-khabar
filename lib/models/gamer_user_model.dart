import 'package:cloud_firestore/cloud_firestore.dart';

class GamerUser {
  final String uid;
  final String username;
  final String displayName;
  final String photoUrl;
  final String coverUrl;
  final String bio;
  final String favoriteGame;
  final String rank;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final int likesReceived;
  final int reportsCount;
  final bool isVerified;
  final String gameId;
  final Map<String, dynamic>? verificationProgress;
  final DateTime? createdAt;

  const GamerUser({
    required this.uid,
    required this.username,
    required this.displayName,
    this.photoUrl = '',
    this.coverUrl = '',
    this.bio = '',
    this.favoriteGame = 'BGMI',
    this.rank = 'Pro Gamer',
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.likesReceived = 0,
    this.reportsCount = 0,
    this.isVerified = false,
    this.gameId = '',
    this.verificationProgress,
    this.createdAt,
  });

  int get accountAgeDays {
    if (createdAt == null) return 0;
    final diff = DateTime.now().difference(createdAt!).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get hasAvatar {
    final clean = photoUrl.trim();
    if (clean.isEmpty) return false;
    return clean.startsWith('http') || clean.startsWith('data:image');
  }

  bool get hasBio => bio.trim().isNotEmpty;

  bool get hasGameIdLinked => gameId.trim().isNotEmpty;

  bool get noReports => reportsCount == 0;

  factory GamerUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated);
    }

    return GamerUser(
      uid: data['uid'] ?? doc.id,
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      bio: data['bio'] ?? '',
      favoriteGame: data['favoriteGame'] ?? 'BGMI',
      rank: data['rank'] ?? 'Pro Gamer',
      followersCount: (data['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
      postsCount: (data['postsCount'] as num?)?.toInt() ?? 0,
      likesReceived: (data['likesReceived'] as num?)?.toInt() ?? 0,
      reportsCount: (data['reportsCount'] as num?)?.toInt() ?? 0,
      isVerified: data['isVerified'] == true,
      gameId: (data['gameId'] ?? data['inGameId'] ?? '').toString(),
      verificationProgress: data['verificationProgress'] is Map
          ? Map<String, dynamic>.from(data['verificationProgress'])
          : null,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username.toLowerCase().trim(),
      'displayName': displayName.trim(),
      'photoUrl': photoUrl,
      'coverUrl': coverUrl,
      'bio': bio.trim(),
      'favoriteGame': favoriteGame,
      'rank': rank.trim(),
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
      'likesReceived': likesReceived,
      'reportsCount': reportsCount,
      'isVerified': isVerified,
      'gameId': gameId.trim(),
      'verificationProgress': {
        'postsCount': postsCount,
        'likesReceived': likesReceived,
        'followersCount': followersCount,
        'accountAgeDays': accountAgeDays,
        'hasGameIdLinked': hasGameIdLinked,
        'hasAvatar': hasAvatar,
        'noReports': noReports,
      },
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  GamerUser copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? photoUrl,
    String? coverUrl,
    String? bio,
    String? favoriteGame,
    String? rank,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    int? likesReceived,
    int? reportsCount,
    bool? isVerified,
    String? gameId,
    Map<String, dynamic>? verificationProgress,
    DateTime? createdAt,
  }) {
    return GamerUser(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      favoriteGame: favoriteGame ?? this.favoriteGame,
      rank: rank ?? this.rank,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      likesReceived: likesReceived ?? this.likesReceived,
      reportsCount: reportsCount ?? this.reportsCount,
      isVerified: isVerified ?? this.isVerified,
      gameId: gameId ?? this.gameId,
      verificationProgress: verificationProgress ?? this.verificationProgress,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
