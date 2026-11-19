// ===============================================================================
// COIN WALLET & REWARDS SCREEN — Professional Setup
// File: lib/screens/coin_wallet_screen.dart
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  String _selectedGameTab = 'Free Fire';

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
                ? ('daily_bonus_claimed_success'.tr() != 'daily_bonus_claimed_success' ? 'daily_bonus_claimed_success'.tr() : '🎁 Daily streak bonus claimed successfully!')
                : ('daily_bonus_already_claimed'.tr() != 'daily_bonus_already_claimed' ? 'daily_bonus_already_claimed'.tr() : 'Already claimed today! Come back tomorrow.')),
            backgroundColor: ok ? GamerTheme.neonGreen : GamerTheme.accentOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  Future<void> _redeemPack(String gameName, String packTitle, int cost, CoinWallet wallet) async {
    if (wallet.coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient G-Coins! You need ${cost - wallet.coins} more coins.'),
          backgroundColor: const Color(0xFFFF4655),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm Redemption', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Redeem $packTitle for $gameName for $cost G-Coins?', style: TextStyle(color: ThemeService.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.neonGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await CoinWalletService.updateCoins(
        userId: _userId,
        amount: -cost,
        type: 'game_currency_redemption',
        description: 'Redeemed $gameName - $packTitle',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Successfully redeemed $packTitle! Status: Pending Delivery.'),
              backgroundColor: GamerTheme.neonGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Redemption failed. Please try again.'),
              backgroundColor: Color(0xFFFF4655),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
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
              'G-Coins Wallet & Rewards 🪙',
              style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.storefront_rounded, color: GamerTheme.neonGreen),
                tooltip: 'Store',
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
                      // 1. Prominent Coin Wallet Card
                      _buildBalanceCard(wallet, isDark),
                      const SizedBox(height: 16),
                      _buildActionButtons(),
                      const SizedBox(height: 20),

                      // 2. Clear "Earn Coins" Cards
                      _buildEarnCoinsSection(),
                      const SizedBox(height: 20),

                      // 3. "Redeem Game Currency" Section
                      _buildRedeemGameCurrencySection(wallet),
                      const SizedBox(height: 20),

                      // 4. Coins & Redemption History List
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
      padding: const EdgeInsets.all(22),
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
        border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: GamerTheme.neonGreen.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CURRENT G-COINS BALANCE',
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: GamerTheme.neonGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '⚡ Active Wallet',
                  style: TextStyle(color: GamerTheme.neonGreen, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
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
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ThemeService.cardSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: GamerTheme.neonGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estimated Value: 1,000 G-Coins ≈ 100 PKR / $1.00 Store Value',
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
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
            label: 'Earn Coins ⚡',
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
            icon: Icons.redeem_rounded,
            label: 'Redeem Store 🎁',
            color: const Color(0xFFFFD700),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CoinStoreScreen()),
              );
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarnCoinsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⚡ Earn Free Coins',
          style: TextStyle(
            color: ThemeService.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _earnCard(
                title: 'Watch Ad',
                reward: '+25 Coins',
                icon: Icons.video_library_rounded,
                color: GamerTheme.accentBlue,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EarnCoinsScreen()));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _earnCard(
                title: 'Daily Bonus',
                reward: '+50 Coins',
                icon: Icons.card_giftcard_rounded,
                color: GamerTheme.neonGreen,
                onTap: _claimDailyBonus,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _earnCard(
                title: 'Invite Friend',
                reward: '+200 Coins',
                icon: Icons.group_add_rounded,
                color: const Color(0xFFFFB800),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EarnCoinsScreen()));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _earnCard({
    required String title,
    required String reward,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                reward,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedeemGameCurrencySection(CoinWallet wallet) {
    final games = ['Free Fire', 'PUBG Mobile', 'Valorant', 'COD Mobile'];
    
    final packsMap = {
      'Free Fire': [
        {'title': '100 Diamonds', 'cost': 500, 'icon': '💎'},
        {'title': '310 Diamonds', 'cost': 1400, 'icon': '💎'},
        {'title': '520 Diamonds', 'cost': 2200, 'icon': '💎'},
      ],
      'PUBG Mobile': [
        {'title': '60 UC', 'cost': 600, 'icon': '🪙'},
        {'title': '325 UC', 'cost': 2800, 'icon': '🪙'},
        {'title': '660 UC', 'cost': 5400, 'icon': '🪙'},
      ],
      'Valorant': [
        {'title': '100 VP', 'cost': 1000, 'icon': '🔺'},
        {'title': '475 VP', 'cost': 4500, 'icon': '🔺'},
      ],
      'COD Mobile': [
        {'title': '80 CP', 'cost': 800, 'icon': '🎖️'},
        {'title': '420 CP', 'cost': 3900, 'icon': '🎖️'},
      ],
    };

    final currentPacks = packsMap[_selectedGameTab] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '🎮 Redeem Game Currency',
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Instant Code Delivery',
              style: TextStyle(color: GamerTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Game Category Selector Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: games.map((game) {
              final isSelected = game == _selectedGameTab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(game),
                  selected: isSelected,
                  selectedColor: GamerTheme.neonGreen,
                  backgroundColor: ThemeService.card,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (_) => setState(() => _selectedGameTab = game),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Reward Packs Grid/List
        Column(
          children: currentPacks.map((pack) {
            final title = pack['title'] as String;
            final cost = pack['cost'] as int;
            final icon = pack['icon'] as String;
            final canAfford = wallet.coins >= cost;
            final progress = (wallet.coins / cost).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ThemeService.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: canAfford ? GamerTheme.neonGreen.withOpacity(0.4) : ThemeService.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ThemeService.cardSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Cost: $cost Coins',
                              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              canAfford ? '✅ Eligible' : '🔒 Need ${cost - wallet.coins} more',
                              style: TextStyle(
                                color: canAfford ? GamerTheme.neonGreen : ThemeService.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: ThemeService.cardSecondary,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              canAfford ? GamerTheme.neonGreen : GamerTheme.accentOrange,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford ? GamerTheme.neonGreen : ThemeService.cardSecondary,
                      foregroundColor: canAfford ? Colors.black : ThemeService.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => _redeemPack(_selectedGameTab, title, cost, wallet),
                    child: Text(
                      'Redeem',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: canAfford ? Colors.black : ThemeService.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
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
              '📜 Coins & Redemption History',
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
                    'No transaction history yet. Earn or redeem coins to start!',
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : ''}${tx.amount} G-Coins',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isCredit ? 'Earned' : 'Spent',
                style: TextStyle(color: ThemeService.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
