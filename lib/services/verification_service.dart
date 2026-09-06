import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/gamer_user_model.dart';

/// Detailed progress model for Gamer Verification
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

  // Target requirement thresholds
  static const int requiredPosts = 10;
  static const int requiredLikes = 100;
  static const int requiredFollowers = 20;
  static const int requiredAccountAgeDays = 15;

  bool get meetsProfileComplete => hasAvatar && hasBio;
  bool get meetsGameId => hasGameIdLinked && gameId.trim().isNotEmpty;
  bool get meetsPosts => postsCount >= requiredPosts;
  bool get meetsLikes => likesReceived >= requiredLikes;
  bool get meetsFollowers => followersCount >= requiredFollowers;
  bool get meetsAccountAge => accountAgeDays >= requiredAccountAgeDays;
  bool get meetsCleanRecord => noReports && reportsCount == 0;

  /// Total requirements met out of 6 core milestones:
  /// 1. Profile Complete (Avatar & Bio)
  /// 2. Game ID Linked
  /// 3. Active Gamer (10+ Posts)
  /// 4. 100+ Likes Received
  /// 5. 20+ Followers
  /// 6. 15+ Days Account Age (Trust)
  int get completedRequirementsCount {
    int count = 0;
    if (meetsProfileComplete) count++;
    if (meetsGameId) count++;
    if (meetsPosts) count++;
    if (meetsLikes) count++;
    if (meetsFollowers) count++;
    if (meetsAccountAge) count++;
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
      meetsFollowers &&
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
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache for fast UI lookups without lag
  static final Map<String, bool> _verifiedCache = {};

  /// Synchronously check if a user is verified from cache
  static bool isVerifiedCached(String userId) {
    return _verifiedCache[userId] ?? false;
  }

  /// Mark cache directly
  static void setCache(String userId, bool isVerified) {
    _verifiedCache[userId] = isVerified;
  }

  /// Asynchronously retrieve and cache verified status for a user
  static Future<bool> isUserVerified(String userId) async {
    if (userId.isEmpty) return false;
    if (_verifiedCache.containsKey(userId)) {
      return _verifiedCache[userId]!;
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) {
        _verifiedCache[userId] = false;
        return false;
      }
      final isVerified = doc.data()!['isVerified'] == true;
      _verifiedCache[userId] = isVerified;
      return isVerified;
    } catch (e) {
      debugPrint('Error fetching verification for $userId: $e');
      return false;
    }
  }

  /// Pure logic: checks if a user object meets all 5 requirement sets
  static bool checkIfEligibleForTick(GamerUser user) {
    final progress = getProgressFromUser(user);
    return progress.isFullyEligible;
  }

  /// Build VerificationProgress object from GamerUser snapshot
  static VerificationProgress getProgressFromUser(GamerUser user) {
    return VerificationProgress(
      isVerified: user.isVerified,
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

  /// Deep live check against Firestore: counts actual posts, likes, followers, age, and reports.
  /// If user fulfills all requirements and is not verified, automatically marks them as verified!
  static Future<VerificationProgress> checkAndAutoVerify(GamerUser user) async {
    final uid = user.uid;
    if (uid.isEmpty) return getProgressFromUser(user);

    try {
      // 1. Fetch user doc for freshest data
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};

      final bool alreadyVerified = userData['isVerified'] == true;
      final String gameId = (userData['gameId'] ?? userData['inGameId'] ?? user.gameId).toString().trim();
      final String photoUrl = (userData['photoUrl'] ?? user.photoUrl).toString().trim();
      final String bio = (userData['bio'] ?? user.bio).toString().trim();
      final int reportsCount = (userData['reportsCount'] as num?)?.toInt() ?? user.reportsCount;

      // Calculate account age
      DateTime? createdAt = user.createdAt;
      final rawCreated = userData['createdAt'];
      if (rawCreated is Timestamp) {
        createdAt = rawCreated.toDate();
      }
      final int ageDays = createdAt != null
          ? (DateTime.now().difference(createdAt).inDays).clamp(0, 99999)
          : 0;

      // 2. Count actual user posts and sum likes
      int realPostsCount = 0;
      int realLikesReceived = 0;
      try {
        final postsSnap = await _firestore
            .collection('posts')
            .where('userId', isEqualTo: uid)
            .get();

        realPostsCount = postsSnap.docs.length;
        for (final doc in postsSnap.docs) {
          final data = doc.data();
          realLikesReceived += (data['likesCount'] as num?)?.toInt() ?? 0;
        }
      } catch (e) {
        realPostsCount = (userData['postsCount'] as num?)?.toInt() ?? user.postsCount;
        realLikesReceived = (userData['likesReceived'] as num?)?.toInt() ?? user.likesReceived;
      }

      // Maximize between accumulated likes and tracked likes
      final int trackedLikes = (userData['likesReceived'] as num?)?.toInt() ?? 0;
      if (trackedLikes > realLikesReceived) {
        realLikesReceived = trackedLikes;
      }

      // 3. Count real followers
      int realFollowers = (userData['followersCount'] as num?)?.toInt() ?? user.followersCount;
      try {
        final followersSnap = await _firestore
            .collection('follows')
            .where('followingId', isEqualTo: uid)
            .get();
        if (followersSnap.docs.isNotEmpty) {
          realFollowers = followersSnap.docs.length;
        }
      } catch (_) {}

      final bool hasAvatar = photoUrl.isNotEmpty && (photoUrl.startsWith('http') || photoUrl.startsWith('data:image'));
      final bool hasBio = bio.isNotEmpty;
      final bool hasGameIdLinked = gameId.isNotEmpty;
      final bool noReports = reportsCount == 0;

      final progress = VerificationProgress(
        isVerified: alreadyVerified,
        hasAvatar: hasAvatar,
        hasBio: hasBio,
        hasGameIdLinked: hasGameIdLinked,
        gameId: gameId,
        postsCount: realPostsCount,
        likesReceived: realLikesReceived,
        followersCount: realFollowers,
        accountAgeDays: ageDays,
        noReports: noReports,
        reportsCount: reportsCount,
      );

      // Save updated progress & counts back to Firestore
      final updates = <String, dynamic>{
        'postsCount': realPostsCount,
        'likesReceived': realLikesReceived,
        'followersCount': realFollowers,
        'gameId': gameId,
        'verificationProgress': progress.toMap(),
      };

      bool becameVerifiedNow = false;

      // Auto-verify if eligible and not already verified
      if (!alreadyVerified && progress.isFullyEligible) {
        updates['isVerified'] = true;
        _verifiedCache[uid] = true;
        becameVerifiedNow = true;

        // Add verification achievement notification
        await _firestore.collection('notifications').add({
          'recipientUid': uid,
          'senderUid': 'system_gamers_id',
          'type': 'verification',
          'title': '🎉 You are now Verified!',
          'message': 'Congratulations! Your Gamer ID has earned the Official Blue Verified Badge ✓',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      } else {
        _verifiedCache[uid] = alreadyVerified;
      }

      await _firestore.collection('users').doc(uid).update(updates).catchError((_) {});

      return VerificationProgress(
        isVerified: alreadyVerified || becameVerifiedNow,
        hasAvatar: hasAvatar,
        hasBio: hasBio,
        hasGameIdLinked: hasGameIdLinked,
        gameId: gameId,
        postsCount: realPostsCount,
        likesReceived: realLikesReceived,
        followersCount: realFollowers,
        accountAgeDays: ageDays,
        noReports: noReports,
        reportsCount: reportsCount,
      );
    } catch (e) {
      debugPrint('Error running checkAndAutoVerify for $uid: $e');
      return getProgressFromUser(user);
    }
  }

  /// Manually link in-game Character ID / UID for requirement 2
  static Future<bool> linkGameId({
    required String userId,
    required String gameId,
    String? gameName,
  }) async {
    final cleanId = gameId.trim();
    if (cleanId.isEmpty) return false;

    try {
      await _firestore.collection('users').doc(userId).update({
        'gameId': cleanId,
        'inGameId': cleanId,
        if (gameName != null && gameName.isNotEmpty) 'favoriteGame': gameName,
        'verificationProgress.hasGameIdLinked': true,
        'verificationProgress.gameId': cleanId,
      });
      return true;
    } catch (e) {
      debugPrint('Error linking game ID: $e');
      return false;
    }
  }

  /// Admin console / test helper: set manual verified flag
  static Future<void> setManualVerification(String userId, bool verified) async {
    _verifiedCache[userId] = verified;
    await _firestore.collection('users').doc(userId).update({
      'isVerified': verified,
    });
  }
}
