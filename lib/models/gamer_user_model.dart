import 'package:games_khabar/services/supabase_service.dart';
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
  final String gameName;
  final String gameId;
  final String claimedRank;
  final String verifiedRank;
  final bool isVerified;
  final String screenshotUrl;
  final String status;
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
    if (rawSubmitted is DateTime) {
      submitted = rawSubmitted;
    } else if (rawSubmitted is String) {
      submitted = DateTime.tryParse(rawSubmitted);
    } else if (rawSubmitted is int) {
      submitted = DateTime.fromMillisecondsSinceEpoch(rawSubmitted);
    } else {
      try {
        submitted = (rawSubmitted as dynamic)?.toDate();
      } catch (_) {}
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
      'submittedAt':
          (submittedAt ?? DateTime.now()).toIso8601String(),
      if (rejectReason != null && rejectReason!.isNotEmpty)
        'rejectReason': rejectReason,
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
  final String verificationStatus;
  final bool isVerifiedBlue;
  final bool isBlueTickVerified;
  final String blueTickStatus;
  final bool isRankVerified;
  final String rankScreenshot;
  final String rankStatus;
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

  // ═══════════════════════════════════════════════════════════
  // PRIVACY FIELDS — Play Store ready
  // ═══════════════════════════════════════════════════════════
  final bool isRankPublic;
  final bool isUidPublic;
  final bool isCoinsPublic;
  final bool isMemberSincePublic;
  final bool isFollowingPublic;
  final bool isFollowersPublic;
  final bool isBioPublic;
  final bool isGamePublic;

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
    // Privacy defaults
    this.isRankPublic = true,
    this.isUidPublic = false,
    this.isCoinsPublic = false,
    this.isMemberSincePublic = false,
    this.isFollowingPublic = true,
    this.isFollowersPublic = true,
    this.isBioPublic = true,
    this.isGamePublic = true,
  });

  bool get isPendingVerification =>
      verificationStatus == 'pending' || blueTickStatus == 'pending';
  bool get isRejectedVerification =>
      verificationStatus == 'rejected' || blueTickStatus == 'rejected';

  bool get isRankPending => rankStatus.toLowerCase() == 'pending';
  bool get isRankApproved =>
      rankStatus.toLowerCase() == 'verified' || isRankVerified;
  bool get isRankRejected => rankStatus.toLowerCase() == 'rejected';

  bool get isOwnerUser {
    if (isOwner) return true;
    if (isAdmin) return true;
    final auth = SupabaseService.client.auth.currentUser;
    if (auth != null) {
      final authEmail = auth.email?.trim().toLowerCase() ?? '';
      if (authEmail == 'tufailm483@gmail.com' &&
          (uid.isEmpty || auth.id == uid)) {
        return true;
      }
    }
    final u = username.toLowerCase().trim();
    final d = displayName.toLowerCase().trim();
    return u == 'owner' || u == 'tufail' || u == 'tufailm483' || d == 'owner';
  }

  bool get hasBlueTick =>
      isOwnerUser ||
      ((isBlueTickVerified || isVerifiedBlue) &&
          (blueTickStatus == 'approved' || verificationStatus == 'verified'));

  bool get isVerifiedBadge => hasBlueTick;

  String get avatarUrl => photoUrl;
  String get gameName => favoriteGame.isNotEmpty ? favoriteGame : selectedGame;
  String get gamerRank => rank.isNotEmpty ? rank : selectedRank;

  String get email {
    final auth = SupabaseService.client.auth.currentUser;
    if (auth != null &&
        (uid.isEmpty || auth.id == uid) &&
        auth.email != null) {
      return auth.email!;
    }
    return '';
  }

  int get appPoints => (level * 100) + coins + (postsCount * 10);

  static String calculateAppRank(int points) => '';

  String get appRank =>
      isRankApproved ? (selectedRank.isNotEmpty ? selectedRank : rank) : '';

  String get verifiedOrAppRank {
    final verifiedGames =
        games.where((g) => g.isVerified || g.status == 'approved').toList();
    if (verifiedGames.isNotEmpty) {
      final top = verifiedGames.first;
      return top.verifiedRank.isNotEmpty ? top.verifiedRank : top.claimedRank;
    }
    return isRankApproved
        ? (selectedRank.isNotEmpty ? selectedRank : rank)
        : '';
  }

  GamerRankBadge getRankBadge() {
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

    if (!isRankApproved &&
        kdRatio <= 5.0 &&
        rankBadgeType != RankBadgeType.kdKing) {
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

    final lowerRank =
        (selectedRank.isNotEmpty ? selectedRank : rank).toLowerCase().trim();
    if (kdRatio > 5.0 ||
        rankBadgeType == RankBadgeType.kdKing ||
        lowerRank.contains('kd king') ||
        lowerRank.contains('5+')) {
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

    if (rankBadgeType == RankBadgeType.conqueror ||
        lowerRank.contains('conqueror')) {
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

    if (lowerRank.contains('crown') ||
        lowerRank.contains('master') ||
        lowerRank.contains('heroic') ||
        lowerRank.contains('legendary')) {
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
    final auth = SupabaseService.client.auth.currentUser;
    if (auth != null && (uid.isEmpty || auth.id == uid)) {
      final c = DateTime.tryParse(auth.createdAt);
      if (c != null) {
        final diff = DateTime.now().difference(c).inDays;
        if (diff > 0) return diff;
      }
    }
    if (username.toLowerCase() == 'fua' ||
        displayName.toLowerCase() == 'fua') {
      return 14;
    }
    return createdAt != null ? 1 : 0;
  }

  bool get hasAvatar => true;
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

  factory GamerUser.fromSupabase(dynamic doc) {
    if (doc == null) return GamerUser.fromMap({}, '');
    try {
      final data = (doc as dynamic).data();
      if (data is Map<String, dynamic>) {
        return GamerUser.fromMap(data, (doc as dynamic).id?.toString());
      }
    } catch (_) {}
    if (doc is Map<String, dynamic>) {
      return GamerUser.fromMap(
          doc, doc['id']?.toString() ?? doc['uid']?.toString());
    }
    return GamerUser.fromMap({}, '');
  }

  factory GamerUser.fromMap(Map<String, dynamic> data, [String? fallbackUid]) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw);
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      try {
        return (raw as dynamic)?.toDate();
      } catch (_) {}
      return null;
    }

    final DateTime? created = parseDate(data['createdAt'] ?? data['created_at']);
    final DateTime? appliedAt = parseDate(data['verificationAppliedAt'] ?? data['verification_applied_at']);
    final DateTime? bannedTimestamp = parseDate(data['bannedAt'] ?? data['banned_at']);

    final rawEmail = (data['email'] ?? '').toString().toLowerCase().trim();
    final authUser = SupabaseService.client.auth.currentUser;
    final bool isOwner = data['isOwner'] == true ||
        data['role']?.toString().toLowerCase() == 'owner' ||
        data['isAdmin'] == true ||
        rawEmail == 'tufailm483@gmail.com' ||
        (authUser != null &&
            authUser.email?.toLowerCase().trim() == 'tufailm483@gmail.com' &&
            ((fallbackUid ?? '') == authUser.id ||
                data['uid'] == authUser.id ||
                data['id'] == authUser.id));

    final rawStatus =
        data['verificationStatus']?.toString().toLowerCase().trim();
    final bool rawBlueTick = isOwner ||
        data['isBlueTickVerified'] == true ||
        data['blueTickVerified'] == true;
    final String rawBlueStatus =
        data['blueTickStatus']?.toString().toLowerCase().trim() ?? '';
    final bool hasApprovedBlueTick =
        isOwner || (rawBlueTick && (rawBlueStatus == 'approved'));
    final String status = isOwner
        ? 'verified'
        : (rawStatus != null && rawStatus.isNotEmpty
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
    final String rawRank =
        data['tier']?.toString() ?? data['rank']?.toString() ?? '';
    final String resolvedRank = rawRank.isNotEmpty ? rawRank : 'Bronze';

    final DateTime? vipPassExpires = parseDate(data['vipTournamentPassUntil']);
    final DateTime? spotlightExpires = parseDate(data['leaderboardSpotlightUntil']);

    final bool isVip = data['isVipMember'] == true ||
        (vipPassExpires != null && vipPassExpires.isAfter(DateTime.now()));

    return GamerUser(
      uid: data['uid'] ?? data['id'] ?? fallbackUid ?? '',
      username: (data['username'] != null &&
              data['username'].toString().trim().isNotEmpty)
          ? data['username'].toString().trim()
          : (data['tag']?.toString().trim() ?? ''),
      displayName:
          data['bgmiName'] ?? data['displayName'] ?? data['display_name'] ?? '',
      photoUrl: data['avatar'] ?? data['photoUrl'] ?? data['avatar_url'] ?? '',
      coverUrl: data['coverUrl'] ?? data['cover_url'] ?? '',
      bio: data['bio'] ?? '',
      favoriteGame: data['favoriteGame'] ?? data['game'] ?? 'BGMI',
      selectedGame: data['selectedGame']?.toString() ??
          data['favoriteGame']?.toString() ??
          data['game']?.toString() ??
          'BGMI',
      rank: resolvedRank,
      selectedRank: data['selectedRank']?.toString() ?? resolvedRank,
      kdRatio: (data['kd'] as num?)?.toDouble() ??
          (data['kdRatio'] as num?)?.toDouble() ??
          0.0,
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
      blueTickStatus: rawBlueStatus.isNotEmpty
          ? rawBlueStatus
          : (hasApprovedBlueTick ? 'approved' : 'none'),
      isRankVerified: rawRankVerified ||
          (data['rankStatus']?.toString().toLowerCase() == 'verified'),
      rankScreenshot: data['rankScreenshot']?.toString() ?? '',
      rankStatus: data['rankStatus']?.toString() ??
          (rawRankVerified ? 'Verified' : 'None'),
      rankVerifiedBy: data['rankVerifiedBy']?.toString() ?? '',
      rankRejectReason: data['rankRejectReason']?.toString() ?? '',
      isAdmin: data['isAdmin'] == true,
      isOwner: isOwner,
      isBanned: data['isBanned'] == true || data['is_banned'] == true,
      bannedAt: bannedTimestamp,
      bannedReason: data['bannedReason']?.toString() ??
          data['banned_reason']?.toString(),
      bannedBy: data['bannedBy']?.toString(),
      isDemoAccount: data['isDemoAccount'] == true,
      clipsCount: (data['clipsCount'] as num?)?.toInt() ?? 0,
      squadRoomsCount: (data['squadRoomsCount'] as num?)?.toInt() ?? 0,
      verificationAppliedAt: appliedAt,
      gameId: (data['bgmiUid'] ?? data['gameId'] ?? data['inGameId'] ?? '')
          .toString(),
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
      unlockedChatColors:
          List<String>.from(data['unlockedChatColors'] ?? []),
      isVipMember: isVip,
      vipTournamentPassUntil: vipPassExpires,
      leaderboardSpotlightUntil: spotlightExpires,
      // Privacy fields
      isRankPublic: data['is_rank_public'] != false,
      isUidPublic: data['is_uid_public'] == true,
      isCoinsPublic: data['is_coins_public'] == true,
      isMemberSincePublic: data['is_member_since_public'] == true,
      isFollowingPublic: data['is_following_public'] != false,
      isFollowersPublic: data['is_followers_public'] != false,
      isBioPublic: data['is_bio_public'] != false,
      isGamePublic: data['is_game_public'] != false,
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
      if (bannedAt != null) 'bannedAt': bannedAt!.toIso8601String(),
      if (bannedReason != null && bannedReason!.isNotEmpty)
        'bannedReason': bannedReason,
      if (bannedBy != null && bannedBy!.isNotEmpty) 'bannedBy': bannedBy,
      'isDemoAccount': isDemoAccount,
      'clipsCount': clipsCount,
      'squadRoomsCount': squadRoomsCount,
      'verificationAppliedAt': verificationAppliedAt?.toIso8601String(),
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
      if (vipTournamentPassUntil != null)
        'vipTournamentPassUntil': vipTournamentPassUntil!.toIso8601String(),
      if (leaderboardSpotlightUntil != null)
        'leaderboardSpotlightUntil':
            leaderboardSpotlightUntil!.toIso8601String(),
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
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      // Privacy fields
      'is_rank_public': isRankPublic,
      'is_uid_public': isUidPublic,
      'is_coins_public': isCoinsPublic,
      'is_member_since_public': isMemberSincePublic,
      'is_following_public': isFollowingPublic,
      'is_followers_public': isFollowersPublic,
      'is_bio_public': isBioPublic,
      'is_game_public': isGamePublic,
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
    bool? isRankPublic,
    bool? isUidPublic,
    bool? isCoinsPublic,
    bool? isMemberSincePublic,
    bool? isFollowingPublic,
    bool? isFollowersPublic,
    bool? isBioPublic,
    bool? isGamePublic,
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
      verificationAppliedAt:
          verificationAppliedAt ?? this.verificationAppliedAt,
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
      vipTournamentPassUntil:
          vipTournamentPassUntil ?? this.vipTournamentPassUntil,
      leaderboardSpotlightUntil:
          leaderboardSpotlightUntil ?? this.leaderboardSpotlightUntil,
      isRankPublic: isRankPublic ?? this.isRankPublic,
      isUidPublic: isUidPublic ?? this.isUidPublic,
      isCoinsPublic: isCoinsPublic ?? this.isCoinsPublic,
      isMemberSincePublic: isMemberSincePublic ?? this.isMemberSincePublic,
      isFollowingPublic: isFollowingPublic ?? this.isFollowingPublic,
      isFollowersPublic: isFollowersPublic ?? this.isFollowersPublic,
      isBioPublic: isBioPublic ?? this.isBioPublic,
      isGamePublic: isGamePublic ?? this.isGamePublic,
    );
  }
}