import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import 'create_gamer_id_screen.dart';
import 'gamer_main_navigation_screen.dart';
import 'banned_screen.dart';

class GamerAuthScreen extends StatefulWidget {
  const GamerAuthScreen({super.key});

  @override
  State<GamerAuthScreen> createState() => _GamerAuthScreenState();
}

class _GamerAuthScreenState extends State<GamerAuthScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handlePostAuth() async {
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) return;

    try {
      Map<String, dynamic>? profile;
      try {
        profile = await SupabaseService.client
            .from('users')
            .select('id, username, display_name, avatar_url, is_banned, banned_reason')
            .or('id.eq.${authUser.id},uid.eq.${authUser.id}')
            .maybeSingle();
      } catch (_) {
        profile = await SupabaseService.client
            .from('users')
            .select()
            .or('id.eq.${authUser.id},uid.eq.${authUser.id}')
            .maybeSingle();
      }

      if (!mounted) return;

      if (profile != null && profile['is_banned'] == true) {
        final reason = profile['banned_reason']?.toString() ?? 'account_suspended'.tr();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => BannedScreen(reason: reason)),
          (route) => false,
        );
        return;
      }

      final rawUsername = profile != null ? profile['username'] : null;
      final username = rawUsername?.toString().trim() ?? '';

      if (profile != null && username.isNotEmpty) {
        await GamerAuthService().refreshCurrentGamer();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const GamerMainNavigationScreen()),
          (route) => false,
        );
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CreateGamerIdScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('[GamerAuthScreen] Post auth check error: $e');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CreateGamerIdScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await GamerAuthService().signInWithGoogle().timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          debugPrint('OAuth launch timed out waiting on app return');
        },
      );
      await _handlePostAuth();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'err_google_sign_in'.tr(args: [e.toString()]);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await GamerAuthService().signInAnonymouslyOrGuest();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GamerMainNavigationScreen()),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'err_guest_login'.tr(args: [e.toString()]);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: GamerTheme.blueOrangeGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: GamerTheme.accentBlue.withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.sports_esports_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                ShaderMask(
                  shaderCallback: (bounds) => GamerTheme.blueOrangeGradient.createShader(bounds),
                  child: const Text(
                    'GAMERS ID',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'auth_subtitle'.tr(),
                  style: const TextStyle(
                    color: GamerTheme.textGray,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),

                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: GamerTheme.redAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GamerTheme.redAccent.withOpacity(0.6), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: GamerTheme.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _errorMessage = null),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black87,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    'G',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'continue_with_google'.tr(),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or_divider'.tr(),
                        style: const TextStyle(
                          color: GamerTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _continueAsGuest,
                    icon: const Icon(Icons.flash_on_rounded, color: GamerTheme.accentOrange, size: 20),
                    label: Text(
                      'play_as_guest'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GamerTheme.accentOrange.withOpacity(0.6), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  'google_sync_notice'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GamerTheme.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
