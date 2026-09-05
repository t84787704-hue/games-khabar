import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/admin_security.dart';
import '../services/bookmark_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../services/ad_free_service.dart';
import '../services/coin_reward_service.dart';
import 'earn_screen.dart';
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
            style: TextStyle(color: neonGreen, fontSize: 11),
          ),
        ),
      );
    }
  }

  void _onVersionTapped() {
    final now = DateTime.now();
    _versionTaps.add(now);
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
            style: TextStyle(color: neonGreen, fontSize: 11),
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
          side: BorderSide(color: neonGreen, width: 1.5),
        ),
        content: Row(
          children: [
            Icon(Icons.lock_open_rounded, color: neonGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'secret_admin_unlocked'.tr(),
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
        final currentLanguageModel = LanguageService.getLanguageModel(context.locale.languageCode);

        return Scaffold(
          backgroundColor: bgDark,
          appBar: AppBar(
            backgroundColor: cardDark,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'profile_settings'.tr(),
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
                      Text(
                        'Games Khabar',
                        style: TextStyle(
                          color: textWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail ?? 'community_member'.tr(),
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
                          child: Text(
                            '🛡️ ${'verified_admin'.tr()}',
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
                        child: Icon(Icons.admin_panel_settings_rounded, color: neonGreen, size: 24),
                      ),
                      title: Text(
                        'admin_panel'.tr(),
                        style: TextStyle(
                          color: textWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'admin_panel_desc'.tr(),
                        style: TextStyle(color: textGray, fontSize: 12),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded, color: neonGreen, size: 16),
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
                      // 7 Language Selector Option
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: neonGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.language_rounded, color: neonGreen, size: 20),
                        ),
                        title: Text(
                          'app_language'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              currentLanguageModel.flag,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              currentLanguageModel.nativeName,
                              style: TextStyle(
                                color: neonGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (currentLanguageModel.code != 'en' && currentLanguageModel.code != 'ro') ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${currentLanguageModel.englishName})',
                                style: TextStyle(color: textGray, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          LanguageService.showLanguageBottomSheet(
                            context,
                            onLanguageChanged: () {
                              if (mounted) setState(() {});
                            },
                          );
                        },
                      ),
                      Divider(color: borderDark, height: 1),

                      // Saved Articles
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: BookmarkService.bookmarkedIdsNotifier,
                        builder: (context, ids, _) {
                          return ListTile(
                            leading: Icon(Icons.bookmark_rounded, color: neonGreen, size: 22),
                            title: Text(
                              'saved_articles_menu'.tr(),
                              style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              ids.isEmpty ? 'no_saved_articles_sub'.tr() : 'saved_articles_sub'.tr(args: ['${ids.length}']),
                              style: TextStyle(color: textGray, fontSize: 12),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
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
                      Divider(color: borderDark, height: 1),

                      // GK Coins & Earn Screen Entry
                      ValueListenableBuilder<int>(
                        valueListenable: CoinRewardService().coinsNotifier,
                        builder: (context, coins, _) {
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('🪙', style: TextStyle(fontSize: 20)),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  'GK Coins',
                                  style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: neonGreen.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: neonGreen.withOpacity(0.6)),
                                  ),
                                  child: Text(
                                    '$coins COINS',
                                    style: TextStyle(
                                      color: neonGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Daily tasks & free giveaways ke liye coins kamayein',
                              style: TextStyle(color: textGray, fontSize: 12),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const EarnScreen()),
                              );
                            },
                          );
                        },
                      ),
                      Divider(color: borderDark, height: 1),

                      // Gaming News Alerts
                      ListTile(
                        leading: Icon(Icons.notifications_active_outlined, color: neonGreen, size: 22),
                        title: Text(
                          'gaming_news_alerts'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'gaming_alerts_sub'.tr(),
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Switch(
                          value: true,
                          activeColor: neonGreen,
                          onChanged: (_) {},
                        ),
                      ),
                      Divider(color: borderDark, height: 1),

                      // Day / Night Theme Mode
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
                            title: Text(
                              'day_night_mode'.tr(),
                              style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              isDark ? 'dark_theme_sub'.tr() : 'light_theme_sub'.tr(),
                              style: TextStyle(color: textGray, fontSize: 12),
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
                      Divider(color: borderDark, height: 1),

                      // Clear Image Cache
                      ListTile(
                        leading: Icon(Icons.cleaning_services_rounded, color: neonGreen, size: 22),
                        title: Text(
                          'clear_cache'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: cardDark2,
                              content: Text('cache_cleared'.tr(), style: TextStyle(color: neonGreen)),
                            ),
                          );
                        },
                      ),
                      Divider(color: borderDark, height: 1),

                      // About Us
                      ListTile(
                        leading: Icon(Icons.groups_rounded, color: neonGreen, size: 22),
                        title: Text(
                          'about_us'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'about_us_sub'.tr(),
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AboutUsScreen()),
                          );
                        },
                      ),
                      Divider(color: borderDark, height: 1),

                      // Contact Us
                      ListTile(
                        leading: Icon(Icons.support_agent_rounded, color: neonGreen, size: 22),
                        title: Text(
                          'contact_us'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'contact_us_sub'.tr(),
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                          );
                        },
                      ),
                      Divider(color: borderDark, height: 1),

                      // Privacy Policy
                      ListTile(
                        leading: Icon(Icons.privacy_tip_outlined, color: neonGreen, size: 22),
                        title: Text(
                          'privacy_policy'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'privacy_policy_sub'.tr(),
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                          );
                        },
                      ),
                      Divider(color: borderDark, height: 1),

                      // App Version
                      ListTile(
                        leading: Icon(Icons.info_outline_rounded, color: neonGreen, size: 22),
                        title: Text(
                          'app_version'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'v1.2.0 (Build 4)',
                          style: TextStyle(color: textGray, fontSize: 11),
                        ),
                        trailing: Text(
                          'v1.2.0',
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
                                      child: Icon(Icons.lock_open_rounded, color: neonGreen, size: 20),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          'admin_login'.tr(),
                                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: neonGreen.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
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
                                    subtitle: Text(
                                      'admin_login_sub'.tr(),
                                      style: TextStyle(color: textGray, fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(Icons.lock_outline_rounded, color: textGray, size: 18),
                                      tooltip: 'Hide Admin Login',
                                      onPressed: () {
                                        setState(() {
                                          _adminCardRevealed = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: cardDark2,
                                            duration: const Duration(seconds: 1),
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
                                    leading: Icon(Icons.logout_rounded, color: alertRed, size: 22),
                                    title: Text(
                                      'sign_out'.tr(),
                                      style: TextStyle(color: alertRed, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      'signed_in_as'.tr(args: [userEmail ?? '']),
                                      style: TextStyle(color: textGray, fontSize: 12),
                                    ),
                                    onTap: () async {
                                      AdminSession.logout();
                                      setState(() {
                                        _adminOptionUnlocked = false;
                                        _adminCardRevealed = false;
                                      });
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
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
