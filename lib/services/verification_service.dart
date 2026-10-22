// ═══════════════════════════════════════════════════════════════════════════════
// VERIFICATION SERVICE — Strict Anti-Inflation Rules & Admin Approval Flow
// File: lib/services/verification_service.dart
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
  bool get meetsPosts => postsCount >= 30;
  bool get meetsLikes => likesReceived >= 100;
  bool get meetsAccountAge => accountAgeDays >= 30;
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
    return (completedRequirementsCount / totalRequirementsCount).clamp(0.0, 1.0);
  }

  bool get isFullyEligible =>
      meetsProfileComplete &&
      meetsGameId &&
      meetsPosts &&
      meetsLikes &&
      meetsAccountAge &&
      meetsCleanRecord;
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
      final row = await SupabaseService.client
          .from('users')
          .select('is_verified, blue_tick_status')
          .or('id.eq.$userId,uid.eq.$userId')
          .maybeSingle();

      if (row == null) {
        _verifiedCache[userId] = false;
        return false;
      }

      final isVerified = row['is_verified'] == true &&
          (row['blue_tick_status']?.toString().toLowerCase() ?? '') == 'approved';
      _verifiedCache[userId] = isVerified;
      return isVerified;
    } catch (e) {
      debugPrint('Error fetching verification for $userId: $e');
      return false;
    }
  }

  /// Strict Rank Check: Bronze, Silver, Gold, Platinum NOT eligible
  static bool isRankEligible(String rank, {String? game}) {
    final r = rank.toLowerCase().trim();
    if (r.isEmpty) return false;

    if (r == 'unranked' ||
        r == 'none' ||
        r == 'skip' ||
        r.contains('bronze') ||
        r.contains('silver') ||
        r.contains('gold') ||
        r.contains('platinum') ||
        r.contains('diamond') ||
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
        r.contains('mythical');
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
      return [
        const VerificationRequirementItem(
          id: 1,
          title: 'Owner Profile',
          description: 'Official Administrator and Founder status',
          currentFormatted: 'Granted',
          targetFormatted: 'Completed',
          progress: 1.0,
          isMet: true,
          icon: Icons.shield_rounded,
        ),
      ];
    }

    final int posts = clipsCount ?? user.postsCount;
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
        : (user.favoriteGame.isNotEmpty ? user.favoriteGame : 'BGMI / PUBG');

    final bool hasBio = user.bio.trim().isNotEmpty;
    final bool hasName = user.displayName.trim().isNotEmpty;
    final bool hasUid = user.gameId.trim().isNotEmpty;

    int profileScore = 0;
    if (hasBio) profileScore++;
    if (hasName) profileScore++;
    if (hasUid) profileScore++;
    final double req1Progress = (profileScore / 3.0).clamp(0.0, 1.0);
    final bool req1Met = hasBio && hasName && hasUid;

    // 1. Profile & Game UID
    items.add(
      VerificationRequirementItem(
        id: 1,
        title: 'Profile & Game UID',
        description: 'Complete bio, username, and connect game character ID',
        currentFormatted: req1Met ? '$activeGame UID: ${user.gameId}' : '${(req1Progress * 100).toInt()}% Complete',
        targetFormatted: '100% Complete',
        progress: req1Progress,
        isMet: req1Met,
        missingReason: req1Met ? null : 'Link your Game UID and complete your bio',
        icon: Icons.account_box_rounded,
      ),
    );

    // 2. High Tier Rank (Crown / Ace / Conqueror)
    final bool rankMet = isRankEligible(user.rank, game: activeGame) || user.isRankApproved;
    double rankProgress = 0.1;
    final lowerRank = user.rank.toLowerCase().trim();
    if (rankMet) {
      rankProgress = 1.0;
    } else if (lowerRank.contains('diamond')) {
      rankProgress = 0.7;
    } else if (lowerRank.contains('platinum')) {
      rankProgress = 0.5;
    } else if (lowerRank.contains('gold')) {
      rankProgress = 0.3;
    }

    items.add(
      VerificationRequirementItem(
        id: 2,
        title: 'High-Tier Rank',
        description: 'Reach Crown, Ace or equivalent rank in $activeGame',
        currentFormatted: user.rank.isEmpty ? 'Unranked' : '$activeGame: ${user.rank}',
        targetFormatted: 'Crown / Ace+',
        progress: rankProgress,
        isMet: rankMet,
        missingReason: rankMet ? null : 'Rank must be Crown, Ace, or higher',
        icon: Icons.military_tech_rounded,
      ),
    );

    // 3. Community Pictures & Posts (Target: 30)
    final bool postsMet = posts >= 30;
    final double req3Progress = (posts / 30.0).clamp(0.0, 1.0);

    items.add(
      VerificationRequirementItem(
        id: 3,
        title: 'Community Content',
        description: 'Publish at least 30 gaming screenshots or posts',
        currentFormatted: '$posts / 30 Posts',
        targetFormatted: '30 Posts',
        progress: req3Progress,
        isMet: postsMet,
        missingReason: postsMet ? null : 'Upload 30 gaming pictures/posts to qualify',
        icon: Icons.add_photo_alternate_rounded,
      ),
    );

    // 4. Community Engagement Likes (Target: 100+)
    final bool likesMet = likes >= 100;
    final double likesProgress = (likes / 100.0).clamp(0.0, 1.0);

    items.add(
      VerificationRequirementItem(
        id: 4,
        title: 'Player Likes Received',
        description: 'Earn 100+ total likes on your posted gaming content',
        currentFormatted: '$likes / 100 Likes',
        targetFormatted: '100 Likes',
        progress: likesProgress,
        isMet: likesMet,
        missingReason: likesMet ? null : 'Requires at least 100 total likes',
        icon: Icons.favorite_rounded,
      ),
    );

    // 5. Account Age & Clean Record (Target: 30 Days + 0 Reports)
    final bool ageMet = ageDays >= 30;
    final bool reportsMet = reports == 0;
    final bool req5Met = ageMet && reportsMet;

    double req5Progress = (ageDays / 30.0).clamp(0.0, 1.0);
    if (!reportsMet) req5Progress = 0.0;

    items.add(
      VerificationRequirementItem(
        id: 5,
        title: 'Account Age & Trust',
        description: 'Account active for at least 30 days with 0 toxicity reports',
        currentFormatted: '$ageDays Days | $reports Reports',
        targetFormatted: '30+ Days & 0 Reports',
        progress: req5Progress,
        isMet: req5Met,
        missingReason: !ageMet ? 'Account must be at least 30 days old' : 'Reports must be 0',
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
      final userRow = await SupabaseService.client
          .from('users')
          .select()
          .or('id.eq.$uid,uid.eq.$uid')
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

      final targetId = userRow['id'] ?? uid;

      int postsCount = 0;
      try {
        final postsRes = await SupabaseService.client
            .from('posts')
            .select('id')
            .or('user_id.eq.$targetId,user_id.eq.$uid');
        postsCount = (postsRes as List).length;
      } catch (_) {}

      int likes = (userRow['likes_received'] as num?)?.toInt() ?? 0;
      try {
        final postsRes = await SupabaseService.client
            .from('posts')
            .select('likes_count')
            .or('user_id.eq.$targetId,user_id.eq.$uid');
        int sumLikes = 0;
        for (final p in (postsRes as List)) {
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

      final bio = (userRow['bio'] ?? '').toString().trim();
      final name = (userRow['display_name'] ?? '').toString().trim();
      final gameId = (userRow['game_id'] ?? '').toString().trim();
      final rank = (userRow['rank'] ?? '').toString().trim();
      final kd = (userRow['kd_ratio'] as num?)?.toDouble() ?? 0.0;

      return VerificationStats(
        clipsCount: postsCount,
        squadRoomsCount: 0,
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

  /// Sends application to Admin Dashboard for Manual Approval
  static Future<VerificationApplicationResult> applyForVerification(GamerUser user) async {
    final uid = user.uid;
    if (uid.isEmpty) {
      return const VerificationApplicationResult(
        success: false,
        status: 'none',
        isVerified: false,
        message: 'Please sign in first',
      );
    }

    try {
      final now = DateTime.now().toIso8601String();

      // Owner is instantly approved
      if (user.isOwnerUser) {
        await SupabaseService.client.from('users').update({
          'is_verified': true,
          'blue_tick_status': 'approved',
          'verification_status': 'verified',
          'updated_at': now,
        }).or('id.eq.$uid,uid.eq.$uid');

        _verifiedCache[uid] = true;
        return const VerificationApplicationResult(
          success: true,
          status: 'verified',
          isVerified: true,
          message: 'Owner status verified!',
        );
      }

      // Mark user as Pending Review for Admin
      await SupabaseService.client.from('users').update({
        'is_verified': false,
        'blue_tick_status': 'pending',
        'verification_status': 'pending',
        'updated_at': now,
      }).or('id.eq.$uid,uid.eq.$uid');

      _verifiedCache[uid] = false;

      return const VerificationApplicationResult(
        success: true,
        status: 'pending',
        isVerified: false,
        message: 'Aapki application Admin review ke liye submit ho chuki hai!',
      );
    } catch (e) {
      debugPrint('Error applying for verification: $e');
      return VerificationApplicationResult(
        success: false,
        status: user.verificationStatus,
        isVerified: user.isVerified,
        message: 'Application failed: $e',
      );
    }
  }

  static Future<bool> setPendingUnderReview(String uid) async {
    if (uid.isEmpty) return false;
    try {
      await SupabaseService.client.from('users').update({
        'blue_tick_status': 'pending',
        'verification_status': 'pending',
        'is_verified': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.$uid,uid.eq.$uid');
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
          .or('id.eq.$userId,uid.eq.$userId');
      return true;
    } catch (e) {
      debugPrint('Error linking game ID: $e');
      return false;
    }
  }
}
