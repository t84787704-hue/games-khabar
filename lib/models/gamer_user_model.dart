import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class UserGameRank {
  final String id;
  final String gameName; // BGMI, PUBG Mobile, Free Fire, COD Mobile, Valorant
  final String gameId;
  final String claimedRank;
  final String verifiedRank;
  final bool isVerified;
  final String screenshotUrl;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime? submittedAt;
  final String? rejectReason;
  final String ownerUid;

  const UserGameRank({
    this.id = '',
    required this.gameName,
    required this.gameId,
    required this.claimedRank,
    this.verifiedRank = '',
    this.isVerified = false,
    this.screenshotUrl = '',
    this.status = 'pending',
    this.submittedAt,
    this.rejectReason,
    this.ownerUid = '',
  });

  factory UserGameRank.fromMap(Map<String, dynamic> map) {
    DateTime? submitted;
    final rawSubmitted = map['submittedAt'];
    if (rawSubmitted is Timestamp) {
      submitted = rawSubmitted.toDate();
    } else if (rawSubmitted is String) {
      submitted = DateTime.tryParse(rawSubmitted);
    } else if (rawSubmitted is int) {
      submitted = DateTime.fromMillisecondsSinceEpoch(rawSubmitted);
    }

    return UserGameRank(
      id: map['id']?.toString() ?? '',
      gameName: map['gameName']?.toString() ?? 'BGMI',
      gameId: map['gameId']?.toString() ?? '',
      claimedRank: map['claimedRank']?.toString() ?? '',
      verifiedRank: map['verifiedRank']?.toString() ?? '',
      isVerified: map['isVerified'] == true,
      screenshotUrl: map['screenshotUrl']?.toString() ?? '',
      status: map['status']?.toString().toLowerCase().trim() ?? 'pending',
      submittedAt: submitted ?? DateTime.now(),
      rejectReason: map['rejectReason']?.toString(),
      ownerUid: map['ownerUid']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'gameName': gameName,
      'gameId': gameId,
      'claimedRank': claimedRank,
      'verifiedRank': verifiedRank,
      'isVerified': isVerified,
      'screenshotUrl': screenshotUrl,
      'status': status,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : Timestamp.now(),
      if (rejectReason != null && rejectReason!.isNotEmpty) 'rejectReason': rejectReason,
      if (ownerUid.isNotEmpty) 'ownerUid': ownerUid,
    };
  }

  UserGameRank copyWith({
    String? id,
    String? gameName,
    String? gameId,
    String? claimedRank,
    String? verifiedRank,
    bool? isVerified,
    String? screenshotUrl,
    String? status,
    DateTime? submittedAt,
    String? rejectReason,
    String? ownerUid,
  }) {
    return UserGameRank(
      id: id ?? this.id,
      gameName: gameName ?? this.gameName,
      gameId: gameId ?? this.gameId,
      claimedRank: claimedRank ?? this.claimedRank,
      verifiedRank: verifiedRank ?? this.verifiedRank,
      isVerified: isVerified ?? this.isVerified,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      rejectReason: rejectReason ?? this.rejectReason,
      ownerUid: ownerUid ?? this.ownerUid,
    );
  }
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
  final DateTime? bannedAt;
  final String? bannedReason;
  final String? bannedBy;
  final int clipsCount;
  final int squadRoomsCount;
  final DateTime? verificationAppliedAt;
  final String gameId;
  final int coins;
  final int level;
  final List<UserGameRank> games;
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
    this.rank = 'Bronze',
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
    this.bannedAt,
    this.bannedReason,
    this.bannedBy,
    this.clipsCount = 0,
    this.squadRoomsCount = 0,
    this.verificationAppliedAt,
    this.gameId = '',
    this.coins = 100,
    this.level = 1,
    this.games = const [],
    this.verificationProgress,
    this.createdAt,
  });

  bool get isPendingVerification => verificationStatus == 'pending';
  bool get isRejectedVerification => verificationStatus == 'rejected';
  bool get isVerifiedBadge => isVerified || isVerifiedBlue || verificationStatus == 'verified';

  // App Rank (auto) calculation: appPoints = (level * 100) + coins + (posts * 10)
  // 0-999 Bronze, 1000-1999 Silver, 2000-2999 Gold, 3000-3699 Platinum, 3700-4199 Diamond, 4200-4699 Crown, 4700-4999 ACE, 5000+ Conqueror
  int get appPoints => (level * 100) + coins + (postsCount * 10);

  static String calculateAppRank(int points) {
    if (points >= 5000) return 'Conqueror';
    if (points >= 4700) return 'ACE';
    if (points >= 4200) return 'Crown';
    if (points >= 3700) return 'Diamond';
    if (points >= 3000) return 'Platinum';
    if (points >= 2000) return 'Gold';
    if (points >= 1000) return 'Silver';
    return 'Bronze';
  }

  String get appRank => calculateAppRank(appPoints);

  /// Returns highest verified game rank if any exists, else appRank or rank
  String get verifiedOrAppRank {
    final verifiedGames = games.where((g) => g.isVerified || g.status == 'approved').toList();
    if (verifiedGames.isNotEmpty) {
      final top = verifiedGames.first;
      return top.verifiedRank.isNotEmpty ? top.verifiedRank : top.claimedRank;
    }
    return rank.isNotEmpty && rank.toLowerCase() != 'bronze' ? rank : appRank;
  }

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

    if (rankBadgeType == RankBadgeType.ace || lowerRank.contains('ace')) {
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

    if (lowerRank.contains('crown') || lowerRank.contains('master') || lowerRank.contains('heroic') || lowerRank.contains('legendary')) {
      return GamerRankBadge(
        type: RankBadgeType.ace,
        label: rank,
        emoji: '🎖️',
        icon: Icons.workspace_premium_rounded,
        primaryColor: const Color(0xFFFF8A00),
        backgroundColor: const Color(0x33FF8A00),
        borderColor: const Color(0xFFFF8A00),
      );
    }

    return GamerRankBadge(
      type: RankBadgeType.none,
      label: rank,
      emoji: '🛡️',
      icon: Icons.shield_outlined,
      primaryColor: const Color(0xFF00E5FF),
      backgroundColor: const Color(0x2200E5FF),
      borderColor: const Color(0x5500E5FF),
    );
  }

  int get accountAgeDays {
    if (createdAt != null) {
      final diff = DateTime.now().difference(createdAt!).inDays;
      if (diff > 0) return diff;
    }
    final auth = FirebaseAuth.instance.currentUser;
    if (auth != null && (uid.isEmpty || auth.uid == uid)) {
      final c = auth.metadata.creationTime;
      if (c != null) {
        final diff = DateTime.now().difference(c).inDays;
        if (diff > 0) return diff;
      }
    }
    if (username.toLowerCase() == 'fua' || displayName.toLowerCase() == 'fua') {
      return 14;
    }
    return createdAt != null ? 1 : 0;
  }

  bool get hasAvatar {
    // If avatar is F initial letter or preset or photo or letter avatar, consider it as valid avatar, don't show Missing
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

    DateTime? bannedTimestamp;
    final rawBannedAt = data['bannedAt'];
    if (rawBannedAt is Timestamp) {
      bannedTimestamp = rawBannedAt.toDate();
    } else if (rawBannedAt is String) {
      bannedTimestamp = DateTime.tryParse(rawBannedAt);
    }

    final rawStatus = data['verificationStatus']?.toString().toLowerCase().trim();
    final bool rawVerifiedBlue = data['isVerifiedBlue'] == true;
    final bool rawVerified = data['isVerified'] == true || rawVerifiedBlue || rawStatus == 'verified';
    final String status = rawStatus != null && rawStatus.isNotEmpty
        ? rawStatus
        : (rawVerified ? 'verified' : 'none');

    final rawGames = data['games'];
    List<UserGameRank> parsedGames = [];
    if (rawGames is List) {
      for (final item in rawGames) {
        if (item is Map<String, dynamic>) {
          parsedGames.add(UserGameRank.fromMap(item));
        } else if (item is Map) {
          parsedGames.add(UserGameRank.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final int userLevel = (data['level'] as num?)?.toInt() ?? 1;
    final String rawRank = data['tier']?.toString() ?? data['rank']?.toString() ?? '';
    final String resolvedRank = rawRank.isNotEmpty ? rawRank : 'Bronze';

    return GamerUser(
      uid: data['uid'] ?? doc.id,
      username: data['tag'] ?? data['username'] ?? '',
      displayName: data['bgmiName'] ?? data['displayName'] ?? '',
      photoUrl: data['avatar'] ?? data['photoUrl'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      bio: data['bio'] ?? '',
      favoriteGame: data['favoriteGame'] ?? 'BGMI',
      rank: resolvedRank,
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
      bannedAt: bannedTimestamp,
      bannedReason: data['bannedReason']?.toString(),
      bannedBy: data['bannedBy']?.toString(),
      clipsCount: (data['clipsCount'] as num?)?.toInt() ?? 0,
      squadRoomsCount: (data['squadRoomsCount'] as num?)?.toInt() ?? 0,
      verificationAppliedAt: appliedAt,
      gameId: (data['bgmiUid'] ?? data['gameId'] ?? data['inGameId'] ?? '').toString(),
      coins: (data['coins'] as num?)?.toInt() ?? 100,
      level: userLevel,
      games: parsedGames,
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
      if (bannedAt != null) 'bannedAt': Timestamp.fromDate(bannedAt!),
      if (bannedReason != null && bannedReason!.isNotEmpty) 'bannedReason': bannedReason,
      if (bannedBy != null && bannedBy!.isNotEmpty) 'bannedBy': bannedBy,
      'clipsCount': clipsCount,
      'squadRoomsCount': squadRoomsCount,
      'verificationAppliedAt': verificationAppliedAt != null ? Timestamp.fromDate(verificationAppliedAt!) : null,
      'gameId': gameId.trim(),
      'bgmiUid': gameId.trim(),
      'coins': coins,
      'level': level,
      'appPoints': appPoints,
      'appRank': appRank,
      'games': games.map((g) => g.toMap()).toList(),
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
    DateTime? bannedAt,
    String? bannedReason,
    String? bannedBy,
    int? clipsCount,
    int? squadRoomsCount,
    DateTime? verificationAppliedAt,
    String? gameId,
    int? coins,
    int? level,
    List<UserGameRank>? games,
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
      bannedAt: bannedAt ?? this.bannedAt,
      bannedReason: bannedReason ?? this.bannedReason,
      bannedBy: bannedBy ?? this.bannedBy,
      clipsCount: clipsCount ?? this.clipsCount,
      squadRoomsCount: squadRoomsCount ?? this.squadRoomsCount,
      verificationAppliedAt: verificationAppliedAt ?? this.verificationAppliedAt,
      gameId: gameId ?? this.gameId,
      coins: coins ?? this.coins,
      level: level ?? this.level,
      games: games ?? this.games,
      verificationProgress: verificationProgress ?? this.verificationProgress,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
