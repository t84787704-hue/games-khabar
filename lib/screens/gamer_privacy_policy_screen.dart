import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

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
            SnackBar(
              content: Text('could_not_open_link'.tr()),
              backgroundColor: const Color(0xFFFF4655),
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
        title: Text(
          'privacy_policy_title'.tr(),
          style: const TextStyle(
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
                        Expanded(
                          child: Text(
                            'privacy_matters_title'.tr(),
                            style: const TextStyle(
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
                      'privacy_policy_desc'.tr(args: [appName]),
                      style: const TextStyle(
                        color: Color(0xFF050505),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'last_updated_prefix'.tr(args: [lastUpdated]),
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
                title: 'sec1_title'.tr(),
                items: [
                  'sec1_li1'.tr(),
                  'sec1_li2'.tr(),
                  'sec1_li3'.tr(),
                  'sec1_li4'.tr(),
                  'sec1_li5'.tr(),
                ],
              ),

              // Section 2: How We Use Your Data
              _buildSection(
                number: '2',
                title: 'sec2_title'.tr(),
                items: [
                  'sec2_li1'.tr(),
                  'sec2_li2'.tr(),
                  'sec2_li3'.tr(),
                  'sec2_li4'.tr(),
                  'sec2_li5'.tr(),
                ],
              ),

              // Section 3: Data Storage & Security
              _buildSection(
                number: '3',
                title: 'sec3_title'.tr(),
                items: [
                  'sec3_li1'.tr(),
                  'sec3_li2'.tr(),
                  'sec3_li3'.tr(),
                  'sec3_li4'.tr(),
                ],
              ),

              // Section 4: Data Sharing
              _buildSection(
                number: '4',
                title: 'sec4_title'.tr(),
                items: [
                  'sec4_li1'.tr(),
                  'sec4_li2'.tr(),
                  'sec4_li3'.tr(),
                  'sec4_li4'.tr(),
                ],
              ),

              // Section 5: Your Privacy Controls
              _buildSection(
                number: '5',
                title: 'sec5_title'.tr(),
                items: [
                  'sec5_li1'.tr(),
                  'sec5_li2'.tr(),
                  'sec5_li3'.tr(),
                  'sec5_li4'.tr(),
                ],
              ),

              // Section 6: Your Rights
              _buildSection(
                number: '6',
                title: 'sec6_title'.tr(),
                items: [
                  'sec6_li1'.tr(),
                  'sec6_li2'.tr(),
                  'sec6_li3'.tr(),
                  'sec6_li4'.tr(),
                  'sec6_li5'.tr(),
                ],
              ),

              // Section 7: Data Retention
              _buildSection(
                number: '7',
                title: 'sec7_title'.tr(),
                items: [
                  'sec7_li1'.tr(),
                  'sec7_li2'.tr(),
                  'sec7_li3'.tr(),
                ],
              ),

              // Section 8: Children's Privacy
              _buildSection(
                number: '8',
                title: 'sec8_title'.tr(),
                items: [
                  'sec8_li1'.tr(),
                  'sec8_li2'.tr(),
                  'sec8_li3'.tr(),
                  'sec8_li4'.tr(),
                ],
              ),

              // Section 9: Changes to This Policy
              _buildSection(
                number: '9',
                title: 'sec9_title'.tr(),
                items: [
                  'sec9_li1'.tr(),
                  'sec9_li2'.tr(),
                  'sec9_li3'.tr(),
                ],
              ),

              // Section 10: Contact Us
              _buildSection(
                number: '10',
                title: 'sec10_title'.tr(),
                items: [
                  'sec10_li1'.tr(),
                  'sec10_li2'.tr(args: [contactEmail]),
                  'sec10_li3'.tr(),
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
                  label: Text(
                    'open_hosted_version'.tr(),
                    style: const TextStyle(
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
                  child: Text(
                    'btn_i_understand'.tr(),
                    style: const TextStyle(
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