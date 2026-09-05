import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/gamer_user_model.dart';

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

  /// Sign In with Email & Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await refreshCurrentGamer();
    return cred;
  }

  /// Sign Up with Email & Password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await refreshCurrentGamer();
    return cred;
  }

  /// Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      await refreshCurrentGamer();
      return cred;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  /// Quick Anonymous / Guest Sign In for instant access and testing
  Future<UserCredential> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    await refreshCurrentGamer();
    return cred;
  }

  /// Uploads photo: attempts Firebase Storage, with fallback to base64 data URI
  Future<String> uploadProfilePhoto(File imageFile, String uid) async {
    try {
      final ref = _storage.ref().child('gamer_profiles').child('$uid.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = await ref.putFile(imageFile, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Storage upload failed, falling back to base64 encoding: $e');
      final bytes = await imageFile.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
  }

  /// Creates or updates `users/{uid}` document
  Future<void> saveGamerProfile(GamerUser user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final exists = (await docRef.get()).exists;

    if (!exists) {
      await docRef.set(user.toMap(), SetOptions(merge: true));
    } else {
      await docRef.update(user.toMap());
    }

    currentGamerNotifier.value = user;
  }

  /// Fetch any user's profile by UID
  Future<GamerUser?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return GamerUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile $uid: $e');
      return null;
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

  /// Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
    currentGamerNotifier.value = null;
  }
}
