// ═══════════════════════════════════════════════════════════════════════════════
// CLEAN COIN STORE SCREEN — Localized with easy_localization & Adaptive Theme
// - Real-time smooth ticking 24h countdown timer (Max 24h capped, Timezone synced)
// - Live synced Personal G-Coins Balance, Daily Check-in, Rewarded Ads, Referral & History
// - Crash-proof SingleChildScrollView + State & Broadcast Stream architecture
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_wallet_model.dart';
import '../models/coin_transaction_model.dart';
import '../services/coin_reward_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../services/app_share_service.dart';
import '../services/team_service.dart';
import '../services/wallet_repository.dart';
import '../models/team_model.dart';
import 'coin_wallet_screen.dart';
import 'teams_screen.dart';

class CoinStoreScreen extends StatefulWidget {
  const CoinStoreScreen({super.key});

  @override
  State<CoinStoreScreen> createState() => _CoinStoreScreenState();
}

class _CoinStoreScreenState extends State<CoinStoreScreen> {
  final CoinWalletService _walletService = CoinWalletService();
  final GamerAuthService _authService = GamerAuthService();
  final TeamService _teamService = TeamService();

  Timer? _countdownTimer;
  DateTime? _lastClaimTime;
  final ValueNotifier<Duration> _timeUntilNextClaimNotifier =
      ValueNotifier<Duration>(Duration.zero);

  bool _isClaimingDaily = false;
  bool _isWatchingAd = false;

  String _resolvedUserId = '';
  CoinWallet? _wallet;
  List<TeamModel> _userTeams = [];
  bool _isLoadingTeams = true;
  List<CoinTransaction> _transactions = [];
  bool _isLoadingTransactions = true;

  StreamSubscription<CoinWallet>? _walletSub;
  StreamSubscription<List<TeamModel>>? _teamsSub;
  StreamSubscription<List<CoinTransaction>>? _txSub;

  String get _userId {
    final authUid = _authService.currentUid;
    if (authUid != null && authUid.trim().isNotEmpty) return authUid.trim();
    final supaUid = SupabaseService.client.auth.currentUser?.id;
    if (supaUid != null && supaUid.trim().isNotEmpty) return supaUid.trim();
    final gamerUid = _authService.currentGamer?.uid;
    if (gamerUid != null && gamerUid.trim().isNotEmpty) return gamerUid.trim();
    return _resolvedUserId;
  }

  String _trSafe(String key, String fallback, {List<String>? args}) {
    try {
      final translated = args != null ? key.tr(args: args) : key.tr();
      if (translated.isEmpty || translated == key) {
        if (args != null && args.isNotEmpty) {
          var res = fallback;
          for (final a in args) {
            res = res.replaceFirst('{}', a);
          }
          return res;
        }
        return fallback;
      }
      return translated;
    } catch (_) {
      if (args != null && args.isNotEmpty) {
        var res = fallback;
        for (final a in args) {
          res = res.replaceFirst('{}', a);
        }
        return res;
      }
      return fallback;
    }
  }

