import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Play Store & GDPR compliant Privacy Policy Screen.
/// 
/// This screen displays the complete privacy policy in-app.
/// Users can also open the hosted version in a browser.
/// 
/// IMPORTANT: The privacy policy URL must be updated with your actual
/// hosted version before publishing to Play Store.
class GamerPrivacyPolicyScreen extends StatelessWidget {
  const GamerPrivacyPolicyScreen({super.key});

  // ⚠️ UPDATE THIS URL with your actual hosted privacy policy
  static const String hostedPolicyUrl =
      'https://gameskhabar.com/privacy-policy';

  static const String appName = 'Games Khabar / Gamers ID';
  static const String contactEmail = 'support@gameskhabar.com';
  static const String lastUpdated = 'January 2025';

  Future<void> _openHostedPolicy(BuildContext context) async {
    final uri = Uri.parse(hostedPolicyUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open link'),
              backgroundColor: Color(0xFFFF4655),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[PrivacyPolicy] launch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Color(0xFF1877F2),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F3FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF1877F2),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.privacy_tip_rounded,
                              color: Color(0xFF1877F2), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Your Privacy Matters',
                            style: TextStyle(
                              color: Color(0xFF050505),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This policy explains what data $appName collects, how we use it, and your rights as a user.',
                      style: const TextStyle(
                        color: Color(0xFF050505),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: $lastUpdated',
                      style: const TextStyle(
                        color: Color(0xFF65676B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 1: Information We Collect
              _buildSection(
                number: '1',
                title: 'Information We Collect',
                items: [
                  'Account Information: Email address, username, display name, and profile photo (via Google Sign In).',
                  'Profile Data: Bio, favorite game, in-game UID, rank, and gaming stats you choose to share.',
                  'Content: Posts, comments, likes, teams, and 1v1 challenges you create.',
                  'Device Data: FCM push notification token, app version, and device type.',
                  'Usage Data: Login times, feature usage patterns for improving the app.',
                ],
              ),

              // Section 2: How We Use Your Data
              _buildSection(
                number: '2',
                title: 'How We Use Your Data',
                items: [
                  'To provide the core features of the app (feed, teams, 1v1 challenges).',
                  'To send push notifications for likes, comments, and team activities.',
                  'To verify your in-game rank and award blue ticks.',
                  'To detect and prevent abuse, spam, and fraud.',
                  'To improve app performance and fix bugs.',
                ],
              ),

              // Section 3: Data Storage & Security
              _buildSection(
                number: '3',
                title: 'Data Storage & Security',
                items: [
                  'Your data is stored securely on Supabase servers with row-level security.',
                  'All communication uses HTTPS encryption.',
                  'Passwords are never stored in plain text — Supabase Auth handles this.',
                  'We use industry-standard security practices to protect your data.',
                ],
              ),

              // Section 4: Data Sharing
              _buildSection(
                number: '4',
                title: 'Data Sharing',
                items: [
                  'We do NOT sell your personal data to anyone.',
                  'We use Supabase for database and authentication.',
                  'We use secure cloud messaging for push notifications only.',
                  'We may share data if required by law.',
                ],
              ),

              // Section 5: Your Privacy Controls
              _buildSection(
                number: '5',
                title: 'Your Privacy Controls',
                items: [
                  'You can hide your rank, UID, coins, bio, and other info from others.',
                  'Go to Profile → Settings → Privacy Settings to control visibility.',
                  'You can block other users to prevent them from interacting with you.',
                  'You can report inappropriate content or users.',
                ],
              ),

              // Section 6: Your Rights
              _buildSection(
                number: '6',
                title: 'Your Rights (GDPR / DPDP Act)',
                items: [
                  'Right to Access: You can download a copy of all your data.',
                  'Right to Delete: You can permanently delete your account.',
                  'Right to Correction: You can edit your profile anytime.',
                  'Right to Portability: You can export your data as JSON.',
                  'Right to Object: You can contact us to object to data processing.',
                ],
              ),

              // Section 7: Data Retention
              _buildSection(
                number: '7',
                title: 'Data Retention',
                items: [
                  'Your data is kept as long as your account is active.',
                  'After account deletion, data is permanently removed within 30 days.',
                  'Some data may be kept longer if required by law.',
                ],
              ),

              // Section 8: Children's Privacy
              _buildSection(
                number: '8',
                title: 'Children\'s Privacy (COPPA)',
                items: [
                  'This app is NOT intended for children under 13 years.',
                  'We do not knowingly collect data from children under 13.',
                  'If you are under 13, please do not use this app.',
                  'Parents can contact us to remove any accidental data.',
                ],
              ),

              // Section 9: Changes to This Policy
              _buildSection(
                number: '9',
                title: 'Changes to This Policy',
                items: [
                  'We may update this policy from time to time.',
                  'You will be notified of major changes via in-app notification.',
                  'Continued use of the app means you accept the updated policy.',
                ],
              ),

              // Section 10: Contact Us
              _buildSection(
                number: '10',
                title: 'Contact Us',
                items: [
                  'For any privacy-related questions, contact us:',
                  'Email: $contactEmail',
                  'We respond within 7 business days.',
                ],
              ),

              const SizedBox(height: 24),

              // Open hosted version button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _openHostedPolicy(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1877F2),
                    side: const BorderSide(color: Color(0xFF1877F2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    'Open Hosted Version',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Close button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'I Understand',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String number,
    required String title,
    required List<String> items,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCED0D4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F3FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: Color(0xFF1877F2),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF050505),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 10),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: Color(0xFF1877F2),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Color(0xFF65676B),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}