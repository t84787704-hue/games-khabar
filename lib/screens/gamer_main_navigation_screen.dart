// ===============================================================================
// File: lib/screens/gamer_main_navigation_screen.dart
// Clean Navigation Screen with Theme & Language Sync + Daily Streak Popup
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../services/streak_service.dart';
import '../widgets/daily_streak_dialog.dart';
import 'gamer_feed_screen.dart';
import 'tournaments_screen.dart'; // Naya Tournaments Screen Import
import 'teams_screen.dart';
import 'gamer_messages_screen.dart';
import 'gamer_rooms_screen.dart';
import 'gamer_profile_screen.dart';
import 'create_gamer_id_screen.dart';
import 'gamer_admin_dashboard_screen.dart';

class GamerMainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const GamerMainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<GamerMainNavigationScreen> createState() =>
      _GamerMainNavigationScreenState();
}

class _GamerMainNavigationScreenState extends State<GamerMainNavigationScreen> {
  late int _currentIndex;
  bool _isAdmin = false;
  StreamSubscription? _adminSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkUsernameSetup();
    _checkAdminStatus();
    _checkDailyLoginStreak();
  }

  void _checkDailyLoginStreak() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      try {
        final result = await StreakService().checkAndClaimDailyStreak();
        if (result != null && !result.isClaimedToday && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => DailyStreakDialog(result: result),
          );
        }
      } catch (e) {
        debugPrint('[GamerMainNavigationScreen] Streak check error: $e');
      }
    });
  }

  void _checkAdminStatus() async {
    final email = GamerAuthService().currentUser?.email ??
        SupabaseService.client.auth.currentUser?.email;
    if (email != null &&
        email.trim().toLowerCase() == 'tufailm483@gmail.com') {
      setState(() => _isAdmin = true);
      return;
    }

    final currentUid = GamerAuthService().currentUid ??
        SupabaseService.client.auth.currentUser?.id;
    if (currentUid != null && currentUid.isNotEmpty) {
      try {
        final data = await SupabaseService.getUser(currentUid);
        if (data != null && mounted) {
          final isDocAdmin = data['isAdmin'] == true || data['is_admin'] == true;
          if (isDocAdmin != _isAdmin) {
            setState(() {
              _isAdmin = isDocAdmin;
              // Tournaments add hone ke baad admin tab index 6 banta hai
              if (!_isAdmin && _currentIndex > 5) {
                _currentIndex = 0;
              }
            });
          }
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _adminSub?.cancel();
    super.dispose();
  }

  void _checkUsernameSetup() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var gamer = GamerAuthService().currentGamer;
      if (gamer == null || gamer.username.trim().isEmpty) {
        final authUser = SupabaseService.client.auth.currentUser;
        if (authUser != null) {
          gamer = await GamerAuthService().refreshCurrentGamer();
        }
      }
      if (mounted && (gamer == null || gamer.username.trim().isEmpty)) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CreateGamerIdScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Index mapping:
    // 0: Feed
    // 1: Tournaments
    // 2: Teams
    // 3: Messages
    // 4: Rooms
    // 5: Profile
    // 6: Admin (if admin)
    final screens = <Widget>[
      const GamerFeedScreen(),
      const TournamentsScreen(),
      const TeamsScreen(),
      const GamerMessagesScreen(),
      const GamerRoomsScreen(),
      const GamerProfileScreen(),
      if (_isAdmin) const GamerAdminDashboardScreen(),
    ];

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;

        return ValueListenableBuilder<String>(
          valueListenable: LanguageService.currentLanguage,
          builder: (context, langCode, _) {
            return Scaffold(
              backgroundColor: ThemeService.bg,
              extendBody: false,
              extendBodyBehindAppBar: false,
              body: SafeArea(
                top: true,
                child: IndexedStack(
                  index: _currentIndex.clamp(0, screens.length - 1),
                  children: screens,
                ),
              ),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  color: ThemeService.bottomNavBg,
                  border: Border(
                    top: BorderSide(color: ThemeService.bottomNavBorder, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 62,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // 0: Feed
                        _buildNavItem(
                          index: 0,
                          icon: Icons.home_rounded,
                          label: 'nav_feed'.tr(),
                          isSelected: _currentIndex == 0,
                          isDark: isDark,
                        ),
                        // 1: Tournaments (Feed aur Teams ke darmiyan)
                        _buildNavItem(
                          index: 1,
                          icon: Icons.emoji_events_rounded,
                          label: 'Tournaments',
                          isSelected: _currentIndex == 1,
                          isDark: isDark,
                        ),
                        // 2: Teams
                        _buildNavItem(
                          index: 2,
                          icon: Icons.shield_rounded,
                          label: 'nav_teams'.tr(),
                          isSelected: _currentIndex == 2,
                          isDark: isDark,
                        ),
                        // 3: Messages
                        _buildNavItem(
                          index: 3,
                          icon: Icons.chat_bubble_rounded,
                          label: 'nav_messages'.tr(),
                          isSelected: _currentIndex == 3,
                          isDark: isDark,
                        ),
                        // 4: Rooms
                        _buildNavItem(
                          index: 4,
                          icon: Icons.military_tech_rounded,
                          label: 'nav_rooms'.tr(),
                          isSelected: _currentIndex == 4,
                          isDark: isDark,
                        ),
                        // 5: Profile
                        _buildNavItem(
                          index: 5,
                          icon: Icons.person_rounded,
                          label: 'nav_profile'.tr(),
                          isSelected: _currentIndex == 5,
                          isDark: isDark,
                        ),
                        // 6: Admin
                        if (_isAdmin)
                          _buildNavItem(
                            index: 6,
                            icon: Icons.admin_panel_settings_rounded,
                            label: 'nav_admin'.tr(),
                            isSelected: _currentIndex == 6,
                            activeColor: const Color(0xFF1877F2),
                            isDark: isDark,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
    Color activeColor = const Color(0xFF1877F2),
  }) {
    final unselectedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF65676B);

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: isSelected ? activeColor : unselectedColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : unselectedColor,
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
