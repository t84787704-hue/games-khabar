// ===============================================================================
// GAMER AUTH SCREEN — With Manual Referral Code Input & Post-Auth Linking
// File: lib/screens/gamer_auth_screen.dart
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  StreamSubscription<AuthState>? _authSubscription;
  bool _isNavigating = false;

  final TextEditingController _referralController = TextEditingController();
  bool _showReferralField = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) &&
          session != null) {
        if (!_isNavigating) {
          _handlePostAuth();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _handlePostAuth() async {
    if (_isNavigating) return;
    _isNavigating = true;

    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
      _isNavigating = false;
      return;
    }

    try {
      // 1. Agar user ne referral code dala hai to referrer dhoond kar link karein
      final rawRefCode = _referralController.text.trim().toLowerCase().replaceAll('@', '');
      if (rawRefCode.isNotEmpty) {
        try {
          final referrer = await SupabaseService.client
              .from('users')
              .select('id, uid')
              .or('username.ilike.$rawRefCode,id.eq.$rawRefCode')
              .maybeSingle();

          if (referrer != null) {
            final referrerUid = (referrer['id'] ?? referrer['uid'])?.toString();
            if (referrerUid != null && referrerUid != authUser.id) {
              await SupabaseService.client
                  .from('users')
                  .update({'referred_by': referrerUid})
                  .or('id.eq.${authUser.id},uid.eq.${authUser.id}');
            }
          }
        } catch (refError) {
          debugPrint('[Referral Link Error]: $refError');
        }
      }

      // 2. Profile fetch karein
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
      await GamerAuthService().signInWithGoogle();
      if (SupabaseService.client.auth.currentUser != null) {
        await _handlePostAuth();
      }
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
                const SizedBox(height: 32),

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
                  const SizedBox(height: 20),
                ],

                // REFERRAL CODE INPUT (OPTIONAL ACCORDION)
                if (!_showReferralField) ...[
                  TextButton.icon(
                    onPressed: () => setState(() => _showReferralField = true),
                    icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF00FF88), size: 16),
                    label: const Text(
                      'Have a Referral Code?',
                      style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
                    ),
                    child: TextField(
                      controller: _referralController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Enter Friend\'s Username (e.g. @fua)',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        labelText: 'Referral Code (Optional)',
                        labelStyle: const TextStyle(color: Color(0xFF00FF88), fontSize: 12),
                        prefixIcon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF00FF88), size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                          onPressed: () {
                            _referralController.clear();
                            setState(() => _showReferralField = false);
                          },
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                              Image.network(
                                'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                                width: 22,
                                height: 22,
                                errorBuilder: (_, __, ___) => const Text(
                                  'G',
                                  style: TextStyle(
                                    color: Color(0xFF4285F4),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
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
