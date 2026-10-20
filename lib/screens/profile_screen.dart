// ===============================================================================
// Profile / Settings & Preferences Screen — Full Multi-Language Support
// File: lib/screens/profile_screen.dart
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../utils/admin_security.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import 'admin_login_screen.dart';
import 'saved_news_screen.dart';
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
  bool _gamingNewsAlerts = true;

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
      final curEmail = SupabaseService.client.auth.currentUser?.email?.toLowerCase().trim() ?? '';
      if (curEmail == 'tufailm483@gmail.com') return true;
      return isAdminUser();
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _gamingNewsAlerts = prefs.getBool('gaming_news_alerts') ?? true;
      });
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
          'log_out'.tr(),
          style: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'log_out_confirm'.tr(),
          style: TextStyle(color: textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'btn_cancel'.tr(),
              style: TextStyle(color: textGray),
            ),
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
            child: Text(
              'log_out'.tr(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
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
    bool showFollowers = privacy['show_followers'] ?? true;
    bool showFollowing = privacy['show_following'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: ThemeService.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: ThemeService.border),
            ),
            child: SingleChildScrollView(
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
                              'privacy_settings'.tr(),
                              style: TextStyle(
                                color: ThemeService.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'privacy_settings_sub'.tr(),
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
                      'private_profile'.tr(),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      'private_profile_sub'.tr(),
                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                    ),
                    value: isPrivate,
                    onChanged: (val) => setSheetState(() => isPrivate = val),
                  ),
                  Divider(color: ThemeService.border, height: 1),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF1877F2),
                    title: Text(
                      'show_game_uid'.tr(),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      'show_game_uid_sub'.tr(),
                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                    ),
                    value: showUid,
                    onChanged: (val) => setSheetState(() => showUid = val),
                  ),
                  Divider(color: ThemeService.border, height: 1),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF1877F2),
                    title: Text(
                      'show_match_stats'.tr(),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      'show_match_stats_sub'.tr(),
                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                    ),
                    value: showStats,
                    onChanged: (val) => setSheetState(() => showStats = val),
                  ),
                  Divider(color: borderDark, height: 1),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF1877F2),
                    title: Text(
                      'show_followers'.tr(),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      'show_followers_sub'.tr(),
                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                    ),
                    value: showFollowers,
                    onChanged: (val) => setSheetState(() => showFollowers = val),
                  ),
                  Divider(color: borderDark, height: 1),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF1877F2),
                    title: Text(
                      'show_following'.tr(),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      'show_following_sub'.tr(),
                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                    ),
                    value: showFollowing,
                    onChanged: (val) => setSheetState(() => showFollowing = val),
                  ),
                  Divider(color: borderDark, height: 1),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF1877F2),
                    title: Text(
                      'allow_challenges'.tr(),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      'allow_challenges_sub'.tr(),
                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5),
                    ),
                    value: allowChallenges,
                    onChanged: (val) => setSheetState(() => allowChallenges = val),
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
                          'show_followers': showFollowers,
                          'show_following': showFollowing,
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
                              'show_followers': showFollowers,
                              'show_following': showFollowing,
                            }).or('id.eq.$curUid,uid.eq.$curUid');
                          }
                        } catch (e) {
                          debugPrint('Error updating privacy settings: $e');
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('privacy_settings_updated'.tr()),
                              backgroundColor: const Color(0xFF00FF88),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Text(
                        'save_settings'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentAdmin = _isCurrentAdminSafe;
    final userEmail = SupabaseService.client.auth.currentUser?.email;

    String langCode = 'en';
    try {
      langCode = LanguageService.currentLanguage.value;
    } catch (_) {}
    try {
      langCode = context.locale.languageCode;
    } catch (_) {}
    final currentLanguageModel = LanguageService.getLanguageModel(langCode);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
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
                            'g_coins_count'.tr(args: ['$coins']),
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
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF38BDF8), Color(0xFFFF8A00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF38BDF8).withOpacity(0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.sports_esports_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'app_name'.tr(),
                        style: TextStyle(
                          color: textWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: 0.5,
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
                const SizedBox(height: 20),

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
                                                ? 'official_verified_gamer'.tr()
                                                : (isPending
                                                    ? 'under_review_24h'.tr()
                                                    : 'apply_for_verification'.tr()),
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
                                              child: Text(
                                                'review_24h_tag'.tr(),
                                                style: const TextStyle(color: Color(0xFFFF8A00), fontSize: 9, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isVerified
                                            ? 'blue_tick_active_desc'.tr()
                                            : (isPending
                                                ? 'app_under_review_desc'.tr()
                                                : 'get_blue_tick_desc'.tr()),
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
                                    isVerified
                                        ? 'verified'.tr()
                                        : (isPending
                                            ? 'pending'.tr()
                                            : 'apply'.tr()),
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

                if (isCurrentAdmin) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: neonGreen, width: 1.5),
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

                Container(
                  decoration: BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderDark),
                  ),
                  child: Column(
                    children: [
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
                            Text(currentLanguageModel.flag, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              currentLanguageModel.nativeName,
                              style: TextStyle(color: neonGreen, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
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
                          'coin_history_passbook'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'coin_history_sub'.tr(),
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          final uid = GamerAuthService().currentUid ?? '';
                          CoinHistorySheet.show(context, userId: uid);
                        },
                      ),
                      Divider(color: borderDark, height: 1),

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
                          'privacy_settings'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'privacy_settings_sub'.tr(),
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: _showPrivacySettingsSheet,
                      ),
                      Divider(color: borderDark, height: 1),

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
                          'blocked_users'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'blocked_users_sub'.tr(),
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
                          'saved_posts_news'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'saved_posts_news_sub'.tr(),
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
                          value: _gamingNewsAlerts,
                          activeColor: neonGreen,
                          onChanged: (val) async {
                            setState(() {
                              _gamingNewsAlerts = val;
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('gaming_news_alerts', val);
                          },
                        ),
                      ),
                      Divider(color: borderDark, height: 1),

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
                              isDark
                                  ? 'dark_theme_sub'.tr()
                                  : 'light_theme_sub'.tr(),
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

                      ListTile(
                        leading: Icon(Icons.cleaning_services_rounded, color: neonGreen, size: 22),
                        title: Text(
                          'clear_cache'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'clear_cache_sub'.tr(),
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: cardDark2,
                              content: Text(
                                'cache_cleared'.tr(),
                                style: TextStyle(color: neonGreen),
                              ),
                            ),
                          );
                        },
                      ),
                      Divider(color: borderDark, height: 1),

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
                          'download_my_data'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'download_my_data_sub'.tr(),
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

                      ListTile(
                        leading: Icon(Icons.share_rounded, color: neonGreen, size: 22),
                        title: Text(
                          'follow_us'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'follow_us_sub'.tr(),
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
                          'terms_of_service'.tr(),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'terms_of_service_sub'.tr(),
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

                      ListTile(
                        leading: Icon(Icons.info_outline_rounded, color: neonGreen, size: 22),
                        title: Text(
                          'app_version'.tr(),
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
                        onTap: null,
                      ),
                      Divider(color: borderDark, height: 1),

                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                        ),
                        title: Text(
                          'log_out'.tr(),
                          style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'log_out_sub'.tr(),
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        onTap: _confirmSignOut,
                      ),
                      Divider(color: borderDark, height: 1),

                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 20),
                        ),
                        title: Text(
                          'delete_account'.tr(),
                          style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'delete_account_sub'.tr(),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
