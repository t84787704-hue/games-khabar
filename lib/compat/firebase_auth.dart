import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../services/supabase_service.dart';

/// Compatibility layer for FirebaseAuth backed 100% by Supabase Auth
class FirebaseAuth {
  static final FirebaseAuth instance = FirebaseAuth._();
  FirebaseAuth._();

  sb.SupabaseClient get _sbClient => SupabaseService.client;

  User? get currentUser {
    final sbUser = _sbClient.auth.currentUser;
    if (sbUser == null) return null;
    return User.fromSupabase(sbUser);
  }

  Stream<User?> authStateChanges() {
    return _sbClient.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      if (user == null) return null;
      return User.fromSupabase(user);
    });
  }

  Future<void> signOut() async {
    try {
      await _sbClient.auth.signOut();
    } catch (_) {}
    try {
      await SupabaseService.signOut();
    } catch (_) {}
  }

  Future<UserCredential> signInAnonymously() async {
    // If guest sign in is triggered, ensure current session or return dummy
    final current = currentUser;
    if (current != null) {
      return UserCredential(user: current);
    }
    return UserCredential(
      user: User(
        uid: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        email: 'guest@gamersid.local',
        displayName: 'Guest Gamer',
      ),
    );
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _sbClient.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = res.user != null ? User.fromSupabase(res.user!) : null;
      return UserCredential(user: user);
    } catch (e) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: e.toString(),
      );
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _sbClient.auth.signUp(
        email: email.trim(),
        password: password,
      );
      final user = res.user != null ? User.fromSupabase(res.user!) : null;
      return UserCredential(user: user);
    } catch (e) {
      throw FirebaseAuthException(
        code: 'signup-error',
        message: e.toString(),
      );
    }
  }

  Future<UserCredential> signInWithCredential(dynamic credential) async {
    final current = currentUser;
    return UserCredential(user: current);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _sbClient.auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      debugPrint('[Compat FirebaseAuth] reset password error: $e');
    }
  }
}

class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final UserMetadata metadata;

  User({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    UserMetadata? metadata,
  }) : metadata = metadata ?? UserMetadata(creationTime: DateTime.now());

  factory User.fromSupabase(sb.User sbUser) {
    final meta = sbUser.userMetadata ?? {};
    final createdAt = sbUser.createdAt.isNotEmpty ? DateTime.tryParse(sbUser.createdAt) : DateTime.now();
    return User(
      uid: sbUser.id,
      email: sbUser.email,
      displayName: meta['full_name'] ?? meta['name'] ?? meta['display_name'] ?? meta['username'],
      photoURL: meta['avatar_url'] ?? meta['picture'] ?? meta['photo_url'],
      metadata: UserMetadata(creationTime: createdAt ?? DateTime.now()),
    );
  }
}

class UserMetadata {
  final DateTime? creationTime;
  final DateTime? lastSignInTime;

  UserMetadata({this.creationTime, this.lastSignInTime});
}

class UserCredential {
  final User? user;
  UserCredential({this.user});
}

class OAuthCredential {
  final String? accessToken;
  final String? idToken;
  OAuthCredential({this.accessToken, this.idToken});
}

class GoogleAuthProvider {
  static OAuthCredential credential({String? accessToken, String? idToken}) {
    return OAuthCredential(accessToken: accessToken, idToken: idToken);
  }
}

class FirebaseAuthException implements Exception {
  final String code;
  final String? message;
  FirebaseAuthException({required this.code, this.message});

  @override
  String toString() => 'FirebaseAuthException($code, $message)';
}
