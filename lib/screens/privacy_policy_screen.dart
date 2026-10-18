import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/theme_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
              'privacy_policy_title'.tr(),
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
                // Header Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.shield_outlined, color: primaryGreen, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'privacy_header_title'.tr(),
                              style: TextStyle(
                                color: textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'privacy_last_updated'.tr(),
                              style: TextStyle(color: textGray, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildSection(
                  title: 'privacy_sec1_title'.tr(),
                  content: 'privacy_sec1_content'.tr(),
                ),

                _buildSection(
                  title: 'privacy_sec2_title'.tr(),
                  content: 'privacy_sec2_content'.tr(),
                ),

                _buildSection(
                  title: 'privacy_sec3_title'.tr(),
                  content: 'privacy_sec3_content'.tr(),
                ),

                _buildSection(
                  title: 'privacy_sec4_title'.tr(),
                  content: 'privacy_sec4_content'.tr(),
                ),

                _buildSection(
                  title: 'privacy_sec5_title'.tr(),
                  content: 'privacy_sec5_content'.tr(),
                ),

                _buildSection(
                  title: 'privacy_sec6_title'.tr(),
                  content: 'privacy_sec6_content'.tr(),
                ),

                _buildSection(
                  title: 'privacy_sec7_title'.tr(),
                  content: 'privacy_sec7_content'.tr(),
                ),

                _buildSection(
                  title: 'privacy_sec8_title'.tr(),
                  content: 'privacy_sec8_content'.tr(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: primaryGreen,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: textGray,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
