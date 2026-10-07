import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_data_export_service.dart';

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

  Future<void> _handleDownload() async {
    final authService = GamerAuthService();
    final uid = authService.currentUid ?? '';

    if (uid.isEmpty) {
      _showSnackBar('User not found. Please login again.', isError: true);
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
        subject: 'My Gamers ID Data Export',
        text: 'Here is my complete Gamers ID data export.',
      );

      if (!mounted) return;
      setState(() => _isExporting = false);
      _showSnackBar('✅ Data exported successfully!', isError: false);
    } catch (e) {
      debugPrint('[DownloadData] Error: $e');
      if (mounted) {
        setState(() => _isExporting = false);
        _showSnackBar('Failed to export data: $e', isError: true);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Download My Data',
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
              // Info Banner
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
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Color(0xFF1877F2), size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Download a copy of all your data on Gamers ID',
                        style: TextStyle(
                          color: Color(0xFF050505),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // What's included
              const Text(
                'What\'s included in your export:',
                style: TextStyle(
                  color: Color(0xFF050505),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _buildBulletPoint('Your profile and account information'),
              _buildBulletPoint('All your posts and content'),
              _buildBulletPoint('Your comments and likes'),
              _buildBulletPoint('Your followers and following lists'),
              _buildBulletPoint('Your teams and team memberships'),
              _buildBulletPoint('Your 1v1 challenge history'),
              _buildBulletPoint('Your G-Coins transaction history'),
              _buildBulletPoint('Your notifications'),

              const SizedBox(height: 24),

              // Format Info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCED0D4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.file_present_rounded,
                        color: Color(0xFF1877F2), size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'File Format: JSON',
                            style: TextStyle(
                              color: Color(0xFF050505),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'You can open the file with any text editor or JSON viewer. Your data is machine-readable and portable.',
                            style: TextStyle(
                              color: Color(0xFF65676B),
                              fontSize: 12,
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
                    backgroundColor: const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE4E6EB),
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
                    _isExporting ? 'Preparing your data...' : 'Download My Data',
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
                  onPressed: _isExporting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF050505),
                    side: const BorderSide(color: Color(0xFFCED0D4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
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

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 10),
            child: Icon(
              Icons.check_circle,
              size: 14,
              color: Color(0xFF1877F2),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF65676B),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}