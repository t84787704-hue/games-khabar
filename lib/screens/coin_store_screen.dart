// ═══════════════════════════════════════════════════════════════════════════════
// CLEAN COIN STORE SCREEN
// - Removed: Frames, Badges, VIP passes, Spotlight, Chat colors, Feed/Room Boost
// - Retained: Live Balance, Daily Check-in, Rewarded Ads, Referral & Activity History
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_wallet_model.dart';
import '../models/coin_transaction_model.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';

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
                      const SnackBar(
                        backgroundColor: GamerTheme.neonGreen,
                        content: Row(
                          children: [
                            Text('🎁', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 10),
                            Text(
                              '+50 G-Coins Claimed! Daily Login Streak Bonus.',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
            backgroundColor: GamerTheme.bgDark,
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
                const Expanded(
                  child: Text(
                    'DAILY BONUS AD',
                    style: TextStyle(
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
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${remainingSeconds}s',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GamerTheme.borderLight),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ondemand_video_rounded, color: GamerTheme.accentOrange, size: 44),
                        SizedBox(height: 8),
                        Text(
                          'Sponsor Gaming Network',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Watch 5s ad to claim 50 G-Coins...',
                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (5 - remainingSeconds) / 5.0,
                  backgroundColor: GamerTheme.borderDark,
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
                  const SnackBar(
                    backgroundColor: GamerTheme.neonGreen,
                    content: Row(
                      children: [
                        Text('⚡', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 10),
                        Text(
                          '+100 G-Coins Added! Rewarded Video Ad completed.',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }
          });

          return AlertDialog(
            backgroundColor: GamerTheme.bgDark,
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
                const Expanded(
                  child: Text(
                    'REWARDED AD SPONSOR',
                    style: TextStyle(
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
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${remainingSeconds}s',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GamerTheme.borderLight),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.smart_display_rounded, color: GamerTheme.accentBlue, size: 44),
                        SizedBox(height: 8),
                        Text(
                          'Streaming Gaming Sponsor',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Watch 5s to earn +100 G-Coins...',
                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (5 - remainingSeconds) / 5.0,
                  backgroundColor: GamerTheme.borderDark,
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

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, color: GamerTheme.neonGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'COIN STORE',
              style: TextStyle(
                color: Colors.white,
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
  }

  Widget _buildStoreHeader(CoinWallet wallet, String uid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: GamerTheme.cardDark,
        border: Border(bottom: BorderSide(color: GamerTheme.borderDark)),
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
                  const Text(
                    'BALANCE',
                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(wallet.coins)} G-Coins',
                    style: const TextStyle(
                      color: Colors.white,
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
              child: const Row(
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: Colors.black, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'EARN +100 📺',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
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
          badge: '+50 COINS',
          badgeColor: GamerTheme.neonGreen,
          title: 'Daily Check-In Reward',
          subtitle: canClaimDaily
              ? 'Watch 1 sponsored ad to claim your 50 G-Coins daily bonus.'
              : 'Next daily claim available in ${_formatDuration(_timeUntilNextClaim)}',
          buttonText: _isClaimingDaily
              ? 'WATCHING...'
              : (canClaimDaily ? 'CLAIM 50 COINS 🎁' : _formatDuration(_timeUntilNextClaim)),
          buttonColor: canClaimDaily ? GamerTheme.neonGreen : GamerTheme.cardElevated,
          textColor: canClaimDaily ? Colors.black : GamerTheme.textMuted,
          onTap: canClaimDaily ? () => _handleClaimDaily(uid) : null,
        ),
        const SizedBox(height: 12),
        _buildEarnActionCard(
          icon: Icons.play_circle_filled_rounded,
          iconColor: GamerTheme.accentOrange,
          badge: '+100 COINS EACH',
          badgeColor: GamerTheme.accentOrange,
          title: 'Watch Sponsored Rewarded Ads',
          subtitle: 'Support the community and earn 100 G-Coins for each completed 5s sponsor video.',
          buttonText: _isWatchingAd ? 'STREAMING AD...' : 'WATCH AD (+100 COINS) 📺',
          buttonColor: GamerTheme.accentOrange,
          textColor: Colors.white,
          onTap: _isWatchingAd ? null : () => _handleWatchAd(uid),
        ),
        const SizedBox(height: 12),
        _buildEarnActionCard(
          icon: Icons.people_alt_rounded,
          iconColor: GamerTheme.accentBlue,
          badge: '+200 COINS',
          badgeColor: GamerTheme.accentBlue,
          title: 'Squad Referral Bonus',
          subtitle: 'Share code $inviteCode with your squad. Both earn +200 G-Coins after 5 matches!',
          buttonText: 'SHARE CODE ($inviteCode) 🚀',
          buttonColor: GamerTheme.accentBlue,
          textColor: Colors.white,
          onTap: () {
            Share.share(
              'Join My Gamer ID for free skill tournaments! Use code: $inviteCode. Play 5 matches to earn +200 G-Coins! 🎮💰',
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'STORE & REWARD HISTORY',
          style: TextStyle(
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
                  color: GamerTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GamerTheme.borderDark),
                ),
                child: const Center(
                  child: Text('No store transactions yet.',
                      style: TextStyle(color: GamerTheme.textMuted, fontSize: 13)),
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
                    color: GamerTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GamerTheme.borderDark),
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
                            Text(tx.title,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMM, hh:mm a').format(tx.timestamp),
                              style: const TextStyle(color: GamerTheme.textMuted, fontSize: 10),
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
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GamerTheme.borderDark),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
          Text(subtitle, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
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
