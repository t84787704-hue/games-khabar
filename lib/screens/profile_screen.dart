import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/admin_security.dart';
import 'admin_login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _logoTapCount = 0;
  bool _adminOptionUnlocked = false;

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color cardDark2 = Color(0xFF15151A);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color alertRed = Color(0xFFFF4655);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);

  @override
  void initState() {
    super.initState();
    // If already logged in as admin, check if previously unlocked
    if (isAdminUser()) {
      _adminOptionUnlocked = true;
    }
  }

  void _onLogoTapped() {
    setState(() {
      _logoTapCount++;
    });

    final currentEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim();
    final isAdmin = currentEmail == kAdminEmail.toLowerCase();

    if (_logoTapCount >= 5) {
      if (isAdmin) {
        setState(() {
          _adminOptionUnlocked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: neonGreen, width: 1.5),
            ),
            content: Row(
              children: const [
                Icon(Icons.lock_open_rounded, color: neonGreen, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Admin Panel Unlocked for t84787704@gmail.com! 🎮',
                    style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: alertRed, width: 1),
            ),
            content: Row(
              children: [
                const Icon(Icons.shield_outlined, color: alertRed, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentEmail == null
                        ? 'Admin access restricted. Please log in with $kAdminEmail'
                        : 'Access Denied - Not Admin ($currentEmail)',
                    style: const TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else if (_logoTapCount >= 2 && isAdmin) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cardDark2,
          duration: const Duration(milliseconds: 600),
          content: Text(
            'Tap ${5 - _logoTapCount} more times to reveal Admin Panel',
            style: const TextStyle(color: neonGreen, fontSize: 11),
          ),
        ),
      );
    }
  }

  Future<void> _openAdminDashboard() async {
    final verified = await promptAdminPinDialog(context);
    if (!verified) return;
    if (!mounted) return;

    Navigator.pushNamed(context, '/admin-dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userEmail = currentUser?.email;
    final isCurrentAdmin = isAdminUser();

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profile & Settings',
          style: TextStyle(
            color: textWhite,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // Secret Tap App Logo Area
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _onLogoTapped,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: cardDark,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isCurrentAdmin && _adminOptionUnlocked) ? neonGreen : borderDark,
                          width: 2,
                        ),
                        boxShadow: [
                          if (isCurrentAdmin && _adminOptionUnlocked)
                            BoxShadow(
                              color: neonGreen.withOpacity(0.25),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: neonGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'GK',
                            style: TextStyle(
                              color: Color(0xFF05080D),
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Games Khabar',
                    style: TextStyle(
                      color: textWhite,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail ?? 'Gaming Community Member',
                    style: TextStyle(
                      color: isCurrentAdmin ? neonGreen : textGray,
                      fontSize: 13,
                      fontWeight: isCurrentAdmin ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (isCurrentAdmin) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: neonGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: neonGreen, width: 1),
                      ),
                      child: const Text(
                        '🛡️ VERIFIED ADMIN',
                        style: TextStyle(
                          color: neonGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // HIDDEN ADMIN PANEL ENTRY (Revealed only if 5 taps AND admin email)
            if (isCurrentAdmin && _adminOptionUnlocked) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: neonGreen, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: neonGreen.withOpacity(0.12),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: neonGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: neonGreen, size: 24),
                  ),
                  title: const Text(
                    'Admin Management Panel',
                    style: TextStyle(
                      color: textWhite,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: const Text(
                    'Manage, publish, edit & delete news articles',
                    style: TextStyle(color: textGray, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: neonGreen, size: 16),
                  onTap: _openAdminDashboard,
                ),
              ),
            ],

            // General Settings Cards
            Container(
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderDark),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined, color: neonGreen, size: 22),
                    title: const Text(
                      'Gaming News Alerts',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Instant notifications for BGMI & esports updates',
                      style: TextStyle(color: textGray, fontSize: 12),
                    ),
                    trailing: Switch(
                      value: true,
                      activeColor: neonGreen,
                      onChanged: (_) {},
                    ),
                  ),
                  const Divider(color: borderDark, height: 1),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_rounded, color: neonGreen, size: 22),
                    title: const Text(
                      'Clear Image Cache',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: cardDark2,
                          content: Text('Image cache cleared', style: TextStyle(color: neonGreen)),
                        ),
                      );
                    },
                  ),
                  const Divider(color: borderDark, height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: neonGreen, size: 22),
                    title: const Text(
                      'App Version',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Text(
                      'v1.2.0 (Build 4)',
                      style: TextStyle(color: textGray, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Account / Login / Logout Section
            Container(
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderDark),
              ),
              child: Column(
                children: [
                  if (currentUser == null) ...[
                    ListTile(
                      leading: const Icon(Icons.login_rounded, color: neonGreen, size: 22),
                      title: const Text(
                        'Admin Login',
                        style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Sign in to manage news',
                        style: TextStyle(color: textGray, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: neonGreen, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                        ).then((_) {
                          setState(() {});
                        });
                      },
                    ),
                  ] else ...[
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: alertRed, size: 22),
                      title: const Text(
                        'Sign Out',
                        style: TextStyle(color: alertRed, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Signed in as $userEmail',
                        style: const TextStyle(color: textGray, fontSize: 12),
                      ),
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        setState(() {
                          _adminOptionUnlocked = false;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: cardDark2,
                              content: Text('Signed out successfully', style: TextStyle(color: textWhite)),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
