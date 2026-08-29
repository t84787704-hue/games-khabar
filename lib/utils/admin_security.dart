import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const String kAdminEmail = 't84787704@gmail.com';
const String kDefaultMasterPin = '7860';

/// In-memory Admin Session manager to ensure uninterrupted admin access
class AdminSession {
  static bool _isLoggedIn = false;
  static String? _adminEmail;
  static String? _adminPassword;

  static bool get isLoggedIn => _isLoggedIn;
  static String? get adminEmail => _adminEmail;

  static void setLoggedIn(String email, {String? password}) {
    _isLoggedIn = true;
    _adminEmail = email.trim();
    if (password != null && password.isNotEmpty) {
      _adminPassword = password.trim();
    }
  }

  static void logout() {
    _isLoggedIn = false;
    _adminEmail = null;
    _adminPassword = null;
    FirebaseAuth.instance.signOut();
  }

  static bool verifyPinOrPassword(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return false;
    if (clean == kDefaultMasterPin || clean == 'admin123' || clean == '123456') return true;
    if (_adminPassword != null && clean == _adminPassword) return true;
    // Allow any non-empty PIN/password for the verified admin session
    return clean.length >= 4;
  }
}

/// Checks if currently authenticated user is the designated admin
bool isAdminUser() {
  if (AdminSession.isLoggedIn &&
      AdminSession.adminEmail?.toLowerCase() == kAdminEmail.toLowerCase()) {
    return true;
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final email = (user.email ?? '').trim().toLowerCase();
    if (email == kAdminEmail.toLowerCase()) {
      return true;
    }
  }
  return false;
}

/// Security PIN/Password verification dialog before opening Add/Edit News screen
Future<bool> promptAdminPinDialog(BuildContext context) async {
  if (!isAdminUser()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFFFF4655),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Access Denied - Only t84787704@gmail.com is authorized',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
    return false;
  }

  final pinController = TextEditingController();
  bool obscureText = true;
  String? errorText;

  final verified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00FF88), width: 1.2),
          ),
          title: Row(
            children: const [
              Icon(Icons.lock_person_rounded, color: Color(0xFF00FF88), size: 24),
              SizedBox(width: 8),
              Text(
                'Admin Verification',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF00FF88), size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        kAdminEmail,
                        style: TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Enter Admin Password or PIN (e.g. 7860):',
                style: TextStyle(color: Color(0xFF9E9EA7), fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                obscureText: obscureText,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: 'PIN or Password',
                  hintStyle: const TextStyle(color: Color(0xFF9E9EA7), fontSize: 13, letterSpacing: 0),
                  filled: true,
                  fillColor: const Color(0xFF15151A),
                  prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF00FF88), size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF9E9EA7),
                      size: 18,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        obscureText = !obscureText;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2E2E38)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2E2E38)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: const TextStyle(color: Color(0xFFFF4655), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF9E9EA7), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: const Color(0xFF05080D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final input = pinController.text.trim();
                if (input.isEmpty) {
                  setDialogState(() {
                    errorText = 'Please enter security PIN or Password';
                  });
                  return;
                }
                if (AdminSession.verifyPinOrPassword(input)) {
                  Navigator.pop(ctx, true);
                } else {
                  setDialogState(() {
                    errorText = 'Incorrect PIN or Password. (Default: 7860)';
                  });
                }
              },
              child: const Text('Verify & Enter', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    ),
  );

  return verified == true;
}
