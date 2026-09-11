import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum RankBadgeType {
  none,
  ace,
  conqueror,
  kdKing,
}

class GamerRankBadge {
  final RankBadgeType type;
  final String label;
  final String emoji;
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;

  const GamerRankBadge({
    required this.type,
    required this.label,
    required this.emoji,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  bool get isVisible => type != RankBadgeType.none;
}

class GamerUser {
  final String uid;
  final String username;
  final String displayName;
  final String photoUrl;
  final String coverUrl;
  final String bio;
  final String favoriteGame;
  final String rank;
  final double kdRatio;
  final RankBadgeType rankBadgeType;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final int likesReceived;
  final int reportsCount;
  final bool isVerified;
  final String verificationStatus; // 'none', 'pending', 'verified', 'rejected'
  final bool isVerifiedBlue;
  final bool isAdmin;
  final bool isBanned;
  final int clipsCount;
  final int squadRoomsCount;
  final DateTime? verificationAppliedAt;
  final String gameId;
  final int coins;
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
    this.rank = 'Ace',
    this.kdRatio = 0.0,
    this.rankBadgeType = RankBadgeType.none,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.likesReceived = 0,
    this.reportsCount = 0,
    this.isVerified = false,
    this.verificationStatus = 'none',
    this.isVerifiedBlue = false,
    this.isAdmin = false,
    this.isBanned = false,
    this.clipsCount = 0,
    this.squadRoomsCount = 0,
    this.verificationAppliedAt,
    this.gameId = '',
    this.coins = 100,
    this.verificationProgress,
    this.createdAt,
  });

  bool get isPendingVerification => verificationStatus == 'pending';
  bool get isRejectedVerification => verificationStatus == 'rejected';
  bool get isVerifiedBadge => isVerified || isVerifiedBlue || verificationStatus == 'verified';

  GamerRankBadge getRankBadge() {
    final lowerRank = rank.toLowerCase().trim();
    if (kdRatio > 5.0 || rankBadgeType == RankBadgeType.kdKing || lowerRank.contains('kd king') || lowerRank.contains('5+')) {
      return const GamerRankBadge(
        type: RankBadgeType.kdKing,
        label: 'K/D King',
        emoji: '💀',
        icon: Icons.dangerous_rounded,
        primaryColor: Color(0xFFFF2D55),
        backgroundColor: Color(0x33FF2D55),
        borderColor: Color(0x88FF2D55),
      );
    }

    if (rankBadgeType == RankBadgeType.conqueror || lowerRank.contains('conqueror')) {
      return const GamerRankBadge(
        type: RankBadgeType.conqueror,
        label: 'Conqueror',
        emoji: '👑',
        icon: Icons.military_tech_rounded,
        primaryColor: Color(0xFFFF334B),
        backgroundColor: Color(0x33FF334B),
        borderColor: Color(0x99FF334B),
      );
    }

    if (rankBadgeType == RankBadgeType.ace || lowerRank.contains('ace') || lowerRank.contains('pro')) {
      return const GamerRankBadge(
        type: RankBadgeType.ace,
        label: 'Ace',
        emoji: '⭐',
        icon: Icons.star_rounded,
        primaryColor: Color(0xFFFF9500),
        backgroundColor: Color(0x33FF9500),
        borderColor: Color(0x88FF9500),
      );
    }

    return const GamerRankBadge(
      type: RankBadgeType.none,
      label: '',
      emoji: '',
      icon: Icons.shield,
      primaryColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
    );
  }

