import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import 'create_gamer_id_screen.dart';
import 'gamer_main_navigation_screen.dart';
import 'banned_screen.dart';

class GamerAuthScreen extends StatefulWidget {
  const GamerAuthScreen({super.key});

  @override
  State<GamerAuthScreen> createState() => _GamerAuthScreenState();
}

class _GamerAuthScreenState extends State<GamerAuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _clearCacheAndRetry() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.signOut();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (e) {
        debugPrint('Error clearing SharedPreferences: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache clear ho gaya hai. Dobara sign in karen.'),
            backgroundColor: GamerTheme.accentBlue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in _clearCacheAndRetry: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePostAuth() async {
    final gamer = await GamerAuthService().refreshCurrentGamer();
    if (!mounted) return;

    if (gamer != null && gamer.isBanned) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => BannedScreen(reason: gamer.bannedReason)),
        (route) => false,
      );
      return;
    }

    if (gamer == null || gamer.username.isEmpty) {
      // Force user to Create ID screen if username does not exist
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CreateGamerIdScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GamerMainNavigationScreen()),
      );
    }
  }

  Future<void> _submitEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (_isSignUp && password != _confirmPasswordController.text.trim()) {
      _showError('Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await GamerAuthService().signUpWithEmail(email, password);
      } else {
        await GamerAuthService().signInWithEmail(email, password);
      }

      await _handlePostAuth();
    } on FirebaseAuthException catch (e) {
      if (!_isSignUp) {
        // Don't show raw Firebase error in red banner. Always show: "Email ya Password galat hai ya session expire ho gaya hai"
        final friendlyMsg = (e.message == 'Session khatam ho gaya hai, dobara login karen')
            ? 'Session khatam ho gaya hai, dobara login karen'
            : 'Email ya Password galat hai ya session expire ho gaya hai';
        setState(() => _errorMessage = friendlyMsg);
      } else {
        String msg = e.message ?? 'Authentication failed';
        if (e.code == 'email-already-in-use') msg = 'This email is already registered';
        setState(() => _errorMessage = msg);
        _showError(msg);
      }
    } catch (e) {
      if (!_isSignUp) {
        const friendlyMsg = 'Email ya Password galat hai ya session expire ho gaya hai';
        setState(() => _errorMessage = friendlyMsg);
      } else {
        final msg = 'Error: $e';
        setState(() => _errorMessage = msg);
        _showError(msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final cred = await GamerAuthService().signInWithGoogle();
      if (cred != null) {
        await _handlePostAuth();
      }
    } on FirebaseAuthException catch (e) {
      final friendlyMsg = (e.message == 'Session khatam ho gaya hai, dobara login karen')
          ? 'Session khatam ho gaya hai, dobara login karen'
          : 'Email ya Password galat hai ya session expire ho gaya hai';
      setState(() => _errorMessage = friendlyMsg);
    } catch (e) {
      setState(() => _errorMessage = 'Email ya Password galat hai ya session expire ho gaya hai');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await GamerAuthService().signInAnonymously();
      await _handlePostAuth();
    } catch (e) {
      _showError('Guest login error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: GamerTheme.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo / Gaming Emblem
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: GamerTheme.blueOrangeGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: GamerTheme.accentBlue.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.sports_esports_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // App Title
                ShaderMask(
                  shaderCallback: (bounds) => GamerTheme.blueOrangeGradient.createShader(bounds),
                  child: const Text(
                    'GAMERS ID',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mini Facebook for Gamers',
                  style: TextStyle(
                    color: GamerTheme.textGray,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 30),

                // Toggle Login / Sign Up
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: GamerTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GamerTheme.borderDark),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isSignUp = false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isSignUp ? GamerTheme.accentBlue : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  color: !_isSignUp ? GamerTheme.bgDark : GamerTheme.textGray,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isSignUp = true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isSignUp ? GamerTheme.accentOrange : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: _isSignUp ? Colors.white : GamerTheme.textGray,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Red Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: GamerTheme.redAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GamerTheme.redAccent.withOpacity(0.6), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: GamerTheme.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _errorMessage = null),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email Input
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: GamerTheme.textWhite),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined, color: GamerTheme.accentBlue),
                    hintText: 'Gamer Email',
                  ),
                ),
                const SizedBox(height: 14),

                // Password Input
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: GamerTheme.textWhite),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: GamerTheme.accentBlue),
                    hintText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: GamerTheme.textMuted,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                // Confirm Password Input (if Sign Up)
                if (_isSignUp) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: GamerTheme.textWhite),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.lock_reset_rounded, color: GamerTheme.accentOrange),
                      hintText: 'Confirm Password',
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitEmailAuth,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _isSignUp ? GamerTheme.flameOrangeGradient : GamerTheme.electricBlueGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text(
                                _isSignUp ? 'Create Account' : 'Sign In',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                // Clear Cache & Retry button
                if (!_isSignUp) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _clearCacheAndRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: GamerTheme.textMuted),
                      label: const Text(
                        'Clear Cache & Retry',
                        style: TextStyle(
                          color: GamerTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                Row(
                  children: const [
                    Expanded(child: Divider(color: GamerTheme.borderDark)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR CONNECT WITH',
                        style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(child: Divider(color: GamerTheme.borderDark)),
                  ],
                ),

                const SizedBox(height: 18),

                // Google Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: GamerTheme.borderLight),
                      backgroundColor: GamerTheme.cardDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Guest / Instant Demo Mode
                TextButton(
                  onPressed: _isLoading ? null : _signInGuest,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.flash_on_rounded, color: GamerTheme.accentOrange, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Instant Demo Mode (Quick Play)',
                        style: TextStyle(color: GamerTheme.accentOrange, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
