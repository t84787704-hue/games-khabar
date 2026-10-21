// ═══════════════════════════════════════════════════════════════════════════════
// CLEAN COIN STORE SCREEN — Localized with easy_localization & Adaptive Theme
// - Retained: Live Balance, Daily Check-in, Rewarded Ads, Referral & Activity History
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_wallet_model.dart';
import '../models/coin_transaction_model.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';

class CoinStoreScreen extends StatefulWidget {
  const CoinStoreScreen({super.key});

  @override
  State<CoinStoreScreen> createState() => _CoinStoreScreenState();
}

class _CoinStoreScreenState extends State<CoinStoreScreen> {
  final CoinWalletService _walletService = CoinWalletService();
  final GamerAuthService _authService = GamerAuthService();

  Timer? _countdownTimer;
  Duration _timeUntilNextClaim = Duration.zero;
  bool _isClaimingDaily = false;
  bool _isWatchingAd = false;

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUid ?? 'guest';
    _walletService.getOrCreateWallet(uid).then((wallet) {
      if (mounted) {
        _updateCountdown(wallet);
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final w = _walletService.currentWallet;
      if (w != null && mounted) {
        _updateCountdown(w);
      }
    });
  }

  void _updateCountdown(CoinWallet wallet) {
    setState(() {
      _timeUntilNextNext(wallet);
    });
  }

