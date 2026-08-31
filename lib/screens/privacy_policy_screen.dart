import 'package:flutter/material.dart';
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
              'Privacy Policy',
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
                              'Games Khabar Privacy Policy',
                              style: TextStyle(
                                color: textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Last updated: August 2026',
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
                  title: '1. Introduction',
                  content:
                      'Welcome to Games Khabar. We respect your privacy and are committed to protecting it. This Privacy Policy explains how our application functions and handles information when you use our mobile gaming news platform.',
                ),

                _buildSection(
                  title: '2. No Personal Data Collection',
                  content:
                      'Games Khabar is purely an informational gaming news application. We DO NOT collect, store, or sell any personal identifiable information (PII) such as your real name, phone number, physical address, or contacts. You can read news, redeem codes, and esports updates completely anonymously without creating a personal user account.',
                ),

                _buildSection(
                  title: '3. Firebase Services',
                  content:
                      'Our application uses Google Firebase (Firebase Cloud Firestore and Firebase Cloud Messaging) solely to provide real-time gaming news updates and push notifications for breaking esports events and game updates. Firebase may process anonymous device tokens strictly to deliver notifications.',
                ),

                _buildSection(
                  title: '4. Advertising (Google AdMob)',
                  content:
                      'Games Khabar may display third-party advertisements served by Google AdMob to support free content delivery. AdMob may use anonymous advertising identifiers (such as Android Advertising ID) and cookies to serve relevant, non-personalized or personalized ads subject to Google\'s Privacy Policy.',
                ),

                _buildSection(
                  title: '5. Bookmarks and Local Storage',
                  content:
                      'Any news articles or redeem codes that you save/bookmark are stored locally on your own device using local storage (SharedPreferences). This data stays entirely on your phone and is never uploaded to our servers.',
                ),

                _buildSection(
                  title: '6. Children\'s Privacy',
                  content:
                      'Games Khabar is suitable for general gaming audiences and does not knowingly collect any personal information from children under the age of 13.',
                ),

                _buildSection(
                  title: '7. Policy Changes',
                  content:
                      'We may update our Privacy Policy periodically. Any modifications will be posted directly within the app on this screen with an updated effective date.',
                ),

                _buildSection(
                  title: '8. Contact Us',
                  content:
                      'If you have any questions, suggestions, or concerns regarding this Privacy Policy, feel free to contact our support team at:\n\nEmail: gameskhabar.help@gmail.com',
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