  int get accountAgeDays {
    if (createdAt == null) return 0;
    final diff = DateTime.now().difference(createdAt!).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get hasAvatar {
    // If avatar is F initial letter or preset or photo, consider it as valid avatar
    final clean = photoUrl.trim();
    if (clean.isEmpty || clean.toUpperCase() == 'F' || clean.startsWith('preset:')) {
      return true;
    }
    return true;
  }

  bool get hasBio => bio.trim().isNotEmpty;

  bool get hasGameIdLinked => gameId.trim().isNotEmpty;

  bool get noReports => reportsCount == 0;

  static RankBadgeType _parseRankBadgeType(String? val) {
    if (val == null) return RankBadgeType.none;
    switch (val.toLowerCase()) {
      case 'ace':
        return RankBadgeType.ace;
      case 'conqueror':
        return RankBadgeType.conqueror;
      case 'kdking':
      case 'kd_king':
        return RankBadgeType.kdKing;
      default:
        return RankBadgeType.none;
    }
  }

  factory GamerUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated);
    }

    DateTime? appliedAt;
    final rawApplied = data['verificationAppliedAt'];
    if (rawApplied is Timestamp) {
      appliedAt = rawApplied.toDate();
    } else if (rawApplied is String) {
      appliedAt = DateTime.tryParse(rawApplied);
    }

    final rawStatus = data['verificationStatus']?.toString().toLowerCase().trim();
    final bool rawVerifiedBlue = data['isVerifiedBlue'] == true;
    final bool rawVerified = data['isVerified'] == true || rawVerifiedBlue || rawStatus == 'verified';
    final String status = rawStatus != null && rawStatus.isNotEmpty
        ? rawStatus
        : (rawVerified ? 'verified' : 'none');

    return GamerUser(
      uid: data['uid'] ?? doc.id,
      username: data['tag'] ?? data['username'] ?? '',
      displayName: data['bgmiName'] ?? data['displayName'] ?? '',
      photoUrl: data['avatar'] ?? data['photoUrl'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      bio: data['bio'] ?? '',
      favoriteGame: data['favoriteGame'] ?? 'BGMI',
      rank: data['tier'] ?? data['rank'] ?? 'Ace',
      kdRatio: (data['kd'] as num?)?.toDouble() ?? (data['kdRatio'] as num?)?.toDouble() ?? 0.0,
      rankBadgeType: _parseRankBadgeType(data['rankBadgeType']?.toString()),
      followersCount: (data['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
      postsCount: (data['postsCount'] as num?)?.toInt() ?? 0,
      likesReceived: (data['likesReceived'] as num?)?.toInt() ?? 0,
      reportsCount: (data['reportsCount'] as num?)?.toInt() ?? 0,
      isVerified: rawVerified,
      verificationStatus: status,
      isVerifiedBlue: rawVerifiedBlue || rawVerified,
      isAdmin: data['isAdmin'] == true,
      isBanned: data['isBanned'] == true,
      clipsCount: (data['clipsCount'] as num?)?.toInt() ?? 0,
      squadRoomsCount: (data['squadRoomsCount'] as num?)?.toInt() ?? 0,
      verificationAppliedAt: appliedAt,
      gameId: (data['bgmiUid'] ?? data['gameId'] ?? data['inGameId'] ?? '').toString(),
      coins: (data['coins'] as num?)?.toInt() ?? 100,
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
      'tag': username.toLowerCase().trim(),
      'displayName': displayName.trim(),
      'bgmiName': displayName.trim(),
      'photoUrl': photoUrl,
      'avatar': photoUrl,
      'coverUrl': coverUrl,
      'bio': bio.trim(),
      'favoriteGame': favoriteGame,
      'rank': rank.trim(),
      'tier': rank.trim(),
      'kdRatio': kdRatio,
      'kd': kdRatio,
      'rankBadgeType': rankBadgeType.name,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
      'likesReceived': likesReceived,
      'reportsCount': reportsCount,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'isVerifiedBlue': isVerifiedBlue,
      'isAdmin': isAdmin,
      'isBanned': isBanned,
      'clipsCount': clipsCount,
      'squadRoomsCount': squadRoomsCount,
      'verificationAppliedAt': verificationAppliedAt != null ? Timestamp.fromDate(verificationAppliedAt!) : null,
      'gameId': gameId.trim(),
      'bgmiUid': gameId.trim(),
      'coins': coins,
      'verificationProgress': {
        'postsCount': postsCount,
        'likesReceived': likesReceived,
        'followersCount': followersCount,
        'accountAgeDays': accountAgeDays,
        'hasGameIdLinked': hasGameIdLinked,
        'hasAvatar': hasAvatar,
        'noReports': noReports,
        'clipsCount': clipsCount,
        'squadRoomsCount': squadRoomsCount,
        'verificationStatus': verificationStatus,
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
    double? kdRatio,
    RankBadgeType? rankBadgeType,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    int? likesReceived,
    int? reportsCount,
    bool? isVerified,
    String? verificationStatus,
    bool? isVerifiedBlue,
    bool? isAdmin,
    bool? isBanned,
    int? clipsCount,
    int? squadRoomsCount,
    DateTime? verificationAppliedAt,
    String? gameId,
    int? coins,
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
      kdRatio: kdRatio ?? this.kdRatio,
      rankBadgeType: rankBadgeType ?? this.rankBadgeType,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      likesReceived: likesReceived ?? this.likesReceived,
      reportsCount: reportsCount ?? this.reportsCount,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isVerifiedBlue: isVerifiedBlue ?? this.isVerifiedBlue,
      isAdmin: isAdmin ?? this.isAdmin,
      isBanned: isBanned ?? this.isBanned,
      clipsCount: clipsCount ?? this.clipsCount,
      squadRoomsCount: squadRoomsCount ?? this.squadRoomsCount,
      verificationAppliedAt: verificationAppliedAt ?? this.verificationAppliedAt,
      gameId: gameId ?? this.gameId,
      coins: coins ?? this.coins,
      verificationProgress: verificationProgress ?? this.verificationProgress,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
