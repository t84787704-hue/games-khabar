// ===============================================================================
// COIN WALLET & REWARDS SCREEN — Google Play Policy Compliant Setup
// - 4-Member Team Coin Tracking & Per-Game Weekly #1 Equal Reward Division
// - Team Membership Requirement for Redemptions & Solo User Coin Protection
// - Strict Privacy & Data Minimization (Public Gaming Handles Only)
// File: lib/screens/coin_wallet_screen.dart
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_transaction_model.dart';
import '../models/coin_wallet_model.dart';
import '../models/team_model.dart';
import '../services/ad_free_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/team_service.dart';
import '../services/theme_service.dart';
import '../widgets/coin_history_sheet.dart';
import 'coin_store_screen.dart';
import 'earn_coins_screen.dart';
import 'leaderboard_screen.dart';
import 'team_profile_screen.dart';
import 'teams_screen.dart';

class CoinWalletScreen extends StatefulWidget {
  const CoinWalletScreen({super.key});

  @override
  State<CoinWalletScreen> createState() => _CoinWalletScreenState();
}

class _CoinWalletScreenState extends State<CoinWalletScreen> {
  final CoinWalletService _walletService = CoinWalletService();
  final TeamService _teamService = TeamService();

  bool _isClaimingDaily = false;
  bool _isWatchingAd = false;
  Timer? _countdownTimer;
  String _selectedGameTab = 'Free Fire';
  List<TeamModel> _userTeams = [];
  bool _isLoadingTeams = true;

  String get _userId => GamerAuthService().currentUid ?? '';

