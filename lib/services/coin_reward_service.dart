import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

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
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null && authUser.uid.isNotEmpty) {
        _userId = authUser.uid;
      } else {
        // Attempt anonymous login or persistent ID fallback
        try {
          final anonCred = await FirebaseAuth.instance.signInAnonymously();
          _userId = anonCred.user?.uid ?? '';
        } catch (_) {
          _userId = prefs.getString(_prefsUserIdKey) ?? '';
          if (_userId.isEmpty) {
            _userId = 'gk_user_${DateTime.now().millisecondsSinceEpoch}';
            await prefs.setString(_prefsUserIdKey, _userId);
          }
        }
      }

      // Initialize Firestore document if not exists
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
    final userRef = FirebaseFirestore.instance.collection('users').doc(_userId);
    final doc = await userRef.get();
    final today = todayPakistanDate();

    if (!doc.exists) {
      await userRef.set({
        'coins': 0,
        'adImpressions': 0,
        'lastAdTime': FieldValue.serverTimestamp(),
        'todayNewsCount': 0,
        'todayPostCount': 0,
        'lastEarnDate': today,
        'dailyLoginDate': '',
        'totalAdsToday': 0,
        'totalAdsYesterday': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      // Check if lastEarnDate is from a previous day and needs counter rotation
      final data = doc.data() ?? {};
      final lastEarn = data['lastEarnDate'] as String? ?? '';
      if (lastEarn != today) {
        final totalToday = (data['totalAdsToday'] as num?)?.toInt() ?? 0;
        await userRef.update({
          'todayNewsCount': 0,
          'todayPostCount': 0,
          'totalAdsYesterday': totalToday,
          'totalAdsToday': 0,
          'lastEarnDate': today,
        });
      }
    }
  }

  /// Real-time listener for current user's document
  void _listenToUserDoc() {
    if (_userId.isEmpty) return;
    _userSub?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() ?? {};
        final c = (data['coins'] as num?)?.toInt() ?? 0;
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

        // Update Firestore: increment adImpressions & totalAdsToday, update lastAdTime
        if (_userId.isNotEmpty) {
          try {
            await FirebaseFirestore.instance.collection('users').doc(_userId).update({
              'adImpressions': FieldValue.increment(1),
              'totalAdsToday': FieldValue.increment(1),
              'lastAdTime': FieldValue.serverTimestamp(),
            });
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
  /// a) Automatic Interstitial after user reads 2 news
  /// Rewards user: 10 coins per news, max 5 per day
  Future<void> onNewsRead(BuildContext? context) async {
    _newsReadSinceLastAd += 1;
    if (_newsReadSinceLastAd >= 2) {
      await _maybeShowInterstitial(reason: 'read_2_news');
    }

    // Try giving coins for reading news (10 coins, max 5 per day)
    await tryGiveCoins(
      context: context,
      activityName: 'News Read',
      coinsToShow: 10,
    );
  }

  /// Hook called whenever user creates a community post
  /// b) Automatic Interstitial after user creates a post
  /// Rewards user: 20 coins per post (if length > 20 chars), max 3 per day
  Future<void> onPostCreated(BuildContext? context, int textLength) async {
    // Show interstitial automatically
    await _maybeShowInterstitial(reason: 'post_created');

    if (textLength > 20) {
      await tryGiveCoins(
        context: context,
        activityName: 'Post Created',
        coinsToShow: 20,
      );
    }
  }

  /// Hook called for Daily Login (20 coins once per day)
  Future<void> checkDailyLogin(BuildContext? context) async {
    final today = todayPakistanDate();
    if (isDailyLoginClaimedNotifier.value) return;

    await tryGiveCoins(
      context: context,
      activityName: 'Daily Login',
      coinsToShow: 20,
    );
  }

  /// STEP 2 - GIVE COINS FOR APP USE (But consume adImpressions):
  /// - Check Pakistan date. If lastEarnDate != today, reset todayNewsCount, todayPostCount.
  /// - If adImpressions <= 0:
  ///     - Show Interstitial Ad first (if cooldown passed), then adImpressions will become 1.
  ///     - If still 0, return without giving coins.
  /// - If adImpressions > 0:
  ///     - coins += coinsToShow
  ///     - adImpressions -= 1
  ///     - Update today counts
  ///     - Show user ONLY: "+{coinsToShow} Coins for {activityName}! 🪙"
  ///     - Do NOT show anything about Ads, Revenue, or 50%.
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
    final userRef = FirebaseFirestore.instance.collection('users').doc(_userId);

    try {
      // 1. Check current ad impressions in Firestore or local state
      final currentDoc = await userRef.get();
      if (!currentDoc.exists) {
        await _ensureUserDocExists();
      }

      int adImpressions = (currentDoc.data()?['adImpressions'] as num?)?.toInt() ?? 0;

      // If adImpressions <= 0, try showing an interstitial ad first naturally (if cooldown passed)
      if (adImpressions <= 0) {
        final showedAd = await _maybeShowInterstitial(reason: 'ad_impression_refill');
        if (showedAd) {
          // Fetch updated adImpressions
          final refetched = await userRef.get();
          adImpressions = (refetched.data()?['adImpressions'] as num?)?.toInt() ?? 0;
        }
      }

      // If still <= 0, cannot award coins right now
      if (adImpressions <= 0) {
        debugPrint('[CoinRewardService] Cannot give coins for $activityName: No adImpressions available');
        return false;
      }

      // 2. Perform Transaction to update coins & decrement adImpressions
      bool awarded = false;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() ?? {};
        final lastEarn = data['lastEarnDate'] as String? ?? '';
        int todayNews = (data['todayNewsCount'] as num?)?.toInt() ?? 0;
        int todayPosts = (data['todayPostCount'] as num?)?.toInt() ?? 0;
        int totalAdsToday = (data['totalAdsToday'] as num?)?.toInt() ?? 0;
        int totalAdsYesterday = (data['totalAdsYesterday'] as num?)?.toInt() ?? 0;
        String dailyLogin = data['dailyLoginDate'] as String? ?? '';
        int currentCoins = (data['coins'] as num?)?.toInt() ?? 0;
        int currentAdImpressions = (data['adImpressions'] as num?)?.toInt() ?? 0;

        // Rotate daily counts if new day in Pakistan
        if (lastEarn != today) {
          todayNews = 0;
          todayPosts = 0;
          totalAdsYesterday = totalAdsToday;
          totalAdsToday = 0;
        }

        // Check Activity Limits
        if (activityName == 'Daily Login') {
          if (dailyLogin == today) return; // Already claimed today
          dailyLogin = today;
        } else if (activityName == 'News Read') {
          if (todayNews >= 5) return; // Max 5 news per day
          todayNews += 1;
        } else if (activityName == 'Post Created') {
          if (todayPosts >= 3) return; // Max 3 posts per day
          todayPosts += 1;
        }

        if (currentAdImpressions <= 0) return;

        // Award Coins & Consume 1 Impression
        final newCoins = currentCoins + coinsToShow;
        final newImpressions = currentAdImpressions - 1;

        transaction.update(userRef, {
          'coins': newCoins,
          'adImpressions': newImpressions,
          'todayNewsCount': todayNews,
          'todayPostCount': todayPosts,
          'dailyLoginDate': dailyLogin,
          'totalAdsToday': totalAdsToday,
          'totalAdsYesterday': totalAdsYesterday,
          'lastEarnDate': today,
          'lastEarnTime': FieldValue.serverTimestamp(),
        });

        awarded = true;
      });

      if (awarded) {
        debugPrint('[CoinRewardService] Successfully awarded +$coinsToShow coins for $activityName');
        if (context != null && context.mounted) {
          _showCoinRewardToast(context, activityName, coinsToShow);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[CoinRewardService] Transaction error: $e');
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
      final authorRef = FirebaseFirestore.instance.collection('users').doc(postAuthorId);
      final postRef = FirebaseFirestore.instance.collection('community_posts').doc(postId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final authorSnap = await transaction.get(authorRef);
        final postSnap = await transaction.get(postRef);

        if (!authorSnap.exists || !postSnap.exists) return;

        final currentCoins = (authorSnap.data()?['coins'] as num?)?.toInt() ?? 0;
        transaction.update(authorRef, {
          'coins': currentCoins + 5,
        });

        transaction.update(postRef, {
          'helpfulCount': FieldValue.increment(1),
        });
      });

      return true;
    } catch (e) {
      debugPrint('[CoinRewardService] Helpful reward error: $e');
      return false;
    }
  }

  /// Shows ONLY: "+{coinsToShow} Coins for {activityName}! 🪙"
  /// Absolutely NO mention of Ads, Revenue, or 50%
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
                  '+$coins Coins for $activityName! 🪙',
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
