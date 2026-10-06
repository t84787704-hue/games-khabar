import 'dart:math';
import 'package:flutter/material.dart';
import '../models/gamer_user_model.dart';
import 'supabase_service.dart';

class VerificationRequirementItem {
  final int id;
  final String title;
  final String description;
  final String currentFormatted;
  final String targetFormatted;
  final double progress;
  final bool isMet;
  final String? missingReason;
  final IconData icon;

  const VerificationRequirementItem({
    required this.id,
    required this.title,
    required this.description,
    required this.currentFormatted,
    required this.targetFormatted,
    required this.progress,
    required this.isMet,
    this.missingReason,
    required this.icon,
  });
}

class VerificationApplicationResult {
  final bool success;
  final String status;
  final bool isVerified;
  final String message;
  final List<String> missingRequirements;

  const VerificationApplicationResult({
    required this.success,
    required this.status,
    required this.isVerified,
    required this.message,
    this.missingRequirements = const [],
  });
}

class VerificationStats {
  final int clipsCount;
  final int squadRoomsCount;
  final int likesReceived;
  final int reportsCount;
  final int accountAgeDays;
  final bool isProfileComplete;
  final bool isGameIdLinked;
  final bool isRankEligible;
  final bool isKdEligible;

  const VerificationStats({
    required this.clipsCount,
    required this.squadRoomsCount,
    required this.likesReceived,
    required this.reportsCount,
    required this.accountAgeDays,
    required this.isProfileComplete,
    required this.isGameIdLinked,
    required this.isRankEligible,
    required this.isKdEligible,
  });
}

class VerificationProgress {
  final bool isVerified;
  final bool hasAvatar;
  final bool hasBio;
  final bool hasGameIdLinked;
  final String gameId;
  final int postsCount;
  final int likesReceived;
  final int followersCount;
  final int accountAgeDays;
  final bool noReports;
  final int reportsCount;

  const VerificationProgress({
    required this.isVerified,
    required this.hasAvatar,
    required this.hasBio,
    required this.hasGameIdLinked,
    required this.gameId,
    required this.postsCount,
    required this.likesReceived,
    required this.followersCount,
    required this.accountAgeDays,
    required this.noReports,
    this.reportsCount = 0,
  });

  bool get meetsProfileComplete => hasAvatar && hasBio;
  bool get meetsGameId => hasGameIdLinked && gameId.trim().isNotEmpty;
  bool get meetsPosts => postsCount >= 3;
  bool get meetsLikes => likesReceived >= 500;
  bool get meetsAccountAge => accountAgeDays >= 7;
  bool get meetsCleanRecord => noReports && reportsCount == 0;

  int get completedRequirementsCount {
    int count = 0;
    if (meetsProfileComplete && meetsGameId) count++;
    if (meetsPosts) count++;
    if (meetsLikes) count++;
    if (meetsAccountAge && meetsCleanRecord) count++;
    return count;
  }

  int get totalRequirementsCount => 6;

  double get progressFraction {
    if (isVerified) return 1.0;
    return (completedRequirementsCount / totalRequirementsCount)
        .clamp(0.0, 1.0);
  }

  bool get isFullyEligible =>
      meetsProfileComplete &&
      meetsGameId &&
      meetsPosts &&
      meetsLikes &&
      meetsAccountAge &&
      meetsCleanRecord;

  Map<String, dynamic> toMap() {
    return {
      'postsCount': postsCount,
      'likesReceived': likesReceived,
      'followersCount': followersCount,
      'accountAgeDays': accountAgeDays,
      'hasGameIdLinked': hasGameIdLinked,
      'hasAvatar': hasAvatar,
      'hasBio': hasBio,
      'noReports': noReports,
      'reportsCount': reportsCount,
      'gameId': gameId,
    };
  }
}

class VerificationService {
  static final Map<String, bool> _verifiedCache = {};

  static bool isVerifiedCached(String userId) {
    return _verifiedCache[userId] ?? false;
  }

