import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gamer_user_model.dart';
import 'supabase_service.dart';
import 'notification_service.dart';

class GamerAuthService {
  static final GamerAuthService _instance = GamerAuthService._internal();
  factory GamerAuthService() => _instance;
  GamerAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final ValueNotifier<GamerUser?> currentGamerNotifier = ValueNotifier<GamerUser?>(null);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(true);

  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;
  GamerUser? get currentGamer => currentGamerNotifier.value;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> init() async {
    _auth.authStateChanges().listen((user) async {
      _userDocSubscription?.cancel();
      _userDocSubscription = null;

      if (user != null) {
        // Setup real-time listener for current user's document
        _listenToUserDoc(user.uid);
      } else {
        currentGamerNotifier.value = null;
        isLoadingNotifier.value = false;
      }
    });
  }

  void _listenToUserDoc(String uid) {
    _userDocSubscription?.cancel();

    // Safety timeout: Never allow loading screen to hang forever
    Future.delayed(const Duration(seconds: 4), () {
      if (isLoadingNotifier.value) {
        debugPrint('[AuthService] Loading safety timeout triggered.');
        isLoadingNotifier.value = false;
      }
    });

    _userDocSubscription = _firestore.collection('users').doc(uid).snapshots().listen(
      (doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['coins'] == null) {
            _firestore.collection('users').doc(uid).set({'coins': 100}, SetOptions(merge: true));
          }
          final gamer = GamerUser.fromFirestore(doc);
          if (gamer.isOwnerUser && (!gamer.isBlueTickVerified || gamer.blueTickStatus != 'approved')) {
            _firestore.collection('users').doc(uid).set({
              'isBlueTickVerified': true,
              'blueTickVerified': true,
              'blueTickStatus': 'approved',
              'isVerified': true,
              'isVerifiedBlue': true,
              'verificationStatus': 'verified',
              'isOwner': true,
            }, SetOptions(merge: true));
          }
          currentGamerNotifier.value = gamer;
          isLoadingNotifier.value = false;
        } else {
          currentGamerNotifier.value = null;
          isLoadingNotifier.value = false;
        }
      },
      onError: (err) {
        debugPrint('[AuthService] Error in user doc listener: $err');
        isLoadingNotifier.value = false;
      },
    );
  }

  Future<GamerUser?> refreshCurrentGamer() async {
    final uid = currentUid;
    if (uid == null) {
      currentGamerNotifier.value = null;
      isLoadingNotifier.value = false;
      return null;
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['coins'] == null) {
          await _firestore.collection('users').doc(uid).set({'coins': 100}, SetOptions(merge: true));
        }
        final gamer = GamerUser.fromFirestore(doc);
        currentGamerNotifier.value = gamer;
        isLoadingNotifier.value = false;
        return gamer;
      } else {
        // User is logged in to FirebaseAuth but has not created Gamer ID yet
        currentGamerNotifier.value = null;
        isLoadingNotifier.value = false;
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching gamer user: $e');
      isLoadingNotifier.value = false;
      return null;
    }
  }

  /// Checks live if a username is available in Firestore & Supabase
  Future<bool> isUsernameAvailable(String username, {String? currentUid}) async {
    final clean = username.toLowerCase().trim();
    if (clean.length < 3) return false;

    try {
      final sbUsers = await SupabaseService.query('users', filters: {'username': 'eq.$clean'}, limit: 1);
      if (sbUsers.isNotEmpty) {
        if (currentUid != null && sbUsers.first['uid'] == currentUid) {
          return true;
        }
        return false;
      }
    } catch (_) {}

    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: clean)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return true;
      if (currentUid != null && query.docs.first.id == currentUid) {
        return true; // It's their own username
      }
      return false;
    } catch (e) {
      debugPrint('Error checking username: $e');
      return true;
    }
  }

  /// Login with Email & Password
  /// Catches 'invalid-credential' or 'user-token-expired', signs out, clears local storage,
  /// performs auto-retry once after signOut, and returns user-friendly Urdu message.
  Future<UserCredential> login(String email, String password, {bool isRetry = false}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Synchronize with Supabase Auth
      try {
        await SupabaseService.signInWithEmail(email: email.trim(), password: password);
      } catch (sbErr) {
        debugPrint('Supabase signin sync notice: $sbErr');
      }
      await refreshCurrentGamer();
      return cred;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' || e.code == 'user-token-expired') {
        debugPrint('[AuthService] Caught ${e.code}. Signing out and clearing local storage...');
        try {
          await _auth.signOut();
        } catch (_) {}
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
        } catch (storageErr) {
          debugPrint('[AuthService] Storage clear error: $storageErr');
        }

        // Add auto-retry once after signOut
        if (!isRetry) {
          try {
            debugPrint('[AuthService] Auto-retrying login once after signOut...');
            return await login(email, password, isRetry: true);
          } catch (retryErr) {
            debugPrint('[AuthService] Retry failed: $retryErr');
          }
        }

        // Then show user friendly message in Urdu instead of raw Firebase error
        throw FirebaseAuthException(
          code: e.code,
          message: 'Session khatam ho gaya hai, dobara login karen',
        );
      }
      rethrow;
    }
  }

  /// Sign In with Email & Password (delegates to login)
  Future<UserCredential> signInWithEmail(String email, String password) => login(email, password);

  /// Sign Up with Email & Password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Synchronize with Supabase Auth and insert into public.users table immediately
    try {
      final cleanEmail = email.trim();
      final defaultUsername = cleanEmail.split('@').first;
      final authRes = await SupabaseService.signUpWithEmail(
        email: cleanEmail,
        password: password,
        userMetadata: {
          'app': 'GAMERS ID NETWORK',
          'uid': cred.user?.uid,
          'username': defaultUsername,
          'display_name': defaultUsername,
        },
      );

      final supabaseAuthId = authRes?['user']?['id']?.toString() ?? cred.user?.uid;
      if (supabaseAuthId != null) {
        await SupabaseService.client.from('users').upsert({
          'id': supabaseAuthId,
          'uid': supabaseAuthId,
          'email': cleanEmail,
          'username': defaultUsername,
          'display_name': defaultUsername,
          'avatar_url': '',
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('[AuthService] Supabase user row created successfully: $supabaseAuthId');
      }
    } catch (sbErr) {
      debugPrint('Supabase signup & user sync notice: $sbErr');
    }
    await refreshCurrentGamer();
    return cred;
  }

  /// Google Sign In / loginWithGoogle
  /// First calls GoogleSignIn().signOut() then GoogleSignIn().signIn() to force account chooser
  Future<UserCredential?> loginWithGoogle() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      print("LOGGED IN UID: ${cred.user?.uid} | EMAIL: ${cred.user?.email}");
      await refreshCurrentGamer();
      NotificationService().saveUserFcmToken(cred.user?.uid);
      return cred;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  /// Alias for loginWithGoogle
  Future<UserCredential?> signInWithGoogle() => loginWithGoogle();

  /// Quick Anonymous / Guest Sign In for instant access and testing
  Future<UserCredential> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    await refreshCurrentGamer();
    return cred;
  }

  /// Sign Up with Supabase Auth
  Future<Map<String, dynamic>?> signUpWithSupabase({
    required String email,
    required String password,
    String? username,
    String? displayName,
    String? avatarUrl,
  }) async {
    final cleanEmail = email.trim();
    final defaultUsername = username ?? cleanEmail.split('@').first;
    final defaultDisplayName = displayName ?? defaultUsername;

    final res = await SupabaseService.signUpWithEmail(
      email: cleanEmail,
      password: password,
      userMetadata: {
        'username': defaultUsername,
        'display_name': defaultDisplayName,
        'app': 'GAMERS ID NETWORK',
      },
    );

    final supabaseAuthId = res?['user']?['id']?.toString();
    if (supabaseAuthId != null) {
      try {
        await SupabaseService.client.from('users').upsert({
          'id': supabaseAuthId,
          'uid': supabaseAuthId,
          'email': cleanEmail,
          'username': defaultUsername,
          'display_name': defaultDisplayName,
          'avatar_url': avatarUrl ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('[AuthService] Supabase user record created for $supabaseAuthId');
      } catch (e) {
        debugPrint('[AuthService] Error writing user to Supabase table: $e');
      }
    }
    return res;
  }

  /// Sign In with Supabase Auth
  Future<Map<String, dynamic>?> signInWithSupabase({
    required String email,
    required String password,
  }) async {
    final res = await SupabaseService.signInWithEmail(
      email: email,
      password: password,
    );
    return res;
  }

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
      debugPrint('Supabase avatar upload notice: $e');
    }

    try {
      final ref = _storage.ref().child('gamer_profiles').child('$uid.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = await ref.putFile(imageFile, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Storage upload failed: $e');
      return '';
    }
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
      debugPrint('Supabase cover upload notice: $e');
    }

    try {
      final ref = _storage.ref().child('gamer_covers').child('$uid.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = await ref.putFile(imageFile, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Storage cover upload failed: $e');
      return '';
    }
  }

  /// Uploads rank proof screenshot to Supabase Storage
  Future<String> uploadRankScreenshot(File imageFile, String uid) async {
    try {
      final url = await SupabaseService.uploadFile(
        file: imageFile,
        folder: 'rank_proofs',
        bucket: SupabaseService.bucketMatchProofs,
        customFileName: 'rank_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (e) {
      debugPrint('Supabase rank screenshot upload notice: $e');
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('rank_proofs').child(uid).child('rank_$timestamp.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = await ref.putFile(imageFile, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Storage rank screenshot upload failed: $e');
      try {
        final bytes = await imageFile.readAsBytes();
        final base64String = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64String';
      } catch (b64Error) {
        debugPrint('Base64 fallback failed: $b64Error');
        return '';
      }
    }
  }

  /// Creates or updates `users/{uid}` document
  Future<void> saveGamerProfile(GamerUser user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    final exists = doc.exists;

    final userMap = user.toMap();
    if (!exists) {
      if (userMap['coins'] == null) userMap['coins'] = 100;
      await docRef.set(userMap, SetOptions(merge: true));
    } else {
      final existingCoins = doc.data()?['coins'];
      if (existingCoins != null) {
        userMap['coins'] = existingCoins;
      } else if (userMap['coins'] == null) {
        userMap['coins'] = 100;
      }
      await docRef.update(userMap);
    }

    final realCoins = (userMap['coins'] as num?)?.toInt() ?? user.coins;
    currentGamerNotifier.value = user.copyWith(coins: realCoins);

    // Synchronize user profile with Supabase public.users table
    try {
      final userEmail = userMap['email']?.toString() ?? user.email;
      final supabaseUser = {
        'id': user.uid,
        'uid': user.uid,
        'username': user.username,
        'email': userEmail,
        'display_name': user.displayName,
        'avatar_url': user.photoUrl,
        'cover_url': user.coverUrl,
        'bio': user.bio,
        'game_id': user.gameId,
        'game_name': user.gameName,
        'gamer_rank': user.gamerRank,
        'coins': realCoins,
        'is_verified': user.isVerified,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await SupabaseService.client.from('users').upsert(supabaseUser);
    } catch (e) {
      debugPrint('Supabase user sync error: $e');
    }
  }

  /// Fetch any user's profile by UID
  Future<GamerUser?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        if (data['coins'] == null) {
          await _firestore.collection('users').doc(uid).set({'coins': 100}, SetOptions(merge: true));
        }
        return GamerUser.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Firestore get user profile $uid notice: $e');
    }

    try {
      final sbUser = await SupabaseService.getUser(uid);
      if (sbUser != null) {
        return GamerUser.fromMap(sbUser);
      }
    } catch (e) {
      debugPrint('Supabase get user profile $uid error: $e');
    }
    return null;
  }

  /// Alias for getUserProfile
  Future<GamerUser?> fetchUserProfile(String uid) => getUserProfile(uid);

  /// Updates profile fields for current user
  Future<void> updateProfile({
    String? rank,
    double? kdRatio,
    String? gameId,
    String? bio,
    String? displayName,
    String? photoUrl,
    String? verificationStatus,
  }) async {
    final uid = currentUid;
    if (uid == null) return;
    final Map<String, dynamic> updates = {};
    if (rank != null) updates['rank'] = rank;
    if (kdRatio != null) updates['kdRatio'] = kdRatio;
    if (gameId != null) updates['gameId'] = gameId;
    if (bio != null) updates['bio'] = bio;
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (verificationStatus != null) updates['verificationStatus'] = verificationStatus;

    if (updates.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid).update(updates);
        await refreshCurrentGamer();
      } catch (e) {
        debugPrint('Error updating user profile $uid: $e');
      }

      // Sync updates to Supabase users table
      try {
        final Map<String, dynamic> sbUpdates = {};
        if (rank != null) sbUpdates['gamer_rank'] = rank;
        if (gameId != null) sbUpdates['game_id'] = gameId;
        if (bio != null) sbUpdates['bio'] = bio;
        if (displayName != null) sbUpdates['display_name'] = displayName;
        if (photoUrl != null) sbUpdates['avatar_url'] = photoUrl;
        if (verificationStatus != null) sbUpdates['is_verified'] = verificationStatus == 'verified';
        if (sbUpdates.isNotEmpty) {
          sbUpdates['updated_at'] = DateTime.now().toIso8601String();
          await SupabaseService.update('users', sbUpdates, 'uid', uid);
        }
      } catch (e) {
        debugPrint('Supabase updateProfile sync notice: $e');
      }
    }
  }

  Stream<GamerUser?> userProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return GamerUser.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Complete Logout / Sign Out
  /// Signs out from FirebaseAuth, Supabase, GoogleSignIn, and calls GoogleSignIn().disconnect()
  /// to ensure Google account chooser is displayed when logging in with another account.
  Future<void> logout() async {
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
    try {
      await SupabaseService.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint("FirebaseAuth signOut error: $e");
    }
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint("GoogleSignIn signOut error: $e");
    }
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint("GoogleSignIn disconnect error: $e");
    }
    currentGamerNotifier.value = null;
    isLoadingNotifier.value = false;
  }

  /// Sign Out alias
  Future<void> signOut() => logout();
}
