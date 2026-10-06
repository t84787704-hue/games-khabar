import 'package:flutter/material.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';

/// In-memory Admin Session manager to synchronize with Supabase Authentication
class AdminSession {
  static bool _isLoggedIn = false;
  static String? _adminEmail;

  static bool get isLoggedIn {
    try {
      final user = GamerAuthService().currentUser;
      return (user != null) || _isLoggedIn;
    } catch (_) {
      return _isLoggedIn;
    }
  }

  static String? get adminEmail {
    try {
      return GamerAuthService().currentUser?.email ?? _adminEmail;
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
      GamerAuthService().signOut();
    } catch (_) {}
  }
}

/// Checks if currently authenticated user is admin:
/// email == "tufailm483@gmail.com" OR userDoc is_admin / isAdmin == true
bool isEmailAdmin(String? email) {
  if (email == null) return false;
  return email.trim().toLowerCase() == 'tufailm483@gmail.com';
}

bool isAdminUser({Map<String, dynamic>? userDocData, bool? docIsAdmin}) {
  try {
    final user = GamerAuthService().currentUser;
    if (user != null && isEmailAdmin(user.email)) {
      return true;
    }
    if (docIsAdmin == true) return true;
    if (userDocData != null && (userDocData['is_admin'] == true || userDocData['isAdmin'] == true)) return true;
  } catch (_) {}
  return false;
}

/// Helper stream to watch current user's admin state in real time
Stream<bool> watchIsAdmin() {
  final user = GamerAuthService().currentUser;
  if (user == null) return Stream.value(false);
  if (isEmailAdmin(user.email)) return Stream.value(true);

  return SupabaseService.client
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((rows) {
    if (rows.isEmpty) return false;
    final data = rows.first;
    return data['is_admin'] == true || data['isAdmin'] == true || isEmailAdmin(user.email);
  });
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
