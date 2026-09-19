import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';

class BannedScreen extends StatelessWidget {
  final String? reason;

  const BannedScreen({super.key, this.reason});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Block Android back button
      child: Scaffold(
        backgroundColor: const Color(0xFF070A0F),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Banned shield icon
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF4655).withOpacity(0.15),
                      border: Border.all(color: const Color(0xFFFF4655), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4655).withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.block_flipped,
                        color: Color(0xFFFF4655),
                        size: 52,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // BANNED BADGE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4655).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
                    ),
                    child: const Text(
                      'ACCOUNT BANNED',
                      style: TextStyle(
                        color: Color(0xFFFF4655),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'Access Restricted',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  const Text(
                    'Your account has been banned by admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reason card if present
                  if (reason != null && reason!.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reason:',
                            style: TextStyle(
                              color: Color(0xFFFF4655),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reason!.trim(),
                            style: const TextStyle(
                              color: Color(0xFFC9D1D9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Support box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10141D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1F2B3E)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Contact support:',
                          style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          'tufailm483@gmail.com',
                          style: TextStyle(
                            color: GamerTheme.accentBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await GamerAuthService().signOut();
                        } catch (_) {
                          await FirebaseAuth.instance.signOut();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF21262D),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF30363D)),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Logout',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