  static void setCache(String userId, bool isVerified) {
    _verifiedCache[userId] = isVerified;
  }

  static Future<bool> isUserVerified(String userId) async {
    if (userId.isEmpty) return false;
    if (_verifiedCache.containsKey(userId)) {
      return _verifiedCache[userId]!;
    }
    try {
      final uuid = SupabaseService.toUuid(userId);
      final row = await SupabaseService.client
          .from('users')
          .select('is_verified, blue_tick_status')
          .eq('id', uuid)
          .maybeSingle();

      if (row == null) {
        _verifiedCache[userId] = false;
        return false;
      }

      final isVerified = row['is_verified'] == true &&
          (row['blue_tick_status']?.toString().toLowerCase() ?? '') ==
              'approved';
      _verifiedCache[userId] = isVerified;
      return isVerified;
    } catch (e) {
      debugPrint('Error fetching verification for $userId: $e');
      return false;
    }
  }

  static bool isRankEligible(String rank, {String? game}) {
    final r = rank.toLowerCase().trim();
    if (r.isEmpty) return false;

    if (r == 'unranked' ||
        r == 'none' ||
        r == 'skip' ||
        r.contains('bronze') ||
        r.contains('silver') ||
        r.contains('gold') ||
        r.contains('rookie') ||
        r.contains('iron')) {
      return false;
    }

    return r.contains('crown') ||
        r.contains('ace') ||
        r.contains('conqueror') ||
        r.contains('dominator') ||
        r.contains('heroic') ||
        r.contains('grandmaster') ||
        r.contains('legendary') ||
        r.contains('radiant') ||
        r.contains('immortal') ||
        r.contains('ascendant') ||
        r.contains('champion') ||
        r.contains('unreal') ||
        r.contains('predator') ||
        r.contains('mythic') ||
        r.contains('mythical') ||
        r.contains('elite') ||
        r.contains('master') ||
        r.contains('th 1') ||
        r.contains('division 1');
  }

  static bool isProfileAndUidComplete(GamerUser user) {
    final hasBio = user.bio.trim().isNotEmpty;
    final hasName = user.displayName.trim().isNotEmpty;
    final hasUid = user.gameId.trim().isNotEmpty;
    return hasBio && hasName && hasUid;
  }

