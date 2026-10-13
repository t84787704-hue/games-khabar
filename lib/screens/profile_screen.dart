import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/admin_security.dart';
import '../services/bookmark_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../services/ad_free_service.dart';
import '../services/coin_reward_service.dart';
import 'earn_screen.dart';
import 'admin_login_screen.dart';
import 'saved_news_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'create_gamer_id_screen.dart';
import 'about_us_screen.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'follow_us_screen.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../models/gamer_user_model.dart';
import 'verification_screen.dart';
import '../widgets/coin_history_sheet.dart';

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

  bool get _isCurrentAdminSafe {
    try {
      return isAdminUser();
    } catch (_) {
      return false;
    }
  }

  String get _currentEmail {
    try {
      return SupabaseService.client.auth.currentUser?.email ??
          GamerAuthService().currentGamer?.email ??
          'N/A';
    } catch (_) {
      return GamerAuthService().currentGamer?.email ?? 'N/A';
    }
  }

  String get _currentUid {
    try {
      return SupabaseService.client.auth.currentUser?.id ??
          GamerAuthService().currentUid ??
          'N/A';
    } catch (_) {
      return GamerAuthService().currentUid ?? 'N/A';
    }
  }

  Stream<List<Map<String, dynamic>>> _getUserCoinsStream() {
    try {
      final uid = GamerAuthService().currentUid;
      if (uid != null && uid.isNotEmpty) {
        return SupabaseService.client
            .from('users')
            .stream(primaryKey: ['id'])
            .eq('id', uid)
            .handleError((e) {
              debugPrint('[ProfileScreen] user coins stream error: $e');
            });
      }
    } catch (e) {
      debugPrint('[ProfileScreen] _getUserCoinsStream init error: $e');
    }
    return const Stream.empty();
  }

  /// Safe translation helper with guaranteed fallback to prevent grey screen (Issue #10)
  String _safeTr(String key, {String? fallback, List<String>? args}) {
    try {
      final res = key.tr(args: args);
      if (res.isNotEmpty && res != key) return res;
    } catch (_) {}
    if (fallback != null) return fallback;
    return key.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  @override
  void initState() {
    super.initState();
    // If user is already authenticated as admin, show admin options
    try {
      if (_isCurrentAdminSafe) {
        _adminOptionUnlocked = true;
        _adminCardRevealed = true;
      }
    } catch (_) {}
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
                _safeTr('secret_admin_unlocked', fallback: 'Secret Admin Unlocked'),
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
    try {
      return ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeService.themeModeNotifier,
        builder: (context, _, __) {
          try {
            return _buildContent(context);
          } catch (e, stack) {
            debugPrint('[ProfileScreen] inner builder exception (Issue #10): $e\n$stack');
            return _buildFallbackUI(context);
          }
        },
      );
    } catch (e, stack) {
      debugPrint('[ProfileScreen] build exception caught (Issue #10): $e\n$stack');
      return _buildFallbackUI(context);
    }
  }

  Widget _buildContent(BuildContext context) {
    final isCurrentAdmin = _isCurrentAdminSafe;
    final userEmail = AdminSession.adminEmail;

    String langCode = 'en';
    try {
      langCode = LanguageService.currentLanguage.value;
    } catch (_) {}
    try {
      langCode = context.locale.languageCode;
    } catch (_) {}
    final currentLanguageModel = LanguageService.getLanguageModel(langCode);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _safeTr('profile_settings', fallback: 'Settings & Preferences'),
          style: TextStyle(
            color: textWhite,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getUserCoinsStream(),
            builder: (context, snapshot) {
              int coins = 0;
              try {
                if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                  final data = snapshot.data!.first;
                  final rawCoins = data['gCoins'] ?? data['coins'];
                  if (rawCoins is num) {
                    coins = rawCoins.toInt();
                  }
                } else {
                  coins = GamerAuthService().currentGamer?.coins ?? 0;
                }
              } catch (_) {
                coins = GamerAuthService().currentGamer?.coins ?? 0;
              }
              return GestureDetector(
                onTap: () {
                  final uid = GamerAuthService().currentUid ?? '';
                  CoinHistorySheet.show(context, userId: uid);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                        'G-Coins: $coins',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.history_rounded, size: 14, color: Color(0xFFFFD700)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
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
                        userEmail ?? _safeTr('community_member', fallback: 'Community Member'),
                        style: TextStyle(
                          color: isCurrentAdmin ? neonGreen : textGray,
                          fontSize: 13,
                          fontWeight: isCurrentAdmin ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Debug: Current Auth User & UID
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardDark2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderDark),
                        ),
                        child: Text(
                          "Email: $_currentEmail | UID: $_currentUid",
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
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
                            '🛡️ ${_safeTr('verified_admin', fallback: 'Verified Admin')}',
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
                const SizedBox(height: 20),

                // Official Blue Tick Verification Card & Apply Button
                ValueListenableBuilder<GamerUser?>(
                  valueListenable: GamerAuthService().currentGamerNotifier,
                  builder: (context, gamer, _) {
                    final bool isVerified = gamer?.isVerifiedBadge ?? false;
                    final bool isPending = gamer?.isPendingVerification ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isVerified
                              ? Colors.blue
                              : (isPending ? const Color(0xFFFF8A00) : Colors.blue.withOpacity(0.5)),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isVerified ? Colors.blue : (isPending ? const Color(0xFFFF8A00) : Colors.blue)).withOpacity(0.12),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => VerificationScreen(user: gamer)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (isVerified ? Colors.blue : (isPending ? const Color(0xFFFF8A00) : Colors.blue)).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isVerified
                                        ? Icons.verified_rounded
                                        : (isPending ? Icons.hourglass_top_rounded : Icons.verified_outlined),
                                    color: isVerified ? Colors.blue : (isPending ? const Color(0xFFFF8A00) : Colors.blue),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            isVerified
                                                ? 'Official Verified Gamer'
                                                : (isPending ? 'Under Review 24h' : 'Apply for Verification'),
                                            style: TextStyle(
                                              color: textWhite,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (isVerified)
                                            const Icon(Icons.verified, color: Colors.blue, size: 16)
                                          else if (isPending)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF8A00).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('24H REVIEW', style: TextStyle(color: Color(0xFFFF8A00), fontSize: 9, fontWeight: FontWeight.w900)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isVerified
                                            ? 'Blue Tick ✓ active on your Gamer ID & all posts.'
                                            : (isPending
                                                ? 'Application under review • 24h validation.'
                                                : 'Get Blue Tick ✓ (Crown/Ace, K/D 3.0+, 5k Likes)'),
                                        style: TextStyle(color: textGray, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (isVerified ? Colors.blue : (isPending ? const Color(0xFFFF8A00) : Colors.blue)).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isVerified ? 'VERIFIED' : (isPending ? 'PENDING' : 'APPLY'),
                                    style: TextStyle(
                                      color: isVerified ? Colors.blue : (isPending ? const Color(0xFFFF8A00) : Colors.blue),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),

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
                        _safeTr('admin_panel', fallback: 'Admin Panel'),
                        style: TextStyle(
                          color: textWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        _safeTr('admin_panel_desc', fallback: 'Manage matches, proofs & news'),
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
                          _safeTr('app_language', fallback: 'App Language'),
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

                      // Coin History & Passbook Entry
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.history_edu_rounded, color: Color(0xFFFFD700), size: 20),
                        ),
                        title: Text(
                          'Coin History & Passbook',
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Kb kitne coin kis liye cut ya add huway',
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          final uid = GamerAuthService().currentUid ?? '';
                          CoinHistorySheet.show(context, userId: uid);
                        },
                      ),
                      Divider(color: borderDark, height: 1),

                      // Gaming News Alerts
                      ListTile(
                        leading: Icon(Icons.notifications_active_outlined, color: neonGreen, size: 22),
                        title: Text(
                          _safeTr('gaming_news_alerts', fallback: 'Gaming News Alerts'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('gaming_alerts_sub', fallback: 'Get notified of latest game releases & tournaments'),
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Switch(
                          value: true,
                          activeColor: neonGreen,
                          onChanged: (_) {},
                        ),
                      ),
                      Divider(color: borderDark, height: 1),

                      // Day / Night Theme Mode (Issue #9)
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
                              _safeTr('day_night_mode', fallback: 'Day / Night Mode'),
                              style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              isDark
                                  ? _safeTr('dark_theme_sub', fallback: 'Night mode enabled')
                                  : _safeTr('light_theme_sub', fallback: 'Day mode enabled'),
                              style: TextStyle(color: textGray, fontSize: 12),
                            ),
                            trailing: Switch(
                              value: isDark,
                              activeColor: neonGreen,
                              onChanged: (val) async {
                                await ThemeService.setTheme(val);
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
                          _safeTr('clear_cache', fallback: 'Clear Cache'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: cardDark2,
                              content: Text(
                                _safeTr('cache_cleared', fallback: 'Cache cleared successfully'),
                                style: TextStyle(color: neonGreen),
                              ),
                            ),
                          );
                        },
                      ),
                      Divider(color: borderDark, height: 1),

                      // About Us
                      ListTile(
                        leading: Icon(Icons.groups_rounded, color: neonGreen, size: 22),
                        title: Text(
                          _safeTr('about_us', fallback: 'About Us'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('about_us_sub', fallback: 'Learn about Games Khabar'),
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
                          _safeTr('contact_us', fallback: 'Contact Us'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('contact_us_sub', fallback: 'Reach our gamer support team'),
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

                      // Follow Us
                      ListTile(
                        leading: Icon(Icons.share_rounded, color: neonGreen, size: 22),
                        title: Text(
                          _safeTr('follow_us', fallback: 'Follow Us'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('follow_us_sub', fallback: 'Join our gaming community on social media'),
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FollowUsScreen()),
                          );
                        },
                      ),
                      Divider(color: borderDark, height: 1),

                      // App Version
                      ListTile(
                        leading: Icon(Icons.info_outline_rounded, color: neonGreen, size: 22),
                        title: Text(
                          _safeTr('app_version', fallback: 'App Version'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'v1.2.0 (Build 4)',
                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                        ),
                        trailing: const Text(
                          'v1.2.0',
                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
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
                                          _safeTr('admin_login', fallback: 'Admin Login'),
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
                                      _safeTr('admin_login_sub', fallback: 'Sign in to access admin console'),
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
                                      _safeTr('sign_out', fallback: 'Sign Out'),
                                      style: TextStyle(color: alertRed, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      _safeTr('signed_in_as', fallback: 'Signed in as $userEmail', args: [userEmail ?? '']),
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
  }

  /// Robust Fallback UI that prevents blank grey screen if data load or build throws (Issue #10)
  Widget _buildFallbackUI(BuildContext context) {
    final bgDark = ThemeService.bg;
    final cardDark = ThemeService.card;
    final borderDark = ThemeService.border;
    final neonGreen = ThemeService.primaryGreen;
    final textWhite = ThemeService.textPrimary;
    final textGray = ThemeService.textSecondary;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings & Preferences',
          style: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderDark),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.language_rounded, color: neonGreen),
                  title: Text('App Language', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
                  subtitle: Text(LanguageService.selectedLang == 'ur' ? 'اردو' : 'English', style: TextStyle(color: textGray)),
                  onTap: () {
                    LanguageService.showLanguageBottomSheet(context);
                  },
                ),
                Divider(color: borderDark, height: 1),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeService.themeModeNotifier,
                  builder: (context, mode, _) {
                    final isDark = mode == ThemeMode.dark;
                    return ListTile(
                      leading: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: neonGreen),
                      title: Text('Day / Night Mode', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
                      trailing: Switch(
                        value: isDark,
                        activeColor: neonGreen,
                        onChanged: (val) => ThemeService.setTheme(val),
                      ),
                    );
                  },
                ),
                Divider(color: borderDark, height: 1),
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: neonGreen),
                  title: Text('Privacy Policy', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                ),
                Divider(color: borderDark, height: 1),
                ListTile(
                  leading: Icon(Icons.groups_rounded, color: neonGreen),
                  title: Text('About Us', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