  @override
  void initState() {
    super.initState();
    _initWalletAndTeamData();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initWalletAndTeamData() async {
    if (_userId.isNotEmpty) {
      _walletService.getOrCreateWallet(_userId);
      await _loadUserTeams();
    } else {
      if (mounted) setState(() => _isLoadingTeams = false);
    }
    // Check and distribute concluded weekly cycle #1 team rewards per game
    await _teamService.checkAndDistributeWeeklyGameRewards();
  }

  Future<void> _loadUserTeams() async {
    if (_userId.isEmpty) {
      if (mounted) {
        setState(() {
          _userTeams = [];
          _isLoadingTeams = false;
        });
      }
      return;
    }
    try {
      final teams = await _teamService.getUserTeams(_userId);
      if (mounted) {
        setState(() {
          _userTeams = teams;
          _isLoadingTeams = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTeams = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _watchAdFor25Coins() async {
    if (_isWatchingAd) return;
    setState(() => _isWatchingAd = true);
    try {
      await AdFreeService().showRewardedAdForAction(
        context: context,
        actionTitle: 'Watch Ad (+25 Coins)',
        onRewardEarned: () async {
          await _walletService.rewardAdCoins(_userId);
          if (mounted) {
            setState(() {});
            final bool hasTeam = _userTeams.isNotEmpty;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  hasTeam
                      ? '🎉 +25 G-Coins added to your wallet & your team\'s weekly total!'
                      : '🎉 +25 G-Coins saved to your personal wallet! Join a team to redeem rewards.',
                ),
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
            content: Text('Ad failed to load: $e'),
            backgroundColor: GamerTheme.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWatchingAd = false);
    }
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
                ? (_userTeams.isNotEmpty
                    ? '🎁 +50 G-Coins daily bonus added to your wallet & weekly team coins!'
                    : '🎁 +50 G-Coins saved to your personal wallet! Join a team to redeem rewards.')
                : ('daily_bonus_already_claimed'.tr() != 'daily_bonus_already_claimed'
                    ? 'daily_bonus_already_claimed'.tr()
                    : 'Already claimed today! Come back tomorrow.')),
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
      await _loadUserTeams();
      await _teamService.checkAndDistributeWeeklyGameRewards();
      await CoinWalletService.recalculateCoins(_userId);
    }
  }

  void _showTeamRequiredForRedemptionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFFFB800), width: 1.4),
        ),
        title: Row(
          children: [
            const Icon(Icons.groups_rounded, color: Color(0xFFFFB800), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Team Membership Required',
                style: TextStyle(
                  color: ThemeService.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Only users who belong to an active team (up to 4 members) can redeem rewards or qualify for Per-Game Weekly #1 Team Rewards.\n\n'
          'Your earned G-Coins remain safely stored in your personal balance and history. Join or create an active team now to unlock reward redemptions!',
          style: TextStyle(
            color: ThemeService.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Later', style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.neonGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.shield_rounded, size: 16),
            label: const Text(
              'Join / View Teams',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeamsScreen()),
              ).then((_) => _loadUserTeams());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _redeemPack(
    String gameName,
    String packTitle,
    int cost,
    CoinWallet wallet,
    List<TeamModel> activeTeams,
  ) async {
    // Rule 4: Block reward redemption for users who are not in an active team
    if (activeTeams.isEmpty) {
      _showTeamRequiredForRedemptionDialog();
      return;
    }

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

    final activeTeam = activeTeams.first;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Redemption',
          style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Redeem $packTitle for $gameName for $cost G-Coins?\n\n'
          'Active Team: ${activeTeam.name} [${activeTeam.tag}] (${activeTeam.memberCount}/${TeamModel.maxMembers} members)',
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.neonGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await CoinWalletService.updateCoins(
        userId: _userId,
        amount: -cost,
        type: 'game_currency_redemption',
        title: '🎁 Redeemed $gameName - $packTitle',
        description:
            'Reward Redemption ($packTitle • $gameName) via Team ${activeTeam.name} [${activeTeam.tag}] • Status: Pending Delivery',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Successfully redeemed $packTitle! Status: Pending Delivery.'),
            backgroundColor: GamerTheme.neonGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700)),
                tooltip: 'Weekly Leaderboards',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                  );
                },
              ),
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
                final wallet = walletSnap.data ??
                    _walletService.currentWallet ??
                    CoinWallet.empty(_userId);

                return StreamBuilder<List<TeamModel>>(
                  stream: _userId.isNotEmpty
                      ? _teamService.getUserTeamsStream(_userId)
                      : Stream.value(const []),
                  builder: (context, teamsSnap) {
                    final activeTeams = teamsSnap.data ?? _userTeams;
                    if (teamsSnap.hasData) {
                      _userTeams = activeTeams;
                    }

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Prominent Coin Wallet Card
                          _buildBalanceCard(wallet, isDark, activeTeams),
                          const SizedBox(height: 14),

                          // 2. Team Membership Status / Solo User Notice Card
                          _buildTeamMembershipStatusBanner(activeTeams),
                          const SizedBox(height: 16),

                          _buildActionButtons(),
                          const SizedBox(height: 20),

                          // 3. Clear "Earn Coins" Cards (+25 Ad Watch, +50 Daily Bonus)
                          _buildEarnCoinsSection(),
                          const SizedBox(height: 20),

                          // 4. "Redeem Game Currency" & Per-Game Weekly #1 Team Leaderboard
                          _buildRedeemGameCurrencySection(wallet, activeTeams),
                          const SizedBox(height: 20),

                          // 5. Coins & Redemption History List
                          _buildRecentTransactions(),
                          const SizedBox(height: 20),

                          // 6. Transparent Play Policy & Privacy Disclosure Card
                          _buildPlayPolicyDisclosureCard(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard(
    CoinWallet wallet,
    bool isDark,
    List<TeamModel> activeTeams,
  ) {
    final bool hasTeam = activeTeams.isNotEmpty;

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
        border: Border.all(
          color: GamerTheme.neonGreen.withOpacity(0.3),
          width: 1.2,
        ),
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
                'PERSONAL G-COINS BALANCE',
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasTeam
                      ? GamerTheme.neonGreen.withOpacity(0.15)
                      : const Color(0xFFFFB800).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasTeam ? '🛡️ Team Eligible' : '👤 Solo Wallet (Saved)',
                  style: TextStyle(
                    color: hasTeam ? GamerTheme.neonGreen : const Color(0xFFFFB800),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
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
                    'Estimated Value: 1,000 G-Coins ≈ 100 PKR / \$1.00 Store Value',
                    style: TextStyle(
                      color: ThemeService.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  /// Displays either:
  /// - Solo User Notice: confirming personal earned coins are safely kept in balance/history while explaining that team membership is required to redeem or qualify for weekly team rewards.
  /// - Active Team Summary Card: showing the user's 4-member team, game, weekly team coins total, and weekly rank.
  Widget _buildTeamMembershipStatusBanner(List<TeamModel> activeTeams) {
    if (activeTeams.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB800).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.5), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFFFFB800), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Solo Player Notice • Team Required to Redeem',
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'All G-Coins you earn from watching ads (+25) or daily bonuses (+50) are safely saved in your personal balance and history. '
              'However, you must belong to an active Team (up to 4 members) to redeem rewards or qualify for Per-Game Weekly #1 Team Rewards.',
              style: TextStyle(
                color: ThemeService.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.groups_rounded, size: 16),
                label: const Text(
                  'Join or Create a 4-Member Team 🛡️',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeamsScreen()),
                  ).then((_) => _loadUserTeams());
                },
              ),
            ),
          ],
        ),
      );
    }