  static List<VerificationRequirementItem> getRequirements(
    GamerUser user, {
    int? clipsCount,
    int? squadRoomsCount,
    int? likesReceived,
    int? reportsCount,
    int? accountAgeDays,
  }) {
    if (user.isOwnerUser) {
      return const [
        VerificationRequirementItem(
          id: 1,
          title: 'Profile 100% Complete & Game UID',
          description: 'Set avatar, bio, and link Game UID.',
          currentFormatted: 'Verified Owner',
          targetFormatted: 'Completed',
          progress: 1.0,
          isMet: true,
          icon: Icons.account_box_rounded,
        ),
        VerificationRequirementItem(
          id: 2,
          title: 'Top Tier Rank',
          description: 'Top competitive tier.',
          currentFormatted: 'Owner Privileges',
          targetFormatted: 'Completed',
          progress: 1.0,
          isMet: true,
          icon: Icons.military_tech_rounded,
        ),
        VerificationRequirementItem(
          id: 3,
          title: 'Game Stats (Optional)',
          description: 'Competitive performance stats.',
          currentFormatted: 'Exempt',
          targetFormatted: 'Optional',
          progress: 1.0,
          isMet: true,
          icon: Icons.speed_rounded,
        ),
        VerificationRequirementItem(
          id: 4,
          title: '3 Posts + 2 Squad/Rooms',
          description: 'Active community creator.',
          currentFormatted: 'Completed',
          targetFormatted: 'Completed',
          progress: 1.0,
          isMet: true,
          icon: Icons.dynamic_feed_rounded,
        ),
        VerificationRequirementItem(
          id: 5,
          title: '500+ Total Likes',
          description: 'Community appreciation.',
          currentFormatted: 'Completed',
          targetFormatted: 'Completed',
          progress: 1.0,
          isMet: true,
          icon: Icons.favorite_rounded,
        ),
        VerificationRequirementItem(
          id: 6,
          title: 'Account 7+ Days & 0 Reports',
          description: 'Clean standing.',
          currentFormatted: 'Clean',
          targetFormatted: 'Completed',
          progress: 1.0,
          isMet: true,
          icon: Icons.verified_user_rounded,
        ),
      ];
    }

    final int clips = clipsCount ?? user.clipsCount;
    final int squadRooms = squadRoomsCount ?? user.squadRoomsCount;
    final int likes = likesReceived ?? user.likesReceived;
    final int reports = reportsCount ?? user.reportsCount;

    int ageDays = accountAgeDays ?? user.accountAgeDays;
    if (ageDays <= 0) {
      final DateTime? created = user.createdAt;
      if (created != null) {
        final diff = DateTime.now().difference(created).inDays;
        ageDays = diff > 0 ? diff : 1;
      }
    }

    final List<VerificationRequirementItem> items = [];
    final activeGame = user.selectedGame.isNotEmpty
        ? user.selectedGame
        : (user.favoriteGame.isNotEmpty ? user.favoriteGame : 'Game');

    final bool hasBio = user.bio.trim().isNotEmpty;
    final bool hasName = user.displayName.trim().isNotEmpty;
    final bool hasUid = user.gameId.trim().isNotEmpty;

    int profileScore = 1;
    if (hasBio) profileScore++;
    if (hasName) profileScore++;
    if (hasUid) profileScore++;
    final double req1Progress = (profileScore / 4.0).clamp(0.0, 1.0);
    final bool req1Met = hasBio && hasName && hasUid;

    items.add(
      VerificationRequirementItem(
        id: 1,
        title: 'Profile 100% Complete & Game UID',
        description:
            'Set your avatar, bio, and link your Game Character UID.',
        currentFormatted: req1Met
            ? '100% Complete ($activeGame UID: ${user.gameId})'
            : '${(req1Progress * 100).toInt()}% Complete',
        targetFormatted: '100% + Linked Game UID',
        progress: req1Progress,
        isMet: req1Met,
        missingReason: req1Met ? null : 'Complete profile & link UID',
        icon: Icons.account_box_rounded,
      ),
    );

    final bool rankMet =
        isRankEligible(user.rank, game: activeGame) || user.isRankApproved;
    double rankProgress = 0.1;
    final lowerRank = user.rank.toLowerCase().trim();
    if (rankMet) {
      rankProgress = 1.0;
    } else if (lowerRank.contains('diamond') ||
        lowerRank.contains('platinum')) {
      rankProgress = 0.7;
    } else if (lowerRank.contains('gold')) {
      rankProgress = 0.4;
    } else if (lowerRank.contains('silver')) {
      rankProgress = 0.2;
    }

    items.add(
      VerificationRequirementItem(
        id: 2,
        title: 'Top Tier Rank in Selected Game',
        description: 'Top competitive rank in $activeGame.',
        currentFormatted:
            (user.rank.isEmpty || lowerRank == 'none' || lowerRank == 'skip')
                ? 'Unranked'
                : '$activeGame: ${user.rank}',
        targetFormatted: 'Top Tier Rank',
        progress: rankProgress,
        isMet: rankMet,
        missingReason: rankMet ? null : 'Reach top tier rank',
        icon: Icons.military_tech_rounded,
      ),
    );

    final bool hasKd = user.kdRatio > 0.0;
    items.add(
      VerificationRequirementItem(
        id: 3,
        title: 'Game Stats (Optional)',
        description: 'Share performance stats.',
        currentFormatted:
            hasKd ? '${user.kdRatio.toStringAsFixed(2)} K/D' : 'Optional',
        targetFormatted: 'Stats (Optional)',
        progress: 1.0,
        isMet: true,
        icon: Icons.speed_rounded,
      ),
    );

    final int communityPosts = (clips > 0) ? clips : user.postsCount;
    final bool postsMet = communityPosts >= 3;
    final bool squadRoomsMet = squadRooms >= 2;
    final bool req4Met = postsMet && squadRoomsMet;

    final double postsPart = (communityPosts.clamp(0, 3) / 3.0) * 0.5;
    final double squadPart = (squadRooms.clamp(0, 2) / 2.0) * 0.5;
    final double req4Progress = (postsPart + squadPart).clamp(0.0, 1.0);

    items.add(
      VerificationRequirementItem(
        id: 4,
        title: '3 Community Posts + 2 Squad/Room Posts',
        description: 'Active community creator.',
        currentFormatted:
            '$communityPosts/3 Posts • $squadRooms/2 Squad/Rooms',
        targetFormatted: '3 Posts & 2 Squad/Rooms',
        progress: req4Progress,
        isMet: req4Met,
        missingReason: req4Met ? null : 'Post more content',
        icon: Icons.dynamic_feed_rounded,
      ),
    );

    final bool likesMet = likes >= 500;
    final double likesProgress = (likes / 500.0).clamp(0.0, 1.0);

    items.add(
      VerificationRequirementItem(
        id: 5,
        title: '500+ Total Likes Received',
        description: 'Community appreciation.',
        currentFormatted: '$likes / 500 Likes',
        targetFormatted: '500+ Likes',
        progress: likesProgress,
        isMet: likesMet,
        missingReason: likesMet ? null : 'Need more likes',
        icon: Icons.favorite_rounded,
      ),
    );

    final bool ageMet = ageDays >= 7;
    final bool reportsMet = reports == 0;
    final bool req6Met = ageMet && reportsMet;

    double req6Progress = (ageDays / 7.0).clamp(0.0, 1.0);
    if (!reportsMet) req6Progress = 0.0;

    items.add(
      VerificationRequirementItem(
        id: 6,
        title: 'Account Age 7+ Days & 0 Reports',
        description: 'Clean community trust.',
        currentFormatted: '$ageDays Days • $reports Reports',
        targetFormatted: '7+ Days & 0 Reports',
        progress: req6Progress,
        isMet: req6Met,
        missingReason: req6Met ? null : 'Account age or reports issue',
        icon: Icons.verified_user_rounded,
      ),
    );

    return items;
  }

