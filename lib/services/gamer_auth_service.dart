// ═══════════════════════════════════════════════════════════════════════════════
// EXACT DIFF:
// - Replaced .eq('id', user.uid) with .or('id.eq.${user.uid},uid.eq.${user.uid}')
// - Replaced .eq('id', uid) with .or('id.eq.$uid,uid.eq.$uid') in updateUserProfile
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final ValueNotifier<bool> profileLoadErrorNotifier = ValueNotifier<bool>(false);

  StreamSubscription<AuthState>? _authSubscription;
  Future<GamerUser?>? _inFlightRefresh;

  User? get currentUser => _supabase.auth.currentUser;
  String? get currentUid => _supabase.auth.currentUser?.id;
  bool get isAuthenticated => _supabase.auth.currentUser != null;
  GamerUser? get currentGamer => currentGamerNotifier.value;

  Stream<User?> get authStateChanges => _supabase.auth.onAuthStateChange.map((event) => event.session?.user);

  static String _cacheKey(String uid) => 'cached_gamer_profile_$uid';

  Future<void> _cacheGamerProfile(GamerUser user) async {
    if (user.uid.isEmpty || user.username.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(user.uid), jsonEncode(user.toMap()));
    } catch (_) {}
  }

  Future<GamerUser?> _loadCachedGamerProfile(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(uid));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final gamer = GamerUser.fromMap(Map<String, dynamic>.from(decoded), uid);
        if (gamer.username.trim().isNotEmpty) {
          return gamer;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _clearCachedGamerProfile(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey(uid));
      await prefs.remove('user_age_$uid');
    } catch (_) {}
  }

  Future<GamerUser> _hydrateLocalAge(GamerUser gamer) async {
    if (gamer.age != null || gamer.uid.isEmpty) return gamer;
    try {
      final prefs = await SharedPreferences.getInstance();
      final localAge = prefs.getInt('user_age_${gamer.uid}');
      if (localAge != null) {
        return gamer.copyWith(age: localAge);
      }
    } catch (_) {}
    return gamer;
  }

  Future<void> init() async {
    _authSubscription?.cancel();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      authUserNotifier.value = user;
      if (user != null) {
        if (currentGamerNotifier.value == null || currentGamerNotifier.value!.uid != user.id) {
          final cached = await _loadCachedGamerProfile(user.id);
          if (cached != null) {
            currentGamerNotifier.value = cached;
            isLoadingNotifier.value = false;
          } else {
            isLoadingNotifier.value = true;
          }
        }
        await refreshCurrentGamer();
      } else {
        currentGamerNotifier.value = null;
        profileLoadErrorNotifier.value = false;
        isLoadingNotifier.value = false;
      }
    });

    final initialUser = _supabase.auth.currentUser;
    authUserNotifier.value = initialUser;
    if (initialUser != null) {
      try {
        NotificationService().subscribeToUser(initialUser.id);
      } catch (_) {}
      final cached = await _loadCachedGamerProfile(initialUser.id);
      if (cached != null) {
        currentGamerNotifier.value = cached;
        profileLoadErrorNotifier.value = false;
        isLoadingNotifier.value = false;
        // Refresh silently in background without blocking startup
        unawaited(refreshCurrentGamer());
      } else {
        isLoadingNotifier.value = true;
        await refreshCurrentGamer();
      }
    } else {
      currentGamerNotifier.value = null;
      profileLoadErrorNotifier.value = false;
      isLoadingNotifier.value = false;
    }
  }

  Future<(Map<String, dynamic>?, bool)> _fetchProfileRow(String authUserId) async {
    try {
      final res = await _supabase
          .from('users')
          .select()
          .or('id.eq.$authUserId,uid.eq.$authUserId')
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      return (res, true);
    } catch (_) {
      try {
        final res = await _supabase
            .from('users')
            .select()
            .eq('id', authUserId)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
        return (res, true);
      } catch (_) {
        try {
          final res = await _supabase
              .from('users')
              .select()
              .eq('uid', authUserId)
              .maybeSingle()
              .timeout(const Duration(seconds: 5));
          return (res, true);
        } catch (_) {
          return (null, false);
        }
      }
    }
  }

  /// Internal sync and load user profile from Supabase users table
  Future<void> _syncAndLoadUser(User user) async {
    try {
      final authUserId = user.id;
      final (profile, querySucceeded) = await _fetchProfileRow(authUserId);

      if (querySucceeded && profile != null) {
        final gamer = await _hydrateLocalAge(GamerUser.fromMap(profile, authUserId));
        currentGamerNotifier.value = gamer;
        profileLoadErrorNotifier.value = false;
        await _cacheGamerProfile(gamer);
      } else if (querySucceeded && profile == null) {
        final cached = await _loadCachedGamerProfile(authUserId);
        if (cached != null) {
          currentGamerNotifier.value = cached;
          profileLoadErrorNotifier.value = false;
        } else {
          // User genuinely has no row in users table yet (new signup)
          final initialGamer = GamerUser(
            uid: authUserId,
            username: '',
            displayName: user.userMetadata?['full_name']?.toString() ??
                user.userMetadata?['name']?.toString() ??
                (user.email?.split('@').first ?? 'Gamer'),
            photoUrl: user.userMetadata?['avatar_url']?.toString() ??
                user.userMetadata?['picture']?.toString() ??
                '',
            coverUrl: '',
            bio: '',
            favoriteGame: 'BGMI',
            selectedGame: 'BGMI',
            selectedRank: 'Bronze',
            rank: 'Bronze',
            coins: 100,
          );
          currentGamerNotifier.value = initialGamer;
          profileLoadErrorNotifier.value = false;
        }
      } else {
        // Network error / timeout: preserve existing or cached profile rather than forcing CreateGamerIdScreen
        final cached = await _loadCachedGamerProfile(authUserId);
        if (currentGamerNotifier.value != null && currentGamerNotifier.value!.uid == authUserId) {
          profileLoadErrorNotifier.value = false;
        } else if (cached != null) {
          currentGamerNotifier.value = cached;
          profileLoadErrorNotifier.value = false;
        } else {
          profileLoadErrorNotifier.value = true;
        }
      }

      try {
        NotificationService().subscribeToUser(authUserId);
        NotificationService().saveUserFcmToken(authUserId);
      } catch (_) {}

      // Check and award 1000 coins welcome bonus on first signup
      checkAndAwardWelcomeBonus(authUserId);
    } catch (e) {
      debugPrint('[GamerAuthService] Error syncing user: $e');
      final cached = await _loadCachedGamerProfile(user.id);
      if (currentGamerNotifier.value != null && currentGamerNotifier.value!.uid == user.id) {
        profileLoadErrorNotifier.value = false;
      } else if (cached != null) {
        currentGamerNotifier.value = cached;
        profileLoadErrorNotifier.value = false;
      } else {
        profileLoadErrorNotifier.value = true;
      }
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  /// Refresh current gamer profile from Supabase
  Future<GamerUser?> refreshCurrentGamer() {
    if (_inFlightRefresh != null) return _inFlightRefresh!;
    final future = _doRefreshCurrentGamer();
    _inFlightRefresh = future;
    future.whenComplete(() {
      if (identical(_inFlightRefresh, future)) {
        _inFlightRefresh = null;
      }
    });
    return future;
  }

  Future<GamerUser?> _doRefreshCurrentGamer() async {
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
      currentGamerNotifier.value = null;
      profileLoadErrorNotifier.value = false;
      isLoadingNotifier.value = false;
      return null;
    }

    try {
      final (profile, querySucceeded) = await _fetchProfileRow(authUser.id);

      if (querySucceeded && profile != null) {
        final gamer = await _hydrateLocalAge(GamerUser.fromMap(profile, authUser.id));
        currentGamerNotifier.value = gamer;
        profileLoadErrorNotifier.value = false;
        await _cacheGamerProfile(gamer);
        return gamer;
      } else if (querySucceeded && profile == null) {
        final cached = await _loadCachedGamerProfile(authUser.id);
        if (cached != null) {
          currentGamerNotifier.value = cached;
          profileLoadErrorNotifier.value = false;
          return cached;
        }
        // User has no row in users table yet (new signup)
        final initialGamer = GamerUser(
          uid: authUser.id,
          username: '',
          displayName: authUser.userMetadata?['full_name']?.toString() ??
              authUser.userMetadata?['name']?.toString() ??
              (authUser.email?.split('@').first ?? 'Gamer'),
          photoUrl: authUser.userMetadata?['avatar_url']?.toString() ??
              authUser.userMetadata?['picture']?.toString() ??
              '',
          coverUrl: '',
          bio: '',
          favoriteGame: 'BGMI',
          selectedGame: 'BGMI',
          selectedRank: 'Bronze',
          rank: 'Bronze',
          coins: 100,
        );
        currentGamerNotifier.value = initialGamer;
        profileLoadErrorNotifier.value = false;
        return initialGamer;
      } else {
        // Network error / timeout: preserve existing or cached profile
        if (currentGamerNotifier.value != null && currentGamerNotifier.value!.uid == authUser.id) {
          profileLoadErrorNotifier.value = false;
          return currentGamerNotifier.value;
        }
        final cached = await _loadCachedGamerProfile(authUser.id);
        if (cached != null) {
          currentGamerNotifier.value = cached;
          profileLoadErrorNotifier.value = false;
          return cached;
        }
        profileLoadErrorNotifier.value = true;
        return null;
      }
    } catch (e) {
      debugPrint('[GamerAuthService] Error refreshing gamer: $e');
      if (currentGamerNotifier.value != null && currentGamerNotifier.value!.uid == authUser.id) {
        profileLoadErrorNotifier.value = false;
        return currentGamerNotifier.value;
      }
      final cached = await _loadCachedGamerProfile(authUser.id);
      if (cached != null) {
        currentGamerNotifier.value = cached;
        profileLoadErrorNotifier.value = false;
        return cached;
      }
      profileLoadErrorNotifier.value = true;
      return null;
    } finally {
      isLoadingNotifier.value = false;
    }
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

  /// Google Sign In:
  /// 1. Tries Native Google Sign-In (via Google Play Services & idToken) using Google Cloud Console SHA-1 & webClientId.
  /// 2. If Native Sign-In is cancelled by user, returns false cleanly without error.
  /// 3. If Native Sign-In fails or webClientId is absent, falls back to Supabase Web OAuth Flow.
  /// 4. Protected with explicit timeouts so UI never hangs indefinitely.
  Future<bool> signInWithGoogle({String? webClientId}) async {
    final effectiveWebClientId = (webClientId ?? SupabaseService.webClientId).trim();

    // ─── STEP 1: ATTEMPT NATIVE GOOGLE SIGN-IN (Play Services) ───
    try {
      debugPrint('[GamerAuthService] Starting Native Google Sign-In (webClientId: "$effectiveWebClientId")');
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: effectiveWebClientId.isNotEmpty ? effectiveWebClientId : null,
        scopes: const ['email', 'profile'],
      );

      // Sign out first to ensure account chooser dialog appears cleanly
      try {
        await googleSignIn.signOut().timeout(const Duration(seconds: 2));
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Google Sign-In prompt timed out after 15 seconds'),
      );

      if (googleUser == null) {
        debugPrint('[GamerAuthService] Google Sign-In cancelled by user.');
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication.timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('Retrieving Google authentication tokens timed out'),
      );

      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken != null && idToken.isNotEmpty) {
        debugPrint('[GamerAuthService] Native Google Sign-In succeeded, authenticating with Supabase signInWithIdToken...');
        await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Supabase token exchange timed out after 10 seconds'),
        );

        final user = _supabase.auth.currentUser;
        if (user != null) {
          authUserNotifier.value = user;
          await refreshCurrentGamer().timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
        }

        debugPrint('[GamerAuthService] Supabase signInWithIdToken successfully completed!');
        return true;
      } else {
        debugPrint('[GamerAuthService] idToken is null (serverClientId / Web Client ID missing or misconfigured). Falling back to OAuth...');
      }
    } on PlatformException catch (pe) {
      debugPrint('[GamerAuthService] PlatformException during native GoogleSignIn: code=${pe.code}, msg=${pe.message}');
      if (pe.code == 'sign_in_canceled') {
        return false;
      }
      debugPrint('[GamerAuthService] Attempting Supabase OAuth fallback due to PlatformException (${pe.code})...');
    } catch (e) {
      debugPrint('[GamerAuthService] Native GoogleSignIn exception: $e. Falling back to Supabase OAuth...');
    }

    // ─── STEP 2: FALLBACK TO SUPABASE OAUTH BROWSER FLOW ───
    try {
      debugPrint('[GamerAuthService] Launching Supabase OAuth Google flow...');
      final launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.gameskhabar://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Browser launch timed out after 10 seconds'),
      );
      return launched;
    } on AuthException catch (ae) {
      debugPrint('[GamerAuthService] Supabase AuthException: ${ae.message}');
      throw Exception('Supabase Auth: ${ae.message}');
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

  /// Creates or updates `users` record in Supabase reliably.
  /// Persists guaranteed base schema columns first (including `username` and `game_id`),
  /// then best-effort updates optional extended columns so missing columns never break saves.
  Future<bool> saveGamerProfile(GamerUser user) async {
    try {
      final cleanUsername = user.username.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
      final cleanGameId = user.gameId.trim();
      final cleanDisplayName = user.displayName.trim().isNotEmpty ? user.displayName.trim() : cleanUsername;
      final authEmail = _supabase.auth.currentUser?.email?.trim() ?? '';

      final corePayload = <String, dynamic>{
        'uid': user.uid,
        if (authEmail.isNotEmpty) 'email': authEmail,
        'username': cleanUsername,
        'display_name': cleanDisplayName,
        'avatar_url': user.photoUrl,
        'cover_url': user.coverUrl,
        'bio': user.bio.trim(),
        'game_id': cleanGameId,
        'game_name': user.favoriteGame.isNotEmpty ? user.favoriteGame : 'BGMI',
        'gamer_rank': user.rank.isNotEmpty ? user.rank : 'Bronze',
        if (user.rankScreenshot.isNotEmpty) 'rank_proof_url': user.rankScreenshot,
        'coins': user.coins,
        'is_verified': user.isVerified,
        'updated_at': DateTime.now().toIso8601String(),
      };

      Map<String, dynamic>? existingRow;
      try {
        existingRow = await _supabase
            .from('users')
            .select('id, uid')
            .or('id.eq.${user.uid},uid.eq.${user.uid}')
            .maybeSingle();
      } catch (_) {}

      bool coreSaved = false;
      if (existingRow != null && existingRow['id'] != null) {
        await _supabase
            .from('users')
            .update(corePayload)
            .eq('id', existingRow['id'].toString());
        coreSaved = true;
      } else {
        final insertPayload = <String, dynamic>{
          'id': SupabaseService.toUuid(user.uid),
          ...corePayload,
        };
        try {
          await _supabase.from('users').insert(insertPayload);
          coreSaved = true;
        } catch (insertError) {
          debugPrint('[GamerAuthService] insert fallback to upsert: $insertError');
          await _supabase.from('users').upsert(insertPayload);
          coreSaved = true;
        }
      }

      // Best-effort update for optional extended columns (ignore if any column is absent in DB)
      final extendedPayload = <String, dynamic>{
        'favorite_game': user.favoriteGame,
        'selected_game': user.selectedGame.isNotEmpty ? user.selectedGame : user.favoriteGame,
        'rank': user.rank.isNotEmpty ? user.rank : 'Bronze',
        'selected_rank': user.selectedRank.isNotEmpty ? user.selectedRank : 'Bronze',
        'is_rank_verified': user.isRankVerified,
        'rank_status': user.rankStatus.isNotEmpty ? user.rankStatus : 'none',
        'active_frame': user.activeFrame,
        'active_badge': user.activeBadge,
        if (user.age != null) 'age': user.age,
        'updated_at': DateTime.now().toIso8601String(),
      };
      try {
        await _supabase
            .from('users')
            .update(extendedPayload)
            .or('id.eq.${user.uid},uid.eq.${user.uid}');
      } catch (extError) {
        debugPrint('[GamerAuthService] optional extended update note: $extError');
      }

      if (coreSaved) {
        try {
          final prefs = await SharedPreferences.getInstance();
          if (user.age != null) {
            await prefs.setInt('user_age_${user.uid}', user.age!);
          } else {
            await prefs.remove('user_age_${user.uid}');
          }
        } catch (_) {}
        final savedUser = user.copyWith(
          username: cleanUsername,
          displayName: cleanDisplayName,
          gameId: cleanGameId,
        );
        currentGamerNotifier.value = savedUser;
        profileLoadErrorNotifier.value = false;
        await _cacheGamerProfile(savedUser);
        unawaited(checkAndAwardWelcomeBonus(user.uid));
      }
      return coreSaved;
    } catch (e) {
      debugPrint('[GamerAuthService] Error saving gamer profile in Supabase: $e');
      rethrow;
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
        await _supabase
            .from('users')
            .update(updates)
            .or('id.eq.$uid,uid.eq.$uid');
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
    final uidToClear = currentUid ?? currentGamerNotifier.value?.uid ?? '';
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('[GamerAuthService] Supabase signOut error: $e');
    }
    try {
      await SupabaseService.signOut();
    } catch (_) {}
    if (uidToClear.isNotEmpty) {
      await _clearCachedGamerProfile(uidToClear);
    }
    currentGamerNotifier.value = null;
    profileLoadErrorNotifier.value = false;
    isLoadingNotifier.value = false;
  }

  Future<void> signOut() => logout();
}