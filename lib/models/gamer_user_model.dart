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
  final String selectedGame;
  final String rank;
  final String selectedRank;
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
  final bool isBlueTickVerified;
  final String blueTickStatus; // 'none', 'pending', 'approved', 'rejected'
  final bool isRankVerified;
  final String rankScreenshot;
  final String rankStatus; // 'None', 'Pending', 'Verified', 'Rejected'
  final String rankVerifiedBy;
  final String rankRejectReason;
  final bool isAdmin;
  final bool isOwner;
  final bool isBanned;
  final DateTime? bannedAt;
  final String? bannedReason;
  final String? bannedBy;
  final bool isDemoAccount;
  final int clipsCount;
  final int squadRoomsCount;
  final DateTime? verificationAppliedAt;
  final String gameId;
  final int coins;
  final int level;
  final List<UserGameRank> games;
  final Map<String, dynamic>? verificationProgress;
  final DateTime? createdAt;
  final String activeFrame;
  final List<String> unlockedFrames;
  final String activeBadge;
  final List<String> unlockedBadges;
  final String chatColor;
  final List<String> unlockedChatColors;
  final bool isVipMember;
  final DateTime? vipTournamentPassUntil;
  final DateTime? leaderboardSpotlightUntil;

  const GamerUser({
    required this.uid,
    required this.username,
    required this.displayName,
    this.photoUrl = '',
    this.coverUrl = '',
    this.bio = '',
    this.favoriteGame = 'BGMI',
    this.selectedGame = '',
    this.rank = 'Bronze',
    this.selectedRank = '',
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
    this.isBlueTickVerified = false,
    this.blueTickStatus = 'none',
    this.isRankVerified = false,
    this.rankScreenshot = '',
    this.rankStatus = 'None',
    this.rankVerifiedBy = '',
    this.rankRejectReason = '',
    this.isAdmin = false,
    this.isOwner = false,
    this.isBanned = false,
    this.bannedAt,
    this.bannedReason,
    this.bannedBy,
    this.isDemoAccount = false,
    this.clipsCount = 0,
    this.squadRoomsCount = 0,
    this.verificationAppliedAt,
    this.gameId = '',
    this.coins = 100,
    this.level = 1,
    this.games = const [],
    this.verificationProgress,
    this.createdAt,
    this.activeFrame = '',
    this.unlockedFrames = const [],
    this.activeBadge = '',
    this.unlockedBadges = const [],
    this.chatColor = '#00FF66',
    this.unlockedChatColors = const [],
    this.isVipMember = false,
    this.vipTournamentPassUntil,
    this.leaderboardSpotlightUntil,
  });

  bool get isPendingVerification => verificationStatus == 'pending' || blueTickStatus == 'pending';
  bool get isRejectedVerification => verificationStatus == 'rejected' || blueTickStatus == 'rejected';

  bool get isRankPending => rankStatus.toLowerCase() == 'pending';
  bool get isRankApproved => rankStatus.toLowerCase() == 'verified' || isRankVerified;
  bool get isRankRejected => rankStatus.toLowerCase() == 'rejected';

  /// Owner verification flag: true for owner/admin or tufailm483
  bool get isOwnerUser {
    if (isOwner) return true;
    if (isAdmin) return true;
    final auth = FirebaseAuth.instance.currentUser;
    if (auth != null) {
      final authEmail = auth.email?.trim().toLowerCase() ?? '';
      if (authEmail == 'tufailm483@gmail.com' && (uid.isEmpty || auth.uid == uid)) {
        return true;
      }
    }
    final u = username.toLowerCase().trim();
    final d = displayName.toLowerCase().trim();
    return u == 'owner' || u == 'tufail' || u == 'tufailm483' || d == 'owner';
  }
  
  /// Blue tick (influencer checkmark ✓) is shown if isOwnerUser OR if approved
  bool get hasBlueTick =>
      isOwnerUser ||
      ((isBlueTickVerified || isVerifiedBlue) &&
      (blueTickStatus == 'approved' || verificationStatus == 'verified'));

  bool get isVerifiedBadge => hasBlueTick;

  String get avatarUrl => photoUrl;
  String get gameName => favoriteGame.isNotEmpty ? favoriteGame : selectedGame;
  String get gamerRank => rank.isNotEmpty ? rank : selectedRank;
  String get email {
    final auth = FirebaseAuth.instance.currentUser;
    if (auth != null && (uid.isEmpty || auth.uid == uid) && auth.email != null) {
      return auth.email!;
    }
    return '';
  }

  // App Rank (auto) calculation: removed per user directive.
  // User ranks are strictly based on user selection and Admin verification.
  int get appPoints => (level * 100) + coins + (postsCount * 10);

  static String calculateAppRank(int points) => '';

  String get appRank => isRankApproved ? (selectedRank.isNotEmpty ? selectedRank : rank) : '';

  /// Returns highest verified game rank if any exists, else verified rank
  String get verifiedOrAppRank {
    final verifiedGames = games.where((g) => g.isVerified || g.status == 'approved').toList();
    if (verifiedGames.isNotEmpty) {
      final top = verifiedGames.first;
      return top.verifiedRank.isNotEmpty ? top.verifiedRank : top.claimedRank;
    }
    return isRankApproved ? (selectedRank.isNotEmpty ? selectedRank : rank) : '';
  }

  GamerRankBadge getRankBadge() {
    // Owner doesn't show competitive game rank badges
    if (isOwnerUser) {
      return const GamerRankBadge(
        type: RankBadgeType.none,
        label: '',
        emoji: '',
        icon: Icons.shield_outlined,
        primaryColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
      );
    }

    // Only verified ranks or K/D King can show a rank badge
    if (!isRankApproved && kdRatio <= 5.0 && rankBadgeType != RankBadgeType.kdKing) {
      return const GamerRankBadge(
        type: RankBadgeType.none,
        label: '',
        emoji: '',
        icon: Icons.shield_outlined,
        primaryColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
      );
    }

    final lowerRank = (selectedRank.isNotEmpty ? selectedRank : rank).toLowerCase().trim();
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
        label: selectedRank.isNotEmpty ? selectedRank : rank,
        emoji: '🎖️',
        icon: Icons.workspace_premium_rounded,
        primaryColor: const Color(0xFFFF8A00),
        backgroundColor: const Color(0x33FF8A00),
        borderColor: const Color(0xFFFF8A00),
      );
    }

    return GamerRankBadge(
      type: isRankApproved ? RankBadgeType.none : RankBadgeType.none,
      label: selectedRank.isNotEmpty ? selectedRank : rank,
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

    final rawEmail = (data['email'] ?? '').toString().toLowerCase().trim();
    final authUser = FirebaseAuth.instance.currentUser;
    final bool isOwner = data['isOwner'] == true ||
        data['role']?.toString().toLowerCase() == 'owner' ||
        data['isAdmin'] == true ||
        rawEmail == 'tufailm483@gmail.com' ||
        (authUser != null && authUser.email?.toLowerCase().trim() == 'tufailm483@gmail.com' && (doc.id == authUser.uid || data['uid'] == authUser.uid));

    final rawStatus = data['verificationStatus']?.toString().toLowerCase().trim();
    final bool rawBlueTick = isOwner || data['isBlueTickVerified'] == true || data['blueTickVerified'] == true;
    final String rawBlueStatus = data['blueTickStatus']?.toString().toLowerCase().trim() ?? '';
    final bool hasApprovedBlueTick = isOwner || (rawBlueTick && (rawBlueStatus == 'approved'));
    final String status = isOwner ? 'verified' : (rawStatus != null && rawStatus.isNotEmpty
        ? rawStatus
        : (hasApprovedBlueTick ? 'verified' : 'none'));

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

    final bool rawRankVerified = data['isRankVerified'] == true ||
        parsedGames.any((g) => g.isVerified || g.status == 'approved');

    final int userLevel = (data['level'] as num?)?.toInt() ?? 1;
    final String rawRank = data['tier']?.toString() ?? data['rank']?.toString() ?? '';
    final String resolvedRank = rawRank.isNotEmpty ? rawRank : 'Bronze';

    DateTime? vipPassExpires;
    final rawVip = data['vipTournamentPassUntil'];
    if (rawVip is Timestamp) {
      vipPassExpires = rawVip.toDate();
    } else if (rawVip is String) {
      vipPassExpires = DateTime.tryParse(rawVip);
    }

    DateTime? spotlightExpires;
    final rawSpotlight = data['leaderboardSpotlightUntil'];
    if (rawSpotlight is Timestamp) {
      spotlightExpires = rawSpotlight.toDate();
    } else if (rawSpotlight is String) {
      spotlightExpires = DateTime.tryParse(rawSpotlight);
    }

    final bool isVip = data['isVipMember'] == true ||
        (vipPassExpires != null && vipPassExpires.isAfter(DateTime.now()));

    return GamerUser(
      uid: data['uid'] ?? doc.id,
      username: data['tag'] ?? data['username'] ?? '',
      displayName: data['bgmiName'] ?? data['displayName'] ?? '',
      photoUrl: data['avatar'] ?? data['photoUrl'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      bio: data['bio'] ?? '',
      favoriteGame: data['favoriteGame'] ?? 'BGMI',
      selectedGame: data['selectedGame']?.toString() ?? data['favoriteGame']?.toString() ?? 'BGMI',
      rank: resolvedRank,
      selectedRank: data['selectedRank']?.toString() ?? resolvedRank,
      kdRatio: (data['kd'] as num?)?.toDouble() ?? (data['kdRatio'] as num?)?.toDouble() ?? 0.0,
      rankBadgeType: _parseRankBadgeType(data['rankBadgeType']?.toString()),
      followersCount: (data['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
      postsCount: (data['postsCount'] as num?)?.toInt() ?? 0,
      likesReceived: (data['likesReceived'] as num?)?.toInt() ?? 0,
      reportsCount: (data['reportsCount'] as num?)?.toInt() ?? 0,
      isVerified: hasApprovedBlueTick,
      verificationStatus: status,
      isVerifiedBlue: hasApprovedBlueTick,
      isBlueTickVerified: rawBlueTick,
      blueTickStatus: rawBlueStatus.isNotEmpty ? rawBlueStatus : (hasApprovedBlueTick ? 'approved' : 'none'),
      isRankVerified: rawRankVerified || (data['rankStatus']?.toString().toLowerCase() == 'verified'),
      rankScreenshot: data['rankScreenshot']?.toString() ?? '',
      rankStatus: data['rankStatus']?.toString() ?? (rawRankVerified ? 'Verified' : 'None'),
      rankVerifiedBy: data['rankVerifiedBy']?.toString() ?? '',
      rankRejectReason: data['rankRejectReason']?.toString() ?? '',
      isAdmin: data['isAdmin'] == true,
      isOwner: isOwner,
      isBanned: data['isBanned'] == true,
      bannedAt: bannedTimestamp,
      bannedReason: data['bannedReason']?.toString(),
      bannedBy: data['bannedBy']?.toString(),
      isDemoAccount: data['isDemoAccount'] == true,
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
      activeFrame: data['activeFrame']?.toString() ?? '',
      unlockedFrames: List<String>.from(data['unlockedFrames'] ?? []),
      activeBadge: data['activeBadge']?.toString() ?? '',
      unlockedBadges: List<String>.from(data['unlockedBadges'] ?? []),
      chatColor: data['chatColor']?.toString() ?? '#00FF66',
      unlockedChatColors: List<String>.from(data['unlockedChatColors'] ?? []),
      isVipMember: isVip,
      vipTournamentPassUntil: vipPassExpires,
      leaderboardSpotlightUntil: spotlightExpires,
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
      'selectedGame': selectedGame.isNotEmpty ? selectedGame : favoriteGame,
      'rank': rank.trim(),
      'selectedRank': selectedRank.isNotEmpty ? selectedRank : rank.trim(),
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
      'isBlueTickVerified': isBlueTickVerified,
      'blueTickVerified': isBlueTickVerified,
      'blueTickStatus': blueTickStatus,
      'isRankVerified': isRankApproved,
      'rankScreenshot': rankScreenshot,
      'rankStatus': rankStatus,
      'rankVerifiedBy': rankVerifiedBy,
      'rankRejectReason': rankRejectReason,
      'isAdmin': isAdmin,
      'isOwner': isOwner || isOwnerUser,
      'isBanned': isBanned,
      if (bannedAt != null) 'bannedAt': Timestamp.fromDate(bannedAt!),
      if (bannedReason != null && bannedReason!.isNotEmpty) 'bannedReason': bannedReason,
      if (bannedBy != null && bannedBy!.isNotEmpty) 'bannedBy': bannedBy,
      'isDemoAccount': isDemoAccount,
      'clipsCount': clipsCount,
      'squadRoomsCount': squadRoomsCount,
      'verificationAppliedAt': verificationAppliedAt != null ? Timestamp.fromDate(verificationAppliedAt!) : null,
      'gameId': gameId.trim(),
      'bgmiUid': gameId.trim(),
      'coins': coins,
      'level': level,
      'appPoints': appPoints,
      'appRank': appRank,
      'activeFrame': activeFrame,
      'unlockedFrames': unlockedFrames,
      'activeBadge': activeBadge,
      'unlockedBadges': unlockedBadges,
      'chatColor': chatColor,
      'unlockedChatColors': unlockedChatColors,
      'isVipMember': isVipMember,
      if (vipTournamentPassUntil != null) 'vipTournamentPassUntil': Timestamp.fromDate(vipTournamentPassUntil!),
      if (leaderboardSpotlightUntil != null) 'leaderboardSpotlightUntil': Timestamp.fromDate(leaderboardSpotlightUntil!),
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
    String? selectedGame,
    String? rank,
    String? selectedRank,
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
    bool? isBlueTickVerified,
    String? blueTickStatus,
    bool? isRankVerified,
    String? rankScreenshot,
    String? rankStatus,
    String? rankVerifiedBy,
    String? rankRejectReason,
    bool? isAdmin,
    bool? isOwner,
    bool? isBanned,
    DateTime? bannedAt,
    String? bannedReason,
    String? bannedBy,
    bool? isDemoAccount,
    int? clipsCount,
    int? squadRoomsCount,
    DateTime? verificationAppliedAt,
    String? gameId,
    int? coins,
    int? level,
    List<UserGameRank>? games,
    Map<String, dynamic>? verificationProgress,
    DateTime? createdAt,
    String? activeFrame,
    List<String>? unlockedFrames,
    String? activeBadge,
    List<String>? unlockedBadges,
    String? chatColor,
    List<String>? unlockedChatColors,
    bool? isVipMember,
    DateTime? vipTournamentPassUntil,
    DateTime? leaderboardSpotlightUntil,
  }) {
    return GamerUser(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      favoriteGame: favoriteGame ?? this.favoriteGame,
      selectedGame: selectedGame ?? this.selectedGame,
      rank: rank ?? this.rank,
      selectedRank: selectedRank ?? this.selectedRank,
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
      isBlueTickVerified: isBlueTickVerified ?? this.isBlueTickVerified,
      blueTickStatus: blueTickStatus ?? this.blueTickStatus,
      isRankVerified: isRankVerified ?? this.isRankVerified,
      rankScreenshot: rankScreenshot ?? this.rankScreenshot,
      rankStatus: rankStatus ?? this.rankStatus,
      rankVerifiedBy: rankVerifiedBy ?? this.rankVerifiedBy,
      rankRejectReason: rankRejectReason ?? this.rankRejectReason,
      isAdmin: isAdmin ?? this.isAdmin,
      isOwner: isOwner ?? this.isOwner,
      isBanned: isBanned ?? this.isBanned,
      bannedAt: bannedAt ?? this.bannedAt,
      bannedReason: bannedReason ?? this.bannedReason,
      bannedBy: bannedBy ?? this.bannedBy,
      isDemoAccount: isDemoAccount ?? this.isDemoAccount,
      clipsCount: clipsCount ?? this.clipsCount,
      squadRoomsCount: squadRoomsCount ?? this.squadRoomsCount,
      verificationAppliedAt: verificationAppliedAt ?? this.verificationAppliedAt,
      gameId: gameId ?? this.gameId,
      coins: coins ?? this.coins,
      level: level ?? this.level,
      games: games ?? this.games,
      verificationProgress: verificationProgress ?? this.verificationProgress,
      createdAt: createdAt ?? this.createdAt,
      activeFrame: activeFrame ?? this.activeFrame,
      unlockedFrames: unlockedFrames ?? this.unlockedFrames,
      activeBadge: activeBadge ?? this.activeBadge,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      chatColor: chatColor ?? this.chatColor,
      unlockedChatColors: unlockedChatColors ?? this.unlockedChatColors,
      isVipMember: isVipMember ?? this.isVipMember,
      vipTournamentPassUntil: vipTournamentPassUntil ?? this.vipTournamentPassUntil,
      leaderboardSpotlightUntil: leaderboardSpotlightUntil ?? this.leaderboardSpotlightUntil,
    );
  }
}
