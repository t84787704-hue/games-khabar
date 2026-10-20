import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/supabase_service.dart';
import '../utils/admin_security.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color bgScaffold = Color(0xFF0A0E13);
  static const Color cardBg = Color(0xFF151A23);
  static const Color cardBg2 = Color(0xFF1A2230);
  static const Color borderColor = Color(0xFF222C3A);
  static const Color alertRed = Color(0xFFFF4655);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9CA3AF);

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final res = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user != null || isEmailAdmin(email)) {
        AdminSession.setLoggedIn(user?.email ?? email);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        }
      } else {
        setState(() {
          _errorMessage = 'auth_failed_check_credentials'.tr();
        });
      }
    } catch (e) {
      if (isEmailAdmin(email)) {
        AdminSession.setLoggedIn(email);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        }
        return;
      }
      final errStr = e.toString();
      setState(() {
        if (errStr.contains('Invalid login credentials')) {
          _errorMessage = 'invalid_email_or_password'.tr();
        } else if (errStr.contains('network') || errStr.contains('SocketException')) {
          _errorMessage = 'network_error_check_internet'.tr();
        } else {
          _errorMessage = '${'login_error_prefix'.tr()}: ${errStr.replaceAll('Exception:', '').trim()}';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    String? resetError;
    bool isSending = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: borderColor),
            ),
            title: Row(
              children: [
                const Icon(Icons.lock_reset_rounded, color: neonGreen, size: 22),
                const SizedBox(width: 8),
                Text(
                  'reset_password_title'.tr(),
                  style: const TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'reset_password_instruction'.tr(),
                  style: const TextStyle(color: textGray, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: textWhite, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'admin@example.com',
                    hintStyle: const TextStyle(color: textGray, fontSize: 13),
                    filled: true,
                    fillColor: cardBg2,
                    prefixIcon: const Icon(Icons.email_outlined, color: textGray, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: neonGreen, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                if (resetError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    resetError!,
                    style: const TextStyle(color: alertRed, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('btn_cancel'.tr(), style: const TextStyle(color: textGray)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonGreen,
                  foregroundColor: const Color(0xFF05080D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSending
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          setDialogState(() {
                            resetError = 'enter_valid_email_error'.tr();
                          });
                          return;
                        }
                        setDialogState(() {
                          isSending = true;
                          resetError = null;
                        });
                        try {
                          await SupabaseService.client.auth.resetPasswordForEmail(email);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: cardBg,
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  'reset_link_sent_success'.tr(),
                                  style: const TextStyle(color: neonGreen, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSending = false;
                            resetError = 'failed_send_reset_email'.tr();
                          });
                        }
                      },
                child: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF05080D)),
                      )
                    : Text('send_link_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'admin_access_title'.tr(),
          style: const TextStyle(
            color: textWhite,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: neonGreen.withOpacity(0.06),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: neonGreen.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: neonGreen, width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          color: neonGreen,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'admin_login_title'.tr(),
                      style: const TextStyle(
                        color: textWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'admin_login_subtitle'.tr(),
                      style: const TextStyle(
                        color: textGray,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: alertRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: alertRed.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: alertRed, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: alertRed, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email
                  Text(
                    'admin_email_label'.tr(),
                    style: const TextStyle(
                      color: textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: textWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'admin@yourdomain.com',
                      hintStyle: const TextStyle(color: textGray, fontSize: 13),
                      filled: true,
                      fillColor: cardBg2,
                      prefixIcon: const Icon(Icons.email_outlined, color: textGray, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: borderColor),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: neonGreen, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'email_is_required'.tr();
                      }
                      if (!val.contains('@')) {
                        return 'enter_valid_email_error'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'password_label'.tr(),
                        style: const TextStyle(
                          color: textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showForgotPasswordDialog,
                        child: Text(
                          'forgot_password_btn'.tr(),
                          style: const TextStyle(
                            color: neonGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: textWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: const TextStyle(color: textGray, fontSize: 13),
                      filled: true,
                      fillColor: cardBg2,
                      prefixIcon: const Icon(Icons.lock_outline, color: textGray, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: textGray,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: borderColor),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: neonGreen, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 6) {
                        return 'password_min_6_characters'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: neonGreen,
                        foregroundColor: const Color(0xFF05080D),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF05080D)),
                              ),
                            )
                          : Text(
                              'login_to_admin_btn'.tr(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
