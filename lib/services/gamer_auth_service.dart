import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gamer_user_model.dart';
import 'cloudinary_service.dart';
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

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;
  GamerUser? get currentGamer => currentGamerNotifier.value;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> init() async {
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await refreshCurrentGamer();
      } else {
        currentGamerNotifier.value = null;
        isLoadingNotifier.value = false;
      }
    });
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

  /// Checks live if a username is available in Firestore
  Future<bool> isUsernameAvailable(String username, {String? currentUid}) async {
    final clean = username.toLowerCase().trim();
    if (clean.length < 3) return false;

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

  /// Uploads user avatar photo directly to Cloudinary
  Future<String> uploadProfilePhoto(File imageFile, String uid) async {
    try {
      final url = await CloudinaryService.uploadFile(file: imageFile, folder: 'user_avatars');
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (e) {
      debugPrint('Cloudinary avatar upload notice: $e');
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

  /// Uploads user cover photo directly to Cloudinary or Firebase Storage
  Future<String> uploadCoverPhoto(File imageFile, String uid) async {
    try {
      final url = await CloudinaryService.uploadFile(file: imageFile, folder: 'user_covers');
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (e) {
      debugPrint('Cloudinary cover upload notice: $e');
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
      return null;
    } catch (e) {
      debugPrint('Error getting user profile $uid: $e');
      return null;
    }
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
  /// Signs out from FirebaseAuth, GoogleSignIn, and calls GoogleSignIn().disconnect()
  /// to ensure Google account chooser is displayed when logging in with another account.
  Future<void> logout() async {
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
