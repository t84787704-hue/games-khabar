// ===============================================================================
// COIN HISTORY SHEET — Localized with easy_localization & Adaptive Day/Night Theme
// File: lib/widgets/coin_history_sheet.dart
// ===============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_transaction_model.dart';
import '../models/coin_wallet_model.dart';
import '../services/coin_wallet_service.dart';
import '../services/coin_reward_service.dart';
import '../services/ad_free_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../services/wallet_repository.dart';
import '../screens/coin_store_screen.dart';
import '../screens/earn_coins_screen.dart';

class CoinHistorySheet extends StatefulWidget {
  final String userId;

  const CoinHistorySheet({super.key, required this.userId});

  static Future<void> show(BuildContext context, {String? userId}) async {
    final targetUid = userId?.isNotEmpty == true
        ? userId!
        : (GamerAuthService().currentUid ?? '');

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
  int _lastSyncedBalance = -1;
  bool _isBackgroundSyncing = false;

  // Cached streams so setState / filter changes / background syncs never recreate streams
  late String _effectiveUserId;
  Stream<CoinWallet>? _walletStream;
  Stream<List<CoinTransaction>>? _transactionsStream;
  Stream<List<Map<String, dynamic>>>? _rewardClaimsStream;

  // Sticky last-known-good state so transient empty/loading snapshots never reset values to 0
  int _cachedValidBalance = 0;
  int _cachedTotalCredited = 0;
  int _cachedTotalSpent = 0;
  List<CoinTransaction> _cachedValidTxs = const <CoinTransaction>[];
  List<Map<String, dynamic>> _cachedRewardClaims = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _initPassbookStreamsAndCache();
  }

