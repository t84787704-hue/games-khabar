import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/theme_service.dart';

/// Play Store compliant Terms of Service Screen.
class GamerTermsOfServiceScreen extends StatelessWidget {
  const GamerTermsOfServiceScreen({super.key});

  static const String hostedTermsUrl =
      'https://gameskhabar.com/terms-of-service';
  static const String appName = 'Games Khabar / Gamers ID';
  static const String contactEmail = 'support@gameskhabar.com';
  static const String lastUpdated = 'January 2025';

  static const Color _bgDark = Color(0xFF0A0E17);
  static const Color _appBarDark = Color(0xFF121824);
  static const Color _cardDark = Color(0xFF121824);
  static const Color _cardElevatedDark = Color(0xFF182234);
  static const Color _borderDark = Color(0xFF1F2E45);
  static const Color _textPrimaryDark = Color(0xFFF8FAFC);
  static const Color _textSecondaryDark = Color(0xFF94A3B8);
  static const Color _accentBlue = Color(0xFF1877F2);
  static const Color _accentCyan = Color(0xFF38BDF8);

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: _bgDark,
          appBar: AppBar(
            backgroundColor: _appBarDark,
            foregroundColor: _textPrimaryDark,
            elevation: 0,
            iconTheme: const IconThemeData(color: _textPrimaryDark),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: _textPrimaryDark,
              ),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _borderDark),
            ),
            title: Text(
              'terms_of_service_title'.tr(),
              style: const TextStyle(
                color: _textPrimaryDark,
                fontWeight: FontWeight.w900,
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
                  // Header Callout Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accentBlue.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _accentBlue.withOpacity(0.55),
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
                              decoration: BoxDecoration(
                                color: _cardElevatedDark,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _accentBlue.withOpacity(0.5),
                                ),
                              ),
                              child: const Icon(
                                Icons.gavel_rounded,
                                color: _accentCyan,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'terms_of_service_title'.tr(),
                                style: const TextStyle(
                                  color: _textPrimaryDark,
                                  fontWeight: FontWeight.w900,
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
                            color: _textPrimaryDark,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'terms_last_updated'.tr(args: [lastUpdated]),
                          style: const TextStyle(
                            color: _textSecondaryDark,
                            fontSize: 11.5,
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
                        backgroundColor: _cardDark,
                        foregroundColor: _accentCyan,
                        side: BorderSide(
                          color: _accentCyan.withOpacity(0.6),
                          width: 1.2,
                        ),
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
                        backgroundColor: _accentBlue,
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
      },
    );
  }

  Widget _buildSection({
    required String number,
    required String title,
    required List<String> items,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _accentBlue.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _accentBlue.withOpacity(0.45),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: _accentCyan,
                        fontWeight: FontWeight.w900,
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
                      color: _textPrimaryDark,
                      fontWeight: FontWeight.w900,
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
                      padding: EdgeInsetsDirectional.only(top: 7, end: 10),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: _accentCyan,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: _textSecondaryDark,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
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