  @override
  void initState() {
    super.initState();
    _wallet = _walletService.currentWallet;
    if (_wallet?.lastDailyBonusClaim != null) {
      _lastClaimTime = _wallet!.lastDailyBonusClaim;
    }

    final initialUid = _userId;
    if (initialUid.isNotEmpty) {
      final cachedTeams = _teamService.getCachedUserTeams(initialUid);
      if (cachedTeams != null) {
        _userTeams = cachedTeams;
        _isLoadingTeams = false;
      }
    }

    _walletService.addListener(_onExternalBalanceChanged);
    _authService.currentGamerNotifier.addListener(_onExternalBalanceChanged);
    CoinRewardService().coinsNotifier.addListener(_onExternalBalanceChanged);
    WalletRepository.instance.gCoinsBalance.addListener(_onExternalBalanceChanged);
    WalletRepository.instance.walletNotifier.addListener(_onExternalBalanceChanged);

    _recalculateCountdown();
    _initStoreData();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _recalculateCountdown();
      }
    });
  }

  void _onExternalBalanceChanged() {
    if (!mounted) return;
    final currentW = _walletService.currentWallet;
    if (currentW != null) {
      if (currentW.lastDailyBonusClaim != null &&
          _lastClaimTime != currentW.lastDailyBonusClaim) {
        _lastClaimTime = currentW.lastDailyBonusClaim;
        _recalculateCountdown();
      }
      setState(() {
        _wallet = currentW;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _initStoreData() async {
    if (_userId.isEmpty) {
      try {
        final savedUid = await SupabaseService.getCurrentUserId();
        if (savedUid != null && savedUid.trim().isNotEmpty) {
          _resolvedUserId = savedUid.trim();
        }
      } catch (_) {}
    }

    final uid = _userId;
    if (uid.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingTeams = false;
          _isLoadingTransactions = false;
        });
      }
      return;
    }

    final cachedTeams = _teamService.getCachedUserTeams(uid);
    if (cachedTeams != null && mounted) {
      setState(() {
        _userTeams = cachedTeams;
        _isLoadingTeams = false;
      });
    }

    _subscribeStreams(uid);

    try {
      final w = await _walletService.getOrCreateWallet(uid);
      if (mounted) {
        setState(() {
          _wallet = w;
          if (w.lastDailyBonusClaim != null) {
            _lastClaimTime = w.lastDailyBonusClaim;
          }
        });
        _recalculateCountdown();
      }
    } catch (_) {}

    try {
      final teams = await _teamService.getUserTeams(uid);
      if (mounted) {
        setState(() {
          _userTeams = teams;
          _isLoadingTeams = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTeams = false);
      }
    }
  }

  void _subscribeStreams(String uid) {
    _walletSub?.cancel();
    _teamsSub?.cancel();
    _txSub?.cancel();

    try {
      _walletSub = _walletService.walletStream(uid).listen((w) {
        if (!mounted) return;
        setState(() {
          _wallet = w;
          if (w.lastDailyBonusClaim != null) {
            _lastClaimTime = w.lastDailyBonusClaim;
          }
        });
        _recalculateCountdown();
      }, onError: (_) {});
    } catch (_) {}

    try {
      _teamsSub = _teamService.getUserTeamsStream(uid).listen((teams) {
        if (!mounted) return;
        setState(() {
          _userTeams = teams;
          _isLoadingTeams = false;
        });
      }, onError: (_) {
        if (mounted && _isLoadingTeams) {
          setState(() => _isLoadingTeams = false);
        }
      });
    } catch (_) {
      if (mounted && _isLoadingTeams) {
        setState(() => _isLoadingTeams = false);
      }
    }

    try {
      _txSub = _walletService.transactionsStream(uid).listen((txs) {
        if (!mounted) return;
        setState(() {
          _transactions = txs;
          _isLoadingTransactions = false;
        });
      }, onError: (_) {
        if (mounted && _isLoadingTransactions) {
          setState(() => _isLoadingTransactions = false);
        }
      });
    } catch (_) {
      if (mounted && _isLoadingTransactions) {
        setState(() => _isLoadingTransactions = false);
      }
    }
  }

  void _recalculateCountdown() {
    if (_lastClaimTime == null) {
      if (_timeUntilNextClaimNotifier.value != Duration.zero) {
        _timeUntilNextClaimNotifier.value = Duration.zero;
      }
      return;
    }

    final claimUtc = _lastClaimTime!.isUtc
        ? _lastClaimTime!
        : _lastClaimTime!.toUtc();
    final nowUtc = DateTime.now().toUtc();

    final nextAvailableUtc = claimUtc.add(const Duration(hours: 24));
    final diff = nextAvailableUtc.difference(nowUtc);

    Duration nextDuration;
    if (diff.isNegative || diff.inSeconds <= 0) {
      nextDuration = Duration.zero;
    } else if (diff.inSeconds > 24 * 3600) {
      nextDuration = const Duration(hours: 24);
    } else {
      nextDuration = diff;
    }

    if (_timeUntilNextClaimNotifier.value.inSeconds != nextDuration.inSeconds) {
      _timeUntilNextClaimNotifier.value = nextDuration;
    }
  }

  int get _effectiveCoinBalance {
    final repoCoins = WalletRepository.instance.currentGCoins;
    final walletCoins = _wallet?.gCoins ?? 0;
    final cwCoins = _walletService.currentWallet?.gCoins ?? 0;
    final gamerCoins = _authService.currentGamer?.coins ?? 0;
    final rewardCoins = CoinRewardService().coinsNotifier.value;

    if (repoCoins > 0) return repoCoins;
    if (walletCoins > 0) return walletCoins;
    if (cwCoins > 0) return cwCoins;
    if (gamerCoins > 0) return gamerCoins;
    if (rewardCoins > 0) return rewardCoins;
    return _wallet?.gCoins ?? _walletService.currentWallet?.gCoins ?? 0;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _walletSub?.cancel();
    _teamsSub?.cancel();
    _txSub?.cancel();
    _walletService.removeListener(_onExternalBalanceChanged);
    _authService.currentGamerNotifier.removeListener(_onExternalBalanceChanged);
    CoinRewardService().coinsNotifier.removeListener(_onExternalBalanceChanged);
    WalletRepository.instance.gCoinsBalance.removeListener(_onExternalBalanceChanged);
    WalletRepository.instance.walletNotifier.removeListener(_onExternalBalanceChanged);
    _timeUntilNextClaimNotifier.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '00:00:00';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _handleClaimDaily(String uid) async {
    if (_isClaimingDaily || uid.isEmpty) return;
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
                  setState(() {
                    _isClaimingDaily = false;
                    _wallet = _walletService.currentWallet ?? _wallet;
                    if (success) {
                      _lastClaimTime = DateTime.now().toUtc();
                    }
                  });
                  _recalculateCountdown();
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
                                _trSafe(
                                  'msg_daily_streak_claimed',
                                  '+50 G-Coins daily check-in reward added to your Personal Wallet!',
                                ),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
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
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: GamerTheme.accentOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _trSafe('daily_bonus_ad_title', 'DAILY BONUS SPONSOR'),
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
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
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
                        const Icon(
                          Icons.ondemand_video_rounded,
                          color: GamerTheme.accentOrange,
                          size: 44,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _trSafe('sponsor_gaming_network', 'Sponsor Gaming Network'),
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _trSafe('watch_5s_ad_desc', 'Watch 5s clip to claim +50 G-Coins'),
                          style: TextStyle(
                            color: ThemeService.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (5 - remainingSeconds) / 5.0,
                    backgroundColor: ThemeService.border,
                    color: GamerTheme.accentOrange,
                    minHeight: 6,
                  ),
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
    if (_isWatchingAd || uid.isEmpty) return;
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
              _walletService.rewardAdCoins(uid).then((_) {
                if (mounted) {
                  setState(() {
                    _isWatchingAd = false;
                    _wallet = _walletService.currentWallet ?? _wallet;
                  });
                }
              });
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
                            _trSafe(
                              'msg_ad_coins_added',
                              '+25 G-Coins added to your Personal Wallet!',
                            ),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
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
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: GamerTheme.accentBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _trSafe('rewarded_ad_sponsor_title', 'REWARDED AD SPONSOR'),
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
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
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
                        const Icon(
                          Icons.smart_display_rounded,
                          color: GamerTheme.accentBlue,
                          size: 44,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _trSafe('streaming_gaming_sponsor', 'Streaming Gaming Sponsor'),
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Watch 5s sponsored clip to earn +25 G-Coins',
                          style: TextStyle(
                            color: ThemeService.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (5 - remainingSeconds) / 5.0,
                    backgroundColor: ThemeService.border,
                    color: GamerTheme.accentBlue,
                    minHeight: 6,
                  ),
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
    final uid = _userId;
    final currentBalance = _effectiveCoinBalance;

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
                  _trSafe('title_coin_store', 'Coin Store'),
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: GamerTheme.neonGreen,
                ),
                tooltip: 'Coin Wallet',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CoinWalletScreen()),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _buildStoreHeader(currentBalance, uid),
              Expanded(
                child: RefreshIndicator(
                  color: GamerTheme.neonGreen,
                  backgroundColor: ThemeService.card,
                  onRefresh: _initStoreData,
                  child: _buildStoreContent(uid),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoreHeader(int coinBalance, String uid) {
    final formattedCoins = NumberFormat('#,###').format(coinBalance);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ThemeService.card,
        border: Border(bottom: BorderSide(color: ThemeService.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _trSafe('balance_caps', 'BALANCE'),
                        style: TextStyle(
                          color: ThemeService.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _trSafe(
                          'coins_formatted_gcoins',
                          '$formattedCoins G-Coins',
                          args: [formattedCoins],
                        ),
                        style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: Colors.black, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Earn +25 G-Coins',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreContent(String uid) {
    final inviteCode = _walletService.getReferralCode(uid);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTeamStatusCard(),
          ValueListenableBuilder<Duration>(
            valueListenable: _timeUntilNextClaimNotifier,
            builder: (context, timeUntilNextClaim, _) {
              final canClaimDaily = timeUntilNextClaim == Duration.zero;
              final formattedCountdown = _formatDuration(timeUntilNextClaim);
              return _buildEarnActionCard(
                icon: Icons.calendar_today_rounded,
                iconColor: GamerTheme.neonGreen,
                badge: '+50 G-Coins',
                badgeColor: GamerTheme.neonGreen,
                title: _trSafe('daily_checkin_reward_title', 'Daily Check-in Reward'),
                subtitle: canClaimDaily
                    ? _trSafe(
                        'daily_checkin_ready_sub',
                        'Your daily reward is ready to claim!',
                      )
                    : _trSafe(
                        'daily_checkin_next_in',
                        'Next check-in in: $formattedCountdown',
                        args: [formattedCountdown],
                      ),
                buttonText: _isClaimingDaily
                    ? _trSafe('btn_watching', 'Watching...')
                    : (canClaimDaily
                        ? 'Claim +50 G-Coins'
                        : formattedCountdown),
                buttonColor:
                    canClaimDaily ? GamerTheme.neonGreen : ThemeService.cardSecondary,
                textColor: canClaimDaily ? Colors.black : ThemeService.textSecondary,
                onTap: canClaimDaily ? () => _handleClaimDaily(uid) : null,
              );
            },
          ),
          const SizedBox(height: 12),
          _buildEarnActionCard(
            icon: Icons.play_circle_filled_rounded,
            iconColor: GamerTheme.accentOrange,
            badge: '+25 G-Coins',
            badgeColor: GamerTheme.accentOrange,
            title: _trSafe('watch_sponsored_ads_title', 'Watch Sponsored Ads'),
            subtitle: _trSafe(
              'watch_sponsored_ads_sub',
              'Watch a short ad to earn free G-Coins instantly.',
            ),
            buttonText: _isWatchingAd
                ? _trSafe('btn_streaming_ad', 'Streaming Ad...')
                : 'Watch Ad (+25)',
            buttonColor: GamerTheme.accentOrange,
            textColor: Colors.white,
            onTap: _isWatchingAd ? null : () => _handleWatchAd(uid),
          ),
          const SizedBox(height: 12),
          _buildEarnActionCard(
            icon: Icons.people_alt_rounded,
            iconColor: GamerTheme.accentBlue,
            badge: '+200 G-Coins',
            badgeColor: GamerTheme.accentBlue,
            title: _trSafe('squad_referral_bonus_title', 'Squad Referral Bonus'),
            subtitle:
                '${_trSafe('squad_referral_bonus_sub', 'Invite your friends using your code and earn bonus G-Coins.')} ($inviteCode)',
            buttonText: '${_trSafe('btn_share_code', 'Share Invite Code')} ($inviteCode)',
            buttonColor: GamerTheme.accentBlue,
            textColor: Colors.white,
            onTap: () {
              AppShareService.shareInviteCode(inviteCode: inviteCode);
            },
          ),
          const SizedBox(height: 24),
          Text(
            _trSafe('store_reward_history_title', 'Reward History'),
            style: const TextStyle(
              color: GamerTheme.accentBlue,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _buildTransactionsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTeamStatusCard() {
    if (_isLoadingTeams) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ThemeService.border),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: GamerTheme.neonGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Checking Active Team Membership...',
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isSolo = _userTeams.isEmpty;
    final activeTeam = isSolo ? null : _userTeams.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSolo
            ? GamerTheme.accentOrange.withOpacity(0.1)
            : GamerTheme.neonGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSolo
              ? GamerTheme.accentOrange.withOpacity(0.45)
              : GamerTheme.neonGreen.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSolo ? Icons.info_outline_rounded : Icons.groups_rounded,
                color: isSolo ? GamerTheme.accentOrange : GamerTheme.neonGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSolo
                      ? 'Solo User Notice • Team Required for Redemptions'
                      : 'Active 4-Member Team: ${activeTeam!.name} (${activeTeam.game})',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isSolo
                ? 'Coins you earn from ads or daily check-in go directly into your Personal Wallet and remain safely stored across weekly resets. Join or create an active 4-member Free Fire or PUBG team to contribute coins and compete for the weekly 1,500 PKR equivalent #1 Team Prize.'
                : 'Coins you earn here go into your Personal Wallet first. Open your G-Coins Wallet to choose how many personal coins to contribute to ${activeTeam!.name} (${activeTeam.game} • ${activeTeam.memberCount}/${TeamModel.maxMembers} members) for the weekly 1,500 PKR equivalent #1 Team Prize.',
            style: TextStyle(
              color: ThemeService.textSecondary,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          if (isSolo) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: GamerTheme.accentOrange,
                  side: const BorderSide(color: GamerTheme.accentOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeamsScreen()),
                  ).then((_) => _initStoreData());
                },
                icon: const Icon(Icons.group_add_rounded, size: 15),
                label: const Text(
                  'Join or Create a Team',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionsSection() {
    if (_isLoadingTransactions && _transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeService.border),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: GamerTheme.neonGreen,
            ),
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeService.border),
        ),
        child: Center(
          child: Text(
            _trSafe('no_store_transactions', 'No reward transactions yet.'),
            style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    final displayList = _transactions.take(20).toList();
    return Column(
      children: displayList.map((tx) {
        final isPositive = tx.amount > 0;
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM, hh:mm a').format(tx.timestamp),
                      style: TextStyle(
                        color: ThemeService.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
      }).toList(),
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
              Expanded(
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
                      child: Text(
                        title,
                        style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onTap,
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
