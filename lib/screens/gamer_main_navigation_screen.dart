import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import 'gamer_feed_screen.dart';
import 'create_post_screen.dart';
import 'saved_news_tab_screen.dart';
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
    // 4 Tabs: Feed (Home), + (Center Create Post), Saved (Bookmark), Profile (Person)
    final screens = [
      const GamerFeedScreen(), // Tab 1: Feed (home) - SUPER FEED
      const SizedBox.shrink(), // Tab 2: Placeholder for center + button
      SavedNewsTabScreen(
        onExploreTap: () => setState(() => _currentIndex = 0),
      ), // Tab 3: Saved (bookmark)
      const GamerProfileScreen(), // Tab 4: Profile (person)
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: IndexedStack(
        index: _currentIndex == 1 ? 0 : _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF10141D),
          border: Border(
            top: BorderSide(color: Color(0xFF1F2B3E), width: 1),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Tab 1: Feed (home icon) - SUPER FEED
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  label: 'Feed',
                  isSelected: _currentIndex == 0,
                ),

                // Tab 2: + (center create post)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                    );
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFFFF6B00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),

                // Tab 3: Saved (bookmark icon)
                _buildNavItem(
                  index: 2,
                  icon: Icons.bookmark_rounded,
                  label: 'Saved',
                  isSelected: _currentIndex == 2,
                ),

                // Tab 4: Profile (person icon)
                _buildNavItem(
                  index: 3,
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: _currentIndex == 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
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
