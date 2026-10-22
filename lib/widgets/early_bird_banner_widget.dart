import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../screens/verification_screen.dart';

class EarlyBirdBannerWidget extends StatefulWidget {
  final String userId;

  const EarlyBirdBannerWidget({super.key, required this.userId});

  @override
  State<EarlyBirdBannerWidget> createState() => _EarlyBirdBannerWidgetState();
}

class _EarlyBirdBannerWidgetState extends State<EarlyBirdBannerWidget> {
  bool _isVisible = false;
  int _userRankNumber = 0;
  int _referralCount = 0;
  static const String _dismissPrefKey = 'early_bird_banner_dismissed';

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    if (widget.userId.isEmpty) return;

    try {
      // 1. Agar user ne pehle 'X' daba kar hide kar diya ho to return ho jaye
      final prefs = await SharedPreferences.getInstance();
      final isDismissed = prefs.getBool(_dismissPrefKey) ?? false;
      if (isDismissed) return;

      // 2. User ka record check karein
      final userRes = await SupabaseService.client
          .from('users')
          .select('created_at, is_verified, blue_tick_status, verification_status')
          .or('id.eq.${widget.userId},uid.eq.${widget.userId}')
          .maybeSingle();

      if (userRes == null) return;

      // 3. RULE 1: Jis user ke paas Blue Tick aa chuka hai, use KABHI na dikhayein
      final bool isAlreadyVerified = userRes['is_verified'] == true ||
          (userRes['blue_tick_status']?.toString().toLowerCase() == 'approved') ||
          (userRes['verification_status']?.toString().toLowerCase() == 'verified');

      if (isAlreadyVerified) {
        if (mounted) setState(() => _isVisible = false);
        return;
      }

      // 4. RULE 2: Registration rank check karein
      final createdAt = userRes['created_at'];
      if (createdAt != null) {
        final countRes = await SupabaseService.client
            .from('users')
            .select('id')
            .lte('created_at', createdAt)
            .count();

        _userRankNumber = countRes.count;

        // RULE 3: Sirf shuru ke 1200 users ke liye show hoga
        if (_userRankNumber <= 1200) {
          // Referrals count nikal lein
          final refRes = await SupabaseService.client
              .from('users')
              .select('id')
              .eq('referred_by', widget.userId)
              .count();

          _referralCount = refRes.count;

          if (mounted) {
            setState(() {
              _isVisible = true;
            });
          }
        } else {
          // 1200 ke baad walo ko bilkul na dikhayein
          if (mounted) setState(() => _isVisible = false);
        }
      }
    } catch (e) {
      debugPrint('[EarlyBirdBanner] Error: $e');
    }
  }

  Future<void> _dismissBanner() async {
    setState(() => _isVisible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissPrefKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF0F3443)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF88).withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Color(0xFF00FF88),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VerificationScreen()),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'VIP Early Bird Member! ',
                        style: TextStyle(
                          color: Color(0xFF00FF88),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '(#$_userRankNumber)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.35),
                      children: [
                        const TextSpan(text: 'Aap hamare pehle 1200 users mein shamil hain! Sirf '),
                        TextSpan(
                          text: '2 accounts join karwa kar',
                          style: TextStyle(
                            color: Colors.amber.shade300,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: ' Blue Tick unlock karein (${_referralCount}/2 Done) 🔥',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Hide Banner',
            onPressed: _dismissBanner,
          ),
        ],
      ),
    );
  }
}
