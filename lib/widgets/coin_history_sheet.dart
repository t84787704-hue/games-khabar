import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_transaction_model.dart';
import '../models/coin_wallet_model.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../screens/redeem_rewards_screen.dart';

class CoinHistorySheet extends StatefulWidget {
  final String userId;

  const CoinHistorySheet({Key? key, required this.userId}) : super(key: key);

  static Future<void> show(BuildContext context, {String? userId}) async {
    final targetUid = userId?.isNotEmpty == true
        ? userId!
        : (FirebaseAuth.instance.currentUser?.uid ?? GamerAuthService().currentUid ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CoinHistorySheet(userId: targetUid),
    );
  }

  @override
  State<CoinHistorySheet> createState() => _CoinHistorySheetState();
}

class _CoinHistorySheetState extends State<CoinHistorySheet> {
  final CoinWalletService _walletService = CoinWalletService();
  int _selectedFilter = 0; // 0: All, 1: Added (+), 2: Deducted (-)

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.88;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF0B101B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                  ),
                  child: const Text('🪙', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coin History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kab kitne coin kahan se add/cut huway',
                        style: TextStyle(
                          color: GamerTheme.textGray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Wallet Stats & Balance Banner
          StreamBuilder<CoinWallet>(
            stream: _walletService.walletStream(widget.userId),
            builder: (context, walletSnap) {
              final wallet = walletSnap.data ?? _walletService.currentWallet ?? const CoinWallet(userId: '', coins: 0);

              return StreamBuilder<List<CoinTransaction>>(
                stream: _walletService.transactionsStream(widget.userId),
                builder: (context, txSnap) {
                  final allTxs = txSnap.data ?? [];

                  int totalAdded = 0;
                  int totalDeducted = 0;

                  for (final tx in allTxs) {
                    if (tx.amount > 0) {
                      totalAdded += tx.amount;
                    } else if (tx.amount < 0) {
                      totalDeducted += tx.amount.abs();
                    }
                  }

                  // If no recorded transactions yet but user has coins, treat initial coins as added
                  if (totalAdded == 0 && wallet.coins > 0) {
                    totalAdded = wallet.coins;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF141D2E), Color(0xFF0F1523)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: GamerTheme.borderDark),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CURRENT BALANCE',
                                    style: TextStyle(
                                      color: GamerTheme.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Text('🪙', style: TextStyle(fontSize: 18)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${NumberFormat("#,###").format(wallet.coins)} Coins',
                                        style: const TextStyle(
                                          color: Color(0xFFFFD700),
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (wallet.escrowCoins > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: GamerTheme.accentOrange.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'IN ESCROW 🔒',
                                        style: TextStyle(
                                          color: GamerTheme.accentOrange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${wallet.escrowCoins} Coins',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: GamerTheme.borderDark, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Added (Income)
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: GamerTheme.neonGreen.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.arrow_downward_rounded, color: GamerTheme.neonGreen, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Total Added',
                                              style: TextStyle(color: GamerTheme.textMuted, fontSize: 10),
                                            ),
                                            Text(
                                              '+${NumberFormat("#,###").format(totalAdded)}',
                                              style: const TextStyle(
                                                color: GamerTheme.neonGreen,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Deducted (Expense)
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: GamerTheme.redAccent.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: GamerTheme.redAccent.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.arrow_upward_rounded, color: GamerTheme.redAccent, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Total Deducted',
                                              style: TextStyle(color: GamerTheme.textMuted, fontSize: 10),
                                            ),
                                            Text(
                                              '-${NumberFormat("#,###").format(totalDeducted)}',
                                              style: const TextStyle(
                                                color: GamerTheme.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GamerTheme.neonGreen,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.card_giftcard_rounded, size: 16),
                              label: const Text(
                                'REDEEM REWARDS (UC, DIAMONDS, GIFT CARDS) 🎁',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RedeemRewardsScreen()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 14),

          // Filter Tabs: All, Added (+), Deducted (-)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All History', 0, Icons.list_alt_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('Added (+)', 1, Icons.add_circle_outline_rounded, activeColor: GamerTheme.neonGreen),
                const SizedBox(width: 8),
                _buildFilterChip('Deducted (-)', 2, Icons.remove_circle_outline_rounded, activeColor: GamerTheme.redAccent),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Transactions List
          Expanded(
            child: StreamBuilder<List<CoinTransaction>>(
              stream: _walletService.transactionsStream(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: GamerTheme.accentBlue),
                  );
                }

                List<CoinTransaction> transactions = snapshot.data ?? [];

                // Filter items
                if (_selectedFilter == 1) {
                  transactions = transactions.where((tx) => tx.amount > 0).toList();
                } else if (_selectedFilter == 2) {
                  transactions = transactions.where((tx) => tx.amount < 0).toList();
                }

                if (transactions.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return _buildTransactionCard(tx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index, IconData icon, {Color activeColor = GamerTheme.accentBlue}) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.18) : GamerTheme.cardDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : GamerTheme.borderDark,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : GamerTheme.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : GamerTheme.textMuted,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(CoinTransaction tx) {
    final isCredit = tx.amount > 0;
    final Color badgeColor = isCredit ? GamerTheme.neonGreen : GamerTheme.redAccent;
    final IconData typeIcon = _getIconForType(tx.type, isCredit);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131A29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showTransactionDetailsDialog(tx),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor.withOpacity(0.3)),
                  ),
                  child: Icon(typeIcon, color: badgeColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Title & Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tx.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${isCredit ? '+' : ''}${tx.amount} Coins',
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tx.description.isNotEmpty ? tx.description : (isCredit ? 'Coins added' : 'Coins deducted'),
                        style: const TextStyle(
                          color: GamerTheme.textGray,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy • hh:mm a').format(tx.timestamp),
                            style: const TextStyle(
                              color: GamerTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isCredit ? 'ADDED' : 'DEDUCTED',
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: GamerTheme.cardDark,
                shape: BoxShape.circle,
                border: Border.all(color: GamerTheme.borderDark),
              ),
              child: const Text('📜', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 1
                  ? 'No coins added yet'
                  : _selectedFilter == 2
                      ? 'No coins deducted yet'
                      : 'No coin history yet',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Jab aap rooms join karenge, match jeetenge ya daily bonus claim karenge to unki detail yahan show hogi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GamerTheme.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type, bool isCredit) {
    switch (type) {
      case 'entry_fee':
        return Icons.sports_esports_rounded;
      case 'room_host_hold':
        return Icons.lock_clock_rounded;
      case 'win_prize':
      case 'win_reward':
        return Icons.emoji_events_rounded;
      case 'refund':
        return Icons.replay_rounded;
      case 'ad_reward':
        return Icons.play_circle_fill_rounded;
      case 'daily_bonus':
      case 'daily_login':
        return Icons.calendar_today_rounded;
      case 'news_read':
        return Icons.article_rounded;
      case 'post_created':
        return Icons.edit_note_rounded;
      case 'helpful_received':
        return Icons.thumb_up_alt_rounded;
      case 'referral':
        return Icons.group_add_rounded;
      case 'admin_bonus':
        return Icons.card_giftcard_rounded;
      default:
        return isCredit ? Icons.add_circle_rounded : Icons.remove_circle_rounded;
    }
  }

  void _showTransactionDetailsDialog(CoinTransaction tx) {
    final isCredit = tx.amount > 0;
    final color = isCredit ? GamerTheme.neonGreen : GamerTheme.redAccent;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101726),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: GamerTheme.borderDark),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getIconForType(tx.type, isCredit), color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tx.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      isCredit ? 'Coins Added' : 'Coins Deducted',
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isCredit ? '+' : ''}${tx.amount} Coins',
                      style: TextStyle(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _detailRow('Reason:', tx.description.isNotEmpty ? tx.description : tx.title),
              const SizedBox(height: 8),
              _detailRow('Category:', tx.type.replaceAll('_', ' ').toUpperCase()),
              const SizedBox(height: 8),
              _detailRow('Date & Time:', DateFormat('dd MMMM yyyy, hh:mm:ss a').format(tx.timestamp)),
              if (tx.roomId != null && tx.roomId!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _detailRow('Room / Squad ID:', tx.roomId!),
              ],
              const SizedBox(height: 8),
              _detailRow('Status:', tx.status.toUpperCase()),
              if (tx.id.isNotEmpty) ...[
                const SizedBox(height: 8),
                _detailRow('Tx ID:', tx.id),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
