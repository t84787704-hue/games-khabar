import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_transaction_model.dart';
import '../models/coin_wallet_model.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../widgets/coin_history_sheet.dart';
import 'coin_store_screen.dart';
import 'earn_coins_screen.dart';

class CoinWalletScreen extends StatefulWidget {
  const CoinWalletScreen({Key? key}) : super(key: key);

  @override
  State<CoinWalletScreen> createState() => _CoinWalletScreenState();
}

class _CoinWalletScreenState extends State<CoinWalletScreen> {
  final CoinWalletService _walletService = CoinWalletService();
  bool _isClaimingDaily = false;

  String get _userId => GamerAuthService().currentUid ?? '';

  Future<void> _claimDailyBonus() async {
    if (_isClaimingDaily) return;
    setState(() => _isClaimingDaily = true);
    try {
      final ok = await _walletService.claimDailyBonus(_userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? '🎁 +50 G-Coins claimed!'
                : '⏳ Daily bonus already claimed today'),
            backgroundColor: ok ? GamerTheme.neonGreen : GamerTheme.accentOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: GamerTheme.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaimingDaily = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Wallet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront_rounded, color: GamerTheme.neonGreen),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CoinStoreScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<CoinWallet>(
        stream: _walletService.walletStream(_userId),
        builder: (context, walletSnap) {
          final wallet = walletSnap.data ?? CoinWallet.empty(_userId);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(wallet),
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
    );
  }

  Widget _buildBalanceCard(CoinWallet wallet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF141D2E), Color(0xFF0F1523)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GamerTheme.borderDark),
        boxShadow: [
          BoxShadow(
            color: GamerTheme.neonGreen.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CURRENT BALANCE',
            style: TextStyle(
              color: GamerTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 32)),
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
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'G-Coins',
                  style: TextStyle(
                    color: GamerTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Net Worth: ${NumberFormat('#,###').format(wallet.totalNetWorth)} (incl. escrow)',
            style: const TextStyle(
              color: GamerTheme.textMuted,
              fontSize: 11,
            ),
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
            label: 'Earn Coins',
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
            label: 'History',
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
            color: GamerTheme.cardDark,
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
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canClaim
              ? GamerTheme.neonGreen.withOpacity(0.5)
              : GamerTheme.borderDark,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (canClaim ? GamerTheme.neonGreen : GamerTheme.textMuted)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: canClaim ? GamerTheme.neonGreen : GamerTheme.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Login Bonus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  canClaim
                      ? 'Claim +50 G-Coins now!'
                      : 'Next claim in ${_formatDuration(wallet.nextDailyBonusDuration)}',
                  style: const TextStyle(
                    color: GamerTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  canClaim ? GamerTheme.neonGreen : GamerTheme.cardElevated,
              foregroundColor: canClaim ? Colors.black : GamerTheme.textMuted,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              disabledBackgroundColor: GamerTheme.cardElevated,
            ),
            onPressed: canClaim && !_isClaimingDaily ? _claimDailyBonus : null,
            child: _isClaimingDaily
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : const Text('CLAIM',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
  }

  Widget _buildStatsRow(CoinWallet wallet) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Lifetime Earned',
            value: '+${NumberFormat('#,###').format(wallet.lifetimeEarned)}',
            color: GamerTheme.neonGreen,
            icon: Icons.trending_up_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'Trust Score',
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
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: GamerTheme.textMuted, fontSize: 10),
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
            const Text(
              'Recent Activity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                CoinHistorySheet.show(context, userId: _userId);
              },
              child: const Text(
                'View All',
                style: TextStyle(
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
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                      color: GamerTheme.neonGreen),
                ),
              );
            }
            final txs = (snapshot.data ?? []).take(5).toList();
            if (txs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: GamerTheme.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GamerTheme.borderDark),
                ),
                child: const Center(
                  child: Text(
                    'No transactions yet',
                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
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
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GamerTheme.borderDark),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM • hh:mm a').format(tx.timestamp),
                  style: const TextStyle(
                    color: GamerTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : ''}${tx.amount}',
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