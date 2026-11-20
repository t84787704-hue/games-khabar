// ===============================================================================
// COIN WALLET & REWARDS SCREEN — Google Play Policy Compliant Setup
// - Weekly (7-Day) Cycle Focused on Free Fire & PUBG Mobile
// - 1,500 PKR Equivalent #1 Team Prize Divided Equally Among Up to 4 Members
// - Personal Wallet First + Manual Team Contribution (All/Max, Custom, or 0)
// - Winner-Only (#1 Team) Redemption, Personal Coin Safety & Weekly Reset to 0
// - Strict Privacy & Data Minimization (Public Gaming Handles Only)
// File: lib/screens/coin_wallet_screen.dart
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_transaction_model.dart';
import '../models/coin_wallet_model.dart';
import '../models/team_model.dart';
import '../services/ad_free_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
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
  final TextEditingController _customContributionCtrl = TextEditingController();

  bool _isClaimingDaily = false;
  bool _isWatchingAd = false;
  bool _isContributingCoins = false;
  String _selectedGameTab = 'Free Fire';
  String _selectedContributionMode = 'custom'; // 'all', 'custom', 'zero'
  List<TeamModel> _userTeams = [];
  bool _isLoadingTeams = true;

  Stream<CoinWallet>? _walletStream;
  Stream<List<TeamModel>>? _userTeamsStream;
  Stream<List<CoinTransaction>>? _transactionsStream;
  String? _cachedStatsTeamId;
  Future<Map<String, dynamic>>? _teamWeeklyStatsFuture;
  final Map<String, Future<List<Map<String, dynamic>>>> _gameLeaderboardFutures = {};

  String _resolvedUserId = '';

  String get _userId {
    final authUid = GamerAuthService().currentUid;
    if (authUid != null && authUid.trim().isNotEmpty) return authUid.trim();
    final supaUid = SupabaseService.client.auth.currentUser?.id;
    if (supaUid != null && supaUid.trim().isNotEmpty) return supaUid.trim();
    return _resolvedUserId;
  }

  @override
  void initState() {
    super.initState();
    final uid = _userId;
    final cachedTeams = uid.isNotEmpty ? _teamService.getCachedUserTeams(uid) : null;
    if (cachedTeams != null) {
      _userTeams = cachedTeams;
      _isLoadingTeams = false;
    } else {
      _isLoadingTeams = true;
    }
    _initStreams();
    _initWalletAndTeamData();
  }

  void _initStreams() {
    final uid = _userId;
    _walletStream = _walletService.walletStream(uid);
    _userTeamsStream = uid.isNotEmpty
        ? _teamService.getUserTeamsStream(uid)
        : const Stream<List<TeamModel>>.empty();
    _transactionsStream = _walletService.transactionsStream(uid);
  }

  Future<Map<String, dynamic>> _getOrCreateTeamStatsFuture(TeamModel team) {
    final cached = _teamService.getCachedTeamWeeklyStats(team.id);
    if (_teamWeeklyStatsFuture == null || _cachedStatsTeamId != team.id) {
      _cachedStatsTeamId = team.id;
      _teamWeeklyStatsFuture = _teamService.getTeamWeeklyCoinStats(team);
    } else if (cached != null) {
      return Future.value(cached);
    }
    return _teamWeeklyStatsFuture!;
  }

  Future<List<Map<String, dynamic>>> _getOrCreateGameLeaderboardFuture(String game) {
    return _gameLeaderboardFutures.putIfAbsent(
      game,
      () => _teamService.getGameWeeklyLeaderboard(game),
    );
  }

  Future<void> _initWalletAndTeamData() async {
    if (_userId.isEmpty) {
      try {
        final fetchedUid = await SupabaseService.getCurrentUserId();
        if (fetchedUid != null && fetchedUid.trim().isNotEmpty) {
          _resolvedUserId = fetchedUid.trim();
          _initStreams();
        }
      } catch (_) {}
    }

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
    final uid = _userId;
    if (uid.isEmpty) {
      if (mounted) {
        setState(() {
          _userTeams = [];
          _isLoadingTeams = false;
        });
      }
      return;
    }
    try {
      final teams = await _teamService.getUserTeams(uid);
      if (teams.isNotEmpty) {
        final primary = teams.first;
        final stats = _teamService.getCachedTeamWeeklyStats(primary.id) ??
            await _teamService.getTeamWeeklyCoinStats(primary);
        _cachedStatsTeamId = primary.id;
        _teamWeeklyStatsFuture = Future.value(stats);
      }
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
    _customContributionCtrl.dispose();
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
          await _loadUserTeams();
          if (mounted) {
            setState(() {});
            final bool hasTeam = _userTeams.isNotEmpty;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  hasTeam
                      ? '🎉 +25 G-Coins added to your Personal Wallet! Choose how many to contribute to your Team Profile below.'
                      : '🎉 +25 G-Coins safely saved in your Personal Wallet!',
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
      if (ok) {
        await _loadUserTeams();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? (_userTeams.isNotEmpty
                    ? '🎁 +50 G-Coins daily bonus added to your Personal Wallet! Choose how many to contribute to your Team Profile below.'
                    : '🎁 +50 G-Coins safely saved in your Personal Wallet!')
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

  Future<void> _handleContributeToTeam({
    required TeamModel team,
    required CoinWallet wallet,
    required int amount,
  }) async {
    if (_isContributingCoins) return;
    FocusScope.of(context).unfocus();

    if (amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid contribution amount (0 or higher).'),
          backgroundColor: Color(0xFFFF4655),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (amount > wallet.coins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient Personal Wallet balance! Available: ${NumberFormat('#,###').format(wallet.coins)} G-Coins.',
          ),
          backgroundColor: const Color(0xFFFF4655),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isContributingCoins = true);
    try {
      final res = await _teamService.contributePersonalCoinsToTeam(
        userId: _userId,
        team: team,
        amount: amount,
      );
      _gameLeaderboardFutures.clear();
      _cachedStatsTeamId = null;
      _teamWeeklyStatsFuture = null;
      await _loadUserTeams();
      if (mounted) {
        setState(() {});
        final bool ok = res['success'] == true;
        final String msg = (res['message'] ?? 'Contribution processed.').toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: ok ? GamerTheme.neonGreen : const Color(0xFFFF4655),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contribution failed: $e'),
            backgroundColor: const Color(0xFFFF4655),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isContributingCoins = false);
    }
  }

  Future<void> _refreshWallet() async {
    if (_userId.isNotEmpty) {
      _gameLeaderboardFutures.clear();
      _cachedStatsTeamId = null;
      _teamWeeklyStatsFuture = null;
      await _walletService.getOrCreateWallet(_userId);
      await _loadUserTeams();
      await _teamService.checkAndDistributeWeeklyGameRewards();
      await CoinWalletService.recalculateCoins(_userId);
    }
  }

  void _showWinnerOnlyRedemptionDialog({
    required String gameName,
    required bool hasTeam,
    int? currentRank,
    String? activeTeamName,
  }) {
    final currencyLabel = TeamService.getGameCurrencyLabel(gameName);
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
            Icon(
              hasTeam ? Icons.emoji_events_rounded : Icons.groups_rounded,
              color: const Color(0xFFFFB800),
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasTeam
                    ? 'Rank #1 Team Required to Redeem'
                    : 'Active Team & Rank #1 Required',
                style: TextStyle(
                  color: ThemeService.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          hasTeam
              ? 'Weekly game-currency reward redemption (${NumberFormat('#,###').format(TeamService.weeklyGameRewardPkr)} PKR equivalent in $currencyLabel, divided equally among up to 4 members) is strictly unlocked for members of the Rank #1 team in $gameName.\n\n'
                  'Your team (${activeTeamName ?? 'Active Team'}) is currently Rank #${currentRank ?? '-'} in $gameName. Contribute G-Coins from your Personal Wallet to help your team reach Rank #1! All personal G-Coins in your Personal Wallet remain 100% safe across weekly resets.'
              : 'Weekly game-currency reward redemption (${NumberFormat('#,###').format(TeamService.weeklyGameRewardPkr)} PKR equivalent in $currencyLabel, divided equally among up to 4 active members) is strictly unlocked for members of the Rank #1 team in $gameName.\n\n'
                  'All G-Coins in your Personal Wallet remain 100% safe in your balance and history. Join or create a 4-member Free Fire or PUBG team and contribute coins to compete for Rank #1!',
          style: TextStyle(
            color: ThemeService.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got It', style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.neonGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(
              hasTeam ? Icons.leaderboard_rounded : Icons.shield_rounded,
              size: 16,
            ),
            label: Text(
              hasTeam ? 'View Weekly Leaderboard' : 'Join / Create Team',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (hasTeam) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                ).then((_) => _loadUserTeams());
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TeamsScreen()),
                ).then((_) => _loadUserTeams());
              }
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
    // 1. Must belong to an active team
    if (activeTeams.isEmpty) {
      _showWinnerOnlyRedemptionDialog(
        gameName: gameName,
        hasTeam: false,
      );
      return;
    }

    // 2. Find user's team for this game (or primary team) and verify Rank #1 status
    TeamModel? matchingTeam;
    for (final t in activeTeams) {
      if (TeamService.matchesGameName(t.game, gameName)) {
        matchingTeam = t;
        break;
      }
    }
    final activeTeam = matchingTeam ?? activeTeams.first;
    final bool matchesSelectedGame = TeamService.matchesGameName(activeTeam.game, gameName);

    final stats = _teamService.getCachedTeamWeeklyStats(activeTeam.id) ??
        await _teamService.getTeamWeeklyCoinStats(activeTeam);
    final int weeklyRank = (stats['weeklyRank'] as num?)?.toInt() ??
        (activeTeam.weeklyRank > 0 ? activeTeam.weeklyRank : 2);
    final int teamWeeklyCoins = (stats['weeklyCoins'] as num?)?.toInt() ?? activeTeam.weeklyCoins;
    final bool isRankOneWinner = matchesSelectedGame && weeklyRank == 1 && teamWeeklyCoins > 0;

    // Rule 3: Winner-Only Redemption — strictly members of the #1 team in that game
    if (!isRankOneWinner) {
      _showWinnerOnlyRedemptionDialog(
        gameName: gameName,
        hasTeam: true,
        currentRank: matchesSelectedGame ? weeklyRank : null,
        activeTeamName: '${activeTeam.name} [${activeTeam.tag}] (${activeTeam.game})',
      );
      return;
    }

    if (wallet.coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient Personal Wallet G-Coins! You need ${cost - wallet.coins} more coins.'),
          backgroundColor: const Color(0xFFFF4655),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final int memberCount = activeTeam.memberCount.clamp(1, TeamModel.maxMembers);
    final int equalPkrShare = TeamService.getEqualPkrShare(memberCount);
    final String currencyLabel = TeamService.getGameCurrencyLabel(gameName);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm #1 Team Winner Redemption',
          style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Redeem $packTitle ($currencyLabel) for $gameName for $cost G-Coins?\n\n'
          '🥇 Rank #1 Team: ${activeTeam.name} [${activeTeam.tag}] ($memberCount/${TeamModel.maxMembers} members)\n'
          '🏆 Weekly #1 Prize Pool: ${NumberFormat('#,###').format(TeamService.weeklyGameRewardPkr)} PKR Equivalent ($equalPkrShare PKR / member)',
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
              'Confirm Claim',
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
        title: '🎁 #1 Team Redeemed $gameName - $packTitle',
        description:
            'Rank #1 Weekly Winner Redemption ($packTitle • $gameName • $equalPkrShare PKR Share of 1,500 PKR) via Team ${activeTeam.name} [${activeTeam.tag}] • Status: Pending Delivery',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Successfully redeemed $packTitle as Rank #1 Team Member! Status: Pending Delivery.'),
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
              stream: _walletStream ?? _walletService.walletStream(_userId),
              builder: (context, walletSnap) {
                final wallet = walletSnap.data ??
                    _walletService.currentWallet ??
                    CoinWallet.empty(_userId);

                return StreamBuilder<List<TeamModel>>(
                  stream: _userTeamsStream ??
                      (_userId.isNotEmpty
                          ? _teamService.getUserTeamsStream(_userId)
                          : const Stream<List<TeamModel>>.empty()),
                  builder: (context, teamsSnap) {
                    if (teamsSnap.hasData && _userId.isNotEmpty) {
                      _userTeams = teamsSnap.data!;
                      _isLoadingTeams = false;
                    }
                    final activeTeams =
                        (teamsSnap.hasData && _userId.isNotEmpty) ? teamsSnap.data! : _userTeams;
                    final bool isTeamsLoading = _isLoadingTeams;

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Prominent Personal Coin Wallet Card
                          _buildBalanceCard(
                            wallet,
                            isDark,
                            activeTeams,
                            isLoadingTeams: isTeamsLoading,
                          ),
                          const SizedBox(height: 14),

                          // 2. Team Membership Status + Manual Personal-to-Team Contribution Card
                          _buildTeamMembershipStatusBanner(
                            wallet,
                            activeTeams,
                            isLoadingTeams: isTeamsLoading,
                          ),
                          const SizedBox(height: 16),

                          _buildActionButtons(),
                          const SizedBox(height: 20),

                          // 3. Clear "Earn Coins" Cards (+25 Ad Watch, +50 Daily Bonus -> Personal Wallet First)
                          _buildEarnCoinsSection(),
                          const SizedBox(height: 20),

                          // 4. "Redeem Game Currency" (Free Fire & PUBG • #1 Team Winner-Only Redemption)
                          _buildRedeemGameCurrencySection(
                            wallet,
                            activeTeams,
                            isLoadingTeams: isTeamsLoading,
                          ),
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
    List<TeamModel> activeTeams, {
    required bool isLoadingTeams,
  }) {
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
                'PERSONAL G-COINS WALLET',
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                ),
              ),
              if (isLoadingTeams)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThemeService.cardSecondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: ThemeService.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Checking Team...',
                        style: TextStyle(
                          color: ThemeService.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasTeam
                        ? GamerTheme.neonGreen.withOpacity(0.15)
                        : const Color(0xFFFFB800).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasTeam ? '🛡️ Active Team Member' : '👤 Personal Wallet (Protected)',
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
                const Icon(Icons.shield_rounded, color: GamerTheme.neonGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All earned coins go to your Personal Wallet first & stay 100% safe across weekly resets. Weekly #1 Team Prize: 1,500 PKR Equivalent (Free Fire & PUBG).',
                    style: TextStyle(
                      color: ThemeService.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
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

  Widget _buildTeamLoadingSkeletonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeService.border, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: GamerTheme.neonGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checking Active Team Membership...',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 10,
                      width: 180,
                      decoration: BoxDecoration(
                        color: ThemeService.cardSecondary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 34,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ThemeService.cardSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  /// Displays either:
  /// - Loading skeleton placeholder while active team membership is resolving.
  /// - Solo User Notice: confirming personal earned coins are safely kept in Personal Wallet while explaining how to join a Free Fire or PUBG team for the 1,500 PKR weekly competition.
  /// - Active Team Summary + Manual Coin Contribution Card: allowing the user to contribute All/Max, a custom amount, or 0 (Keep in Personal Wallet) to their Team Profile.
  Widget _buildTeamMembershipStatusBanner(
    CoinWallet wallet,
    List<TeamModel> activeTeams, {
    required bool isLoadingTeams,
  }) {
    if (isLoadingTeams) {
      return _buildTeamLoadingSkeletonCard();
    }

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
                    'Solo Player Notice • Personal Coins 100% Safe',
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
              'All G-Coins you earn from watching ads (+25) or daily bonuses (+50) go directly into your Personal Wallet and remain safely stored across weekly resets. '
              'To compete for the weekly 1,500 PKR equivalent #1 Team Prize in Free Fire or PUBG Mobile (and unlock #1 team reward redemption), join or create a 4-member team.',
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
    final cachedStats = _teamService.getCachedTeamWeeklyStats(primaryTeam.id);
    return FutureBuilder<Map<String, dynamic>>(
      initialData: cachedStats,
      future: _getOrCreateTeamStatsFuture(primaryTeam),
      builder: (context, snap) {
        final stats = snap.data ?? cachedStats;
        final int statsWeeklyCoins = (stats?['weeklyCoins'] as num?)?.toInt() ?? 0;
        final int breakdownCoins = (stats?['memberBreakdown'] is List)
            ? (stats!['memberBreakdown'] as List).fold<int>(
                0,
                (sum, m) => sum + ((m is Map ? (m['weeklyCoins'] as num?)?.toInt() : 0) ?? 0),
              )
            : 0;
        final int memberMapCoins = primaryTeam.memberWeeklyCoins.values.fold<int>(
          0,
          (sum, v) => sum + v,
        );
        int teamWeeklyCoins = statsWeeklyCoins;
        if (breakdownCoins > teamWeeklyCoins) teamWeeklyCoins = breakdownCoins;
        if (primaryTeam.weeklyCoins > teamWeeklyCoins) teamWeeklyCoins = primaryTeam.weeklyCoins;
        if (memberMapCoins > teamWeeklyCoins) teamWeeklyCoins = memberMapCoins;

        final int weeklyRank = (stats?['weeklyRank'] as num?)?.toInt() ??
            (primaryTeam.weeklyRank > 0 ? primaryTeam.weeklyRank : 1);
        final int memberCount = primaryTeam.memberCount.clamp(1, TeamModel.maxMembers);
        final int equalPkrShare = TeamService.getEqualPkrShare(memberCount);
        final String currencyLabel = TeamService.getGameCurrencyLabel(primaryTeam.game);
        final String weekLabel = TeamService.getWeekRangeLabel();
        final bool isRankOneWinner = weeklyRank == 1 && teamWeeklyCoins > 0;

        // Calculate current user's weekly contribution to this team
        int myWeeklyContrib = 0;
        if (stats?['memberCoins'] is Map) {
          final map = stats!['memberCoins'] as Map;
          final uidClean = _userId.trim();
          final uidUuid = SupabaseService.toUuid(uidClean);
          myWeeklyContrib = (map[uidClean] as num?)?.toInt() ??
              (map[uidUuid] as num?)?.toInt() ??
              0;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRankOneWinner
                  ? const Color(0xFFFFD700).withOpacity(0.65)
                  : GamerTheme.neonGreen.withOpacity(0.45),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isRankOneWinner
                          ? const Color(0xFFFFD700).withOpacity(0.18)
                          : GamerTheme.neonGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isRankOneWinner ? Icons.emoji_events_rounded : Icons.verified_rounded,
                      color: isRankOneWinner ? const Color(0xFFFFD700) : GamerTheme.neonGreen,
                      size: 20,
                    ),
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
                          'Game: ${primaryTeam.game} • Members: $memberCount/${TeamModel.maxMembers} • ${isRankOneWinner ? '#1 Winner Redemption Unlocked 🔓' : 'Reach #1 to Redeem ($weekLabel)'}',
                          style: TextStyle(
                            color: isRankOneWinner ? GamerTheme.neonGreen : ThemeService.textSecondary,
                            fontSize: 11,
                            fontWeight: isRankOneWinner ? FontWeight.w700 : FontWeight.normal,
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
                      '${weeklyRank == 1 ? '🥇 ' : ''}Rank #$weeklyRank',
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
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
                          'Your Weekly Contrib: +${NumberFormat('#,###').format(myWeeklyContrib)}',
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '#1 Weekly Prize: ${NumberFormat('#,###').format(TeamService.weeklyGameRewardPkr)} PKR ($currencyLabel)',
                          style: const TextStyle(
                            color: GamerTheme.neonGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.2,
                          ),
                        ),
                        Text(
                          'Equal Share: $equalPkrShare PKR / member',
                          style: TextStyle(
                            color: ThemeService.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Manual Personal-to-Team Contribution Controls
              _buildManualTeamContributionBox(primaryTeam, wallet),

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
                    ).then((_) => _loadUserTeams());
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Interactive box inside the Wallet screen allowing the user to manually transfer/contribute
  /// personal G-Coins to their active Team Profile (`All / Max`, custom amount, or `0` to keep in Personal Wallet).
  Widget _buildManualTeamContributionBox(TeamModel team, CoinWallet wallet) {
    final int availableCoins = wallet.coins.clamp(0, 999999999);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeService.cardSecondary.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: GamerTheme.neonGreen, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Contribute Personal Coins to Team (${team.game})',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how many coins from your Personal Wallet (${NumberFormat('#,###').format(availableCoins)} available) to add to ${team.name}\'s weekly score. Weekly team scores reset to 0 every Monday; uncontributed coins stay safely in your Personal Wallet.',
            style: TextStyle(
              color: ThemeService.textSecondary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _contributionPresetChip(
                label: 'All / Max (${NumberFormat('#,###').format(availableCoins)})',
                isSelected: _selectedContributionMode == 'all',
                onTap: () {
                  setState(() {
                    _selectedContributionMode = 'all';
                    _customContributionCtrl.text = availableCoins.toString();
                  });
                },
              ),
              if (availableCoins >= 100)
                _contributionPresetChip(
                  label: '+100 Coins',
                  isSelected: _selectedContributionMode == '100',
                  onTap: () {
                    setState(() {
                      _selectedContributionMode = '100';
                      _customContributionCtrl.text = '100';
                    });
                  },
                ),
              if (availableCoins >= 500)
                _contributionPresetChip(
                  label: '+500 Coins',
                  isSelected: _selectedContributionMode == '500',
                  onTap: () {
                    setState(() {
                      _selectedContributionMode = '500';
                      _customContributionCtrl.text = '500';
                    });
                  },
                ),
              _contributionPresetChip(
                label: 'Keep in Personal Wallet (0)',
                isSelected: _selectedContributionMode == 'zero',
                onTap: () {
                  setState(() {
                    _selectedContributionMode = 'zero';
                    _customContributionCtrl.text = '0';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _customContributionCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) {
                      if (_selectedContributionMode != 'custom') {
                        setState(() => _selectedContributionMode = 'custom');
                      }
                    },
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter amount (0 – $availableCoins)',
                      hintStyle: TextStyle(
                        color: ThemeService.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: const Icon(
                        Icons.monetization_on_outlined,
                        color: Color(0xFFFFD700),
                        size: 17,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: ThemeService.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: ThemeService.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: ThemeService.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: GamerTheme.neonGreen, width: 1.3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GamerTheme.neonGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: _isContributingCoins
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.shield_rounded, size: 16),
                  label: Text(
                    _isContributingCoins ? 'Sending...' : 'Contribute',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  onPressed: _isContributingCoins
                      ? null
                      : () {
                          final rawText = _customContributionCtrl.text.trim();
                          final int parsed = rawText.isEmpty
                              ? (_selectedContributionMode == 'all' ? availableCoins : 0)
                              : (int.tryParse(rawText) ?? -1);
                          _handleContributeToTeam(
                            team: team,
                            wallet: wallet,
                            amount: parsed,
                          );
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contributionPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? GamerTheme.neonGreen.withOpacity(0.2)
              : ThemeService.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? GamerTheme.neonGreen : ThemeService.border,
            width: isSelected ? 1.3 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? GamerTheme.neonGreen : ThemeService.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
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
          '⚡ Earn Free Coins (Added to Personal Wallet First)',
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
    List<TeamModel> activeTeams, {
    required bool isLoadingTeams,
  }) {
    final games = TeamService.supportedGames; // ['Free Fire', 'PUBG Mobile']
    if (!games.contains(_selectedGameTab)) {
      _selectedGameTab = games.first;
    }
    final bool hasTeam = activeTeams.isNotEmpty;

    // Check if the user belongs to the Rank #1 team in _selectedGameTab
    TeamModel? matchingGameTeam;
    for (final t in activeTeams) {
      if (TeamService.matchesGameName(t.game, _selectedGameTab)) {
        matchingGameTeam = t;
        break;
      }
    }
    final TeamModel? evaluatedTeam = matchingGameTeam ?? (activeTeams.isNotEmpty ? activeTeams.first : null);
    final cachedTeamStats = evaluatedTeam != null
        ? _teamService.getCachedTeamWeeklyStats(evaluatedTeam.id)
        : null;
    final int teamRankInGame = (cachedTeamStats?['weeklyRank'] as num?)?.toInt() ??
        (evaluatedTeam?.weeklyRank ?? 0);
    final int teamWeeklyCoinsInGame = (cachedTeamStats?['weeklyCoins'] as num?)?.toInt() ??
        (evaluatedTeam?.weeklyCoins ?? 0);
    final bool isRankOneInSelectedGame = hasTeam &&
        evaluatedTeam != null &&
        TeamService.matchesGameName(evaluatedTeam.game, _selectedGameTab) &&
        teamRankInGame == 1 &&
        teamWeeklyCoinsInGame > 0;

    final packsMap = {
      'Free Fire': [
        {'title': '100 Diamonds (375 PKR Share)', 'cost': 500, 'icon': '💎'},
        {'title': '310 Diamonds (750 PKR Share)', 'cost': 1400, 'icon': '💎'},
        {'title': '520 Diamonds (1,500 PKR #1 Pool)', 'cost': 2200, 'icon': '💎'},
      ],
      'PUBG Mobile': [
        {'title': '60 UC (375 PKR Share)', 'cost': 600, 'icon': '🪙'},
        {'title': '325 UC (750 PKR Share)', 'cost': 2800, 'icon': '🪙'},
        {'title': '660 UC (1,500 PKR #1 Pool)', 'cost': 5400, 'icon': '🪙'},
      ],
    };

    final currentPacks = packsMap[_selectedGameTab] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '🎮 Redeem Game Currency (#1 Team)',
                style: TextStyle(
                  color: ThemeService.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (isLoadingTeams)
              Text(
                'Checking Team...',
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                isRankOneInSelectedGame
                    ? '🥇 #1 Team Unlocked'
                    : (hasTeam ? 'Requires Rank #1 🏆' : 'Requires #1 Team 🔒'),
                style: TextStyle(
                  color: isRankOneInSelectedGame
                      ? GamerTheme.neonGreen
                      : const Color(0xFFFFB800),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Two Weekly Competition Games Tabs: Free Fire & PUBG Mobile
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

        // Per-Game Weekly #1 Team Reward Banner (1,500 PKR Equivalent) for selected game
        _buildPerGameWeeklyTopTeamCard(_selectedGameTab),
        const SizedBox(height: 12),

        // Reward Packs List (Winner-Only Redemption)
        Column(
          children: currentPacks.map((pack) {
            final title = pack['title'] as String;
            final cost = pack['cost'] as int;
            final icon = pack['icon'] as String;
            final canAfford = wallet.coins >= cost;
            final canRedeem = !isLoadingTeams && isRankOneInSelectedGame && canAfford;
            final progress = (wallet.coins / cost).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ThemeService.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: canRedeem
                      ? GamerTheme.neonGreen.withOpacity(0.45)
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
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Cost: $cost Coins',
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isLoadingTeams
                                    ? '⏳ Checking team...'
                                    : (!hasTeam
                                        ? '🛡️ Join a Team (#1 Wins)'
                                        : (!isRankOneInSelectedGame
                                            ? '🏆 Rank #1 Team Only'
                                            : (canAfford
                                                ? '✅ #1 Winner Eligible'
                                                : '🔒 Need ${cost - wallet.coins} more'))),
                                style: TextStyle(
                                  color: isLoadingTeams
                                      ? ThemeService.textSecondary
                                      : (!isRankOneInSelectedGame
                                          ? const Color(0xFFFFB800)
                                          : (canAfford
                                              ? GamerTheme.neonGreen
                                              : ThemeService.textSecondary)),
                                  fontSize: 11,
                                  fontWeight: (!isLoadingTeams && !isRankOneInSelectedGame)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
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
                      backgroundColor: isLoadingTeams
                          ? ThemeService.cardSecondary
                          : (canRedeem
                              ? GamerTheme.neonGreen
                              : (!isRankOneInSelectedGame
                                  ? const Color(0xFFFFB800).withOpacity(0.2)
                                  : ThemeService.cardSecondary)),
                      foregroundColor: isLoadingTeams
                          ? ThemeService.textSecondary
                          : (canRedeem
                              ? Colors.black
                              : (!isRankOneInSelectedGame
                                  ? const Color(0xFFFFB800)
                                  : ThemeService.textSecondary)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: isLoadingTeams
                        ? null
                        : () => _redeemPack(_selectedGameTab, title, cost, wallet, activeTeams),
                    child: Text(
                      isLoadingTeams
                          ? '...'
                          : (!hasTeam
                              ? 'Join Team'
                              : (!isRankOneInSelectedGame ? '#1 Only' : 'Redeem')),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isLoadingTeams
                            ? ThemeService.textSecondary
                            : (canRedeem
                                ? Colors.black
                                : (!isRankOneInSelectedGame
                                    ? const Color(0xFFFFB800)
                                    : ThemeService.textSecondary)),
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

  /// Displays the current 7-day week's #1 Team & 1,500 PKR Equivalent Weekly Prize Pool for [game]
  Widget _buildPerGameWeeklyTopTeamCard(String game) {
    final weekLabel = TeamService.getWeekRangeLabel();
    final cachedLeaderboard = _teamService.getCachedGameWeeklyLeaderboard(game);
    final currencyLabel = TeamService.getGameCurrencyLabel(game);

    return FutureBuilder<List<Map<String, dynamic>>>(
      initialData: cachedLeaderboard,
      future: _getOrCreateGameLeaderboardFuture(game),
      builder: (context, snap) {
        final entries = snap.data ?? cachedLeaderboard ?? const [];
        final topEntry = entries.isNotEmpty ? entries.first : null;
        final String topTeamName = topEntry != null
            ? '${topEntry['teamName']} [${topEntry['teamTag']}]'
            : 'No ranked team yet';
        final int topWeeklyCoins = (topEntry?['weeklyCoins'] as int?) ?? 0;
        final int topMemberCount = ((topEntry?['memberCount'] as int?) ?? 4).clamp(1, 4);
        final int equalPkrShare = TeamService.getEqualPkrShare(topMemberCount);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.45)),
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
                      '$game Weekly #1 Prize (1,500 PKR Equivalent • $currencyLabel)',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.2,
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
                topEntry != null && topWeeklyCoins > 0
                    ? 'Current #1 in $game: $topTeamName • ${NumberFormat('#,###').format(topWeeklyCoins)} Weekly Team Coins ($topMemberCount/4 active members • $equalPkrShare PKR equivalent in $currencyLabel each at week\'s end)'
                    : 'At the end of the 7-day weekly cycle ($weekLabel), the #1 team in $game receives 1,500 PKR equivalent in $currencyLabel divided equally among its active members (up to 4). Weekly team scores reset to 0 each new week.',
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
          stream: _transactionsStream ?? _walletService.transactionsStream(_userId),
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
                    'No transaction history yet. Earn or contribute coins to start!',
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
    final isTeamContribution = tx.type == 'team_weekly_contribution';
    final isRedemption = tx.type == 'game_currency_redemption' || tx.type == 'store_purchase';

    final Color color = isWeeklyReward
        ? const Color(0xFFFFD700)
        : (isTeamContribution
            ? GamerTheme.accentBlue
            : (isCredit ? GamerTheme.neonGreen : GamerTheme.redAccent));

    String statusLabel = isCredit ? 'Added to Personal Wallet' : 'Spent';
    if (isWeeklyReward) {
      statusLabel = 'Weekly #1 Prize Share';
    } else if (isTeamContribution) {
      statusLabel = 'Contributed to Team';
    } else if (isRedemption) {
      statusLabel = '#1 Team Redeemed';
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
              : (isTeamContribution
                  ? GamerTheme.accentBlue.withOpacity(0.45)
                  : ThemeService.border),
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
                  : (isTeamContribution
                      ? Icons.shield_rounded
                      : (isCredit ? Icons.add_rounded : Icons.redeem_rounded)),
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
                  'How G-Coins, 1,500 PKR Weekly Team Prize & Privacy Work',
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
            '1. Weekly (7-Day) Cycle, Two Games & 1,500 PKR Equivalent Prize:',
            'The weekly team competition runs on a 7-day cycle (Monday 00:00 UTC – Sunday 23:59 UTC) focused on Free Fire and PUBG Mobile. At the end of each week, the #1 team in Free Fire and the #1 team in PUBG Mobile each receive 1,500 PKR equivalent in that game\'s in-game currency (Free Fire Diamonds or PUBG UC), divided equally among that winning #1 team\'s active members (up to 4 members per team).',
          ),
          const SizedBox(height: 6),
          _disclosureBullet(
            '2. Personal Wallet First + Manual Team Contribution:',
            'All G-Coins earned from watching ads (+25), daily bonuses (+50), or activities go directly into your Personal Wallet first. Inside this Wallet screen, you choose how many personal coins to contribute to your active Team Profile for the weekly competition (All / Max, a custom amount, or keep them in your Personal Wallet / contribute 0).',
          ),
          const SizedBox(height: 6),
          _disclosureBullet(
            '3. Winner-Only Redemption, Personal Coin Safety & Weekly Reset:',
            'Weekly game-currency reward redemption is unlocked strictly for members of the #1 team in that game for that weekly cycle. Non-#1 teams\' and solo players\' personal G-Coins remain 100% safe in their Personal Wallet balance and history. Weekly team coin scores and weekly member contributions reset to 0 at the start of each new weekly cycle while preserving past results.',
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
