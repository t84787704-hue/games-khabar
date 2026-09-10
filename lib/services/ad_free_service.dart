import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdFreeService {
  static final AdFreeService _instance = AdFreeService._internal();
  factory AdFreeService() => _instance;
  AdFreeService._internal();

  static const String prefsKey = 'ad_free_until';
  // Google Mobile Ads Test Rewarded Ad Unit ID
  static const String rewardedTestAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // ValueNotifiers for reactive UI updates
  static final ValueNotifier<DateTime?> adFreeUntilNotifier = ValueNotifier<DateTime?>(null);
  static final ValueNotifier<String> remainingTimeNotifier = ValueNotifier<String>('');
  static final ValueNotifier<bool> isLoadingAdNotifier = ValueNotifier<bool>(false);

  Timer? _tickerTimer;
  bool _isInitialized = false;

  /// Initialize AdFreeService by reading stored timestamp from SharedPreferences
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(prefsKey);
      if (timestamp != null) {
        final savedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().isBefore(savedDate)) {
          adFreeUntilNotifier.value = savedDate;
          _updateRemainingTime();
          _startTicker();
        } else {
          // Expired already
          await prefs.remove(prefsKey);
          adFreeUntilNotifier.value = null;
          remainingTimeNotifier.value = '';
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('AdFreeService init error: $e');
    }
  }

  /// Check whether user currently has active ad-free status
  bool get isAdFree {
    final until = adFreeUntilNotifier.value;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  /// Get remaining time string formatted (e.g., "42m left" or "59m left" or "45s left")
  String get remainingFormatted {
    final until = adFreeUntilNotifier.value;
    if (until == null) return '';
    final diff = until.difference(DateTime.now());
    if (diff.isNegative) return '';

    if (diff.inHours > 0) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      return '${hours}h ${minutes}m left';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m left';
    } else {
      return '${diff.inSeconds}s left';
    }
  }

  void _updateRemainingTime() {
    if (!isAdFree) {
      remainingTimeNotifier.value = '';
      if (adFreeUntilNotifier.value != null) {
        adFreeUntilNotifier.value = null;
      }
      _tickerTimer?.cancel();
      _tickerTimer = null;
    } else {
      remainingTimeNotifier.value = remainingFormatted;
    }
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isAdFree) {
        _updateRemainingTime();
      } else {
        _updateRemainingTime();
        timer.cancel();
      }
    });
  }

  /// Set ad-free duration (e.g. 1 hour) and save to SharedPreferences
  Future<void> activateAdFree({Duration duration = const Duration(hours: 1)}) async {
    final until = DateTime.now().add(duration);
    adFreeUntilNotifier.value = until;
    _updateRemainingTime();
    _startTicker();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefsKey, until.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving ad-free timestamp: $e');
    }
  }

  /// Load and display rewarded ad on user button tap
  /// Does NOT auto-load on app start, only loads when requested by user.
  Future<void> showRewardedAd(BuildContext context) async {
    if (isLoadingAdNotifier.value) return;

    isLoadingAdNotifier.value = true;

    // Show small loading feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF1E1F28),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading Rewarded Ad...',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    RewardedAd.load(
      adUnitId: rewardedTestAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          isLoadingAdNotifier.value = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (RewardedAd ad) {
              debugPrint('Rewarded ad showed full screen.');
            },
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              debugPrint('Rewarded ad dismissed.');
              ad.dispose();
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              debugPrint('Rewarded ad failed to show: $error');
              ad.dispose();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E1F28),
                    content: Text(
                      'Failed to display ad: ${error.message}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              }
            },
          );

          ad.show(
            onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
              debugPrint('User earned reward: ${reward.amount} ${reward.type}');
              // 1 hour ad-free activation
              await activateAdFree(duration: const Duration(hours: 1));

              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E1F28),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
                    ),
                    duration: const Duration(seconds: 4),
                    content: const Row(
                      children: [
                        Icon(Icons.bolt, color: Color(0xFF00FF88), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '1 Ghante tak Ad-Free active!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          isLoadingAdNotifier.value = false;
          debugPrint('Rewarded ad failed to load: $error');
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF1E1F28),
                content: Text(
                  'Ad could not be loaded: ${error.message}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  /// Show Rewarded Ad specifically required for an action (e.g., joining tournament, claiming coins)
  /// Triggers onUserEarnedReward callback once watched
  Future<void> showRewardedAdForAction({
    required BuildContext context,
    required String actionTitle,
    required VoidCallback onRewardEarned,
  }) async {
    RewardedAd.load(
      adUnitId: rewardedTestAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _showFallbackAdDialog(context, actionTitle, onRewardEarned);
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              onRewardEarned();
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('RewardedAd load failed ($err), using sponsored ad dialog fallback');
          _showFallbackAdDialog(context, actionTitle, onRewardEarned);
        },
      ),
    );
  }

  void _showFallbackAdDialog(BuildContext context, String actionTitle, VoidCallback onRewardEarned) {
    if (!context.mounted) return;
    int remaining = 5;
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (remaining > 1) {
              setState(() => remaining--);
            } else {
              t.cancel();
              Navigator.pop(ctx);
              onRewardEarned();
            }
          });

          return AlertDialog(
            backgroundColor: const Color(0xFF0F1523),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
            ),
            title: Row(
              children: [
                const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF00FF88), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    actionTitle.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: Text('${remaining}s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF162032),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tv_rounded, color: Color(0xFF00FF88), size: 36),
                        SizedBox(height: 8),
                        Text(
                          'Sponsored Tournament Video Ad',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Verifying free entry reward...',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (5 - remaining) / 5.0,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFF00FF88),
                  minHeight: 5,
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) => timer?.cancel());
  }
}