    final primaryTeam = activeTeams.first;
    return FutureBuilder<Map<String, dynamic>>(
      future: _teamService.getTeamWeeklyCoinStats(primaryTeam),
      builder: (context, snap) {
        final stats = snap.data;
        final int teamWeeklyCoins = (stats?['weeklyCoins'] as int?) ?? 0;
        final int weeklyRank = (stats?['weeklyRank'] as int?) ?? 1;
        final int memberCount = primaryTeam.memberCount.clamp(1, TeamModel.maxMembers);
        final int equalShare = (TeamService.weeklyGameRewardPool / memberCount).floor();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.45), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GamerTheme.neonGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_rounded, color: GamerTheme.neonGreen, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Team: ${primaryTeam.name} [${primaryTeam.tag}]',
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Game: ${primaryTeam.game} • Members: $memberCount/${TeamModel.maxMembers} • Redemption Unlocked',
                          style: TextStyle(
                            color: ThemeService.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                    ),
                    child: Text(
                      'Rank #$weeklyRank',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Weekly Team Coins: ${NumberFormat('#,###').format(teamWeeklyCoins)}',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '#1 Prize Share: +$equalShare Coins',
                      style: const TextStyle(
                        color: GamerTheme.neonGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14, color: GamerTheme.neonGreen),
                  label: const Text(
                    'View 4-Member Breakdown in Team Profile',
                    style: TextStyle(
                      color: GamerTheme.neonGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamProfileScreen(teamId: primaryTeam.id),
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
          '⚡ Earn Free Coins (Personal + Team Weekly Coins)',
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
                title: _isWatchingAd ? 'Loading...' : 'Watch Ad',
                reward: '+25 Coins',
                icon: Icons.video_library_rounded,
                color: GamerTheme.accentBlue,
                onTap: _watchAdFor25Coins,
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
                reward: '+100 Coins',
                icon: Icons.group_add_rounded,
                color: const Color(0xFFFFB800),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EarnCoinsScreen()),
                  );
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

  Widget _buildRedeemGameCurrencySection(
    CoinWallet wallet,
    List<TeamModel> activeTeams,
  ) {
    final games = ['Free Fire', 'PUBG Mobile', 'Valorant', 'COD Mobile'];
    final bool hasTeam = activeTeams.isNotEmpty;

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
              hasTeam ? 'Team Verified ✅' : 'Requires Active Team 🔒',
              style: TextStyle(
                color: hasTeam ? GamerTheme.neonGreen : const Color(0xFFFFB800),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
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

        // Per-Game Weekly #1 Team Reward Banner for selected game
        _buildPerGameWeeklyTopTeamCard(_selectedGameTab),
        const SizedBox(height: 12),

        // Reward Packs List
        Column(
          children: currentPacks.map((pack) {
            final title = pack['title'] as String;
            final cost = pack['cost'] as int;
            final icon = pack['icon'] as String;
            final canAfford = wallet.coins >= cost;
            final canRedeem = hasTeam && canAfford;
            final progress = (wallet.coins / cost).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ThemeService.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: canRedeem
                      ? GamerTheme.neonGreen.withOpacity(0.4)
                      : ThemeService.border,
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
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                !hasTeam
                                    ? '🛡️ Join a Team to Redeem'
                                    : (canAfford
                                        ? '✅ Eligible'
                                        : '🔒 Need ${cost - wallet.coins} more'),
                                style: TextStyle(
                                  color: !hasTeam
                                      ? const Color(0xFFFFB800)
                                      : (canAfford
                                          ? GamerTheme.neonGreen
                                          : ThemeService.textSecondary),
                                  fontSize: 11,
                                  fontWeight: !hasTeam ? FontWeight.bold : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                              canRedeem ? GamerTheme.neonGreen : GamerTheme.accentOrange,
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
                      backgroundColor: canRedeem
                          ? GamerTheme.neonGreen
                          : (!hasTeam
                              ? const Color(0xFFFFB800).withOpacity(0.2)
                              : ThemeService.cardSecondary),
                      foregroundColor: canRedeem
                          ? Colors.black
                          : (!hasTeam
                              ? const Color(0xFFFFB800)
                              : ThemeService.textSecondary),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () =>
                        _redeemPack(_selectedGameTab, title, cost, wallet, activeTeams),
                    child: Text(
                      !hasTeam ? 'Join Team' : 'Redeem',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: canRedeem
                            ? Colors.black
                            : (!hasTeam
                                ? const Color(0xFFFFB800)
                                : ThemeService.textSecondary),
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

  /// Displays the current week's #1 Team & Weekly Prize Pool for [game]
  Widget _buildPerGameWeeklyTopTeamCard(String game) {
    final weekLabel = TeamService.getWeekRangeLabel();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _teamService.getGameWeeklyLeaderboard(game),
      builder: (context, snap) {
        final entries = snap.data ?? const [];
        final topEntry = entries.isNotEmpty ? entries.first : null;
        final String topTeamName = topEntry != null
            ? '${topEntry['teamName']} [${topEntry['teamTag']}]'
            : 'No ranked team yet';
        final int topWeeklyCoins = (topEntry?['weeklyCoins'] as int?) ?? 0;
        final int topMemberCount = ((topEntry?['memberCount'] as int?) ?? 4).clamp(1, 4);
        final int equalShare = (TeamService.weeklyGameRewardPool / topMemberCount).floor();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$game Weekly #1 Team Reward (${NumberFormat('#,###').format(TeamService.weeklyGameRewardPool)} Coins)',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Text(
                    weekLabel,
                    style: TextStyle(
                      color: ThemeService.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                topEntry != null
                    ? 'Current #1 in $game: $topTeamName • ${NumberFormat('#,###').format(topWeeklyCoins)} Weekly Coins ($topMemberCount/4 members • +$equalShare Coins each at week\'s end)'
                    : 'At the end of the weekly cycle, the #1 team in $game divides ${TeamService.weeklyGameRewardPool} G-Coins equally among its members (up to 4).',
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      },
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
            final txs = (snapshot.data ?? []).take(6).toList();
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
    final isWeeklyReward = tx.type == 'weekly_team_reward';
    final isRedemption = tx.type == 'game_currency_redemption' || tx.type == 'store_purchase';

    final Color color = isWeeklyReward
        ? const Color(0xFFFFD700)
        : (isCredit ? GamerTheme.neonGreen : GamerTheme.redAccent);

    String statusLabel = isCredit ? 'Earned' : 'Spent';
    if (isWeeklyReward) {
      statusLabel = 'Weekly #1 Team Share';
    } else if (isRedemption) {
      statusLabel = 'Redeemed';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWeeklyReward
              ? const Color(0xFFFFD700).withOpacity(0.45)
              : ThemeService.border,
        ),
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
              isWeeklyReward
                  ? Icons.emoji_events_rounded
                  : (isCredit ? Icons.add_rounded : Icons.redeem_rounded),
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
                if (tx.description.isNotEmpty && tx.description != tx.title) ...[
                  const SizedBox(height: 2),
                  Text(
                    tx.description,
                    style: TextStyle(
                      color: ThemeService.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM • hh:mm a').format(tx.timestamp),
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
                statusLabel,
                style: TextStyle(
                  color: color.withOpacity(0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Google Play Policy-Compliant In-App Explanatory Notice & Privacy Disclosure
  Widget _buildPlayPolicyDisclosureCard() {
    return Container(
      width: double.infinity,
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
            children: [
              const Icon(Icons.policy_rounded, color: Color(0xFF1877F2), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'How G-Coins, Weekly Team Rewards & Privacy Work',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _disclosureBullet(
            '1. Personal & 4-Member Team Coin Tracking:',
            'Each team supports up to 4 members. Watching a rewarded ad awards +25 G-Coins and claiming the daily login bonus awards +50 G-Coins to your personal balance and history, while also recording your weekly coin contribution for your team\'s game.',
          ),
          const SizedBox(height: 6),
          _disclosureBullet(
            '2. Per-Game Weekly #1 Team & Equal Division:',
            'Weekly team coins are tracked separately for each game (e.g., PUBG Mobile, Free Fire, BGMI, Valorant, COD Mobile). At the end of each weekly cycle, the #1 team with the highest weekly coins in each game divides that game\'s 1,000 G-Coins weekly reward equally among its members.',
          ),
          const SizedBox(height: 6),
          _disclosureBullet(
            '3. Team Requirement & Solo Player Protection:',
            'Only users who belong to an active team can redeem rewards or qualify for weekly team rewards. If a solo user earns coins while not in a team, all earned coins remain visible in their personal balance and history until they join a team.',
          ),
          const SizedBox(height: 6),
          _disclosureBullet(
            '4. Privacy & Data Minimization (Play Policy):',
            'In team views and weekly leaderboards, only public gaming display names/handles, team rank, and coin contribution figures are shown. Private or sensitive personal data (such as email addresses, phone numbers, real names/addresses, or account credentials) is never exposed to other users.',
          ),
        ],
      ),
    );
  }

  Widget _disclosureBullet(String heading, String body) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: ThemeService.textSecondary,
          fontSize: 11.5,
          height: 1.4,
        ),
        children: [
          TextSpan(
            text: '$heading ',
            style: TextStyle(
              color: ThemeService.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: body),
        ],
      ),
    );
  }
}
