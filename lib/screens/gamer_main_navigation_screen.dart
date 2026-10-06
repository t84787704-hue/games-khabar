import 'dart:async';
import 'package:flutter/material.dart';
import 'package:games_khabar/compat/firebase_auth.dart';
import 'package:games_khabar/compat/cloud_firestore.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import 'gamer_feed_screen.dart';
import 'teams_screen.dart';
import 'gamer_rooms_screen.dart';
import 'gamer_profile_screen.dart';
import 'create_gamer_id_screen.dart';
import 'gamer_admin_dashboard_screen.dart';

class GamerMainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const GamerMainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<GamerMainNavigationScreen> createState() => _GamerMainNavigationScreenState();
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
  }

  void _checkAdminStatus() {
    final user = FirebaseAuth.instance.currentUser;
    // Condition 1: FirebaseAuth currentUser email == "tufailm483@gmail.com"
    if (user != null && user.email?.trim().toLowerCase() == 'tufailm483@gmail.com') {
      setState(() => _isAdmin = true);
      return;
    }

    // Condition 2: userDoc isAdmin == true
    if (user != null) {
      _adminSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (!snapshot.exists) return;
        final data = snapshot.data();
        final isDocAdmin = data?['isAdmin'] == true;
        final isEmailMatch = user.email?.trim().toLowerCase() == 'tufailm483@gmail.com';
        final newIsAdmin = isDocAdmin || isEmailMatch;
        if (newIsAdmin != _isAdmin && mounted) {
          setState(() {
            _isAdmin = newIsAdmin;
            if (!_isAdmin && _currentIndex > 3) {
              _currentIndex = 0;
            }
          });
        }
      });
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
        // Enforce Create ID Screen only if profile does not exist or username is empty
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CreateGamerIdScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 4 Core tabs: Feed, Teams, Rooms, Profile
    // Admin tab: Admin (shield icon) visible ONLY to admin
    final screens = <Widget>[
      const GamerFeedScreen(),
      const TeamsScreen(),
      const GamerRoomsScreen(),
      const GamerProfileScreen(),
      if (_isAdmin) const GamerAdminDashboardScreen(),
    ];

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;

        return Scaffold(
          backgroundColor: ThemeService.bg,
          extendBody: false,
          extendBodyBehindAppBar: false,
          body: SafeArea(
            top: true,
            bottom: true,
            child: IndexedStack(
              index: _currentIndex.clamp(0, screens.length - 1),
              children: screens,
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: BorderSide(color: Color(0xFFE4E6EB), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: SizedBox(
                height: 62,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Tab 0: Feed
                    _buildNavItem(
                      index: 0,
                      icon: Icons.home_rounded,
                      label: 'Feed',
                      isSelected: _currentIndex == 0,
                    ),

                    // Tab 1: Teams
                    _buildNavItem(
                      index: 1,
                      icon: Icons.shield_rounded,
                      label: 'Teams',
                      isSelected: _currentIndex == 1,
                    ),

                    // Tab 2: Rooms (Tournaments / Custom Rooms)
                    _buildNavItem(
                      index: 2,
                      icon: Icons.military_tech_rounded,
                      label: 'Rooms',
                      isSelected: _currentIndex == 2,
                    ),

                    // Tab 3: Profile
                    _buildNavItem(
                      index: 3,
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      isSelected: _currentIndex == 3,
                    ),

                    // Tab 4: Admin (Visible ONLY to Admin)
                    if (_isAdmin)
                      _buildNavItem(
                        index: 4,
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Admin',
                        isSelected: _currentIndex == 4,
                        activeColor: const Color(0xFF1877F2),
                      ),
                  ],
                ),
              ),
            ),
          ),
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
    Color activeColor = const Color(0xFF1877F2),
  }) {
    const unselectedColor = Color(0xFF65676B);

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _isAdmin ? 8 : 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? activeColor : unselectedColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : unselectedColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
