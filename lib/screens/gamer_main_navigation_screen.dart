import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import 'gamer_feed_screen.dart';
import 'squad_finder_screen.dart';
import 'clips_screen.dart';
import 'tournament_board_screen.dart';
import 'gamer_profile_screen.dart';
import 'create_gamer_id_screen.dart';

class GamerMainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const GamerMainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<GamerMainNavigationScreen> createState() => _GamerMainNavigationScreenState();
}

class _GamerMainNavigationScreenState extends State<GamerMainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkUsernameSetup();
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
    // 5 Viral Gaming Tabs:
    // Tab 0: Feed (Home)
    // Tab 1: Squads (Squad Finder LFG System)
    // Tab 2: Clips (Memes & Clips Zone)
    // Tab 3: Rooms (Tournament / Custom Room Board)
    // Tab 4: Profile (Gamer Profile & Badges)
    final screens = [
      const GamerFeedScreen(),
      const SquadFinderScreen(),
      ClipsScreen(isTabActive: _currentIndex == 2),
      const TournamentBoardScreen(),
      const GamerProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      extendBody: false,
      extendBodyBehindAppBar: false,
      body: SafeArea(
        top: true,
        bottom: true,
        child: IndexedStack(
          index: _currentIndex,
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

                // Tab 2: Clips (Reels & Memes)
                _buildNavItem(
                  index: 2,
                  icon: Icons.movie_filter_rounded,
                  label: 'Clips',
                  isSelected: _currentIndex == 2,
                ),

                // Tab 3: Rooms (Tournaments / Custom Rooms)
                _buildNavItem(
                  index: 3,
                  icon: Icons.military_tech_rounded,
                  label: 'Rooms',
                  isSelected: _currentIndex == 3,
                ),

                // Tab 4: Profile
                _buildNavItem(
                  index: 4,
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: _currentIndex == 4,
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
      if (index != 2) {
        // Pauses all active clip video & audio immediately when leaving Clips tab
        ClipsPlaybackManager.pauseAllClips();
      }
      ClipsPlaybackManager.isClipsTabActive.value = (index == 2);
      setState(() => _currentIndex = index);
    }
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFF00E5FF) : GamerTheme.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00E5FF) : GamerTheme.textMuted,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
