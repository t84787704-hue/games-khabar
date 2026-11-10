import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/team_service.dart';
import '../services/notification_service.dart';
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

      // Initialize notifications without blocking auth startup
      unawaited(NotificationService().initialize().catchError((_) {}));

      // Initialize auth once on startup (loads cached profile immediately)
      await _authService.init();

      // Universally synchronize all teams' tournament wins, points (+25), leaderboard and match history
      TeamService().syncAllTeamsTournamentWins();
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
        return ValueListenableBuilder<bool>(
          valueListenable: _authService.isLoadingNotifier,
          builder: (context, isLoading, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _authService.profileLoadErrorNotifier,
              builder: (context, profileLoadError, _) {
                return ValueListenableBuilder<GamerUser?>(
                  valueListenable: _authService.currentGamerNotifier,
                  builder: (context, gamer, _) {
                    // If gamer profile exists
                    if (gamer != null) {
                      // Banned check
                      if (gamer.isBanned) {
                        return BannedScreen(reason: gamer.bannedReason);
                      }

                      // User Profile complete
                      if (gamer.username.trim().isNotEmpty) {
                        return const GamerMainNavigationScreen();
                      }

                      // Confirmed missing username (new user needs to create Gamer ID)
                      return const CreateGamerIdScreen();
                    }

                    // Network / DB error while loading profile: show Retry screen instead of CreateGamerIdScreen
                    if (profileLoadError) {
                      return const _GamerLoadingScreen(isRetryMode: true);
                    }

                    // If loading completed cleanly without error and gamer is still null, proceed to CreateGamerIdScreen
                    if (!isLoading) {
                      return const CreateGamerIdScreen();
                    }

                    // Loading in progress: show loader with Retry / Sign Out recovery after 5s
                    return const _GamerLoadingScreen();
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GamerLoadingScreen extends StatefulWidget {
  final bool isRetryMode;

  const _GamerLoadingScreen({this.isRetryMode = false});

  @override
  State<_GamerLoadingScreen> createState() => _GamerLoadingScreenState();
}

class _GamerLoadingScreenState extends State<_GamerLoadingScreen> {
  Timer? _safetyTimer;
  bool _showAction = false;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _showAction = widget.isRetryMode;
    if (!widget.isRetryMode) {
      _startActionTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _GamerLoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRetryMode != oldWidget.isRetryMode) {
      setState(() => _showAction = widget.isRetryMode);
      if (!widget.isRetryMode) {
        _startActionTimer();
      } else {
        _safetyTimer?.cancel();
      }
    }
  }

  void _startActionTimer() {
    _safetyTimer?.cancel();
    _safetyTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showAction = true);
      }
    });
  }

  Future<void> _retryLoad() async {
    if (_isRetrying) return;
    setState(() {
      _isRetrying = true;
      _showAction = false;
    });
    _startActionTimer();
    try {
      GamerAuthService().profileLoadErrorNotifier.value = false;
      GamerAuthService().isLoadingNotifier.value = true;
      await GamerAuthService().refreshCurrentGamer();
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showActions = _showAction || widget.isRetryMode;
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
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
              if (!widget.isRetryMode || _isRetrying)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: GamerTheme.accentBlue,
                  ),
                ),
              if (showActions) ...[
                const SizedBox(height: 20),
                Text(
                  widget.isRetryMode
                      ? 'Could not load your profile. Check your internet connection and retry.'
                      : 'Taking longer than usual to sync your profile...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isRetrying ? null : _retryLoad,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GamerTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await GamerAuthService().signOut();
                  },
                  child: const Text(
                    'Sign Out / Switch Account',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
