import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

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
            SnackBar(
              content: Text('err_could_not_open_link'.tr()),
              backgroundColor: const Color(0xFFFF4655),
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
        title: Text(
          'terms_of_service_title'.tr(),
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
                          child: const Icon(Icons.gavel_rounded,
                              color: Color(0xFF1877F2), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'terms_of_service_title'.tr(),
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
                      'terms_header_desc'.tr(args: [appName]),
                      style: const TextStyle(
                        color: Color(0xFF050505),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'terms_last_updated'.tr(args: [lastUpdated]),
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
                title: 'terms_sec1_title'.tr(),
                items: [
                  'terms_sec1_item1'.tr(),
                  'terms_sec1_item2'.tr(),
                  'terms_sec1_item3'.tr(),
                ],
              ),

              // Section 2: Account Responsibilities
              _buildSection(
                number: '2',
                title: 'terms_sec2_title'.tr(),
                items: [
                  'terms_sec2_item1'.tr(),
                  'terms_sec2_item2'.tr(),
                  'terms_sec2_item3'.tr(),
                  'terms_sec2_item4'.tr(),
                ],
              ),

              // Section 3: Acceptable Use
              _buildSection(
                number: '3',
                title: 'terms_sec3_title'.tr(),
                items: [
                  'terms_sec3_item1'.tr(),
                  'terms_sec3_item2'.tr(),
                  'terms_sec3_item3'.tr(),
                  'terms_sec3_item4'.tr(),
                  'terms_sec3_item5'.tr(),
                  'terms_sec3_item6'.tr(),
                ],
              ),

              // Section 4: Content Ownership
              _buildSection(
                number: '4',
                title: 'terms_sec4_title'.tr(),
                items: [
                  'terms_sec4_item1'.tr(),
                  'terms_sec4_item2'.tr(),
                  'terms_sec4_item3'.tr(),
                  'terms_sec4_item4'.tr(),
                ],
              ),

              // Section 5: Virtual Coins
              _buildSection(
                number: '5',
                title: 'terms_sec5_title'.tr(),
                items: [
                  'terms_sec5_item1'.tr(),
                  'terms_sec5_item2'.tr(),
                  'terms_sec5_item3'.tr(),
                  'terms_sec5_item4'.tr(),
                ],
              ),

              // Section 6: 1v1 Challenges & Teams
              _buildSection(
                number: '6',
                title: 'terms_sec6_title'.tr(),
                items: [
                  'terms_sec6_item1'.tr(),
                  'terms_sec6_item2'.tr(),
                  'terms_sec6_item3'.tr(),
                  'terms_sec6_item4'.tr(),
                ],
              ),

              // Section 7: Account Suspension
              _buildSection(
                number: '7',
                title: 'terms_sec7_title'.tr(),
                items: [
                  'terms_sec7_item1'.tr(),
                  'terms_sec7_item2'.tr(),
                  'terms_sec7_item3'.tr(),
                  'terms_sec7_item4'.tr(),
                ],
              ),

              // Section 8: Disclaimers
              _buildSection(
                number: '8',
                title: 'terms_sec8_title'.tr(),
                items: [
                  'terms_sec8_item1'.tr(),
                  'terms_sec8_item2'.tr(),
                  'terms_sec8_item3'.tr(),
                  'terms_sec8_item4'.tr(),
                ],
              ),

              // Section 9: Limitation of Liability
              _buildSection(
                number: '9',
                title: 'terms_sec9_title'.tr(),
                items: [
                  'terms_sec9_item1'.tr(),
                  'terms_sec9_item2'.tr(),
                  'terms_sec9_item3'.tr(),
                ],
              ),

              // Section 10: Changes to Terms
              _buildSection(
                number: '10',
                title: 'terms_sec10_title'.tr(),
                items: [
                  'terms_sec10_item1'.tr(),
                  'terms_sec10_item2'.tr(),
                  'terms_sec10_item3'.tr(),
                ],
              ),

              // Section 11: Contact
              _buildSection(
                number: '11',
                title: 'terms_sec11_title'.tr(),
                items: [
                  'terms_sec11_item1'.tr(),
                  'terms_sec11_item2'.tr(args: [contactEmail]),
                  'terms_sec11_item3'.tr(),
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
                  label: Text(
                    'btn_open_hosted_version'.tr(),
                    style: const TextStyle(
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
                  child: Text(
                    'btn_i_agree'.tr(),
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
                      padding: EdgeInsetsDirectional.only(top: 6, end: 10),
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
