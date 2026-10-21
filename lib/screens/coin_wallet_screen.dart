// ===============================================================================
// COIN WALLET SCREEN — Full Multi-Language Live Translation & Adaptive Day/Night Theme
// File: lib/screens/coin_wallet_screen.dart
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_transaction_model.dart';
import '../models/coin_wallet_model.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/coin_history_sheet.dart';
import 'coin_store_screen.dart';
import 'earn_coins_screen.dart';

class CoinWalletScreen extends StatefulWidget {
  const CoinWalletScreen({super.key});

  @override
  State<CoinWalletScreen> createState() => _CoinWalletScreenState();
}

class _CoinWalletScreenState extends State<CoinWalletScreen> {
  final CoinWalletService _walletService = CoinWalletService();
  bool _isClaimingDaily = false;
  Timer? _countdownTimer;

  String get _userId => GamerAuthService().currentUid ?? '';

  @override
  void initState() {
    super.initState();
    if (_userId.isNotEmpty) {
      _walletService.getOrCreateWallet(_userId);
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _claimDailyBonus() async {
    if (_isClaimingDaily) return;
    setState(() => _isClaimingDaily = true);
    try {
      final ok = await _walletService.claimDailyBonus(_userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'daily_bonus_claimed_success'.tr()
                : 'daily_bonus_already_claimed'.tr()),
            backgroundColor: ok ? GamerTheme.neonGreen : GamerTheme.accentOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'err_prefix'.tr()}: $e'),
            backgroundColor: GamerTheme.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaimingDaily = false);
    }
  }

  Future<void> _refreshWallet() async {
    if (_userId.isNotEmpty) {
      await _walletService.getOrCreateWallet(_userId);
      await CoinWalletService.recalculateCoins(_userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        final isDark = ThemeService.isDarkMode;

        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: ThemeService.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'my_wallet_title'.tr(),
              style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.storefront_rounded, color: GamerTheme.neonGreen),
                tooltip: 'tooltip_coin_store'.tr(),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CoinStoreScreen()),
                  );
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            color: GamerTheme.neonGreen,
            backgroundColor: ThemeService.card,
            onRefresh: _refreshWallet,
            child: StreamBuilder<CoinWallet>(
              stream: _walletService.walletStream(_userId),
              builder: (context, walletSnap) {
                final wallet = walletSnap.data ?? _walletService.currentWallet ?? CoinWallet.empty(_userId);

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceCard(wallet, isDark),
                      const SizedBox(height: 16),
                      _buildActionButtons(),
                      const SizedBox(height: 20),
                      _buildDailyBonusCard(wallet),
                      const SizedBox(height: 20),
                      _buildStatsRow(wallet),
                      const SizedBox(height: 20),
                      _buildRecentTransactions(),
                      const SizedBox(height: 100),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard(CoinWallet wallet, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? null : ThemeService.card,
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF141D2E), Color(0xFF0F1523)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThemeService.border),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? GamerTheme.neonGreen.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'current_balance_label'.tr(),
            style: TextStyle(
              color: ThemeService.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              Text(
                NumberFormat('#,###').format(wallet.coins),
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'g_coins_label'.tr(),
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'escrow_coins_tag'.tr(args: [NumberFormat('#,###').format(wallet.escrowCoins)]),
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'total_net_worth_label'.tr(args: [NumberFormat('#,###').format(wallet.totalNetWorth)]),
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.play_circle_fill_rounded,
            label: 'earn_coins_btn'.tr(),
            color: GamerTheme.neonGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EarnCoinsScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            icon: Icons.history_rounded,
            label: 'history_btn'.tr(),
            color: GamerTheme.accentBlue,
            onTap: () {
              CoinHistorySheet.show(context, userId: _userId);
            },
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyBonusCard(CoinWallet wallet) {
    final canClaim = wallet.canClaimDailyBonus;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canClaim
              ? GamerTheme.neonGreen.withOpacity(0.5)
              : ThemeService.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (canClaim ? GamerTheme.neonGreen : ThemeService.textSecondary)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: canClaim ? GamerTheme.neonGreen : ThemeService.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'daily_login_bonus_title'.tr(),
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  canClaim
                      ? 'claim_bonus_now_desc'.tr()
                      : 'next_claim_time_desc'.tr(args: [_formatDuration(wallet.nextDailyBonusDuration)]),
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  canClaim ? GamerTheme.neonGreen : ThemeService.cardSecondary,
              foregroundColor: canClaim ? Colors.black : ThemeService.textSecondary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              disabledBackgroundColor: ThemeService.cardSecondary,
            ),
            onPressed: canClaim && !_isClaimingDaily ? _claimDailyBonus : null,
            child: _isClaimingDaily
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : Text(
                    'claim_bonus_50_btn'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return 'duration_hours_mins'.tr(args: ['${d.inHours}', '${d.inMinutes % 60}']);
    }
    return 'duration_mins_secs'.tr(args: ['${d.inMinutes}', '${d.inSeconds % 60}']);
  }

  Widget _buildStatsRow(CoinWallet wallet) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'total_earned_label'.tr(),
            value: '+${NumberFormat('#,###').format(wallet.lifetimeEarned)}',
            color: GamerTheme.neonGreen,
            icon: Icons.trending_up_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'trust_score_label'.tr(),
            value: '${wallet.trustScore}/100',
            color: GamerTheme.accentBlue,
            icon: Icons.verified_user_rounded,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeService.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: ThemeService.textSecondary, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'recent_activities_title'.tr(),
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                CoinHistorySheet.show(context, userId: _userId);
              },
              child: Text(
                'view_all_btn'.tr(),
                style: const TextStyle(
                  color: GamerTheme.neonGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<CoinTransaction>>(
          stream: _walletService.transactionsStream(_userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: GamerTheme.neonGreen),
                ),
              );
            }
            final txs = (snapshot.data ?? []).take(5).toList();
            if (txs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ThemeService.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Center(
                  child: Text(
                    'no_transactions_yet'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                  ),
                ),
              );
            }
            return Column(
              children: txs.map((tx) => _buildTxTile(tx)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTxTile(CoinTransaction tx) {
    final isCredit = tx.amount > 0;
    final color = isCredit ? GamerTheme.neonGreen : GamerTheme.redAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.add_rounded : Icons.remove_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM • hh:mm a').format(tx.timestamp),
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : ''}${tx.amount} ${'coins_amount_tag'.tr()}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
