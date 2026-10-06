import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../models/gamer_user_model.dart';
import 'gamer_auth_screen.dart';
import 'create_gamer_id_screen.dart';
import 'gamer_main_navigation_screen.dart';
import 'banned_screen.dart';

class GamerAppRoot extends StatefulWidget {
  const GamerAppRoot({super.key});

  @override
  State<GamerAppRoot> createState() => _GamerAppRootState();
}

class _GamerAppRootState extends State<GamerAppRoot> {
  final GamerAuthService _authService = GamerAuthService();
  bool _forceTimeout = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    try {
      _authService.init();
    } catch (e) {
      debugPrint('Auth service init error: $e');
    }

    // Strict safety timeout: loading screen MUST disappear within 2 seconds
    _timeoutTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _forceTimeout = true;
          _authService.isLoadingNotifier.value = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_forceTimeout) {
      // Once timeout triggers, immediately route user without spinning
      final user = _authService.currentUser;
      if (user == null) {
        return const GamerAuthScreen();
      }
      final gamer = _authService.currentGamer;
      // 4. If profile exists AND is_banned = true:
      if (gamer != null && gamer.isBanned) {
        return BannedScreen(reason: gamer.bannedReason);
      }
      // 3. If profile exists AND username is not empty:
      if (gamer != null && gamer.username.trim().isNotEmpty) {
        return const GamerMainNavigationScreen();
      }
      // 5. If profile does NOT exist OR username is empty:
      return const CreateGamerIdScreen();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _authService.isLoadingNotifier,
      builder: (context, isLoading, _) {
        return ValueListenableBuilder<User?>(
          valueListenable: _authService.authUserNotifier,
          builder: (context, user, _) {
            // 1. If no user is logged in:
            if (user == null) {
              if (isLoading && !_forceTimeout) {
                return _GamerLoadingScreen(onSkip: () {
                  setState(() => _forceTimeout = true);
                });
              }
              return const GamerAuthScreen();
            }

            // 2. User is logged in, but still syncing profile from Supabase
            if (isLoading && !_forceTimeout) {
              return _GamerLoadingScreen(onSkip: () {
                setState(() => _forceTimeout = true);
              });
            }

            // 3. User is logged in and profile is loaded
            return ValueListenableBuilder<GamerUser?>(
              valueListenable: _authService.currentGamerNotifier,
              builder: (context, gamer, _) {
                // 4. If profile exists AND is_banned = true:
                if (gamer != null && gamer.isBanned) {
                  return BannedScreen(reason: gamer.bannedReason);
                }

                // 3. If profile exists AND username is not empty:
                if (gamer != null && gamer.username.trim().isNotEmpty) {
                  return const GamerMainNavigationScreen();
                }

                // 5. If profile does NOT exist OR username is empty:
                return const CreateGamerIdScreen();
              },
            );
          },
        );
      },
    );
  }
}

class _GamerLoadingScreen extends StatefulWidget {
  final VoidCallback? onSkip;
  const _GamerLoadingScreen({this.onSkip});

  @override
  State<_GamerLoadingScreen> createState() => _GamerLoadingScreenState();
}

class _GamerLoadingScreenState extends State<_GamerLoadingScreen> {
  bool _showSkipButton = false;
  Timer? _skipTimer;

  @override
  void initState() {
    super.initState();
    _skipTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showSkipButton = true);
    });
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: GamerTheme.blueOrangeGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: GamerTheme.accentBlue.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.sports_esports_rounded, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (bounds) => GamerTheme.blueOrangeGradient.createShader(bounds),
              child: const Text(
                'GAMERS ID',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: GamerTheme.accentBlue,
              ),
            ),
            if (_showSkipButton && widget.onSkip != null) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: widget.onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: GamerTheme.accentOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  'Tap to Continue →',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
