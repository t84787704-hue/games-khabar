import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import 'gamer_feed_screen.dart';
import 'squad_finder_screen.dart';
import 'tournament_board_screen.dart';
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
            if (!_isAdmin && _currentIndex > 4) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gamer = GamerAuthService().currentGamer;
      if (gamer == null || gamer.username.isEmpty) {
        // Enforce Create ID Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CreateGamerIdScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 4 Core tabs: Feed, Squads, Rooms, Profile
    // Admin tab: Admin (shield icon) visible ONLY to admin
    final screens = <Widget>[
      const GamerFeedScreen(),
      const SquadFinderScreen(),
      const TournamentBoardScreen(),
      const GamerProfileScreen(),
      if (_isAdmin) const GamerAdminDashboardScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
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
        decoration: const BoxDecoration(
          color: Color(0xFF10141D),
          border: Border(
            top: BorderSide(color: Color(0xFF1F2B3E), width: 1),
          ),
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

                // Tab 1: Squads (LFG System)
                _buildNavItem(
                  index: 1,
                  icon: Icons.group_rounded,
                  label: 'Squads',
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
                    icon: Icons.shield_rounded,
                    label: 'Admin',
                    isSelected: _currentIndex == 4,
                    activeColor: const Color(0xFF00FF88),
                  ),
              ],
            ),
          ),
        ),
      ),
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
    Color activeColor = const Color(0xFF00E5FF),
  }) {
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
              color: isSelected ? activeColor : GamerTheme.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : GamerTheme.textMuted,
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
