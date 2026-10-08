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

/// Fallback email-based admin check (owner)
bool isEmailAdmin(String? email) {
  if (email == null) return false;
  return email.trim().toLowerCase() == 'tufailm483@gmail.com';
}

/// Primary admin check — reads `is_admin` from Supabase users table.
/// Priority: is_admin column > owner email fallback.
Future<bool> checkIsAdmin() async {
  try {
    // 1. Check Supabase Auth current user
    final sbUserId = SupabaseService.client.auth.currentUser?.id;
    if (sbUserId != null) {
      final userData = await SupabaseService.query(
        'users',
        select: 'is_admin,email',
        filters: {'id': 'eq.$sbUserId'},
        limit: 1,
      );
      if (userData.isNotEmpty) {
        final data = userData.first;
        if (data['is_admin'] == true) return true;
        if (isEmailAdmin(data['email']?.toString())) return true;
      }
    }

    // 2. Fallback to GamerAuthService current user
    final user = GamerAuthService().currentUser;
    if (user != null) {
      if (isEmailAdmin(user.email)) return true;
      final userData = await SupabaseService.query(
        'users',
        select: 'is_admin,email',
        filters: {'uid': 'eq.${user.id}'},
        limit: 1,
      );
      if (userData.isNotEmpty) {
        final data = userData.first;
        if (data['is_admin'] == true) return true;
        if (isEmailAdmin(data['email']?.toString())) return true;
      }
    }
  } catch (e) {
    debugPrint('[AdminSecurity] checkIsAdmin error: $e');
  }
  return false;
}

/// Synchronous version for quick UI checks (uses cached session)
bool isAdminUser({Map<String, dynamic>? userDocData, bool? docIsAdmin}) {
  try {
    if (docIsAdmin == true) return true;
    if (userDocData != null &&
        (userDocData['is_admin'] == true || userDocData['isAdmin'] == true)) {
      return true;
    }
    final user = GamerAuthService().currentUser;
    if (user != null && isEmailAdmin(user.email)) return true;
  } catch (_) {}
  return false;
}

/// Realtime stream of current user's admin state
Stream<bool> watchIsAdmin() {
  try {
    final sbUserId = SupabaseService.client.auth.currentUser?.id;
    if (sbUserId == null) return Stream.value(false);

    return SupabaseService.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', sbUserId)
        .map((rows) {
      if (rows.isEmpty) return false;
      final data = rows.first;
      return data['is_admin'] == true ||
          data['isAdmin'] == true ||
          isEmailAdmin(data['email']?.toString());
    });
  } catch (e) {
    return Stream.value(false);
  }
}

/// Confirmation dialog before performing admin actions
Future<bool> promptAdminPinDialog(BuildContext context) async {
  final ok = await checkIsAdmin();
  if (!ok) {
    if (context.mounted) {
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
    }
    return false;
  }
  return true;
}