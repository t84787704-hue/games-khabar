import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Play Store compliant Terms of Service Screen.
class GamerTermsOfServiceScreen extends StatelessWidget {
  const GamerTermsOfServiceScreen({super.key});

  static const String hostedTermsUrl =
      'https://gameskhabar.com/terms-of-service';
  static const String appName = 'Games Khabar / Gamers ID';
  static const String contactEmail = 'support@gameskhabar.com';
  static const String lastUpdated = 'January 2025';

  Future<void> _openHostedTerms(BuildContext context) async {
    final uri = Uri.parse(hostedTermsUrl);
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
      debugPrint('[TermsOfService] launch error: $e');
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
          'Terms of Service',
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
                          child: const Icon(Icons.gavel_rounded,
                              color: Color(0xFF1877F2), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Terms of Service',
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
                      'By using $appName, you agree to these terms. Please read them carefully.',
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

              // Section 1: Acceptance
              _buildSection(
                number: '1',
                title: 'Acceptance of Terms',
                items: [
                  'By creating an account or using the app, you accept these terms.',
                  'If you do not agree, please do not use the app.',
                  'You must be at least 13 years old to use this app.',
                ],
              ),

              // Section 2: Account Responsibilities
              _buildSection(
                number: '2',
                title: 'Account Responsibilities',
                items: [
                  'You are responsible for maintaining the confidentiality of your account.',
                  'You must provide accurate information during registration.',
                  'You must not share your account with others.',
                  'You are responsible for all activity under your account.',
                ],
              ),

              // Section 3: Acceptable Use
              _buildSection(
                number: '3',
                title: 'Acceptable Use',
                items: [
                  'No hate speech, harassment, or threats.',
                  'No spam, scams, or misleading content.',
                  'No sharing of illegal, violent, or adult content.',
                  'No impersonation of other users or brands.',
                  'No cheating, hacking, or exploiting the app.',
                  'No posting false or misleading rank screenshots.',
                ],
              ),

              // Section 4: Content Ownership
              _buildSection(
                number: '4',
                title: 'Content Ownership',
                items: [
                  'You own the content you post (posts, comments, images).',
                  'By posting, you grant us a license to display your content in the app.',
                  'You must not post copyrighted content without permission.',
                  'We may remove any content that violates these terms.',
                ],
              ),

              // Section 5: Virtual Coins
              _buildSection(
                number: '5',
                title: 'Virtual Coins (G-Coins)',
                items: [
                  'G-Coins are virtual currency for in-app use only.',
                  'G-Coins have NO real-world value and cannot be exchanged for cash.',
                  'We may adjust G-Coin prices, rewards, or balances at any time.',
                  'Abuse of the coin system may result in account suspension.',
                ],
              ),

              // Section 6: 1v1 Challenges & Teams
              _buildSection(
                number: '6',
                title: '1v1 Challenges & Teams',
                items: [
                  'You must provide valid screenshots for match verification.',
                  'Fake or edited screenshots will result in disqualification.',
                  'We are not responsible for disputes between players.',
                  'Admin decisions on match results are final.',
                ],
              ),

              // Section 7: Account Suspension
              _buildSection(
                number: '7',
                title: 'Account Suspension & Termination',
                items: [
                  'We may suspend or ban accounts that violate these terms.',
                  'Repeated violations may result in permanent ban.',
                  'You may delete your own account anytime from settings.',
                  'Banned accounts may lose access to all content and coins.',
                ],
              ),

              // Section 8: Disclaimers
              _buildSection(
                number: '8',
                title: 'Disclaimers',
                items: [
                  'The app is provided "as is" without warranties.',
                  'We do not guarantee uninterrupted service or bug-free experience.',
                  'We are not responsible for any loss of data or coins.',
                  'Game names and trademarks belong to their respective owners.',
                ],
              ),

              // Section 9: Limitation of Liability
              _buildSection(
                number: '9',
                title: 'Limitation of Liability',
                items: [
                  'We are not liable for any indirect or consequential damages.',
                  'Our total liability is limited to the amount you paid us (if any).',
                  'This app is a community platform — user interactions are their own responsibility.',
                ],
              ),

              // Section 10: Changes to Terms
              _buildSection(
                number: '10',
                title: 'Changes to Terms',
                items: [
                  'We may update these terms from time to time.',
                  'Continued use of the app means you accept the new terms.',
                  'Major changes will be notified via in-app notification.',
                ],
              ),

              // Section 11: Contact
              _buildSection(
                number: '11',
                title: 'Contact Us',
                items: [
                  'For any questions about these terms:',
                  'Email: $contactEmail',
                  'We respond within 7 business days.',
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _openHostedTerms(context),
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
                    'I Agree',
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