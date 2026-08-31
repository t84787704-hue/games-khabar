import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static const Color bgDark = Color(0xFF0A0A0A);
  static const Color appBarDark = Color(0xFF141414);
  static const Color primaryGreen = Color(0xFF00FF88);
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color cardDark2 = Color(0xFF15151A);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);

  static const String contactEmail = 'gameskhabar.help@gmail.com';
  static const String instagramHandle = '@gameskhabar';
  static const String instagramUrl = 'https://instagram.com/gameskhabar';

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: contactEmail,
      query: 'subject=Games Khabar Support & Feedback',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        _copyToClipboard(context, contactEmail, 'Email copied to clipboard');
      }
    } catch (_) {
      _copyToClipboard(context, contactEmail, 'Email copied to clipboard');
    }
  }

  Future<void> _launchInstagram(BuildContext context) async {
    final Uri instaUri = Uri.parse(instagramUrl);
    try {
      if (await canLaunchUrl(instaUri)) {
        await launchUrl(instaUri, mode: LaunchMode.externalApplication);
      } else {
        _copyToClipboard(context, instagramHandle, 'Instagram handle copied to clipboard');
      }
    } catch (_) {
      _copyToClipboard(context, instagramHandle, 'Instagram handle copied to clipboard');
    }
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cardDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: primaryGreen, width: 1.2),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: primaryGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: appBarDark,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primaryGreen, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Contact Us',
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
            // Intro header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Get in Touch with Games Khabar',
                    style: TextStyle(
                      color: textWhite,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Have gaming news tips, partnership inquiries, or need support? Reach out to us directly through email or social media.',
                    style: TextStyle(
                      color: textGray,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Direct Channels',
              style: TextStyle(
                color: textWhite,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),

            // Email Card
            _buildContactCard(
              context: context,
              icon: Icons.email_rounded,
              title: 'Official Email Support',
              subtitle: contactEmail,
              actionLabel: 'Send Email',
              onAction: () => _launchEmail(context),
              onCopy: () => _copyToClipboard(context, contactEmail, 'Email copied to clipboard!'),
            ),

            const SizedBox(height: 14),

            // Instagram Card
            _buildContactCard(
              context: context,
              icon: Icons.camera_alt_rounded,
              title: 'Instagram Official',
              subtitle: '$instagramHandle • Daily Gaming Updates & Reels',
              actionLabel: 'Open Instagram',
              onAction: () => _launchInstagram(context),
              onCopy: () => _copyToClipboard(context, instagramHandle, 'Instagram handle copied!'),
            ),

            const SizedBox(height: 28),

            // Response Time Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardDark2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primaryGreen.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: primaryGreen, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Quick Response Promise',
                          style: TextStyle(
                            color: textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'We typically respond to inquiries within 24 to 48 hours.',
                          style: TextStyle(color: textGray, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: textWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF05080D)),
                  label: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: Color(0xFF05080D),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: textGray, size: 20),
                tooltip: 'Copy',
                onPressed: onCopy,
                style: IconButton.styleFrom(
                  backgroundColor: cardDark2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: borderDark),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