  static bool canApplyForVerification(
    GamerUser user, {
    int? clipsCount,
    int? squadRoomsCount,
    int? likesReceived,
    int? reportsCount,
    int? accountAgeDays,
  }) {
    if (user.isOwnerUser) return true;
    final reqs = getRequirements(
      user,
      clipsCount: clipsCount,
      squadRoomsCount: squadRoomsCount,
      likesReceived: likesReceived,
      reportsCount: reportsCount,
      accountAgeDays: accountAgeDays,
    );
    return reqs.every((r) => r.isMet);
  }

  static Future<VerificationStats> fetchLiveStats(String uid) async {
    if (uid.isEmpty) {
      return const VerificationStats(
        clipsCount: 0,
        squadRoomsCount: 0,
        likesReceived: 0,
        reportsCount: 0,
        accountAgeDays: 0,
        isProfileComplete: false,
        isGameIdLinked: false,
        isRankEligible: false,
        isKdEligible: false,
      );
    }

    try {
      final uuid = SupabaseService.toUuid(uid);

      final userRow = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', uuid)
          .maybeSingle();

      if (userRow == null) {
        return const VerificationStats(
          clipsCount: 0,
          squadRoomsCount: 0,
          likesReceived: 0,
          reportsCount: 0,
          accountAgeDays: 0,
          isProfileComplete: false,
          isGameIdLinked: false,
          isRankEligible: false,
          isKdEligible: false,
        );
      }

      int clips = 0;
      try {
        final posts = await SupabaseService.client
            .from('posts')
            .select('id')
            .eq('user_id', uuid);
        clips = (posts as List).length;
      } catch (_) {}

      int squadRooms = 0;

      int likes = (userRow['likes_received'] as num?)?.toInt() ?? 0;
      try {
        final posts = await SupabaseService.client
            .from('posts')
            .select('likes_count')
            .eq('user_id', uuid);
        int sumLikes = 0;
        for (final p in (posts as List)) {
          sumLikes += (p['likes_count'] as num?)?.toInt() ?? 0;
        }
        likes = max(likes, sumLikes);
      } catch (_) {}

      int reports = (userRow['reports_count'] as num?)?.toInt() ?? 0;

      DateTime? created;
      final raw = userRow['created_at'];
      if (raw is String) {
        created = DateTime.tryParse(raw);
      }
      int ageDays = created != null
          ? DateTime.now().difference(created).inDays.clamp(0, 99999)
          : 1;

      final photo = (userRow['avatar_url'] ?? '').toString().trim();
      final bio = (userRow['bio'] ?? '').toString().trim();
      final name = (userRow['display_name'] ?? '').toString().trim();
      final gameId = (userRow['game_id'] ?? '').toString().trim();
      final rank = (userRow['rank'] ?? '').toString().trim();
      final kd = (userRow['kd_ratio'] as num?)?.toDouble() ?? 0.0;

      return VerificationStats(
        clipsCount: clips,
        squadRoomsCount: squadRooms,
        likesReceived: likes,
        reportsCount: reports,
        accountAgeDays: ageDays,
        isProfileComplete: bio.isNotEmpty && name.isNotEmpty,
        isGameIdLinked: gameId.isNotEmpty,
        isRankEligible: isRankEligible(rank),
        isKdEligible: kd >= 2.5,
      );
    } catch (e) {
      debugPrint('Error in fetchLiveStats: $e');
      return const VerificationStats(
        clipsCount: 0,
        squadRoomsCount: 0,
        likesReceived: 0,
        reportsCount: 0,
        accountAgeDays: 0,
        isProfileComplete: false,
        isGameIdLinked: false,
        isRankEligible: false,
        isKdEligible: false,
      );
    }
  }

