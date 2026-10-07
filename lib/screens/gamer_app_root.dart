import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../models/gamer_user_model.dart';
import 'gamer_age_gate_screen.dart';
import 'gamer_auth_screen.dart';
import 'create_gamer_id_screen.dart';
import 'gamer_main_navigation_screen.dart';
import 'banned_screen.dart';

/// Root navigator that decides which screen to show on app start:
/// 
/// 1. First check: Age gate (13+) — if not verified, show AgeGate
/// 2. Then check auth state (Supabase)
/// 3. Then check profile + banned state
class GamerAppRoot extends StatefulWidget {
  const GamerAppRoot({super.key});

  @override
  State<GamerAppRoot> createState() => _GamerAppRootState();
}

class _GamerAppRootState extends State<GamerAppRoot> {
  final GamerAuthService _authService = GamerAuthService();

  bool _ageGateChecked = false;
  bool _ageVerified = false;

  @override
  void initState() {
    super.initState();
    _checkAgeGate();
  }

  Future<void> _checkAgeGate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final verified = prefs.getBool('age_verified') ?? false;
      if (mounted) {
        setState(() {
          _ageVerified = verified;
          _ageGateChecked = true;
        });
      }

      // Now start auth listener
      await _authService.init();
    } catch (e) {
      debugPrint('[AppRoot] AgeGate check error: $e');
      if (mounted) {
        setState(() {
          _ageGateChecked = true;
          _ageVerified = false;
        });
      }
    }
  }

  void _onAgeVerified() {
    if (mounted) {
      setState(() => _ageVerified = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Age Gate not yet checked → loading
    if (!_ageGateChecked) {
      return const _GamerLoadingScreen();
    }

    // 2. Age Gate not verified → show age gate
    if (!_ageVerified) {
      return GamerAgeGateScreen(onVerified: _onAgeVerified);
    }

    // 3. Age verified → proceed to normal auth flow
    return ValueListenableBuilder<bool>(
      valueListenable: _authService.isLoadingNotifier,
      builder: (context, isLoading, _) {
        return ValueListenableBuilder<User?>(
          valueListenable: _authService.authUserNotifier,
          builder: (context, user, _) {
            // 1. App opens → Splash / Loading screen
            if (isLoading) {
              return const _GamerLoadingScreen();
            }

            // 2. Not logged in → GamerAuthScreen (Google Sign In)
            if (user == null) {
              return const GamerAuthScreen();
            }

            // 3. Logged in → Check public.users profile:
            return ValueListenableBuilder<GamerUser?>(
              valueListenable: _authService.currentGamerNotifier,
              builder: (context, gamer, _) {
                // Profile exists + is_banned → BannedScreen
                if (gamer != null && gamer.isBanned) {
                  return BannedScreen(reason: gamer.bannedReason);
                }

                // Profile exists + username not empty → GamerMainNavigationScreen
                if (gamer != null && gamer.username.trim().isNotEmpty) {
                  return const GamerMainNavigationScreen();
                }

                // Profile missing OR username empty → CreateGamerIdScreen
                return const CreateGamerIdScreen();
              },
            );
          },
        );
      },
    );
  }
}

class _GamerLoadingScreen extends StatelessWidget {
  const _GamerLoadingScreen();

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
          ],
        ),
      ),
    );
  }
}