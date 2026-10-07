import 'dart:async';
import 'package:flutter/material.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import 'gamer_auth_screen.dart';

/// Play Store compliant Delete Account Screen
/// 
/// - User ke 2-step confirmation ke baad account soft-delete hoga
/// - `users.deleted_at` timestamp set hoga
/// - User logout ho jaayega
/// - 30 din baad Supabase cron job permanent delete karega
/// - GDPR / DPDP Act compliant
class GamerDeleteAccountScreen extends StatefulWidget {
  const GamerDeleteAccountScreen({super.key});

  @override
  State<GamerDeleteAccountScreen> createState() =>
      _GamerDeleteAccountScreenState();
}

class _GamerDeleteAccountScreenState extends State<GamerDeleteAccountScreen> {
  bool _step1Accepted = false;
  bool _step2Accepted = false;
  bool _isDeleting = false;
  final TextEditingController _confirmController = TextEditingController();

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteAccount() async {
    final authService = GamerAuthService();
    final uid = authService.currentUid ?? '';

    if (uid.isEmpty) {
      _showSnackBar('User not found. Please login again.', isError: true);
      return;
    }

    if (_confirmController.text.trim().toUpperCase() != 'DELETE') {
      _showSnackBar('Please type DELETE to confirm.', isError: true);
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final uuid = SupabaseService.toUuid(uid);

      // 1. Soft-delete: Set deleted_at timestamp
      await SupabaseService.client
          .from('users')
          .update({
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uuid);

      // 2. Sign out user
      await authService.signOut();

      if (!mounted) return;

      // 3. Show success and redirect
      _showSnackBar(
        '✅ Account scheduled for deletion. Logged out.',
        isError: false,
      );

      // Wait 2 seconds so user sees the message
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // 4. Navigate to auth screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const GamerAuthScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('[DeleteAccount] Error: $e');
      if (mounted) {
        setState(() => _isDeleting = false);
        _showSnackBar('Failed to delete account: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFFF4655) : const Color(0xFF34A853),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _step1Accepted &&
        _step2Accepted &&
        _confirmController.text.trim().toUpperCase() == 'DELETE' &&
        !_isDeleting;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Delete Account',
          style: TextStyle(
            color: Color(0xFFDC2626),
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
              // Warning Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFFF4655), size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Warning: This action cannot be undone after 30 days',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // What will be deleted
              const Text(
                'What will be permanently deleted:',
                style: TextStyle(
                  color: Color(0xFF050505),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _buildBulletPoint('Your profile and all personal information'),
              _buildBulletPoint('All your posts, comments, and likes'),
              _buildBulletPoint('Your teams and team memberships'),
              _buildBulletPoint('Your 1v1 challenge history'),
              _buildBulletPoint('Your G-Coins balance and transaction history'),
              _buildBulletPoint('Your followers and following lists'),

              const SizedBox(height: 20),

              // 30-day grace period info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F3FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1877F2), width: 1.2),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Color(0xFF1877F2), size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You have a 30-day grace period. If you log back in within 30 days, your account will be restored automatically.',
                        style: TextStyle(
                          color: Color(0xFF050505),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(color: Color(0xFFCED0D4), thickness: 1),
              const SizedBox(height: 20),

              // Step 1: I understand
              _buildCheckboxTile(
                value: _step1Accepted,
                title: 'I understand this action cannot be undone after 30 days',
                onChanged: (v) => setState(() => _step1Accepted = v ?? false),
              ),
              const SizedBox(height: 8),

              // Step 2: I want to delete
              _buildCheckboxTile(
                value: _step2Accepted,
                title: 'I want to permanently delete my account',
                onChanged: (v) => setState(() => _step2Accepted = v ?? false),
              ),

              const SizedBox(height: 24),

              // Confirm Text Field
              const Text(
                'Type DELETE to confirm:',
                style: TextStyle(
                  color: Color(0xFF050505),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                enabled: !_isDeleting,
                style: const TextStyle(
                  color: Color(0xFF050505),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: const TextStyle(color: Color(0xFF8A8D91)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCED0D4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCED0D4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Delete Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: canDelete ? _handleDeleteAccount : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE4E6EB),
                    disabledForegroundColor: const Color(0xFF8A8D91),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_forever_rounded, size: 20),
                  label: Text(
                    _isDeleting
                        ? 'Deleting Account...'
                        : 'Permanently Delete My Account',
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
                  onPressed: _isDeleting ? null : () => Navigator.pop(context),
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
              Icons.circle,
              size: 6,
              color: Color(0xFFDC2626),
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

  Widget _buildCheckboxTile({
    required bool value,
    required String title,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF050505),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}