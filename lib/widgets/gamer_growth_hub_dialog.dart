// ===============================================================================
// GAMER GROWTH HUB — Daily 10-Min Timer, UC Shop & Room Countdown
// File: lib/widgets/gamer_growth_hub_dialog.dart
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';

class GamerGrowthHubDialog extends StatefulWidget {
  const GamerGrowthHubDialog({super.key});

  @override
  State<GamerGrowthHubDialog> createState() => _GamerGrowthHubDialogState();
}

class _GamerGrowthHubDialogState extends State<GamerGrowthHubDialog> {
  static const int _targetSeconds = 600; // 10 minutes
  static int _secondsSpent = 0;
  static bool _hasClaimedToday = false;
  Timer? _ticker;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsSpent < _targetSeconds) {
        setState(() {
          _secondsSpent++;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatTimer(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _claim10MinReward() async {
    final uid = GamerAuthService().currentUid ?? SupabaseService.client.auth.currentUser?.id;
    if (uid == null || _hasClaimedToday || _secondsSpent < _targetSeconds) return;

    setState(() => _isClaiming = true);
    try {
      // ✅ 'gamers' ko 'users' se replace kiya gaya
      final userRes = await SupabaseService.client.from('users').select('coins').eq('id', uid).maybeSingle();
      final currentCoins = (userRes?['coins'] as num?)?.toInt() ?? 0;

      await SupabaseService.client.from('users').update({
        'coins': currentCoins + 50,
      }).eq('id', uid);

      try {
        await SupabaseService.client.from('coin_transactions').insert({
          'user_id': uid,
          'amount': 50,
          'type': 'daily_stay_reward',
          'description': '10 Minutes daily active app reward',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Agar coin_transactions table mojood na ho to error na de
      }

      setState(() {
        _hasClaimedToday = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 +50 Coins Added for spending 10 minutes!'),
            backgroundColor: Color(0xFF00FF88),
            duration: Duration(seconds: 2), // 2 seconds mein auto hide
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claim failed: $e'),
            backgroundColor: const Color(0xFFFF4655),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  void _showRedeemPrompt(String itemName, int requiredCoins) {
    final uid = GamerAuthService().currentUid ?? SupabaseService.client.auth.currentUser?.id;
    final gameIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.redeem_rounded, color: Color(0xFFFFD700)),
            const SizedBox(width: 8),
            Text('Redeem $itemName', style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cost: $requiredCoins Coins',
                style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            const Text('Enter your Game Character ID (UID) to receive direct code:',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: gameIdController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Player UID / Game ID',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final playerUid = gameIdController.text.trim();
              if (playerUid.isEmpty) return;

              try {
                // ✅ 'gamers' ko 'users' se replace kiya gaya
                final userRes = await SupabaseService.client.from('users').select('coins').eq('id', uid!).maybeSingle();
                final balance = (userRes?['coins'] as num?)?.toInt() ?? 0;

                if (balance < requiredCoins) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Insufficient Coins! Play more to earn.'),
                        backgroundColor: Color(0xFFFF4655),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                  return;
                }

                // Deduct coins & create order
                await SupabaseService.client.from('users').update({'coins': balance - requiredCoins}).eq('id', uid);
                await SupabaseService.client.from('reports').insert({
                  'reporter_username': playerUid,
                  'target_type': 'redeem_request',
                  'target_content': 'Requested $itemName for Game UID: $playerUid',
                  'reason': 'Pending UC/Diamond Transfer',
                  'status': 'pending',
                  'created_at': DateTime.now().toIso8601String(),
                });

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Redeem request for $itemName submitted! Will be delivered in 2 hours.'),
                      backgroundColor: const Color(0xFF00FF88),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Redeem error: $e'),
                      backgroundColor: const Color(0xFFFF4655),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm Claim', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_secondsSpent / _targetSeconds).clamp(0.0, 1.0);
    final isDone = _secondsSpent >= _targetSeconds;

    return Dialog(
      backgroundColor: const Color(0xFF161A22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 24),
                    SizedBox(width: 8),
                    Text('Rewards & UC Vault',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 10 MINUTE LIVE TIMER CARD
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Daily 10-Min Stay Bonus',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatTimer(_secondsSpent),
                          style: const TextStyle(
                              color: Color(0xFF00FF88), fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
                    borderRadius: BorderRadius.circular(6),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Spend 10 mins in app = +50 Coins',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDone && !_hasClaimedToday ? const Color(0xFF00FF88) : Colors.white12,
                          foregroundColor: isDone && !_hasClaimedToday ? Colors.black : Colors.white38,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: (isDone && !_hasClaimedToday && !_isClaiming) ? _claim10MinReward : null,
                        child: Text(_hasClaimedToday ? 'Claimed ✓' : 'Claim +50 🪙',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // REDEEM STORE SECTION
            const Text('Redeem Game Currency',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Limited Daily Stock • Fast Delivery to Game UID',
                style: TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 10),

            _buildRedeemItem(
              title: '60 PUBG UC Code',
              tag: 'PUBG / BGMI',
              cost: 1500,
              icon: Icons.sports_esports_rounded,
              color: const Color(0xFFFFD700),
              onTap: () => _showRedeemPrompt('60 PUBG UC', 1500),
            ),
            const SizedBox(height: 8),
            _buildRedeemItem(
              title: '100 Free Fire Diamonds',
              tag: 'Free Fire',
              cost: 1200,
              icon: Icons.diamond_rounded,
              color: const Color(0xFF38BDF8),
              onTap: () => _showRedeemPrompt('100 Free Fire Diamonds', 1200),
            ),
            const SizedBox(height: 8),
            _buildRedeemItem(
              title: '₹50 Google Play Card',
              tag: 'Play Store Redeem',
              cost: 1800,
              icon: Icons.card_giftcard_rounded,
              color: const Color(0xFF00FF88),
              onTap: () => _showRedeemPrompt('₹50 Google Play Card', 1800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedeemItem({
    required String title,
    required String tag,
    required int cost,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1218),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(tag, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onTap,
            child: Text('$cost 🪙', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