  static Future<VerificationApplicationResult> applyForVerification(
      GamerUser user) async {
    final uid = user.uid;
    if (uid.isEmpty) {
      return const VerificationApplicationResult(
        success: false,
        status: 'none',
        isVerified: false,
        message: 'Please sign in to apply.',
      );
    }

    try {
      final uuid = SupabaseService.toUuid(uid);
      final now = DateTime.now().toIso8601String();

      if (user.isOwnerUser) {
        await SupabaseService.client.from('users').update({
          'is_verified': true,
          'blue_tick_status': 'approved',
          'updated_at': now,
        }).eq('id', uuid);

        _verifiedCache[uid] = true;
        return const VerificationApplicationResult(
          success: true,
          status: 'verified',
          isVerified: true,
          message: 'Owner Blue Tick granted.',
        );
      }

      final stats = await fetchLiveStats(uid);
      final reqs = getRequirements(
        user,
        clipsCount: stats.clipsCount,
        squadRoomsCount: stats.squadRoomsCount,
        likesReceived: stats.likesReceived,
        reportsCount: stats.reportsCount,
        accountAgeDays: stats.accountAgeDays,
      );

      final unmet = reqs.where((r) => !r.isMet).toList();
      if (unmet.isNotEmpty) {
        return VerificationApplicationResult(
          success: false,
          status: user.verificationStatus,
          isVerified: user.isVerified,
          message: 'Cannot apply: ${unmet.length} requirement(s) missing.',
          missingRequirements: unmet.map((u) => u.title).toList(),
        );
      }

      await SupabaseService.client.from('users').update({
        'is_verified': true,
        'blue_tick_status': 'approved',
        'updated_at': now,
      }).eq('id', uuid);

      _verifiedCache[uid] = true;

      try {
        await SupabaseService.sendNotification({
          'userId': uuid,
          'title': '🎉 Blue Tick Verified!',
          'message': 'Congratulations! Blue Tick is now active on your ID.',
          'type': 'verification',
        });
      } catch (_) {}

      return const VerificationApplicationResult(
        success: true,
        status: 'verified',
        isVerified: true,
        message: 'Congratulations! Blue Tick granted.',
      );
    } catch (e) {
      debugPrint('Error applying for verification: $e');
      return VerificationApplicationResult(
        success: false,
        status: user.verificationStatus,
        isVerified: user.isVerified,
        message: 'Verification failed: $e',
      );
    }
  }

