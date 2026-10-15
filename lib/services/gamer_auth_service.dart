import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gamer_user_model.dart';
import 'supabase_service.dart';
import 'notification_service.dart';
import 'coin_wallet_service.dart';

class GamerAuthService {
  static final GamerAuthService _instance = GamerAuthService._internal();
  factory GamerAuthService() => _instance;
  GamerAuthService._internal();

  SupabaseClient get _supabase => SupabaseService.client;

  final ValueNotifier<GamerUser?> currentGamerNotifier = ValueNotifier<GamerUser?>(null);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<User?> authUserNotifier = ValueNotifier<User?>(null);

  StreamSubscription<AuthState>? _authSubscription;

  User? get currentUser => _supabase.auth.currentUser;
  String? get currentUid => _supabase.auth.currentUser?.id;
  bool get isAuthenticated => _supabase.auth.currentUser != null;
  GamerUser? get currentGamer => currentGamerNotifier.value;

  Stream<User?> get authStateChanges => _supabase.auth.onAuthStateChange.map((event) => event.session?.user);

  Future<void> init() async {
    _authSubscription?.cancel();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      authUserNotifier.value = user;
      if (user != null) {
        isLoadingNotifier.value = true;
        await refreshCurrentGamer();
      } else {
        currentGamerNotifier.value = null;
        isLoadingNotifier.value = false;
      }
    });

    final initialUser = _supabase.auth.currentUser;
    authUserNotifier.value = initialUser;
    if (initialUser != null) {
      isLoadingNotifier.value = true;
      await refreshCurrentGamer();
    } else {
      currentGamerNotifier.value = null;
      isLoadingNotifier.value = false;
    }
  }

  /// Internal sync and load user profile from Supabase users table
  Future<void> _syncAndLoadUser(User user) async {
    try {
      final authUserId = user.id;

      Map<String, dynamic>? profile;
      try {
        profile = await _supabase
            .from('users')
            .select()
            .or('id.eq.$authUserId,uid.eq.$authUserId')
            .maybeSingle();
      } catch (_) {
        try {
          profile = await _supabase
              .from('users')
              .select('id, username, display_name, avatar_url, cover_url, is_banned, banned_reason')
              .eq('id', authUserId)
              .maybeSingle();
        } catch (_) {
          try {
            profile = await _supabase
                .from('users')
                .select('id, username, display_name, avatar_url, cover_url, is_banned, banned_reason')
                .eq('uid', authUserId)
                .maybeSingle();
          } catch (_) {}
        }
      }

      if (profile != null) {
        final gamer = GamerUser.fromMap(profile, authUserId);
        currentGamerNotifier.value = gamer;
      } else {
        currentGamerNotifier.value = null;
      }

      try {
        NotificationService().saveUserFcmToken(authUserId);
      } catch (_) {}

      // Check and award 1000 coins welcome bonus on first signup
      checkAndAwardWelcomeBonus(authUserId);
    } catch (e) {
      debugPrint('[GamerAuthService] Error syncing user: $e');
      currentGamerNotifier.value = null;
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  /// Refresh current gamer profile from Supabase
  Future<GamerUser?> refreshCurrentGamer() async {
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
      currentGamerNotifier.value = null;
      isLoadingNotifier.value = false;
      return null;
    }

    try {
      Map<String, dynamic>? profile;
      try {
        profile = await _supabase
            .from('users')
            .select()
            .or('id.eq.${authUser.id},uid.eq.${authUser.id}')
            .maybeSingle();
      } catch (_) {
        try {
          profile = await _supabase
              .from('users')
              .select('id, username, display_name, avatar_url, cover_url, is_banned, banned_reason')
              .eq('id', authUser.id)
              .maybeSingle();
        } catch (_) {
          try {
            profile = await _supabase
                .from('users')
                .select('id, username, display_name, avatar_url, cover_url, is_banned, banned_reason')
                .eq('uid', authUser.id)
                .maybeSingle();
          } catch (_) {}
        }
      }

      if (profile != null) {
        final gamer = GamerUser.fromMap(profile, authUser.id);
        currentGamerNotifier.value = gamer;
        isLoadingNotifier.value = false;
        return gamer;
      }
    } catch (e) {
      debugPrint('[GamerAuthService] Error refreshing gamer: $e');
    }
    isLoadingNotifier.value = false;
    return currentGamerNotifier.value;
  }

  /// Checks live if a username is available in Supabase
  Future<bool> isUsernameAvailable(String username, {String? currentUid}) async {
    final clean = username.toLowerCase().trim();
    if (clean.length < 3) return false;

    try {
      final res = await _supabase
          .from('users')
          .select('id, uid, username')
          .eq('username', clean)
          .limit(1)
          .timeout(const Duration(seconds: 2), onTimeout: () => []);
      if (res.isNotEmpty) {
        final row = res.first;
        final rowId = (row['id'] ?? '').toString();
        final rowUid = (row['uid'] ?? '').toString();
        if (currentUid != null && (rowId == currentUid || rowUid == currentUid)) {
          return true;
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking username: $e');
      return true;
    }
  }

  /// Google Sign In (via Supabase OAuth)
  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.gameskhabar://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[GamerAuthService] Supabase Google OAuth Error: $e');
      rethrow;
    }
  }

  /// Guest / Instant Sign In
  Future<GamerUser> signInAnonymouslyOrGuest() async {
    isLoadingNotifier.value = true;
    try {
      final res = await _supabase.auth.signInAnonymously().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw Exception('Anonymous login timeout'),
      );
      final user = res.user;
      if (user != null) {
        await _syncAndLoadUser(user);
        final gamer = currentGamer;
        if (gamer != null) return gamer;
      }
    } catch (e) {
      debugPrint('[GamerAuthService] Guest/Anonymous Supabase fallback: $e');
    }

    final guestUid = 'guest_${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final guestGamer = GamerUser(
      uid: guestUid,
      username: 'gamer_$guestUid',
      displayName: 'Guest Gamer',
      photoUrl: '',
      coverUrl: '',
      bio: 'Gamer on the rise! 🎮',
      favoriteGame: 'PUBG Mobile',
      selectedGame: 'PUBG Mobile',
      selectedRank: 'Bronze',
      rank: 'Bronze',
      coins: 100,
    );
    currentGamerNotifier.value = guestGamer;
    isLoadingNotifier.value = false;
    return guestGamer;
  }

  /// Alias for signInWithGoogle
  Future<void> loginWithGoogle() => signInWithGoogle();

  /// Uploads user avatar photo directly to Supabase Storage
  Future<String> uploadProfilePhoto(File imageFile, String uid) async {
    try {
      final url = await SupabaseService.uploadFile(
        file: imageFile,
        folder: 'user_avatars',
        bucket: SupabaseService.bucketAvatars,
        customFileName: 'avatar_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (e) {
      debugPrint('[GamerAuthService] Supabase avatar upload error: $e');
    }
    return '';
  }

  /// Uploads user cover photo directly to Supabase Storage
  Future<String> uploadCoverPhoto(File imageFile, String uid) async {
    try {
      final url = await SupabaseService.uploadFile(
        file: imageFile,
        folder: 'user_covers',
        bucket: SupabaseService.bucketCovers,
        customFileName: 'cover_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (e) {
      debugPrint('[GamerAuthService] Supabase cover upload error: $e');
    }
    return '';
  }

  /// Uploads rank proof screenshot to Supabase Storage
  Future<String> uploadRankScreenshot(File imageFile, String uid) async {
    try {
      final url = await SupabaseService.uploadFile(
        file: imageFile,
        folder: 'rank_proofs',
        bucket: SupabaseService.bucketScreenshots,
        customFileName: 'rank_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (e) {
      debugPrint('[GamerAuthService] Supabase rank screenshot upload error: $e');
    }
    return '';
  }

  /// Creates or updates `users` record in Supabase
  /// Uses upsert first, then falls back to update by id and uid
  Future<bool> saveGamerProfile(GamerUser user) async {
    try {
      final payload = <String, dynamic>{
        'id': user.uid,
        'uid': user.uid,
        'username': user.username,
        'display_name': user.displayName,
        'avatar_url': user.photoUrl,
        'cover_url': user.coverUrl,
        'bio': user.bio,
        'game': (user.favoriteGame.isNotEmpty && user.favoriteGame != 'All Games') ? user.favoriteGame : null,
        'game_name': user.favoriteGame.isNotEmpty ? user.favoriteGame : null,
        'rank': user.rank.isNotEmpty ? user.rank : null,
        'gamer_rank': user.rank.isNotEmpty ? user.rank : null,
        'selected_rank': user.selectedRank.isNotEmpty ? user.selectedRank : null,
        'is_rank_verified': user.isRankVerified,
        'rank_status': user.rankStatus.isNotEmpty ? user.rankStatus : 'none',
        'rank_proof_url': user.rankScreenshot.isNotEmpty ? user.rankScreenshot : null,
        'coins': user.coins,
        'is_verified': user.isVerified,
        'updated_at': DateTime.now().toIso8601String(),
      };

      bool saved = false;
      try {
        await _supabase.from('users').upsert(payload);
        debugPrint('[GamerAuthService] ✅ upsert successful for ${user.uid}');
        saved = true;
      } catch (upsertError) {
        debugPrint('[GamerAuthService] upsert failed, trying update: $upsertError');

        try {
          await _supabase.from('users').update(payload).eq('id', user.uid);
          debugPrint('[GamerAuthService] ✅ update by id successful for ${user.uid}');
          saved = true;
        } catch (updateError) {
          try {
            await _supabase.from('users').update(payload).eq('uid', user.uid);
            debugPrint('[GamerAuthService] ✅ update by uid successful for ${user.uid}');
            saved = true;
          } catch (_) {}
        }
      }

      // Safe fallback: Always ensure core avatar, cover, and display name are updated in DB
      final corePayload = <String, dynamic>{
        'avatar_url': user.photoUrl,
        'cover_url': user.coverUrl,
        'display_name': user.displayName,
        'bio': user.bio,
        'updated_at': DateTime.now().toIso8601String(),
      };
      try {
        await _supabase.from('users').update(corePayload).eq('id', user.uid);
        saved = true;
      } catch (_) {
        try {
          await _supabase.from('users').update(corePayload).eq('uid', user.uid);
          saved = true;
        } catch (_) {}
      }

      currentGamerNotifier.value = user;
      await checkAndAwardWelcomeBonus(user.uid);
      return saved;
    } catch (e) {
      debugPrint('[GamerAuthService] Error saving gamer profile in Supabase: $e');
      return false;
    }
  }

  /// Awards 1000 G-Coins welcome bonus on first signup (Issue #6)
  Future<void> checkAndAwardWelcomeBonus(String userId) async {
    if (userId.isEmpty) return;
    try {
      final userRow = await _supabase
          .from('users')
          .select('welcome_bonus_claimed, id')
          .or('id.eq.$userId,uid.eq.$userId')
          .maybeSingle();

      final bool alreadyClaimed =
          userRow != null && (userRow['welcome_bonus_claimed'] == true);
      if (alreadyClaimed) return;

      // Duplicate prevention: check coin_transactions table
      final existingTx = await _supabase
          .from('coin_transactions')
          .select('id')
          .eq('user_id', SupabaseService.toUuid(userId))
          .eq('type', 'welcome_bonus')
          .limit(1);

      if (existingTx.isNotEmpty) {
        try {
          await _supabase
              .from('users')
              .update({'welcome_bonus_claimed': true})
              .or('id.eq.$userId,uid.eq.$userId');
        } catch (_) {}
        return;
      }

      // Mark welcome_bonus_claimed = true
      try {
        await _supabase
            .from('users')
            .update({'welcome_bonus_claimed': true})
            .or('id.eq.$userId,uid.eq.$userId');
      } catch (_) {}

      // Award 1000 G-Coins via CoinWalletService
      await CoinWalletService.updateCoins(
        userId: userId,
        amount: 1000,
        type: 'welcome_bonus',
        title: 'Welcome Bonus',
        description: 'First time signup bonus',
      );

      // Send welcome notification
      await NotificationService().createNotification(
        userId: userId,
        title: 'Welcome to Games Khabar!',
        body: 'Welcome to Games Khabar! Aapko 1000 G-Coins mile hain!',
        type: 'welcome_bonus',
      );
    } catch (e) {
      debugPrint('[GamerAuthService] checkAndAwardWelcomeBonus error: $e');
    }
  }

  /// ✅ FIXED: Fetch any user's profile by UID from Supabase
  /// Pehle `id` se exact match, phir `uid` se fallback
  Future<GamerUser?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;

    try {
      // 1. Pehle `id` se exact match karo
      final userById = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (userById != null) {
        return GamerUser.fromMap(userById, uid);
      }

      // 2. Agar `id` se nahi mila, to `uid` se try karo
      final userByUid = await _supabase
          .from('users')
          .select()
          .eq('uid', uid)
          .maybeSingle();

      if (userByUid != null) {
        final actualId = (userByUid['id'] ?? uid).toString();
        return GamerUser.fromMap(userByUid, actualId);
      }
    } catch (e) {
      debugPrint('[GamerAuthService] Supabase get user profile error: $e');
    }
    return null;
  }

  Future<GamerUser?> fetchUserProfile(String uid) => getUserProfile(uid);

  /// Updates profile fields in Supabase
  Future<void> updateProfile({
    String? rank,
    double? kdRatio,
    String? gameId,
    String? bio,
    String? displayName,
    String? photoUrl,
    String? coverUrl,
    String? verificationStatus,
  }) async {
    final uid = currentUid;
    if (uid == null) return;

    final Map<String, dynamic> updates = {};
    if (rank != null) updates['rank'] = rank;
    if (bio != null) updates['bio'] = bio;
    if (displayName != null) updates['display_name'] = displayName;
    if (photoUrl != null) updates['avatar_url'] = photoUrl;
    if (coverUrl != null) updates['cover_url'] = coverUrl;
    if (verificationStatus != null) updates['is_verified'] = verificationStatus == 'verified';

    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      try {
        await _supabase.from('users').update(updates).eq('id', uid);
        await refreshCurrentGamer();
      } catch (e) {
        debugPrint('[GamerAuthService] Error updating profile: $e');
      }
    }
  }

  Stream<GamerUser?> userProfileStream(String uid) async* {
    while (true) {
      final user = await getUserProfile(uid);
      yield user;
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  /// Sign out
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('[GamerAuthService] Supabase signOut error: $e');
    }
    try {
      await SupabaseService.signOut();
    } catch (_) {}
    currentGamerNotifier.value = null;
    isLoadingNotifier.value = false;
  }

  Future<void> signOut() => logout();
}