  @override
  void didUpdateWidget(covariant CoinHistorySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _initPassbookStreamsAndCache();
    }
  }

  void _initPassbookStreamsAndCache() {
    _effectiveUserId = widget.userId.trim().isNotEmpty
        ? widget.userId.trim()
        : (GamerAuthService().currentUid?.trim() ?? '');

    // Seed initial balance from shared WalletRepository / in-memory wallet / auth / reward notifiers
    final int repoCoins = WalletRepository.instance.currentGCoins;
    final int walletCoins = _walletService.currentWallet?.gCoins ?? 0;
    final int gamerCoins = GamerAuthService().currentGamer?.coins ?? 0;
    final int notifierCoins = CoinRewardService().coinsNotifier.value;
    final int initialSeedBalance = repoCoins > 0
        ? repoCoins
        : (walletCoins > 0
            ? walletCoins
            : (gamerCoins > 0 ? gamerCoins : (notifierCoins > 0 ? notifierCoins : 0)));
    if (initialSeedBalance > 0) {
      _cachedValidBalance = initialSeedBalance;
    }

    // Seed initial transactions and totals from CoinWalletService memory cache
    final initialTxs = _walletService.getCachedTransactions(_effectiveUserId);
    if (initialTxs.isNotEmpty) {
      _cachedValidTxs = initialTxs;
      _recomputeAndCacheSummaryFromTxs(initialTxs);
    }

    _walletStream = _walletService.walletStream(_effectiveUserId);
    _transactionsStream = _walletService.transactionsStream(_effectiveUserId);
    _rewardClaimsStream = _effectiveUserId.isNotEmpty
        ? SupabaseService.getRealtimeRewardClaims(userId: _effectiveUserId)
        : Stream.value(const <Map<String, dynamic>>[]).asBroadcastStream();
  }

  void _recomputeAndCacheSummaryFromTxs(List<CoinTransaction> txs) {
    if (txs.isEmpty) return;
    int added = 0;
    int deducted = 0;
    for (final tx in txs) {
      if (tx.amount > 0) {
        added += tx.amount;
      } else if (tx.amount < 0) {
        deducted += tx.amount.abs();
      }
    }
    if (added > 0 || deducted > 0) {
      _cachedTotalCredited = added;
      _cachedTotalSpent = deducted;
      final int net = (added - deducted).clamp(0, 9999999);
      if (net > 0 || _cachedValidBalance == 0) {
        _cachedValidBalance = net;
      }
    }
  }

  /// Background Safe Auto-Sync to shared WalletRepository & Supabase coin_wallets.g_coins
  Future<void> _safeBackgroundSync(int targetCoins) async {
    if (targetCoins <= 0 || _isBackgroundSyncing) return;
    _isBackgroundSyncing = true;
    try {
      final currentUserId = _effectiveUserId;
      if (currentUserId.isEmpty) return;

      // Immediately publish to shared WalletRepository so Coin Store, Earn G-Coins,
      // Settings & Preferences, and Profile all reflect the exact same live balance!
      WalletRepository.instance.publishLiveBalance(
        targetCoins,
        userId: currentUserId,
        lifetimeEarned: _cachedTotalCredited > 0 ? _cachedTotalCredited : null,
        lifetimeSpent: _cachedTotalSpent > 0 ? _cachedTotalSpent : null,
      );

      await WalletRepository.instance.persistWalletToSupabase(
        userId: currentUserId,
        gCoins: targetCoins,
        lifetimeEarned: _cachedTotalCredited > 0 ? _cachedTotalCredited : null,
        lifetimeSpent: _cachedTotalSpent > 0 ? _cachedTotalSpent : null,
      );

      debugPrint('AUTO-SYNCED: Balance safely locked at $targetCoins G-Coins');
    } catch (e) {
      debugPrint('AUTO-SYNC ERROR: $e');
    } finally {
      _isBackgroundSyncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.88;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        final isDark = ThemeService.isDarkMode;
        final Color goldTextColor = isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309);
        final Color greenTextColor = isDark ? GamerTheme.neonGreen : const Color(0xFF047857);

        return Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black54 : Colors.black12,
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: StreamBuilder<CoinWallet>(
            stream: _walletStream,
            initialData: _walletService.currentWallet,
            builder: (context, walletSnap) {
              final int liveWalletCoins = walletSnap.data?.coins ?? 0;
              if (liveWalletCoins > 0 && _cachedValidTxs.isEmpty) {
                _cachedValidBalance = liveWalletCoins;
              }

              return StreamBuilder<List<CoinTransaction>>(
                stream: _transactionsStream,
                initialData: _cachedValidTxs.isNotEmpty ? _cachedValidTxs : null,
                builder: (context, txSnap) {
                  final incomingTxs = txSnap.data;
                  if (incomingTxs != null && incomingTxs.isNotEmpty) {
                    _cachedValidTxs = incomingTxs;
                    _recomputeAndCacheSummaryFromTxs(incomingTxs);
                  } else if (incomingTxs != null &&
                      incomingTxs.isEmpty &&
                      _cachedValidTxs.isNotEmpty) {
                    debugPrint(
                      '[CoinHistorySheet] Ignored transient empty transactions snapshot; preserving ${_cachedValidTxs.length} cached transactions.',
                    );
                  }

                  final List<CoinTransaction> allTxs = _cachedValidTxs;
                  final int totalAdded = _cachedTotalCredited;
                  final int totalDeducted = _cachedTotalSpent;
                  final int expectedBalance =
                      (totalAdded - totalDeducted).clamp(0, 9999999);

                  final int displayCoins = (totalAdded > 0 || totalDeducted > 0)
                      ? expectedBalance
                      : (_cachedValidBalance > 0
                          ? _cachedValidBalance
                          : liveWalletCoins);

                  if (displayCoins > 0 &&
                      WalletRepository.instance.currentGCoins != displayCoins) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      WalletRepository.instance.publishLiveBalance(
                        displayCoins,
                        userId: _effectiveUserId,
                        lifetimeEarned: totalAdded > 0 ? totalAdded : null,
                        lifetimeSpent: totalDeducted > 0 ? totalDeducted : null,
                      );
                    });
                  }

                  if (expectedBalance > 0 &&
                      (liveWalletCoins != expectedBalance ||
                          _lastSyncedBalance != expectedBalance)) {
                    _lastSyncedBalance = expectedBalance;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _safeBackgroundSync(expectedBalance);
                    });
                  }

                  return Column(
                    children: [
                      // Drag Handle
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: ThemeService.border,
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
                                border: Border.all(
                                  color: const Color(0xFFFFD700).withOpacity(0.4),
                                ),
                              ),
                              child: const Text('🪙', style: TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'passbook_sheet_title'.tr(),
                                    style: TextStyle(
                                      color: ThemeService.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'passbook_sheet_subtitle'.tr(),
                                    style: TextStyle(
                                      color: ThemeService.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: ThemeService.textPrimary,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Wallet Stats & Balance Banner
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ThemeService.cardSecondary,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: ThemeService.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'label_current_balance'.tr(),
                                        style: TextStyle(
                                          color: ThemeService.textSecondary,
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
                                            '${NumberFormat("#,###").format(displayCoins)} G-Coins',
                                            style: TextStyle(
                                              color: goldTextColor,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // REWARD CLAIM BUTTON
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _openRewardClaimModal(
                                        context,
                                        _effectiveUserId,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 13,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF00FF88),
                                              Color(0xFF00C853),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF00FF88)
                                                  .withOpacity(0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('🎁', style: TextStyle(fontSize: 14)),
                                            SizedBox(width: 6),
                                            Text(
                                              'Claim Reward',
                                              style: TextStyle(
                                                color: Color(0xFF0B0F14),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(color: ThemeService.border, height: 1),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Added (Income)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: GamerTheme.neonGreen.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: GamerTheme.neonGreen.withOpacity(0.25),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.arrow_downward_rounded,
                                            color: greenTextColor,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'label_total_credited'.tr(),
                                                  style: TextStyle(
                                                    color: ThemeService.textSecondary,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                Text(
                                                  '+${NumberFormat("#,###").format(totalAdded)}',
                                                  style: TextStyle(
                                                    color: greenTextColor,
                                                    fontWeight: FontWeight.w900,
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: GamerTheme.redAccent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: GamerTheme.redAccent.withOpacity(0.25),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.arrow_upward_rounded,
                                            color: GamerTheme.redAccent,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'label_total_spent'.tr(),
                                                  style: TextStyle(
                                                    color: ThemeService.textSecondary,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                Text(
                                                  '-${NumberFormat("#,###").format(totalDeducted)}',
                                                  style: const TextStyle(
                                                    color: GamerTheme.redAccent,
                                                    fontWeight: FontWeight.w900,
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
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.storefront_rounded, size: 16),
                                  label: Text(
                                    'btn_open_coin_store_sheet'.tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CoinStoreScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Filter Tabs
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildFilterChip(
                              'tab_all_activities'.tr(),
                              0,
                              Icons.list_alt_rounded,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'tab_earned'.tr(),
                              1,
                              Icons.add_circle_outline_rounded,
                              activeColor: greenTextColor,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'tab_spent'.tr(),
                              2,
                              Icons.remove_circle_outline_rounded,
                              activeColor: GamerTheme.redAccent,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Transactions & Reward Claims List
                      Expanded(
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _rewardClaimsStream,
                          initialData: _cachedRewardClaims.isNotEmpty
                              ? _cachedRewardClaims
                              : null,
                          builder: (context, claimsSnap) {
                            final incomingClaims = claimsSnap.data;
                            if (incomingClaims != null && incomingClaims.isNotEmpty) {
                              _cachedRewardClaims = incomingClaims;
                            }
                            final List<Map<String, dynamic>> rewardClaims =
                                _selectedFilter == 0
                                    ? _cachedRewardClaims
                                    : const <Map<String, dynamic>>[];

                            if (txSnap.connectionState == ConnectionState.waiting &&
                                allTxs.isEmpty &&
                                claimsSnap.connectionState == ConnectionState.waiting &&
                                rewardClaims.isEmpty) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: GamerTheme.accentBlue,
                                ),
                              );
                            }

                            List<CoinTransaction> transactions = List.from(allTxs);
                            if (rewardClaims.isNotEmpty) {
                              transactions = transactions
                                  .where((tx) => tx.type != 'game_currency_redemption')
                                  .toList();
                            }

                            if (_selectedFilter == 1) {
                              transactions =
                                  transactions.where((tx) => tx.amount > 0).toList();
                            } else if (_selectedFilter == 2) {
                              transactions =
                                  transactions.where((tx) => tx.amount < 0).toList();
                            }

                            if (rewardClaims.isEmpty && transactions.isEmpty) {
                              return _buildEmptyState();
                            }

                            final totalItems =
                                rewardClaims.length + transactions.length;
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: totalItems,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                if (index < rewardClaims.length) {
                                  return _buildRewardClaimCard(rewardClaims[index]);
                                }
                                final tx = transactions[index - rewardClaims.length];
                                return _buildTransactionCard(tx);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
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
            color: isSelected ? activeColor.withOpacity(0.18) : ThemeService.cardSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : ThemeService.border,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : ThemeService.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : ThemeService.textSecondary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardClaimCard(Map<String, dynamic> claim) {
    final String claimCode = (claim['claim_code'] ?? '#RW').toString();
    final String rawGame = (claim['game_name'] ?? 'free_fire').toString().toLowerCase();
    final String gameLabel =
        (rawGame == 'pubg_mobile' || rawGame.contains('pubg') || rawGame.contains('bgmi'))
            ? 'PUBG Mobile'
            : 'Free Fire';
    final String playerUid = (claim['player_uid'] ?? 'N/A').toString();
    final String playerIgn = (claim['player_ign'] ?? '').toString();
    final String teamName = (claim['team_name'] ?? 'Rank #1 Team').toString();
    final int shareAmountPkr = (claim['share_amount_pkr'] as num?)?.toInt() ?? 375;
    final String rewardLabel = (claim['reward_label'] ?? '').toString();
    final String status = (claim['status'] ?? 'pending').toString().toLowerCase();
    final String adminNote = (claim['admin_note'] ?? '').toString();
    final String proofImageUrl = (claim['proof_image_url'] ?? '').toString().trim();

    final bool isDelivered = status == 'delivered';
    final bool isRejected = status == 'rejected';
    final Color accentColor = isDelivered
        ? GamerTheme.neonGreen
        : (isRejected ? GamerTheme.redAccent : const Color(0xFFFFB800));

    final DateTime? timestamp =
        DateTime.tryParse((claim['delivered_at'] ?? claim['created_at'] ?? '').toString());
    final String dateText = timestamp != null
        ? DateFormat('dd MMM yyyy • hh:mm a').format(timestamp.toLocal())
        : 'Recent';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.cardSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.55), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDelivered
                      ? Icons.verified_rounded
                      : (isRejected ? Icons.cancel_rounded : Icons.card_giftcard_rounded),
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎁 #1 Team Reward • $gameLabel',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    if (rewardLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        rewardLabel,
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isDelivered
                      ? '✅ Reward Sent'
                      : (isRejected ? '❌ Rejected' : '⏳ Pending Delivery (24–48 hrs)'),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: claimCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Claim ID copied: $claimCode'),
                      backgroundColor: GamerTheme.neonGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThemeService.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Claim ID: $claimCode',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 12, color: Color(0xFFFFD700)),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeService.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Text(
                  'Game UID: $playerUid${playerIgn.isNotEmpty ? ' ($playerIgn)' : ''}',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeService.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Text(
                  'Team: $teamName • Share: ${NumberFormat('#,###').format(shareAmountPkr)} PKR / 1,500 PKR',
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.45)),
            ),
            child: Text(
              isDelivered
                  ? 'Reward Sent! آپ کا ریوارڈ بھیج دیا گیا ہے — براہِ کرم اپنا گیم اکاؤنٹ چیک کر لیں۔\n(Claim ID: $claimCode • Game UID: $playerUid)${adminNote.isNotEmpty ? '\nNote: $adminNote' : ''}'
                  : (isRejected
                      ? 'Claim Status: Rejected${adminNote.isNotEmpty ? ' • Note: $adminNote' : ''}'
                      : '⏳ Status: Pending Delivery (24–48 hrs) • Claim ID: $claimCode • Game UID: $playerUid'),
              style: TextStyle(
                color: isDelivered ? GamerTheme.neonGreen : accentColor,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
          if (proofImageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _showDeliveryProofDialog(
                imageUrl: proofImageUrl,
                claimCode: claimCode,
                playerUid: playerUid,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GamerTheme.neonGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: GamerTheme.neonGreen.withOpacity(0.45),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          color: GamerTheme.neonGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            '📸 Delivery Proof Screenshot (Tap to View Full Screen)',
                            style: TextStyle(
                              color: GamerTheme.neonGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: GamerTheme.neonGreen.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_out_map_rounded, size: 12, color: GamerTheme.neonGreen),
                              SizedBox(width: 3),
                              Text(
                                'View',
                                style: TextStyle(
                                  color: GamerTheme.neonGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        height: 135,
                        width: double.infinity,
                        child: Image.network(
                          proofImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: ThemeService.card,
                            alignment: Alignment.center,
                            child: const Text(
                              'Unable to load delivery proof screenshot',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            dateText,
            style: TextStyle(color: ThemeService.textSecondary, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  void _showDeliveryProofDialog({
    required String imageUrl,
    required String claimCode,
    required String playerUid,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: GamerTheme.neonGreen, width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: ThemeService.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: GamerTheme.neonGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delivery Proof • $claimCode (UID: $playerUid)',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: ThemeService.textPrimary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.5,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Failed to load delivery proof screenshot',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(CoinTransaction tx) {
    final isCredit = tx.amount > 0;
    final isWeeklyTeamReward = tx.type == 'weekly_team_reward';
    final isRedemption = tx.type == 'game_currency_redemption' || tx.type == 'store_purchase';
    final isEscrowHold = tx.type == 'escrow_hold' || tx.type == 'room_host_hold' || tx.type == 'tournament_entry';
    final isRelease = tx.type == 'escrow_release' || tx.type == 'escrow_transferred';

    final Color badgeColor = isWeeklyTeamReward
        ? const Color(0xFFFFD700)
        : isCredit
            ? GamerTheme.neonGreen
            : (isRelease ? const Color(0xFF00E5FF) : (isEscrowHold ? GamerTheme.accentOrange : GamerTheme.redAccent));

    final IconData typeIcon = _getIconForType(tx.type, isCredit);
    final String badgeText = isWeeklyTeamReward
        ? 'WEEKLY #1 TEAM'
        : isCredit
            ? 'tag_earned'.tr()
            : (isRelease
                ? 'tag_released'.tr()
                : (isEscrowHold
                    ? 'tag_escrow'.tr()
                    : (isRedemption ? 'REDEEMED' : 'tag_spent'.tr())));
    final String amountText = isCredit
        ? '+${'coins_amount_format'.tr(args: [tx.amount.toString()])}'
        : '-${'coins_amount_format'.tr(args: [tx.amount.abs().toString()])}';

    return Container(
      decoration: BoxDecoration(
        color: ThemeService.cardSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeService.border),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tx.title,
                              style: TextStyle(
                                color: ThemeService.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            amountText,
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tx.description.isNotEmpty ? tx.description : (isCredit ? 'coins_added_desc'.tr() : 'coins_deducted_desc'.tr()),
                        style: TextStyle(
                          color: ThemeService.textSecondary,
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
                            style: TextStyle(
                              color: ThemeService.textSecondary,
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
                              badgeText,
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
                color: ThemeService.cardSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: ThemeService.border),
              ),
              child: const Text('📜', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 1
                  ? 'no_coins_earned_yet'.tr()
                  : _selectedFilter == 2
                      ? 'no_coins_spent_yet'.tr()
                      : 'no_coin_history_yet'.tr(),
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'coin_history_empty_hint'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeService.textSecondary,
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
      case 'tournament_entry':
      case 'entry_fee':
        return Icons.sports_esports_rounded;
      case 'escrow_hold':
      case 'room_host_hold':
        return Icons.lock_clock_rounded;
      case 'escrow_refund':
      case 'room_host_refund':
      case 'refund':
        return Icons.replay_rounded;
      case 'escrow_release':
      case 'escrow_transferred':
        return Icons.verified_user_rounded;
      case 'weekly_team_reward':
      case 'win_prize':
      case 'team_prize':
      case 'win_reward':
        return Icons.emoji_events_rounded;
      case 'game_currency_redemption':
      case 'store_purchase':
        return Icons.shopping_bag_rounded;
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
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: ThemeService.border),
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
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
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
                      isCredit ? 'coins_added_desc'.tr() : 'coins_deducted_desc'.tr(),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isCredit ? '+' : ''}${tx.amount} ${'coins_label'.tr()}',
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
              _detailRow('${'reason_label'.tr()}:', tx.description.isNotEmpty ? tx.description : tx.title),
              const SizedBox(height: 8),
              _detailRow('${'type_label'.tr()}:', tx.type.replaceAll('_', ' ').toUpperCase()),
              const SizedBox(height: 8),
              _detailRow('${'date_and_time_label'.tr()}:', DateFormat('dd MMMM yyyy، hh:mm:ss a').format(tx.timestamp)),
              if (tx.roomId != null && tx.roomId!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _detailRow('${'room_id_label'.tr()}:', tx.roomId!),
              ],
              const SizedBox(height: 8),
              _detailRow('${'status_label'.tr()}:', tx.status.toUpperCase()),
              if (tx.id.isNotEmpty) ...[
                const SizedBox(height: 8),
                _detailRow('${'transaction_id_label'.tr()}:', tx.id),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('btn_close'.tr(), style: const TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold)),
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
            style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<void> _openRewardClaimModal(BuildContext parentContext, String userId) async {
    final effectiveUid = userId.isNotEmpty
        ? userId
        : (GamerAuthService().currentUid ?? '');

    if (effectiveUid.isEmpty) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text('Please log in to claim coin rewards!'),
          backgroundColor: Color(0xFFFF4655),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (!parentContext.mounted) return;

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final now = DateTime.now();
            final lastMysteryStr = prefs.getString('last_mystery_reward_$effectiveUid');
            DateTime? lastMysteryDate;
            if (lastMysteryStr != null) {
              lastMysteryDate = DateTime.tryParse(lastMysteryStr);
            }
            final bool isMysteryAvailable = lastMysteryDate == null ||
                now.difference(lastMysteryDate).inHours >= 12;

            return StreamBuilder<CoinWallet>(
              stream: CoinWalletService().walletStream(effectiveUid),
              builder: (context, walletSnap) {
                final CoinWallet wallet = walletSnap.data ?? CoinWallet.empty(effectiveUid);

                final bool canDaily = wallet.canClaimDailyBonus;
                final nextBonusDuration = wallet.nextDailyBonusDuration;

                String formatDuration(Duration d) {
                  final h = d.inHours;
                  final m = d.inMinutes % 60;
                  if (h > 0) return '${h}h ${m}m';
                  return '${m}m';
                }

                return Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    MediaQuery.of(ctx).padding.bottom + 20,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeService.card,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: ThemeService.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: ThemeService.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF88).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF00FF88).withOpacity(0.4),
                              ),
                            ),
                            child: const Text('🎁', style: TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Claim Rewards & Bonuses',
                                  style: TextStyle(
                                    color: ThemeService.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Collect daily coins and sponsored bonuses',
                                  style: TextStyle(
                                    color: ThemeService.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: ThemeService.textPrimary),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 1. Daily Login Bonus
                      _rewardCard(
                        icon: Icons.calendar_today_rounded,
                        iconColor: const Color(0xFFFFD700),
                        title: 'Daily Login Bonus',
                        subtitle: canDaily
                            ? 'Claim +50 G-Coins for checking in today!'
                            : 'Already claimed today • Next in ${formatDuration(nextBonusDuration)}',
                        coinsBadge: '+50 G-Coins',
                        actionWidget: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canDaily
                                ? const Color(0xFF00FF88)
                                : ThemeService.cardSecondary,
                            foregroundColor: canDaily
                                ? const Color(0xFF0B0F14)
                                : ThemeService.textSecondary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: canDaily
                              ? () async {
                                  Navigator.pop(modalCtx);
                                  final success = await _walletService.claimDailyBonus(effectiveUid);
                                  if (mounted) {
                                    ScaffoldMessenger.of(parentContext).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? '🎉 50 G-Coins Claimed Successfully!'
                                              : 'Daily bonus already claimed for today.',
                                        ),
                                        backgroundColor: success
                                            ? const Color(0xFF00FF88)
                                            : const Color(0xFFFF9900),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          child: Text(
                            canDaily ? 'Claim +50' : '✓ Claimed',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 2. Watch Sponsored Video
                      _rewardCard(
                        icon: Icons.play_circle_filled_rounded,
                        iconColor: const Color(0xFF00FF88),
                        title: 'Sponsored Video Ad',
                        subtitle: 'Watch a short 5-second video to earn instant G-Coins',
                        coinsBadge: '+25 G-Coins',
                        actionWidget: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF88),
                            foregroundColor: const Color(0xFF0B0F14),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.tv_rounded, size: 15),
                          label: const Text(
                            'Watch (+25)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: () async {
                            Navigator.pop(modalCtx);
                            try {
                              await AdFreeService().showRewardedAdForAction(
                                context: parentContext,
                                actionTitle: 'Sponsored Video',
                                onRewardEarned: () async {
                                  await _walletService.rewardAdCoins(effectiveUid);
                                  if (mounted) {
                                    ScaffoldMessenger.of(parentContext).showSnackBar(
                                      const SnackBar(
                                        content: Text('🎉 +25 G-Coins Added to Your Wallet!'),
                                        backgroundColor: Color(0xFF00FF88),
                                      ),
                                    );
                                  }
                                },
                              );
                            } catch (e) {
                              debugPrint('Reward ad error: $e');
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 3. Lucky Mystery Box
                      _rewardCard(
                        icon: Icons.card_giftcard_rounded,
                        iconColor: const Color(0xFFFF9900),
                        title: 'Lucky Mystery Box',
                        subtitle: isMysteryAvailable
                            ? 'Tap to unbox a surprise coin gift (+25 to +75 G-Coins)!'
                            : 'Opened recently • Next box in 12 hours',
                        coinsBadge: '+25~75 G-Coins',
                        actionWidget: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMysteryAvailable
                                ? const Color(0xFFFF9900)
                                : ThemeService.cardSecondary,
                            foregroundColor: isMysteryAvailable
                                ? Colors.white
                                : ThemeService.textSecondary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: isMysteryAvailable
                              ? () async {
                                  final randomCoins = 25 + Random().nextInt(51); // 25..75
                                  await prefs.setString(
                                    'last_mystery_reward_$effectiveUid',
                                    DateTime.now().toIso8601String(),
                                  );

                                  await CoinWalletService.updateCoins(
                                    userId: effectiveUid,
                                    amount: randomCoins,
                                    type: 'mystery_reward',
                                    title: '🎁 Lucky Mystery Box',
                                    description: 'Surprise Passbook Coin Reward',
                                  );

                                  Navigator.pop(modalCtx);

                                  if (mounted) {
                                    ScaffoldMessenger.of(parentContext).showSnackBar(
                                      SnackBar(
                                        content: Text('🎉 Wow! You unboxed +$randomCoins G-Coins!'),
                                        backgroundColor: const Color(0xFF00FF88),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          child: Text(
                            isMysteryAvailable ? 'Open Box 🎰' : '✓ Opened',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. More Coins Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: ThemeService.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            foregroundColor: ThemeService.textPrimary,
                          ),
                          icon: const Icon(Icons.monetization_on_outlined, size: 18, color: Color(0xFFFFD700)),
                          label: const Text(
                            'Open Earn Coins Center 🚀',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () {
                            Navigator.pop(modalCtx);
                            Navigator.push(
                              parentContext,
                              MaterialPageRoute(
                                builder: (_) => const EarnCoinsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _rewardCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String coinsBadge,
    required Widget actionWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeService.cardSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeService.border),
      ),
      child: Row(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        coinsBadge,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          actionWidget,
        ],
      ),
    );
  }
}
