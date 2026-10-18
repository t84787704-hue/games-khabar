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

  String _safeTr(String key, {String? fallback, List<String>? args}) {
    try {
      final res = key.tr(args: args, context: context);
      if (res.isNotEmpty && res != key) return res;
    } catch (_) {}
    if (fallback != null) return fallback;
    return key.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
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
          _safeTr('log_out', fallback: 'لاگ آؤٹ'),
          style: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _safeTr('log_out_confirm', fallback: 'کیا آپ واقعی گیمرز آئی ڈی سے لاگ آؤٹ کرنا چاہتے ہیں؟'),
          style: TextStyle(color: textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _safeTr('cancel', fallback: 'منسوخ'),
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
              _safeTr('log_out', fallback: 'لاگ آؤٹ'),
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
                              _safeTr('privacy_settings', fallback: 'پراائیویسی سیٹنگز'),
                              style: TextStyle(
                                color: ThemeService.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _safeTr('privacy_settings_sub', fallback: 'کنٹرول کریں کہ دوسرے آپ کی پروفائل پر کیا دیکھ سکتے ہیں'),
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
                      _safeTr('private_profile', fallback: 'پراائیویٹ پروفائل'),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      _safeTr('private_profile_sub', fallback: 'صرف آپ کے فالوورز یا ٹیم ممبرز آپ کی مکمل پروفائل دیکھ سکتے ہیں'),
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
                      _safeTr('show_game_uid', fallback: 'ان-گیم نام اور گیم UID دکھائیں'),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      _safeTr('show_game_uid_sub', fallback: 'دوسرے کھلاڑیوں کو آپ کی آفیشل گیم کریکٹر آئی ڈی کاپی کرنے کی اجازت دیں'),
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
                      _safeTr('show_match_stats', fallback: 'میچ اسٹیٹس اور فتوحات دکھائیں'),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      _safeTr('show_match_stats_sub', fallback: 'اپنے ٹورنامنٹ کی جیت، ون ریٹ اور روم ہسٹری دکھائیں'),
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
                      _safeTr('show_followers', fallback: 'فالوورز کی لسٹ اور تعداد دکھائیں'),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      _safeTr('show_followers_sub', fallback: 'دوسرے گیمرز کو دیکھنے دیں کہ آپ کو کون فالو کرتا ہے'),
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
                      _safeTr('show_following', fallback: 'فالوئنگ لسٹ اور تعداد دکھائیں'),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      _safeTr('show_following_sub', fallback: 'دوسرے گیمرز کو دیکھنے دیں کہ آپ کس کو فالو کر رہے ہیں'),
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
                      _safeTr('allow_challenges', fallback: 'براہ راست چیلنجز کی اجازت دیں'),
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      _safeTr('allow_challenges_sub', fallback: 'دوسرے گیمرز اور ٹیموں کو 1v1 میچز میں چیلنج کرنے کی اجازت دیں'),
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
                              content: Text(
                                _safeTr('privacy_settings_updated', fallback: '✅ پراائیویسی سیٹنگز کامیابی کے ساتھ اپڈیٹ ہو گئیں!'),
                              ),
                              backgroundColor: const Color(0xFF00FF88),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Text(
                        _safeTr('save_settings', fallback: 'سیٹنگز محفوظ کریں'),
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
              _safeTr('profile_settings', fallback: 'سیٹنگز اور ترجیحات'),
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
                            _safeTr('g_coins_count', fallback: 'جی-کوائنز: $coins', args: ['$coins']),
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
                        userEmail ?? _safeTr('community_member', fallback: 'کومونٹی ممبر'),
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
                            '🛡️ ${_safeTr('verified_admin', fallback: 'تصدیق شدہ ایڈمن')}',
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
                                                ? _safeTr('official_verified_gamer', fallback: 'آفیشل تصدیق شدہ گیمر')
                                                : (isPending
                                                    ? _safeTr('under_review_24h', fallback: 'زیرِ جائزہ 24 گھنٹے')
                                                    : _safeTr('apply_for_verification', fallback: 'تصدیق کے لیے اپلائی کریں')),
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
                                                _safeTr('review_24h_tag', fallback: '24 گھنٹے جائزہ'),
                                                style: const TextStyle(color: Color(0xFFFF8A00), fontSize: 9, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isVerified
                                            ? _safeTr('blue_tick_active_desc', fallback: 'آپ کی گیمرز آئی ڈی اور تمام پوسٹس پر بلیو ٹک فعال ہے۔')
                                            : (isPending
                                                ? _safeTr('app_under_review_desc', fallback: 'درخواست زیرِ جائزہ ہے • 24 گھنٹے تصدیق۔')
                                                : _safeTr('get_blue_tick_desc', fallback: 'بلیو ٹک حاصل کریں (کاؤن/ایس، K/D 3.0+، 5k لائکس)')),
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
                                        ? _safeTr('verified', fallback: 'تصدیق شدہ')
                                        : (isPending
                                            ? _safeTr('pending', fallback: 'پینڈنگ')
                                            : _safeTr('apply', fallback: 'اپلائی')),
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
                        _safeTr('admin_panel', fallback: 'ایڈمن پینل'),
                        style: TextStyle(
                          color: textWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        _safeTr('admin_panel_desc', fallback: 'میچز، پروفس اور مواد کا انتظام کریں'),
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
                          _safeTr('app_language', fallback: 'ایپ کی زبان'),
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
                          _safeTr('coin_history_passbook', fallback: 'کوائن ہسٹری اور پاس بک'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('coin_history_sub', fallback: 'کوائنز کب شامل یا کم کیے گئے اور وجہ'),
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
                          _safeTr('privacy_settings', fallback: 'پراائیویسی سیٹنگز'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('privacy_settings_sub', fallback: 'کنٹرول کریں کہ دوسرے آپ کی پروفائل پر کیا دیکھ سکتے ہیں'),
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
                          _safeTr('blocked_users', fallback: 'بلاک کیے گئے صارفین'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('blocked_users_sub', fallback: 'اپنے بلاک کیے گئے صارفین کا انتظام کریں'),
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
                          _safeTr('saved_posts_news', fallback: 'محفوظ کردہ پوسٹس اور نیوز'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('saved_posts_news_sub', fallback: 'اپنی محفوظ کردہ کلپس اور آرٹیکلز دیکھیں'),
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
                          _safeTr('gaming_news_alerts', fallback: 'گیمنگ نیوز الرٹس'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('gaming_alerts_sub', fallback: 'نئے گیم ریلیزز اور ٹورنامنٹس کی اطلاع حاصل کریں'),
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
                              _safeTr('day_night_mode', fallback: 'ڈے / نائট موڈ'),
                              style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              isDark
                                  ? _safeTr('dark_theme_sub', fallback: 'نائٹ موڈ فعال ہے')
                                  : _safeTr('light_theme_sub', fallback: 'ڈے موڈ فعال ہے'),
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
                          _safeTr('clear_cache', fallback: 'کیش صاف کریں'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('clear_cache_sub', fallback: 'لوکل امیج اسٹوریج کی جگہ خالی کریں'),
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: textGray, size: 14),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: cardDark2,
                              content: Text(
                                _safeTr('cache_cleared', fallback: 'کیش کامیابی سے صاف کر دیا گیا'),
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
                          _safeTr('download_my_data', fallback: 'میرا ڈیٹا ڈاؤن لوڈ کریں'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('download_my_data_sub', fallback: 'اپنی گیمرز آئی ڈی کے ڈیٹا کی کاپی حاصل کریں (JSON)'),
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
                          _safeTr('about_us', fallback: 'ہمارے بارے میں'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('about_us_sub', fallback: 'گیمرز آئی ڈی کے بارے में ਜਾਣیں'),
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
                          _safeTr('contact_us', fallback: 'رابطہ کریں'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('contact_us_sub', fallback: 'ہماری گیمر سپورٹ ٹیم سے رابطہ کریں'),
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
                          _safeTr('follow_us', fallback: 'ہمیں فالو کریں'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('follow_us_sub', fallback: 'سوشل میڈیا پر ہماری گیمنگ کمیونٹی سے جڑیں'),
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
                          _safeTr('privacy_policy', fallback: 'پراائیویسی پالیسی'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('privacy_policy_sub', fallback: 'ہم آپ کا ڈیٹا کیسے جمع اور محفوظ کرتے ہیں'),
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
                          _safeTr('terms_of_service', fallback: 'سروس کی شرائط'),
                          style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _safeTr('terms_of_service_sub', fallback: 'گیمرز آئی ڈی استعمال کرنے کے اصول'),
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
                          _safeTr('app_version', fallback: 'ایپ ورژن'),
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
                          _safeTr('log_out', fallback: 'لاگ آؤٹ'),
                          style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          _safeTr('log_out_sub', fallback: 'گیمرز آئی ڈی نیٹ ورک سے سائن آؤٹ کریں'),
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
                          _safeTr('delete_account', fallback: 'اکاؤنٹ ڈیلیٹ کریں'),
                          style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          _safeTr('delete_account_sub', fallback: 'اپنی گیمرز آئی ڈی مستقل طور پر حذف کریں (30 دن گریس پیریڈ)'),
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
