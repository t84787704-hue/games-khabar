import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gamer_user_model.dart';
import 'supabase_service.dart';
import 'notification_service.dart';

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
            .select('id, username, display_name, avatar_url, is_banned, banned_reason')
            .eq('id', authUserId)
            .maybeSingle();
      } catch (_) {
        profile = await _supabase
            .from('users')
            .select()
            .eq('id', authUserId)
            .maybeSingle();
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
            .select('id, username, display_name, avatar_url, is_banned, banned_reason')
            .eq('id', authUser.id)
            .maybeSingle();
      } catch (_) {
        profile = await _supabase
            .from('users')
            .select()
            .eq('id', authUser.id)
            .maybeSingle();
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
    currentGamerNotifier.value = null;
    isLoadingNotifier.value = false;
    return null;
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
        final rowUid = row['uid'] ?? row['id'];
        if (currentUid != null && rowUid == currentUid) {
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
  /// Uses upsert first, then falls back to update by id
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
        'rank': user.rank.isNotEmpty ? user.rank : null,
        'coins': user.coins,
        'is_verified': user.isVerified,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 1. Try upsert first
      try {
        await _supabase.from('users').upsert(payload);
        debugPrint('[GamerAuthService] ✅ upsert successful for ${user.uid}');
      } catch (upsertError) {
        debugPrint('[GamerAuthService] upsert failed, trying update: $upsertError');

        // 2. Fallback: try update only
        try {
          await _supabase.from('users').update(payload).eq('id', user.uid);
          debugPrint('[GamerAuthService] ✅ update successful for ${user.uid}');
        } catch (updateError) {
          debugPrint('[GamerAuthService] update also failed: $updateError');

          // 3. Last fallback: try insert with uid only
          try {
            await _supabase.from('users').insert(payload);
            debugPrint('[GamerAuthService] ✅ insert successful for ${user.uid}');
          } catch (insertError) {
            debugPrint('[GamerAuthService] insert also failed: $insertError');
            return false;
          }
        }
      }

      currentGamerNotifier.value = user;
      return true;
    } catch (e) {
      debugPrint('[GamerAuthService] Error saving gamer profile in Supabase: $e');
      return false;
    }
  }

  /// Fetch any user's profile by UID from Supabase
  Future<GamerUser?> getUserProfile(String uid) async {
    try {
      final userData = await _supabase.from('users').select().or('id.eq.$uid,uid.eq.$uid').maybeSingle();
      if (userData != null) {
        return GamerUser.fromMap(userData, uid);
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