  void _timeUntilNextNext(CoinWallet wallet) {
    if (wallet.lastDailyBonusClaim == null) {
      _timeUntilNextClaim = Duration.zero;
      return;
    }
    final nextAvailable = wallet.lastDailyBonusClaim!.add(const Duration(hours: 24));
    final diff = nextAvailable.difference(DateTime.now());
    _timeUntilNextClaim = diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _handleClaimDaily(String uid) async {
    if (_isClaimingDaily) return;
    setState(() => _isClaimingDaily = true);

    int remainingSeconds = 5;
    Timer? adTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          adTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (remainingSeconds > 1) {
              setDialogState(() => remainingSeconds--);
            } else {
              t.cancel();
              Navigator.pop(dialogCtx);
              _walletService.claimDailyBonus(uid).then((success) {
                if (mounted) {
                  setState(() => _isClaimingDaily = false);
                  if (success) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        backgroundColor: GamerTheme.neonGreen,
                        content: Row(
                          children: [
                            const Text('🎁', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'msg_daily_streak_claimed'.tr(),
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                }
              });
            }
          });

          return AlertDialog(
            backgroundColor: ThemeService.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: GamerTheme.accentOrange, width: 2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: GamerTheme.accentOrange.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: GamerTheme.accentOrange, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'daily_bonus_ad_title'.tr(),
                    style: const TextStyle(
                      color: GamerTheme.accentOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThemeService.border,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${remainingSeconds}s',
                    style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: ThemeService.cardSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ThemeService.border),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.ondemand_video_rounded, color: GamerTheme.accentOrange, size: 44),
                        const SizedBox(height: 8),
                        Text(
                          'sponsor_gaming_network'.tr(),
                          style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'watch_5s_ad_desc'.tr(),
                          style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (5 - remainingSeconds) / 5.0,
                  backgroundColor: ThemeService.border,
                  color: GamerTheme.accentOrange,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      adTimer?.cancel();
      if (mounted) setState(() => _isClaimingDaily = false);
    });
  }

  Future<void> _handleWatchAd(String uid) async {
    if (_isWatchingAd) return;
    setState(() => _isWatchingAd = true);

    int remainingSeconds = 5;
    Timer? adTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          adTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (remainingSeconds > 1) {
              setDialogState(() => remainingSeconds--);
            } else {
              t.cancel();
              Navigator.pop(dialogCtx);
              _walletService.rewardAdCoins(uid);
              if (mounted) {
                setState(() => _isWatchingAd = false);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    backgroundColor: GamerTheme.neonGreen,
                    content: Row(
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'msg_ad_coins_added'.tr(),
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }
          });

          return AlertDialog(
            backgroundColor: ThemeService.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: GamerTheme.accentBlue, width: 2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: GamerTheme.accentBlue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: GamerTheme.accentBlue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'rewarded_ad_sponsor_title'.tr(),
                    style: const TextStyle(
                      color: GamerTheme.accentBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThemeService.border,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${remainingSeconds}s',
                    style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: ThemeService.cardSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ThemeService.border),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.smart_display_rounded, color: GamerTheme.accentBlue, size: 44),
                        const SizedBox(height: 8),
                        Text(
                          'streaming_gaming_sponsor'.tr(),
                          style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'watch_5s_earn_100_desc'.tr(),
                          style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (5 - remainingSeconds) / 5.0,
                  backgroundColor: ThemeService.border,
                  color: GamerTheme.accentBlue,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      adTimer?.cancel();
      if (mounted) setState(() => _isWatchingAd = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUid ?? 'guest';

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: ThemeService.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_rounded, color: GamerTheme.neonGreen, size: 22),
                const SizedBox(width: 8),
                Text(
                  'title_coin_store'.tr(),
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          body: StreamBuilder<CoinWallet>(
            stream: _walletService.walletStream(uid),
            builder: (context, snapshot) {
              final wallet = snapshot.data ?? _walletService.currentWallet ?? CoinWallet.empty(uid);

              return Column(
                children: [
                  _buildStoreHeader(wallet, uid),
                  Expanded(
                    child: _buildStoreContent(uid, wallet),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStoreHeader(CoinWallet wallet, String uid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ThemeService.card,
        border: Border(bottom: BorderSide(color: ThemeService.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Text('💰', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'balance_caps'.tr(),
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'coins_formatted_gcoins'.tr(args: [NumberFormat('#,###').format(wallet.coins)]),
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          InkWell(
            onTap: () => _handleWatchAd(uid),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: GamerTheme.neonGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill_rounded, color: Colors.black, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'btn_earn_100_ad'.tr(),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreContent(String uid, CoinWallet wallet) {
    final canClaimDaily = _timeUntilNextClaim == Duration.zero;
    final inviteCode = _walletService.getReferralCode(uid);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildEarnActionCard(
          icon: Icons.calendar_today_rounded,
          iconColor: GamerTheme.neonGreen,
          badge: 'badge_plus_50_coins'.tr(),
          badgeColor: GamerTheme.neonGreen,
          title: 'daily_checkin_reward_title'.tr(),
          subtitle: canClaimDaily
              ? 'daily_checkin_ready_sub'.tr()
              : 'daily_checkin_next_in'.tr(args: [_formatDuration(_timeUntilNextClaim)]),
          buttonText: _isClaimingDaily
              ? 'btn_watching'.tr()
              : (canClaimDaily ? 'btn_claim_50_coins'.tr() : _formatDuration(_timeUntilNextClaim)),
          buttonColor: canClaimDaily ? GamerTheme.neonGreen : ThemeService.cardSecondary,
          textColor: canClaimDaily ? Colors.black : ThemeService.textSecondary,
          onTap: canClaimDaily ? () => _handleClaimDaily(uid) : null,
        ),
        const SizedBox(height: 12),
        _buildEarnActionCard(
          icon: Icons.play_circle_filled_rounded,
          iconColor: GamerTheme.accentOrange,
          badge: 'badge_plus_100_each'.tr(),
          badgeColor: GamerTheme.accentOrange,
          title: 'watch_sponsored_ads_title'.tr(),
          subtitle: 'watch_sponsored_ads_sub'.tr(),
          buttonText: _isWatchingAd ? 'btn_streaming_ad'.tr() : 'btn_watch_ad_100'.tr(),
          buttonColor: GamerTheme.accentOrange,
          textColor: Colors.white,
          onTap: _isWatchingAd ? null : () => _handleWatchAd(uid),
        ),
        const SizedBox(height: 12),
        _buildEarnActionCard(
          icon: Icons.people_alt_rounded,
          iconColor: GamerTheme.accentBlue,
          badge: 'badge_plus_200_coins'.tr(),
          badgeColor: GamerTheme.accentBlue,
          title: 'squad_referral_bonus_title'.tr(),
          subtitle: 'squad_referral_bonus_sub'.tr(args: [inviteCode]),
          buttonText: 'btn_share_code'.tr(args: [inviteCode]),
          buttonColor: GamerTheme.accentBlue,
          textColor: Colors.white,
          onTap: () {
            Share.share(
              'share_invite_msg'.tr(args: [inviteCode]),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'store_reward_history_title'.tr(),
          style: const TextStyle(
            color: GamerTheme.accentBlue,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<CoinTransaction>>(
          stream: _walletService.transactionsStream(uid),
          builder: (context, txSnap) {
            final txList = txSnap.data ?? [];
            if (txList.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ThemeService.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Center(
                  child: Text(
                    'no_store_transactions'.tr(),
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final tx = txList[index];
                final isPositive = tx.amount > 0;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThemeService.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThemeService.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? GamerTheme.neonGreen.withOpacity(0.15)
                              : Colors.redAccent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPositive ? Icons.add_circle_rounded : Icons.shopping_bag_rounded,
                          color: isPositive ? GamerTheme.neonGreen : Colors.redAccent,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.title,
                              style: TextStyle(
                                color: ThemeService.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMM, hh:mm a').format(tx.timestamp),
                              style: TextStyle(color: ThemeService.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${NumberFormat('#,###').format(tx.amount)}',
                        style: TextStyle(
                          color: isPositive ? GamerTheme.neonGreen : Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEarnActionCard({
    required IconData icon,
    required Color iconColor,
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required String buttonText,
    required Color buttonColor,
    required Color textColor,
    required VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeService.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onTap,
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
