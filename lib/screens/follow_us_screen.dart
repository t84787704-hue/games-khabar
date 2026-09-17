import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';

class FollowUsScreen extends StatelessWidget {
  const FollowUsScreen({super.key});

  Color get bgDark => ThemeService.bg;
  Color get appBarDark => ThemeService.appBarBg;
  Color get primaryGreen => ThemeService.primaryGreen;
  Color get cardDark => ThemeService.card;
  Color get cardDark2 => ThemeService.cardSecondary;
  Color get borderDark => ThemeService.border;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;

  static const String youtubeUrl = 'https://youtube.com/@GamersIDNetwork';
  static const String instagramUrl = 'https://instagram.com/gamersidnetwork';
  static const String tiktokUrl = 'https://tiktok.com/@gamersidnetwork';
  static const String facebookUrl = 'https://facebook.com/gamersidnetwork';

  Future<void> _launchSocialUrl(BuildContext context, String urlStr, String title) async {
    final Uri uri = Uri.parse(urlStr);
    try {
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback to in-app webview or platform default if external app fails
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        if (context.mounted) {
          Clipboard.setData(ClipboardData(text: urlStr));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cardDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: primaryGreen, width: 1.2),
              ),
              content: Row(
                children: [
                  Icon(Icons.link_rounded, color: primaryGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$title link copied to clipboard!',
                      style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, mode, _) {
        return Scaffold(
          backgroundColor: bgDark,
          appBar: AppBar(
            backgroundColor: appBarDark,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded, color: textWhite, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Follow Us',
              style: TextStyle(
                color: textWhite,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: borderDark, height: 1),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryGreen.withOpacity(0.18),
                        cardDark,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryGreen.withOpacity(0.4), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.public_rounded, color: primaryGreen, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join Our Gaming Community',
                              style: TextStyle(
                                color: textWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Follow us across official channels for daily updates, tournaments, and gaming news.',
                              style: TextStyle(
                                color: textGray,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'Official Channels',
                  style: TextStyle(
                    color: textWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),

                // 1. YouTube Option
                _buildSocialItem(
                  context: context,
                  iconWidget: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFFF0000), size: 24),
                  ),
                  title: 'YouTube',
                  subtitle: 'Subscribe for tournament streams & guides',
                  badgeText: 'SUBSCRIBE',
                  badgeColor: const Color(0xFFFF0000),
                  onTap: () => _launchSocialUrl(context, youtubeUrl, 'YouTube'),
                ),

                const SizedBox(height: 14),

                // 2. Instagram Option
                _buildSocialItem(
                  context: context,
                  iconWidget: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1306C).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFE1306C), size: 24),
                  ),
                  title: 'Instagram',
                  subtitle: 'Follow for daily gaming reels & highlights',
                  badgeText: 'FOLLOW',
                  badgeColor: const Color(0xFFE1306C),
                  onTap: () => _launchSocialUrl(context, instagramUrl, 'Instagram'),
                ),

                const SizedBox(height: 14),

                // 3. TikTok Option
                _buildSocialItem(
                  context: context,
                  iconWidget: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F2FE).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.music_note_rounded, color: Color(0xFF00F2FE), size: 24),
                  ),
                  title: 'TikTok',
                  subtitle: 'Watch short BGMI clips & viral gameplay',
                  badgeText: 'WATCH',
                  badgeColor: const Color(0xFF00F2FE),
                  onTap: () => _launchSocialUrl(context, tiktokUrl, 'TikTok'),
                ),

                const SizedBox(height: 14),

                // 4. Facebook Option
                _buildSocialItem(
                  context: context,
                  iconWidget: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1877F2).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 24),
                  ),
                  title: 'Facebook',
                  subtitle: 'Connect with community discussions & events',
                  badgeText: 'CONNECT',
                  badgeColor: const Color(0xFF1877F2),
                  onTap: () => _launchSocialUrl(context, facebookUrl, 'Facebook'),
                ),

                const SizedBox(height: 28),

                // Clean info note matching style
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardDark2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderDark),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: primaryGreen, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No payment or subscription required. Following is completely optional.',
                          style: TextStyle(color: textGray, fontSize: 11.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialItem({
    required BuildContext context,
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderDark),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                iconWidget,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: textWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: textGray,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.open_in_new_rounded,
                  color: textGray,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
