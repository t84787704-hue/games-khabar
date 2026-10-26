// ===============================================================================
// GAMER GROWTH HUB — UC Shop & Room Countdown (10-Min Timer Removed)
// File: lib/widgets/gamer_growth_hub_dialog.dart
// ===============================================================================

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
              final playerGameUid = gameIdController.text.trim();
              if (playerGameUid.isEmpty) return;

              try {
                final userRes = await SupabaseService.client.from('users').select('coins, username, email').eq('id', uid!).maybeSingle();
                final balance = (userRes?['coins'] as num?)?.toInt() ?? 0;
                final username = (userRes?['username'] ?? 'Player').toString();

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

                // Deduct coins
                await SupabaseService.client.from('users').update({'coins': balance - requiredCoins}).eq('id', uid);

                // Transaction log
                try {
                  await SupabaseService.client.from('coin_transactions').insert({
                    'user_id': uid,
                    'amount': -requiredCoins,
                    'type': 'redeem_purchase',
                    'description': 'Redeemed $itemName for Game UID: $playerGameUid',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                } catch (_) {}

                // Insert into reports as redemption request so Admin sees it
                await SupabaseService.client.from('reports').insert({
                  'reporter_username': username,
                  'target_type': 'redeem_request',
                  'target_id': uid,
                  'target_content': '$itemName | Game UID: $playerGameUid | Cost: $requiredCoins Coins',
                  'reason': 'Pending Delivery: $itemName to $playerGameUid',
                  'status': 'pending',
                  'created_at': DateTime.now().toIso8601String(),
                });

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Redeem request for $itemName submitted! Admin will deliver soon.'),
                      backgroundColor: const Color(0xFF00FF88),
                      duration: const Duration(seconds: 3),
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
