import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// In-memory Admin Session manager to synchronize with Firebase Authentication
class AdminSession {
  static bool _isLoggedIn = false;
  static String? _adminEmail;

  static bool get isLoggedIn {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return (user != null) || _isLoggedIn;
    } catch (_) {
      return _isLoggedIn;
    }
  }

  static String? get adminEmail {
    try {
      return FirebaseAuth.instance.currentUser?.email ?? _adminEmail;
    } catch (_) {
      return _adminEmail;
    }
  }

  static void setLoggedIn(String email) {
    _isLoggedIn = true;
    _adminEmail = email.trim();
  }

  static void logout() {
    _isLoggedIn = false;
    _adminEmail = null;
    try {
      FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}

/// Checks if currently authenticated user is signed in with Firebase Auth
bool isAdminUser() {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && user.email!.isNotEmpty) {
      return true;
    }
  } catch (_) {}
  return AdminSession.isLoggedIn;
}

/// Optional confirmation dialog before performing admin actions
Future<bool> promptAdminPinDialog(BuildContext context) async {
  if (!isAdminUser()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFFFF4655),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Access Denied - Please login as Admin first',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
    return false;
  }
  return true;
}
