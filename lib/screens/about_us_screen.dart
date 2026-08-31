import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  Color get bgDark => ThemeService.bg;
  Color get appBarDark => ThemeService.appBarBg;
  Color get primaryGreen => ThemeService.primaryGreen;
  Color get cardDark => ThemeService.card;
  Color get borderDark => ThemeService.border;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: bgDark,
          appBar: AppBar(
            backgroundColor: appBarDark,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryGreen, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'About Us',
              style: TextStyle(
                color: textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo & Brand Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: cardDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryGreen, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: primaryGreen.withOpacity(0.2),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'GK',
                              style: TextStyle(
                                color: Color(0xFF05080D),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Games Khabar',
                        style: TextStyle(
                          color: textWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your Ultimate Gaming & Esports News Hub',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Mission Statement
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderDark),
                  ),
                  child: Text(
                    'Games Khabar is dedicated to bringing passionate gamers the fastest, most reliable, and up-to-date gaming news, tournament coverage, daily redeem codes, and patch updates in one unified, modern experience.',
                    style: TextStyle(
                      color: textWhite,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'What We Cover',
                  style: TextStyle(
                    color: textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),

                _buildGameCategoryCard(
                  icon: Icons.sports_esports_rounded,
                  title: 'BGMI & PUBG Mobile',
                  description: 'Latest updates, royal pass leaks, esports tournaments, and pro player news.',
                ),
                _buildGameCategoryCard(
                  icon: Icons.local_fire_department_rounded,
                  title: 'Free Fire & Free Fire MAX',
                  description: 'Daily redeem codes, OB updates, gun skin releases, and event rewards.',
                ),
                _buildGameCategoryCard(
                  icon: Icons.military_tech_rounded,
                  title: 'Call of Duty (COD & Warzone Mobile)',
                  description: 'Season battle passes, meta loadouts, patch notes, and esports scene.',
                ),
                _buildGameCategoryCard(
                  icon: Icons.shield_rounded,
                  title: 'Valorant & PC Gaming',
                  description: 'VCT tournament matches, agent tier lists, skin bundles, and tactical guides.',
                ),
                _buildGameCategoryCard(
                  icon: Icons.confirmation_number_rounded,
                  title: 'Daily Redeem Codes & Free Rewards',
                  description: 'Verified active redeem codes and giveaways updated every single day.',
                ),

                const SizedBox(height: 20),

                // Footer note
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryGreen.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Built for Gamers, by Gamers ❤️',
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Stay connected for 24/7 gaming updates.',
                        style: TextStyle(color: textGray, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameCategoryCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: textGray,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
