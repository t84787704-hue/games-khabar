import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';

/// COPPA / Play Store compliant Age Gate Screen.
/// 
/// Shows on first launch. User MUST confirm they are 13+ to use the app.
/// If user is under 13, app exits (or shows a message).
/// 
/// Age verification is stored locally (SharedPreferences) AND
/// in Supabase users table (age_verified column).
class GamerAgeGateScreen extends StatefulWidget {
  final VoidCallback onVerified;

  const GamerAgeGateScreen({super.key, required this.onVerified});

  @override
  State<GamerAgeGateScreen> createState() => _GamerAgeGateScreenState();
}

class _GamerAgeGateScreenState extends State<GamerAgeGateScreen> {
  bool _isChecking = false;

  Future<void> _handleConfirmAge() async {
    setState(() => _isChecking = true);

    try {
      // 1. Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('age_verified', true);
      await prefs.setString(
        'age_verified_at',
        DateTime.now().toIso8601String(),
      );

      // 2. Try to save to Supabase (if user is logged in)
      try {
        final uid = GamerAuthService().currentUid ?? '';
        if (uid.isNotEmpty) {
          final uuid = SupabaseService.toUuid(uid);
          await SupabaseService.client
              .from('users')
              .update({
            'age_verified': true,
            'terms_accepted': true,
            'terms_accepted_at': DateTime.now().toIso8601String(),
            'privacy_accepted': true,
            'privacy_accepted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', uuid);
        }
      } catch (e) {
        debugPrint('[AgeGate] Supabase update error (ignored): $e');
      }

      if (!mounted) return;
      widget.onVerified();
    } catch (e) {
      debugPrint('[AgeGate] Error: $e');
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _handleUnderage() async {
    // Show dialog explaining that the app is for 13+ only
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFF1877F2), size: 24),
              SizedBox(width: 8),
              Text(
                'Age Restriction',
                style: TextStyle(
                  color: Color(0xFF050505),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          content: const Text(
            'Games Khabar is designed for users 13 years and older. We do not knowingly collect data from children under 13.\n\nIf you are under 13, please close the app and do not use it.',
            style: TextStyle(
              color: Color(0xFF65676B),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                // Optionally close the app
                // exit(0);  // Uncomment to close app on Android
              },
              child: const Text(
                'I Understand',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1877F2), Color(0xFFFF8A00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1877F2).withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.sports_esports_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'GAMERS ID',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Mini Facebook for Gamers',
                  style: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 48),

                // Age Question Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A29),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF1877F2).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1877F2).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cake_rounded,
                          color: Color(0xFF1877F2),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Age Verification',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Kya aap 13 saal ya usse zyada ke hain?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Are you 13 years or older?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // YES Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isChecking ? null : _handleConfirmAge,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1877F2),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF1877F2).withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isChecking
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Haan, main 13+ hoon',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // NO Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isChecking ? null : _handleUnderage,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8B949E),
                            side: const BorderSide(color: Color(0xFF2A3447)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Nahi, main 13 se chota hoon',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Legal Links
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/privacy-policy');
                      },
                      child: const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text(
                      '•',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/terms');
                      },
                      child: const Text(
                        'Terms of Service',
                        style: TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // COPPA Notice
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'This app complies with COPPA. We do not knowingly collect data from children under 13.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF65676B),
                      fontSize: 11,
                      height: 1.4,
                    ),
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