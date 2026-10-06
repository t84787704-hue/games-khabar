import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
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
    final gamer = await GamerAuthService().refreshCurrentGamer();
    if (!mounted) return;

    if (gamer != null && gamer.isBanned) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => BannedScreen(reason: gamer.bannedReason)),
        (route) => false,
      );
      return;
    }

    if (gamer == null || gamer.username.isEmpty) {
      // Force user to Create ID screen if username does not exist or empty
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CreateGamerIdScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GamerMainNavigationScreen()),
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
          _errorMessage = 'Google Sign In could not complete: $e';
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
          _errorMessage = 'Guest login error: $e';
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
                // App Logo / Gaming Emblem
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

                // App Title
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
                const Text(
                  'Mini Facebook for Gamers',
                  style: TextStyle(
                    color: GamerTheme.textGray,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),

                // Error Banner
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

                // Google Sign In Button (Only Google Sign In via Supabase OAuth)
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
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
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

                // OR Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
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

                // Quick Guest / Instant Play Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _continueAsGuest,
                    icon: const Icon(Icons.flash_on_rounded, color: GamerTheme.accentOrange, size: 20),
                    label: const Text(
                      'Play as Guest (Instant Access)',
                      style: TextStyle(
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

                const Text(
                  'Sign in with Google to sync your rank, teams, and tournament matches across devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
