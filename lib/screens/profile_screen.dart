import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/admin_security.dart';
import '../services/bookmark_service.dart';
import '../services/theme_service.dart';
import 'admin_login_screen.dart';
import 'saved_news_screen.dart';
import 'about_us_screen.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<DateTime> _logoTaps = [];
  final List<DateTime> _versionTaps = [];
  bool _adminCardRevealed = false;
  bool _adminOptionUnlocked = false;

  Color get neonGreen => ThemeService.primaryGreen;
  Color get bgDark => ThemeService.bg;
  Color get cardDark => ThemeService.card;
  Color get cardDark2 => ThemeService.cardSecondary;
  Color get borderDark => ThemeService.border;
  Color get alertRed => const Color(0xFFFF4655);
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;

  @override
  void initState() {
    super.initState();
    // If user is already authenticated as admin, show admin options
    if (isAdminUser()) {
      _adminOptionUnlocked = true;
      _adminCardRevealed = true;
    }
  }

  void _onLogoTapped() {
    final now = DateTime.now();
    _logoTaps.add(now);
    // Keep only taps within the last 3 seconds
    _logoTaps.removeWhere((t) => now.difference(t).inMilliseconds > 3000);

    if (_logoTaps.length >= 5) {
      _logoTaps.clear();
      _revealAdminAccess();
    } else if (_logoTaps.length >= 2 && !_adminCardRevealed && !isAdminUser()) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cardDark2,
          duration: const Duration(milliseconds: 600),
          content: Text(
            '${5 - _logoTaps.length} more taps to unlock',
            style: const TextStyle(color: neonGreen, fontSize: 11),
          ),
        ),
      );
    }
  }

  void _onVersionTapped() {
    final now = DateTime.now();
    _versionTaps.add(now);
    // Keep only taps within the last 3 seconds
    _versionTaps.removeWhere((t) => now.difference(t).inMilliseconds > 3000);

    if (_versionTaps.length >= 7) {
      _versionTaps.clear();
      _revealAdminAccess();
    } else if (_versionTaps.length >= 3 && !_adminCardRevealed && !isAdminUser()) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cardDark2,
          duration: const Duration(milliseconds: 600),
          content: Text(
            '${7 - _versionTaps.length} more taps to unlock Admin',
            style: const TextStyle(color: neonGreen, fontSize: 11),
          ),
        ),
      );
    }
  }

  void _revealAdminAccess() {
    if (_adminCardRevealed && _adminOptionUnlocked) return;
    setState(() {
      _adminCardRevealed = true;
      if (isAdminUser()) {
        _adminOptionUnlocked = true;
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
                '🔓 Secret Admin Login revealed!',
                style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openAdminDashboard() async {
    final verified = await promptAdminPinDialog(context);
    if (!verified) return;
    if (!mounted) return;

    Navigator.pushNamed(context, '/admin-dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        final isCurrentAdmin = isAdminUser();
        final userEmail = AdminSession.adminEmail;

        return Scaffold(
          backgroundColor: bgDark,
          appBar: AppBar(
            backgroundColor: cardDark,
            elevation: 0,
            centerTitle: true,
            title: Text(
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

            // HIDDEN ADMIN PANEL ENTRY (Revealed for verified admin)
            if (isCurrentAdmin || _adminOptionUnlocked) ...[
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
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: BookmarkService.bookmarkedIdsNotifier,
                    builder: (context, ids, _) {
                      return ListTile(
                        leading: const Icon(Icons.bookmark_rounded, color: neonGreen, size: 22),
                        title: const Text(
                          'Saved Articles',
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          ids.isEmpty ? 'No articles saved yet' : '${ids.length} saved articles',
                          style: const TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                body: SavedNewsScreen(
                                  onExploreTap: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const Divider(color: borderDark, height: 1),
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
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeService.themeModeNotifier,
                    builder: (context, mode, _) {
                      final isDark = mode == ThemeMode.dark;
                      return ListTile(
                        leading: Icon(
                          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: neonGreen,
                          size: 22,
                        ),
                        title: const Text(
                          'Day & Night Mode',
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isDark ? 'Dark Theme (Night Mode)' : 'Light Theme (Day Mode)',
                          style: const TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Switch(
                          value: isDark,
                          activeColor: neonGreen,
                          onChanged: (val) {
                            ThemeService.setTheme(val);
                          },
                        ),
                      );
                    },
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
                    leading: const Icon(Icons.groups_rounded, color: neonGreen, size: 22),
                    title: const Text(
                      'About Us',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Games Khabar coverage & esports info',
                      style: TextStyle(color: textGray, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutUsScreen()),
                      );
                    },
                  ),
                  const Divider(color: borderDark, height: 1),
                  ListTile(
                    leading: const Icon(Icons.support_agent_rounded, color: neonGreen, size: 22),
                    title: const Text(
                      'Contact Us',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Email & Instagram support channels',
                      style: TextStyle(color: textGray, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                      );
                    },
                  ),
                  const Divider(color: borderDark, height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: neonGreen, size: 22),
                    title: const Text(
                      'Privacy Policy',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'AdMob & Firebase data terms',
                      style: TextStyle(color: textGray, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
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
                    subtitle: const Text(
                      'Tap for build info',
                      style: TextStyle(color: textGray, fontSize: 11),
                    ),
                    trailing: const Text(
                      'v1.2.0 (Build 4)',
                      style: TextStyle(color: textGray, fontSize: 13),
                    ),
                    onTap: _onVersionTapped,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Secret Admin Login / Logout Section
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: (_adminCardRevealed || isCurrentAdmin) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                child: (_adminCardRevealed || isCurrentAdmin)
                    ? Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrentAdmin ? neonGreen : neonGreen.withOpacity(0.6),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: neonGreen.withOpacity(0.08),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (!isCurrentAdmin) ...[
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: neonGreen.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.lock_open_rounded, color: neonGreen, size: 20),
                                ),
                                title: Row(
                                  children: [
                                    const Text(
                                      'Admin Login',
                                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: neonGreen.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'UNLOCKED',
                                        style: TextStyle(
                                          color: neonGreen,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: const Text(
                                  'Sign in to manage & publish news',
                                  style: TextStyle(color: textGray, fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.lock_outline_rounded, color: textGray, size: 18),
                                  tooltip: 'Hide Admin Login',
                                  onPressed: () {
                                    setState(() {
                                      _adminCardRevealed = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: cardDark2,
                                        duration: Duration(seconds: 1),
                                        content: Text('Admin Login hidden', style: TextStyle(color: textGray)),
                                      ),
                                    );
                                  },
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                                  ).then((_) {
                                    setState(() {
                                      if (isAdminUser()) {
                                        _adminOptionUnlocked = true;
                                        _adminCardRevealed = true;
                                      }
                                    });
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
                                  AdminSession.logout();
                                  setState(() {
                                    _adminOptionUnlocked = false;
                                    _adminCardRevealed = false;
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
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
