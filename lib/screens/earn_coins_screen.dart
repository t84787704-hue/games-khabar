import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_wallet_model.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/ad_free_service.dart';

class EarnCoinsScreen extends StatefulWidget {
  const EarnCoinsScreen({Key? key}) : super(key: key);

  @override
  State<EarnCoinsScreen> createState() => _EarnCoinsScreenState();
}

class _EarnCoinsScreenState extends State<EarnCoinsScreen> {
  final CoinWalletService _walletService = CoinWalletService();
  final TextEditingController _referralInputController = TextEditingController();

  bool _isWatchingAd = false;
  bool _isClaimingDaily = false;
  bool _isRegisteringReferral = false;

  String get _userId => GamerAuthService().currentUid ?? '';

  @override
  void initState() {
    super.initState();
    if (_userId.isNotEmpty) {
      _walletService.getOrCreateWallet(_userId);
    }
  }

  @override
  void dispose() {
    _referralInputController.dispose();
    super.dispose();
  }

  Future<void> _watchAd() async {
    if (_isWatchingAd) return;
    setState(() => _isWatchingAd = true);
    try {
      await AdFreeService().showRewardedAdForAction(
        context: context,
        actionTitle: 'action_watch_ad_100_coins'.tr(),
        onRewardEarned: () async {
          await _walletService.rewardAdCoins(_userId);
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('msg_100_gcoins_added'.tr()),
                backgroundColor: GamerTheme.neonGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_ad_failed_load'.tr(args: [e.toString()])),
            backgroundColor: GamerTheme.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWatchingAd = false);
    }
  }

  Future<void> _claimDailyBonus(CoinWallet wallet) async {
    if (_isClaimingDaily) return;
    if (!wallet.canClaimDailyBonus) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('msg_next_daily_bonus_in'.tr(args: [_formatDuration(wallet.nextDailyBonusDuration)])),
          backgroundColor: GamerTheme.accentOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isClaimingDaily = true);
    try {
      final success = await _walletService.claimDailyBonus(_userId);
      if (mounted) {
        setState(() {});
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('msg_50_gcoins_daily_bonus_claimed'.tr()),
              backgroundColor: GamerTheme.neonGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('msg_daily_bonus_already_claimed'.tr()),
              backgroundColor: GamerTheme.accentOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_failed_to_claim_bonus'.tr(args: [e.toString()])),
            backgroundColor: GamerTheme.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaimingDaily = false);
    }
  }

  Future<void> _applyReferralCode() async {
    final code = _referralInputController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('msg_enter_referral_code'.tr()),
          backgroundColor: GamerTheme.accentOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final myCode = _walletService.getReferralCode(_userId);
    if (code == myCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('err_cannot_use_own_referral'.tr()),
          backgroundColor: GamerTheme.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isRegisteringReferral = true);
    try {
      final ok = await _walletService.registerReferralCode(_userId, code);
      if (mounted) {
        setState(() {});
        if (ok) {
          _referralInputController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('msg_referral_linked_success'.tr()),
              backgroundColor: GamerTheme.neonGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('err_referral_already_linked_or_invalid'.tr()),
              backgroundColor: GamerTheme.accentOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_failed_with_msg'.tr(args: [e.toString()])),
            backgroundColor: GamerTheme.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegisteringReferral = false);
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B101B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'title_earn_g_coins'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<CoinWallet>(
        stream: _walletService.walletStream(_userId),
        builder: (context, snapshot) {
          final wallet = snapshot.data ?? _walletService.currentWallet ?? CoinWallet.empty(_userId);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceBanner(wallet.coins),
                const SizedBox(height: 20),
                Text(
                  'ways_to_earn_title'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. WATCH AD (+100 COINS, UNLIMITED)
                _buildActionCard(
                  icon: Icons.play_circle_fill_rounded,
                  iconColor: GamerTheme.neonGreen,
                  badgeText: 'badge_plus_100_coins'.tr(),
                  title: 'watch_sponsored_ad_title'.tr(),
                  subtitle: 'watch_sponsored_ad_sub'.tr(),
                  buttonText: _isWatchingAd ? 'btn_loading'.tr() : 'btn_watch_ad_100'.tr(),
                  isLoading: _isWatchingAd,
                  onTap: _isWatchingAd ? null : _watchAd,
                ),
                const SizedBox(height: 12),

                // 2. DAILY LOGIN BONUS (+50 COINS, 24H COOLDOWN)
                _buildActionCard(
                  icon: Icons.calendar_today_rounded,
                  iconColor: GamerTheme.accentOrange,
                  badgeText: 'badge_plus_50_coins'.tr(),
                  title: 'daily_login_bonus_gift_title'.tr(),
                  subtitle: wallet.canClaimDailyBonus
                      ? 'daily_bonus_available_now'.tr()
                      : 'daily_bonus_next_in'.tr(args: [_formatDuration(wallet.nextDailyBonusDuration)]),
                  buttonText: _isClaimingDaily
                      ? 'btn_claiming'.tr()
                      : (wallet.canClaimDailyBonus ? 'btn_claim_50'.tr() : 'btn_locked_wait'.tr()),
                  isLoading: _isClaimingDaily,
                  onTap: wallet.canClaimDailyBonus && !_isClaimingDaily
                      ? () => _claimDailyBonus(wallet)
                      : null,
                ),
                const SizedBox(height: 20),

                // 3. REFERRAL SECTION (+100 COINS)
                Text(
                  'refer_and_earn_title'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildReferralCard(),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceBanner(int coins) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF141D2E), Color(0xFF0F1523)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: GamerTheme.neonGreen.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🪙', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'your_wallet_balance_caps'.tr(),
                style: const TextStyle(
                  color: GamerTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'coins_formatted_gcoins'.tr(args: [NumberFormat('#,###').format(coins)]),
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required String title,
    required String subtitle,
    required String buttonText,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: GamerTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: onTap != null ? iconColor : GamerTheme.cardElevated,
                      foregroundColor: onTap != null ? Colors.black : GamerTheme.textMuted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      disabledBackgroundColor: GamerTheme.cardElevated,
                    ),
                    onPressed: onTap,
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            buttonText,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard() {
    final myCode = _walletService.getReferralCode(_userId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GamerTheme.accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: GamerTheme.accentBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'invite_earn_together_title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'invite_earn_together_sub'.tr(),
                      style: const TextStyle(
                        color: GamerTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // User's own referral code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B101B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Text(
                  'your_code_caps'.tr(),
                  style: const TextStyle(
                    color: GamerTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                SelectableText(
                  myCode,
                  style: const TextStyle(
                    color: GamerTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: myCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('msg_referral_code_copied'.tr()),
                        backgroundColor: GamerTheme.neonGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_rounded, color: GamerTheme.neonGreen, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Share button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.neonGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.share_rounded, size: 16),
              label: Text(
                'btn_share_invite_code'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
              onPressed: () {
                Share.share(
                  'share_invite_earn_msg'.tr(args: [myCode]),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: GamerTheme.borderDark, height: 1),
          const SizedBox(height: 14),

          // Friend's referral entry field
          Text(
            'have_friend_referral_title'.tr(),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'have_friend_referral_sub'.tr(),
            style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _referralInputController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'hint_enter_referral_code'.tr(),
                    hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0B101B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: GamerTheme.borderDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: GamerTheme.accentBlue),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GamerTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isRegisteringReferral ? null : _applyReferralCode,
                child: _isRegisteringReferral
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'btn_apply'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
