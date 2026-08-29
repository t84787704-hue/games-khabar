import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const String kAdminEmail = 't84787704@gmail.com';

/// Checks if currently authenticated user is the designated admin
bool isAdminUser() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final email = (user.email ?? '').trim().toLowerCase();
  return email == kAdminEmail.toLowerCase();
}

/// Security PIN/Password verification dialog before opening Add/Edit News screen
Future<bool> promptAdminPinDialog(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  final userEmail = (user?.email ?? '').trim().toLowerCase();

  // Strict email validation
  if (user == null || userEmail != kAdminEmail.toLowerCase()) {
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
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF00FF88), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        kAdminEmail,
                        style: const TextStyle(
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
                'Enter Admin PIN / Password to continue:',
                style: TextStyle(color: Color(0xFF9E9EA7), fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                obscureText: obscureText,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: 'Enter PIN or Password',
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
                Navigator.pop(ctx, true);
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
