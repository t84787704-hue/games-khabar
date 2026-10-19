// lib/widgets/coin_or_ad_popup.dart
//
// WHAT CHANGED:
// - Full easy_localization integration (.tr())
// - Replaced all hardcoded text and Roman Urdu with translation keys

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/gamer_auth_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/ad_free_service.dart';
import '../services/supabase_service.dart';

class CoinOrAdPopup extends StatefulWidget {
  final String actionName;
  final Future<void> Function() onConfirm;
  final int coinCost;

  const CoinOrAdPopup({
    super.key,
    required this.actionName,
    required this.onConfirm,
    this.coinCost = 100,
  });

  /// Displays the confirmation popup. Returns true if action was executed, false if cancelled.
  static Future<bool> show({
    required BuildContext context,
    required String actionName,
    required Future<void> Function() onConfirm,
    int coinCost = 100,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CoinOrAdPopup(
        actionName: actionName,
        onConfirm: onConfirm,
        coinCost: coinCost,
      ),
    );
    return result ?? false;
  }

  @override
  State<CoinOrAdPopup> createState() => _CoinOrAdPopupState();
}

class _CoinOrAdPopupState extends State<CoinOrAdPopup> {
  int _userCoins = 0;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchUserCoins();
  }

  Future<void> _fetchUserCoins() async {
    int balance = 0;
    try {
      final currentGamer = GamerAuthService().currentGamer;
      if (currentGamer != null) {
        balance = currentGamer.coins;
      }

      final uid = GamerAuthService().currentUid ??
          SupabaseService.client.auth.currentUser?.id ??
          '';
      if (uid.isNotEmpty) {
        final row = await SupabaseService.client
            .from('users')
            .select('coins')
            .or('id.eq.$uid,uid.eq.$uid')
            .maybeSingle();
        if (row != null && row['coins'] != null) {
          balance = (row['coins'] as num).toInt();
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _userCoins = balance;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUseCoins() async {
    if (_userCoins < widget.coinCost || _isProcessing) return;

    setState(() => _isProcessing = true);
    final uid = GamerAuthService().currentUid ??
        SupabaseService.client.auth.currentUser?.id ??
        '';

    try {
      if (uid.isNotEmpty) {
        await CoinWalletService.updateCoins(
          userId: uid,
          amount: -widget.coinCost,
          type: 'action_fee',
          title: 'Action Fee — ${widget.actionName}',
          description: 'Used ${widget.coinCost} coins for ${widget.actionName}',
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
      await widget.onConfirm();
    } catch (e) {
      debugPrint('[CoinOrAdPopup] Error using coins: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
        Navigator.pop(context, false);
      }
    }
  }

  Future<void> _handleWatchAd() async {
    if (_isProcessing) return;

    Navigator.pop(context, true);

    await AdFreeService().showRewardedAdForAction(
      context: context,
      actionTitle: widget.actionName,
      onRewardEarned: () async {
        try {
          await widget.onConfirm();
        } catch (e) {
          debugPrint('[CoinOrAdPopup] onRewardEarned error: $e');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canAffordCoins = _userCoins >= widget.coinCost;

    return Dialog(
      backgroundColor: const Color(0xFF131A29),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: Color(0xFF00FF88), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'confirm_action_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Name Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2B3E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A3C54)),
              ),
              child: Row(
                children: [
                  Text(
                    '${'action_label'.tr()}: ',
                    style: const TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.actionName,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Option 1: Use Coins
            ElevatedButton(
              onPressed: (_isLoading || !canAffordCoins || _isProcessing)
                  ? null
                  : _handleUseCoins,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB800),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF2A3342),
                disabledForegroundColor: const Color(0xFF65676B),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'use_coins_btn'.tr(args: [widget.coinCost.toString()]),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isLoading
                        ? 'checking_balance_label'.tr()
                        : '(${'your_balance_label'.tr(args: [_userCoins.toString()])})${!canAffordCoins ? ' — ${'min_coins_required_label'.tr(args: [widget.coinCost.toString()])}' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: canAffordCoins
                          ? Colors.black87
                          : const Color(0xFFFF4655),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Option 2: Watch Ad (30 seconds)
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleWatchAd,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
              label: Text(
                'watch_ad_btn'.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 3: Cancel
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8B949E),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                'btn_cancel'.tr(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
