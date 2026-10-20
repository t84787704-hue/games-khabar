import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'gamer_auth_service.dart';
import 'coin_wallet_service.dart';
import 'package:easy_localization/easy_localization.dart';

class CoinRewardService {
  static final CoinRewardService _instance = CoinRewardService._internal();
  factory CoinRewardService() => _instance;
  CoinRewardService._internal();

  static const String _testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _prefsUserIdKey = 'coin_system_user_id';

  // Reactive notifiers for UI
  final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> adImpressionsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> todayNewsCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> todayPostCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isDailyLoginClaimedNotifier = ValueNotifier<bool>(false);

  String _userId = '';
  String get userId => _userId;

  // Interstitial Ad Management
  InterstitialAd? _interstitialAd;
  bool _isLoadingAd = false;
  DateTime? _lastAdDismissedLocalTime;
  int _newsReadSinceLastAd = 0;

  // Hidden local revenue accumulator (4 Rs per ad - NEVER shown to user)
  double _hiddenRevenueRs = 0.0;
  double get hiddenRevenueRs => _hiddenRevenueRs;

  bool _isInitialized = false;
  StreamSubscription<List<Map<String, dynamic>>>? _userSub;

  /// Timezone helper for Asia/Karachi (UTC+5, Pakistan Standard Time)
  static String todayPakistanDate() {
    final pkTime = DateTime.now().toUtc().add(const Duration(hours: 5));
    return "${pkTime.year.toString().padLeft(4, '0')}-${pkTime.month.toString().padLeft(2, '0')}-${pkTime.day.toString().padLeft(2, '0')}";
  }

  /// Initialize CoinRewardService, sync user doc, preload ad & start 60s timer
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Determine or create User ID
      final currentUid = GamerAuthService().currentUid ?? SupabaseService.client.auth.currentUser?.id;
      if (currentUid != null && currentUid.isNotEmpty) {
        _userId = currentUid;
      } else {
        _userId = prefs.getString(_prefsUserIdKey) ?? '';
        if (_userId.isEmpty) {
          _userId = 'gk_user_${DateTime.now().millisecondsSinceEpoch}';
          await prefs.setString(_prefsUserIdKey, _userId);
        }
      }

      // Initialize document if not exists
      await _ensureUserDocExists();

      // Listen to real-time user document changes
      _listenToUserDoc();

      // Preload the first Interstitial Ad
      _loadInterstitialAd();

