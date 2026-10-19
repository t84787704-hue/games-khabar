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

class GamerAppRoot extends StatefulWidget {
  const GamerAppRoot({super.key});

  @override
  State<GamerAppRoot> createState() => _GamerAppRootState();
}

class _GamerAppRootState extends State<GamerAppRoot> {
  final GamerAuthService _authService = GamerAuthService();

  bool _initialCheckDone = false;
  bool _ageVerified = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ageVerified = prefs.getBool('age_verified') ?? false;

      // Initialize auth once on startup
      await _authService.init();
    } catch (e) {
      debugPrint('[AppRoot] Init error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _initialCheckDone = true;
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
    // 1. Initial startup loading (Sirf ek dafa chalega app start hone par)
    if (!_initialCheckDone) {
      return const _GamerLoadingScreen();
    }

    // 2. Age Gate check
    if (!_ageVerified) {
      return GamerAgeGateScreen(onVerified: _onAgeVerified);
    }

    // 3. Auth & Profile State (Background refresh hone par app unmount nahi hogi)
    return ValueListenableBuilder<User?>(
      valueListenable: _authService.authUserNotifier,
      builder: (context, user, _) {
        // Not logged in → Auth Screen
        if (user == null) {
          return const GamerAuthScreen();
        }

        // Logged in → Check profile & banned status
        return ValueListenableBuilder<GamerUser?>(
          valueListenable: _authService.currentGamerNotifier,
          builder: (context, gamer, _) {
            // Profile abhi fetch nahi hui pehli dafa to chota loader
            if (gamer == null) {
              return const _GamerLoadingScreen();
            }

            // Banned check
            if (gamer.isBanned) {
              return BannedScreen(reason: gamer.bannedReason);
            }

            // User Profile complete
            if (gamer.username.trim().isNotEmpty) {
              return const GamerMainNavigationScreen();
            }

            // Profile missing username
            return const CreateGamerIdScreen();
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
