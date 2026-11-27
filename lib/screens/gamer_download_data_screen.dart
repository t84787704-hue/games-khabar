import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_data_export_service.dart';
import '../services/theme_service.dart';

/// GDPR / DPDP Act compliant Download Data Screen.
///
/// User can download all their data as a JSON file.
class GamerDownloadDataScreen extends StatefulWidget {
  const GamerDownloadDataScreen({super.key});

  @override
  State<GamerDownloadDataScreen> createState() =>
      _GamerDownloadDataScreenState();
}

class _GamerDownloadDataScreenState extends State<GamerDownloadDataScreen> {
  bool _isExporting = false;

  static const Color _bgDark = Color(0xFF0A0E17);
  static const Color _appBarDark = Color(0xFF121824);
  static const Color _cardDark = Color(0xFF121824);
  static const Color _cardElevatedDark = Color(0xFF182234);
  static const Color _borderDark = Color(0xFF1F2E45);
  static const Color _textPrimaryDark = Color(0xFFF8FAFC);
  static const Color _textSecondaryDark = Color(0xFF94A3B8);
  static const Color _accentBlue = Color(0xFF1877F2);
  static const Color _accentCyan = Color(0xFF38BDF8);

  Future<void> _handleDownload() async {
    final authService = GamerAuthService();
    final uid = authService.currentUid ?? '';

    if (uid.isEmpty) {
      _showSnackBar('err_user_not_found_login'.tr(), isError: true);
      return;
    }

    setState(() => _isExporting = true);

    try {
      // 1. Fetch all data
      final data = await GamerDataExportService().exportUserData(uid);
      final jsonString = GamerDataExportService().toJsonString(data);

      // 2. Write to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/gamers_id_data_$timestamp.json');
      await file.writeAsString(jsonString);

      if (!mounted) return;

      // 3. Share the file
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'data_export_share_subject'.tr(),
        text: 'data_export_share_text'.tr(),
      );

      if (!mounted) return;
      setState(() => _isExporting = false);
      _showSnackBar('msg_data_exported_success'.tr(), isError: false);
    } catch (e) {
      debugPrint('[DownloadData] Error: $e');
      if (mounted) {
        setState(() => _isExporting = false);
        _showSnackBar(
          'err_failed_to_export_data'.tr(args: [e.toString()]),
          isError: true,
        );
      }
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFFF4655) : const Color(0xFF34A853),
        duration: const Duration(seconds: 3),
      ),
    );
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
              'title_download_my_data'.tr(),
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
                  // Info Banner
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
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: _accentCyan,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'download_data_banner_text'.tr(),
                            style: const TextStyle(
                              color: _textPrimaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // What's included
                  Text(
                    'download_data_included_title'.tr(),
                    style: const TextStyle(
                      color: _textPrimaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint('download_bullet_profile'.tr()),
                  _buildBulletPoint('download_bullet_posts'.tr()),
                  _buildBulletPoint('download_bullet_comments'.tr()),
                  _buildBulletPoint('download_bullet_followers'.tr()),
                  _buildBulletPoint('download_bullet_teams'.tr()),
                  _buildBulletPoint('download_bullet_challenges'.tr()),
                  _buildBulletPoint('download_bullet_coins'.tr()),
                  _buildBulletPoint('download_bullet_notifications'.tr()),

                  const SizedBox(height: 24),

                  // Format Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderDark),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accentBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.file_present_rounded,
                            color: _accentCyan,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'format_info_title'.tr(),
                                style: const TextStyle(
                                  color: _textPrimaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'format_info_desc'.tr(),
                                style: const TextStyle(
                                  color: _textSecondaryDark,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Download Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : _handleDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _cardElevatedDark,
                        disabledForegroundColor: _textSecondaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 20),
                      label: Text(
                        _isExporting
                            ? 'btn_preparing_data'.tr()
                            : 'btn_download_my_data'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed:
                          _isExporting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _cardDark,
                        foregroundColor: _textPrimaryDark,
                        side: const BorderSide(color: _borderDark, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'cancel'.tr(),
                        style: const TextStyle(
                          color: _textPrimaryDark,
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

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(top: 3, end: 10),
            child: Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: _accentCyan,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _textSecondaryDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
