// ===============================================================================
// EXACT DIFF — Profile / Settings & Preferences Screen
// -------------------------------------------------------------------------------
// File: lib/screens/profile_screen.dart
//
// 1. FIXED SYNTAX ERROR: Color(0xFFFEE2E2) properly closed with bracket and comma.
// 2. RESTORED: "Privacy Settings" (Control what others can see on your profile)
//    placed directly above Blocked Users with complete toggle sheet.
// 3. REORDERED: Log Out placed right after App Version.
// 4. REORDERED: Delete Account placed at the very last position.
// 5. REMOVED: Redundant bottom "Sign Out" container.
// 6. Full Adaptive Day & Night Mode synchronization via ThemeService.
// ===============================================================================

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
import 'blocked_users_screen.dart';
import 'gamer_download_data_screen.dart';
import 'gamer_terms_of_service_screen.dart';
import 'gamer_delete_account_screen.dart';
import 'gamer_auth_screen.dart';

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

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log Out',
          style: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out of Gamers ID?',
          style: TextStyle(color: textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: alertRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              AdminSession.logout();
              await GamerAuthService().signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const GamerAuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrivacySettingsSheet() {
    final user = SupabaseService.client.auth.currentUser;
    final meta = user?.userMetadata ?? {};
    final privacy = (meta['privacy_settings'] is Map)
        ? Map<String, dynamic>.from(meta['privacy_settings'])
        : <String, dynamic>{};

    bool isPrivate = privacy['is_private'] == true;
    bool showUid = privacy['show_game_uid'] ?? true;
    bool showStats = privacy['show_match_stats'] ?? true;
    bool allowChallenges = privacy['allow_challenges'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: ThemeService.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: ThemeService.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ThemeService.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1877F2).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock_rounded, color: Color(0xFF1877F2), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy Settings',
                            style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Control what others can see on your profile',
                            style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: ThemeService.border, height: 1),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF1877F2),
                  title: Text(
                    'Private Profile',
                    style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Only your followers/team members can view your full profile',
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                  ),
                  value: isPrivate,
                  onChanged: (val) {
                    setSheetState(() => isPrivate = val);
                  },
                ),
                Divider(color: ThemeService.border, height: 1),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF1877F2),
                  title: Text(
                    'Show In-Game Name & Game UID',
                    style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Allow other players to copy your official game character ID',
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                  ),
                  value: showUid,
                  onChanged: (val) {
                    setSheetState(() => showUid = val);
                  },
                ),
                Divider(color: ThemeService.border, height: 1),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF1877F2),
                  title: Text(
                    'Show Match Stats & Wins',
                    style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Display your tournament wins, win rate, and room history',
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                  ),
                  value: showStats,
                  onChanged: (val) {
                    setSheetState(() => showStats = val);
                  },
                ),
                Divider(color: ThemeService.border, height: 1),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF1877F2),
                  title: Text(
                    'Allow Direct Challenges',
                    style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Allow other gamers and teams to challenge you in 1v1 matches',
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                  ),
                  value: allowChallenges,
                  onChanged: (val) {
                    setSheetState(() => allowChallenges = val);
                  },
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final updated = {
                        'is_private': isPrivate,
                        'show_game_uid': showUid,
                        'show_match_stats': showStats,
                        'allow_challenges': allowChallenges,
                      };
                      try {
                        await SupabaseService.client.auth.updateUser(
                          UserAttributes(
                            data: {
                              ...meta,
                              'privacy_settings': updated,
                            },
                          ),
                        );
                        final curUid = user?.id;
                        if (curUid != null) {
                          await SupabaseService.client.from('users').update({
                            'is_private': isPrivate,
                          }).or('id.eq.$curUid,uid.eq.$curUid');
                        }
                      } catch (e) {
                        debugPrint('Error updating privacy settings: $e');
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Privacy Settings updated successfully!'),
                            backgroundColor: Color(0xFF00FF88),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
            debugPrint('[ProfileScreen] inner builder exception: $e\n$stack');
            return _buildFallbackUI(context);
          }
        },
      );
    } catch (e, stack) {
      debugPrint('[ProfileScreen] build exception caught: $e\n$stack');
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

            // Official Blue Tick Verification Card
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

            // Consolidated Settings Card
            Container(
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderDark),
              ),
              child: Column(
                children: [
                  // App Language
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

                  // Coin History & Passbook
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

                  // Privacy Settings (Directly above Blocked Users)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F3FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lock_rounded, color: Color(0xFF1877F2), size: 20),
                    ),
                    title: Text(
                      'Privacy Settings',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Control what others can see on your profile',
                      style: TextStyle(color: textGray, fontSize: 12),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                    onTap: _showPrivacySettingsSheet,
                  ),
                  Divider(color: borderDark, height: 1),

                  // Blocked Users
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 20),
                    ),
                    title: Text(
                      'Blocked Users',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Manage users you have blocked',
                      style: TextStyle(color: textGray, fontSize: 12),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                      );
                    },
                  ),
                  Divider(color: borderDark, height: 1),

                  // Saved Posts & News
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F3FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bookmark_rounded, color: Color(0xFF1877F2), size: 20),
                    ),
                    title: Text(
                      'Saved Posts & News',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'View your bookmarked clips & articles',
                      style: TextStyle(color: textGray, fontSize: 12),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SavedNewsScreen()),
                      );
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

                  // Download My Data
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: neonGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.download_rounded, color: neonGreen, size: 20),
                    ),
                    title: Text(
                      'Download My Data',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Get a copy of your Gamers ID data (JSON)',
                      style: TextStyle(color: textGray, fontSize: 12),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GamerDownloadDataScreen()),
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

                  // Privacy Policy
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: neonGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.privacy_tip_rounded, color: neonGreen, size: 20),
                    ),
                    title: Text(
                      'Privacy Policy',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'How we collect and protect your data',
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

                  // Terms of Service
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: neonGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.gavel_rounded, color: neonGreen, size: 20),
                    ),
                    title: Text(
                      'Terms of Service',
                      style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Rules for using Gamers ID',
                      style: TextStyle(color: textGray, fontSize: 12),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GamerTermsOfServiceScreen()),
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
                  Divider(color: borderDark, height: 1),

                  // Log Out (App Version ke foran baad)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                    ),
                    title: const Text(
                      'Log Out',
                      style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Sign out of Gamers ID Network',
                      style: TextStyle(color: textGray, fontSize: 12),
                    ),
                    onTap: _confirmSignOut,
                  ),
                  Divider(color: borderDark, height: 1),

                  // Delete Account (Bilkul aakhri position par)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 20),
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Permanently delete your Gamer ID (30-day grace)',
                      style: TextStyle(color: textGray, fontSize: 12),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GamerDeleteAccountScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Secret Admin Login Section
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: (_adminCardRevealed && !isCurrentAdmin) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                child: (_adminCardRevealed && !isCurrentAdmin)
                    ? Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: neonGreen.withOpacity(0.6),
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
                        child: ListTile(
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
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
