import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
              'about_us_title'.tr(),
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
                // 1. Logo & Brand Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF38BDF8), Color(0xFFFF8A00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF38BDF8).withOpacity(0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF38BDF8), Color(0xFFFF8A00)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.sports_esports_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'app_name'.tr(),
                        style: TextStyle(
                          color: textWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'about_us_tagline'.tr(),
                        textAlign: TextAlign.center,
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

                // 2. Mission Statement
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderDark),
                  ),
                  child: Text(
                    'about_us_mission_desc'.tr(),
                    style: TextStyle(
                      color: textWhite,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'about_us_coverage_title'.tr(),
                  style: TextStyle(
                    color: textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),

                _buildGameCategoryCard(
                  icon: Icons.sports_esports_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  title: 'about_cat_bgmi_title'.tr(),
                  description: 'about_cat_bgmi_desc'.tr(),
                ),
                _buildGameCategoryCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFFF5252),
                  title: 'about_cat_ff_title'.tr(),
                  description: 'about_cat_ff_desc'.tr(),
                ),
                _buildGameCategoryCard(
                  icon: Icons.military_tech_rounded,
                  iconColor: const Color(0xFFFFD700),
                  title: 'about_cat_cod_title'.tr(),
                  description: 'about_cat_cod_desc'.tr(),
                ),
                _buildGameCategoryCard(
                  icon: Icons.shield_rounded,
                  iconColor: const Color(0xFF00FF88),
                  title: 'about_cat_val_title'.tr(),
                  description: 'about_cat_val_desc'.tr(),
                ),
                _buildGameCategoryCard(
                  icon: Icons.workspace_premium_rounded,
                  iconColor: const Color(0xFFFFA000),
                  title: 'about_cat_coins_title'.tr(),
                  description: 'about_cat_coins_desc'.tr(),
                ),

                const SizedBox(height: 20),

                // 3. Footer note
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
                        'about_footer_built_by'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'about_footer_network_info'.tr(),
                        textAlign: TextAlign.center,
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
    required Color iconColor,
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
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
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