  /// Mark application as pending under review (used when user submits application form).
  static Future<bool> setPendingUnderReview(String uid) async {
    if (uid.isEmpty) return false;
    try {
      final uuid = SupabaseService.toUuid(uid);
      await SupabaseService.client.from('users').update({
        'blue_tick_status': 'pending',
        'is_verified': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uuid);
      _verifiedCache[uid] = false;
      return true;
    } catch (e) {
      debugPrint('Error setting pending review: $e');
      return false;
    }
  }

  static Future<bool> linkGameId({
    required String userId,
    required String gameId,
    String? gameName,
  }) async {
    final cleanId = gameId.trim();
    if (cleanId.isEmpty) return false;

    try {
      final uuid = SupabaseService.toUuid(userId);
      final Map<String, dynamic> updates = {
        'game_id': cleanId,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (gameName != null && gameName.isNotEmpty) {
        updates['favorite_game'] = gameName;
        updates['selected_game'] = gameName;
      }
      await SupabaseService.client
          .from('users')
          .update(updates)
          .eq('id', uuid);
      return true;
    } catch (e) {
      debugPrint('Error linking game ID: $e');
      return false;
    }
  }

  static VerificationProgress getProgressFromUser(GamerUser user) {
    return VerificationProgress(
      isVerified: user.isVerified || user.verificationStatus == 'verified',
      hasAvatar: user.hasAvatar,
      hasBio: user.hasBio,
      hasGameIdLinked: user.hasGameIdLinked,
      gameId: user.gameId,
      postsCount: user.postsCount,
      likesReceived: user.likesReceived,
      followersCount: user.followersCount,
      accountAgeDays: user.accountAgeDays,
      noReports: user.noReports,
      reportsCount: user.reportsCount,
    );
  }

  static Future<VerificationProgress> checkAndAutoVerify(GamerUser user) async {
    final uid = user.uid;
    if (uid.isEmpty) return getProgressFromUser(user);

    try {
      final stats = await fetchLiveStats(uid);
      final bool canVerify = canApplyForVerification(
        user,
        clipsCount: stats.clipsCount,
        squadRoomsCount: stats.squadRoomsCount,
        likesReceived: stats.likesReceived,
        reportsCount: stats.reportsCount,
        accountAgeDays: stats.accountAgeDays,
      );

      bool isVerifiedNow =
          user.isVerified || user.verificationStatus == 'verified';

      if (canVerify &&
          !isVerifiedNow &&
          user.verificationStatus == 'pending') {
        final uuid = SupabaseService.toUuid(uid);
        await SupabaseService.client.from('users').update({
          'is_verified': true,
          'blue_tick_status': 'approved',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', uuid);
        isVerifiedNow = true;
        _verifiedCache[uid] = true;
      }

      return VerificationProgress(
        isVerified: isVerifiedNow,
        hasAvatar: user.hasAvatar,
        hasBio: user.hasBio,
        hasGameIdLinked: user.hasGameIdLinked,
        gameId: user.gameId,
        postsCount: stats.clipsCount,
        likesReceived: stats.likesReceived,
        followersCount: user.followersCount,
        accountAgeDays: stats.accountAgeDays,
        noReports: stats.reportsCount == 0,
        reportsCount: stats.reportsCount,
      );
    } catch (e) {
      debugPrint('Error in checkAndAutoVerify: $e');
      return getProgressFromUser(user);
    }
  }
}