      // Natural Trigger (c): On app start after 60 seconds
      Timer(const Duration(seconds: 60), () {
        debugPrint('[CoinRewardService] 60s app start timer triggered');
        _maybeShowInterstitial(reason: 'app_start_60s');
      });
    } catch (e) {
      debugPrint('[CoinRewardService] Init error: $e');
    }
  }

  /// Ensure users/{uid} document exists with all required fields
  Future<void> _ensureUserDocExists() async {
    if (_userId.isEmpty) return;
    final today = todayPakistanDate();
    try {
      final res = await SupabaseService.client
          .from('users')
          .select()
          .or('id.eq.$_userId,uid.eq.$_userId')
          .maybeSingle();

      if (res == null) {
        await SupabaseService.client.from('users').upsert({
          'id': _userId,
          'uid': _userId,
          'coins': 1000,
          'g_coins': 1000,
          'adImpressions': 0,
          'lastAdTime': DateTime.now().toIso8601String(),
          'todayNewsCount': 0,
          'todayPostCount': 0,
          'lastEarnDate': today,
          'dailyLoginDate': '',
          'totalAdsToday': 0,
          'totalAdsYesterday': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        if (res['coins'] == null) {
          await SupabaseService.client
              .from('users')
              .update({'coins': 1000, 'g_coins': 1000})
              .or('id.eq.$_userId,uid.eq.$_userId');
        }
        final lastEarn = res['lastEarnDate'] as String? ?? '';
        if (lastEarn != today) {
          final totalToday = (res['totalAdsToday'] as num?)?.toInt() ?? 0;
          await SupabaseService.client.from('users').update({
            'todayNewsCount': 0,
            'todayPostCount': 0,
            'totalAdsYesterday': totalToday,
            'totalAdsToday': 0,
            'lastEarnDate': today,
          }).or('id.eq.$_userId,uid.eq.$_userId');
        }
      }
    } catch (e) {
      debugPrint('[CoinRewardService] _ensureUserDocExists error: $e');
    }
  }

  /// Real-time listener for current user's document
  void _listenToUserDoc() {
    if (_userId.isEmpty) return;
    _userSub?.cancel();
    _userSub = SupabaseService.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', _userId)
        .listen((list) {
      if (list.isNotEmpty) {
        final data = list.first;
        final c = (data['coins'] as num?)?.toInt() ?? (data['g_coins'] as num?)?.toInt() ?? 0;
        final ads = (data['adImpressions'] as num?)?.toInt() ?? 0;
        final news = (data['todayNewsCount'] as num?)?.toInt() ?? 0;
        final posts = (data['todayPostCount'] as num?)?.toInt() ?? 0;
        final loginDate = data['dailyLoginDate'] as String? ?? '';

        coinsNotifier.value = c;
        adImpressionsNotifier.value = ads;
        todayNewsCountNotifier.value = news;
        todayPostCountNotifier.value = posts;
        isDailyLoginClaimedNotifier.value = (loginDate == todayPakistanDate());
      }
    }, onError: (err) {
      debugPrint('[CoinRewardService] Listener error: $err');
    });
  }

  /// Hidden cooldown check: Don't show next interstitial if less than 2 minutes (120s)
  bool _isCooldownActive() {
    if (_lastAdDismissedLocalTime == null) return false;
    final diff = DateTime.now().difference(_lastAdDismissedLocalTime!);
    return diff.inSeconds < 120;
  }

  /// Preload InterstitialAd
  void _loadInterstitialAd() {
    if (_isLoadingAd || _interstitialAd != null) return;
    _isLoadingAd = true;

    InterstitialAd.load(
      adUnitId: _testInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingAd = false;
          _interstitialAd = ad;
          debugPrint('[CoinRewardService] Interstitial ad loaded successfully');
        },
        onAdFailedToLoad: (err) {
          _isLoadingAd = false;
          _interstitialAd = null;
          debugPrint('[CoinRewardService] Interstitial failed to load: $err');
          // Retry loading after 30 seconds
          Future.delayed(const Duration(seconds: 30), () {
            if (_interstitialAd == null) _loadInterstitialAd();
          });
        },
      ),
    );
  }

  /// Show Interstitial if cooldown has passed and ad is ready.
  /// Returns a Future<bool> indicating whether an ad was actually displayed and dismissed.
  Future<bool> _maybeShowInterstitial({required String reason}) async {
    if (_isCooldownActive()) {
      debugPrint('[CoinRewardService] Interstitial skipped ($reason): 2-minute cooldown active');
      return false;
    }

    if (_interstitialAd == null) {
      _loadInterstitialAd();
      debugPrint('[CoinRewardService] Interstitial skipped ($reason): Ad not loaded yet');
      return false;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null; // Consume loaded ad reference

    final Completer<bool> completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('[CoinRewardService] Interstitial showed ($reason)');
      },
      onAdDismissedFullScreenContent: (ad) async {
        debugPrint('[CoinRewardService] Interstitial dismissed ($reason)');
        ad.dispose();
        _lastAdDismissedLocalTime = DateTime.now();
        _newsReadSinceLastAd = 0;
        _hiddenRevenueRs += 4.0; // 4 Rs hidden revenue per ad

        // Update Supabase: increment adImpressions & totalAdsToday, update lastAdTime
        if (_userId.isNotEmpty) {
          try {
            final res = await SupabaseService.client
                .from('users')
                .select('adImpressions,totalAdsToday')
                .or('id.eq.$_userId,uid.eq.$_userId')
                .maybeSingle();
            final currentAds = (res?['adImpressions'] as num?)?.toInt() ?? 0;
            final currentTodayAds = (res?['totalAdsToday'] as num?)?.toInt() ?? 0;
            await SupabaseService.client.from('users').update({
              'adImpressions': currentAds + 1,
              'totalAdsToday': currentTodayAds + 1,
              'lastAdTime': DateTime.now().toIso8601String(),
            }).or('id.eq.$_userId,uid.eq.$_userId');
          } catch (e) {
            debugPrint('[CoinRewardService] Error incrementing adImpressions: $e');
          }
        }

        // Preload next ad immediately
        _loadInterstitialAd();

        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('[CoinRewardService] Interstitial failed to show ($reason): $err');
        ad.dispose();
        _loadInterstitialAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      await ad.show();
      return await completer.future;
    } catch (e) {
      debugPrint('[CoinRewardService] Exception showing interstitial: $e');
      if (!completer.isCompleted) completer.complete(false);
      return false;
    }
  }

  /// Hook called whenever user reads a news article
  Future<void> onNewsRead(BuildContext? context) async {
    _newsReadSinceLastAd += 1;
    if (_newsReadSinceLastAd >= 2) {
      await _maybeShowInterstitial(reason: 'read_2_news');
    }

    await tryGiveCoins(
      context: context,
      activityName: 'News Read',
      coinsToShow: 10,
    );
  }

  /// Hook called whenever user creates a community post
  Future<void> onPostCreated(BuildContext? context, int textLength) async {
    await _maybeShowInterstitial(reason: 'post_created');

    if (textLength > 20) {
      await tryGiveCoins(
        context: context,
        activityName: 'Post Created',
        coinsToShow: 20,
      );
    }
  }

  /// Hook called for Daily Login
  Future<void> checkDailyLogin(BuildContext? context) async {
    if (isDailyLoginClaimedNotifier.value) return;

    await tryGiveCoins(
      context: context,
      activityName: 'Daily Login',
      coinsToShow: 20,
    );
  }

  /// STEP 2 - GIVE COINS FOR APP USE (And consume adImpressions):
  Future<bool> tryGiveCoins({
    BuildContext? context,
    required String activityName,
    required int coinsToShow,
  }) async {
    if (_userId.isEmpty) {
      await init();
      if (_userId.isEmpty) return false;
    }

    final today = todayPakistanDate();
    try {
      final currentDoc = await SupabaseService.client
          .from('users')
          .select()
          .or('id.eq.$_userId,uid.eq.$_userId')
          .maybeSingle();

      if (currentDoc == null) {
        await _ensureUserDocExists();
      }

      int adImpressions = (currentDoc?['adImpressions'] as num?)?.toInt() ?? 0;

      // If adImpressions <= 0, try showing an interstitial ad first naturally
      if (adImpressions <= 0) {
        final showedAd = await _maybeShowInterstitial(reason: 'ad_impression_refill');
        if (showedAd) {
          final refetched = await SupabaseService.client
              .from('users')
              .select('adImpressions')
              .or('id.eq.$_userId,uid.eq.$_userId')
              .maybeSingle();
          adImpressions = (refetched?['adImpressions'] as num?)?.toInt() ?? 0;
        }
      }

      if (adImpressions <= 0) {
        debugPrint('[CoinRewardService] Cannot give coins for $activityName: No adImpressions available');
        return false;
      }

      final data = currentDoc ?? {};
      final lastEarn = data['lastEarnDate'] as String? ?? '';
      int todayNews = (data['todayNewsCount'] as num?)?.toInt() ?? 0;
      int todayPosts = (data['todayPostCount'] as num?)?.toInt() ?? 0;
      int totalAdsToday = (data['totalAdsToday'] as num?)?.toInt() ?? 0;
      int totalAdsYesterday = (data['totalAdsYesterday'] as num?)?.toInt() ?? 0;
      String dailyLogin = data['dailyLoginDate'] as String? ?? '';
      int currentAdImpressions = adImpressions;

      // Rotate daily counts if new day in Pakistan
      if (lastEarn != today) {
        todayNews = 0;
        todayPosts = 0;
        totalAdsYesterday = totalAdsToday;
        totalAdsToday = 0;
      }

      // Check Activity Limits
      if (activityName == 'Daily Login') {
        if (dailyLogin == today) return false;
        dailyLogin = today;
      } else if (activityName == 'News Read') {
        if (todayNews >= 5) return false;
        todayNews += 1;
      } else if (activityName == 'Post Created') {
        if (todayPosts >= 3) return false;
        todayPosts += 1;
      }

      if (currentAdImpressions <= 0) return false;

      final newImpressions = currentAdImpressions - 1;
      final nowStr = DateTime.now().toIso8601String();

      // Update counters in users table
      await SupabaseService.client.from('users').update({
        'adImpressions': newImpressions,
        'todayNewsCount': todayNews,
        'todayPostCount': todayPosts,
        'dailyLoginDate': dailyLogin,
        'totalAdsToday': totalAdsToday,
        'totalAdsYesterday': totalAdsYesterday,
        'lastEarnDate': today,
        'lastEarnTime': nowStr,
      }).or('id.eq.$_userId,uid.eq.$_userId');

      // Use unified CoinWalletService.updateCoins to keep users, coin_wallets and transactions perfectly in sync
      final txType = activityName == 'Daily Login'
          ? 'daily_bonus'
          : (activityName == 'News Read' ? 'news_read' : 'post_created');

      await CoinWalletService.updateCoins(
        userId: _userId,
        amount: coinsToShow,
        type: txType,
        title: 'coins_reward_title_format'.tr(args: ['$coinsToShow', activityName]),
        description: 'coins_reward_desc_format'.tr(args: [activityName]),
      );

      debugPrint('[CoinRewardService] Successfully awarded +$coinsToShow coins for $activityName');
      if (context != null && context.mounted) {
        _showCoinRewardToast(context, activityName, coinsToShow);
      }
      return true;
    } catch (e) {
      debugPrint('[CoinRewardService] Reward activity error: $e');
    }

    return false;
  }

  /// Helpful Received: 5 coins when other user clicks Helpful on your post
  Future<bool> rewardHelpfulReceived({
    required String postAuthorId,
    required String postId,
  }) async {
    if (postAuthorId.isEmpty || postAuthorId == _userId) return false;

    try {
      await CoinWalletService.updateCoins(
        userId: postAuthorId,
        amount: 5,
        type: 'helpful_received',
        title: 'helpful_upvote_title'.tr(),
        description: 'helpful_upvote_desc'.tr(),
      );

      final postData = await SupabaseService.client
          .from('community_posts')
          .select('helpfulCount')
          .or('id.eq.$postId')
          .maybeSingle();
      final currentHelpful = (postData?['helpfulCount'] as num?)?.toInt() ?? 0;

      await SupabaseService.client
          .from('community_posts')
          .update({'helpfulCount': currentHelpful + 1})
          .or('id.eq.$postId');

      return true;
    } catch (e) {
      debugPrint('[CoinRewardService] Helpful reward error: $e');
      return false;
    }
  }

  /// Shows ONLY: "+{coinsToShow} Coins for {activityName}! 🪙"
  void _showCoinRewardToast(BuildContext context, String activityName, int coins) {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0D1812),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
          ),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E2D22),
                  shape: BoxShape.circle,
                ),
                child: const Text('🪙', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'coin_reward_toast_format'.tr(args: ['$coins', activityName]),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  void dispose() {
    _userSub?.cancel();
    _interstitialAd?.dispose();
  }
}
