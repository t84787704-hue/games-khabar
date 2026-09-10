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
import 'redeem_rewards_screen.dart';

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

    // Daily Login Rule: Watch 1 Ad = 50 Coins. Ad nahi to Coin nahi.
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
                            Text('🎉', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 10),
                            Text(
                              '+50 G-Coins Claimed! (Watched 1 Ad)',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        duration: Duration(seconds: 3),
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
              side: const BorderSide(color: GamerTheme.neonGreen, width: 2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: GamerTheme.neonGreen.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: GamerTheme.neonGreen, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'DAILY LOGIN SPONSORED AD',
                    style: TextStyle(
                      color: GamerTheme.neonGreen,
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
                  height: 140,
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
                        Icon(Icons.calendar_today_rounded, color: GamerTheme.neonGreen, size: 44),
                        SizedBox(height: 8),
                        Text(
                          'Daily Reward Verification',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Watching ad to claim +50 G-Coins...',
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
                  color: GamerTheme.neonGreen,
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

  void _simulateRewardedAd(String uid) {
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
                    backgroundColor: GamerTheme.accentOrange,
                    content: Row(
                      children: [
                        Text('💰', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 10),
                        Text(
                          '+50 G-Coins Rewarded for watching sponsor video!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
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
                    'SPONSORED REWARDED AD',
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
                  height: 140,
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
                        Icon(Icons.sports_esports_rounded, color: GamerTheme.accentBlue, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'BGMI Pro Gear & Perks',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Watching ad to claim +50 Coins...',
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
      if (mounted) setState(() => _isWatchingAd = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUid ?? 'guest';
    final user = _authService.currentGamer;
    final inviteCode = (user?.gameId.isNotEmpty == true)
        ? user!.gameId.toUpperCase()
        : uid.substring(0, uid.length > 6 ? 6 : uid.length).toUpperCase();

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.cardDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('💰', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'G-Coin Wallet & Store',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
      ),
      body: StreamBuilder<CoinWallet>(
        stream: _walletService.walletStream(uid),
        initialData: _walletService.currentWallet ?? const CoinWallet(userId: '', coins: 1000),
        builder: (context, snapshot) {
          final wallet = snapshot.data ?? const CoinWallet(userId: '', coins: 1000);
          final canClaim = _timeUntilNextClaim == Duration.zero;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Balance Card
                _buildTopBalanceCard(wallet),

                const SizedBox(height: 24),

                // Ways to Earn Header
                const Text(
                  'WAYS TO EARN G-COINS',
                  style: TextStyle(
                    color: GamerTheme.accentBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. Daily Bonus Card (Watch 1 Ad = 50 Coins)
                _buildEarnCard(
                  icon: Icons.calendar_today_rounded,
                  iconColor: GamerTheme.neonGreen,
                  badge: '+50 COINS',
                  badgeColor: GamerTheme.neonGreen,
                  title: 'Daily Check-in (Watch 1 Ad)',
                  subtitle: canClaim
                      ? 'Ready! Watch 1 short sponsored ad to claim +50 G-Coins.'
                      : 'Next bonus unlocks in ${_formatDuration(_timeUntilNextClaim)}',
                  actionButton: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canClaim ? GamerTheme.neonGreen : GamerTheme.cardElevated,
                      foregroundColor: canClaim ? Colors.black : GamerTheme.textMuted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: canClaim ? () => _handleClaimDaily(uid) : null,
                    child: _isClaimingDaily
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            canClaim ? 'CLAIM 50 (AD) 📺' : _formatDuration(_timeUntilNextClaim),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // 2. Watch Ad Card
                _buildEarnCard(
                  icon: Icons.play_circle_filled_rounded,
                  iconColor: GamerTheme.accentOrange,
                  badge: '+50 COINS',
                  badgeColor: GamerTheme.accentOrange,
                  title: 'Watch Sponsored Ad',
                  subtitle: 'Watch a quick 5-second gaming ad to earn +50 Coins immediately.',
                  actionButton: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.accentOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _isWatchingAd ? null : () => _simulateRewardedAd(uid),
                    child: const Text('WATCH AD 📺', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),

                const SizedBox(height: 12),

                // 3. Win Tournament Card
                _buildEarnCard(
                  icon: Icons.emoji_events_rounded,
                  iconColor: Colors.amber,
                  badge: 'FULL POOL',
                  badgeColor: Colors.amber,
                  title: 'Win Custom Tournaments',
                  subtitle: 'Host or join BGMI 1v1 / Classic matches. Winner takes the entire prize pool!',
                  actionButton: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.amber),
                      foregroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('JOIN MATCH 🏆', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ),

                const SizedBox(height: 12),

                // 4. Referral Card (Rewarded after friend plays 5 tournaments)
                _buildEarnCard(
                  icon: Icons.group_add_rounded,
                  iconColor: GamerTheme.accentBlue,
                  badge: '+200 COINS',
                  badgeColor: GamerTheme.accentBlue,
                  title: 'Invite Gaming Squad',
                  subtitle: 'Share code "$inviteCode". When your friend plays 5 tournaments (watches 5 ads), BOTH of you receive +200 G-Coins!',
                  actionButton: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.accentBlue,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 14),
                    label: const Text('INVITE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    onPressed: () {
                      Share.share(
                        'Join My Gamer ID for free skill tournaments! Use code: $inviteCode. Play 5 matches to earn +200 G-Coins! 🎮💰',
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // Transaction History Header
                const Text(
                  'TRANSACTION HISTORY',
                  style: TextStyle(
                    color: GamerTheme.accentBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),

                // Transaction History List
                StreamBuilder<List<CoinTransaction>>(
                  stream: _walletService.transactionsStream(uid),
                  builder: (context, txSnap) {
                    final txList = txSnap.data ?? [];
                    if (txList.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: GamerTheme.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GamerTheme.borderDark),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.history_rounded, color: GamerTheme.textMuted, size: 36),
                            SizedBox(height: 8),
                            Text(
                              'No transactions yet.',
                              style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
                            ),
                          ],
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
                        return _buildTransactionTile(tx);
                      },
                    );
                  },
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBalanceCard(CoinWallet wallet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF162032), Color(0xFF0F1522)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GamerTheme.accentBlue.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: GamerTheme.accentBlue.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: GamerTheme.accentBlue, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'CURRENT AVAILABLE COINS',
                    style: TextStyle(
                      color: GamerTheme.accentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: GamerTheme.neonGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded, color: GamerTheme.neonGreen, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Trust: ${wallet.trustScore}/100',
                      style: const TextStyle(
                        color: GamerTheme.neonGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('💰', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 8),
              Text(
                NumberFormat('#,###').format(wallet.coins),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'G-Coins',
                style: TextStyle(
                  color: GamerTheme.accentBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: GamerTheme.borderDark, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_clock_rounded, color: GamerTheme.accentOrange, size: 13),
                        SizedBox(width: 4),
                        Text('IN ESCROW', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${NumberFormat('#,###').format(wallet.escrowCoins)} Coins',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(height: 28, width: 1, color: GamerTheme.borderDark),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.trending_up_rounded, color: GamerTheme.neonGreen, size: 13),
                        SizedBox(width: 4),
                        Text('LIFETIME EARNED', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${NumberFormat('#,###').format(wallet.lifetimeEarned)} Coins',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.neonGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.card_giftcard_rounded, size: 18),
              label: const Text(
                'REDEEM REWARDS (UC, DIAMONDS, GIFT CARDS) 🎁',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RedeemRewardsScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarnCard({
    required IconData icon,
    required Color iconColor,
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required Widget actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeColor,
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
                  style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 10),
                actionButton,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(CoinTransaction tx) {
    final isIncome = tx.amount > 0;
    final color = isIncome ? GamerTheme.neonGreen : GamerTheme.accentOrange;

    IconData txIcon;
    switch (tx.type) {
      case 'daily_bonus':
        txIcon = Icons.calendar_today_rounded;
        break;
      case 'ad_reward':
        txIcon = Icons.play_circle_filled_rounded;
        break;
      case 'room_host_hold':
        txIcon = Icons.lock_clock_rounded;
        break;
      case 'entry_fee':
        txIcon = Icons.login_rounded;
        break;
      case 'win_prize':
        txIcon = Icons.emoji_events_rounded;
        break;
      case 'refund':
        txIcon = Icons.replay_rounded;
        break;
      case 'referral':
        txIcon = Icons.person_add_alt_1_rounded;
        break;
      default:
        txIcon = Icons.card_giftcard_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(txIcon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM, hh:mm a').format(tx.timestamp),
                  style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : ''}${tx.amount} Coins',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
