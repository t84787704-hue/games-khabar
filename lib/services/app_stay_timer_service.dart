// ===============================================================================
// File: lib/services/app_stay_timer_service.dart
// 10-Min Active Stay Tracker — Global & Unstoppable
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AppStayTimerService with WidgetsBindingObserver {
  static final AppStayTimerService _instance = AppStayTimerService._internal();
  factory AppStayTimerService() => _instance;
  AppStayTimerService._internal();

  Timer? _timer;
  int secondsPassed = 0;
  final int targetSeconds = 600; // 10 Minutes = 600 Seconds
  bool isRewardClaimedToday = false;
  bool isRunning = true;
  bool _isInitialized = false;

  final ValueNotifier<int> secondsNotifier = ValueNotifier<int>(0);

  void init(BuildContext context) async {
    if (_isInitialized) return;
    _isInitialized = true;

    WidgetsBinding.instance.addObserver(this);
    await _checkTodayStatus();

    if (!isRewardClaimedToday && (_timer == null || !_timer!.isActive)) {
      startTimer(context);
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _isInitialized = false;
  }

  // App Minimize / Resume hone par check
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      isRunning = true;
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      isRunning = false;
    }
  }

  Future<void> _checkTodayStatus() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    try {
      final res = await SupabaseService.client
          .from('users')
          .select('last_stay_bonus_date')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null && res['last_stay_bonus_date'] != null) {
        final lastDate = DateTime.tryParse(res['last_stay_bonus_date'].toString());
        final now = DateTime.now();
        if (lastDate != null &&
            lastDate.year == now.year &&
            lastDate.month == now.month &&
            lastDate.day == now.day) {
          isRewardClaimedToday = true;
        }
      }
    } catch (_) {}
  }

  void startTimer(BuildContext context) {
    if (isRewardClaimedToday) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isRunning || isRewardClaimedToday) return;

      secondsPassed++;
      secondsNotifier.value = secondsPassed;

      // 10 Minute complete!
      if (secondsPassed >= targetSeconds) {
        _timer?.cancel();
        _claimReward(context);
      }
    });
  }

  Future<void> _claimReward(BuildContext context) async {
    isRewardClaimedToday = true;
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Current coins fetch karein
      final userDoc = await SupabaseService.client
          .from('users')
          .select('coins')
          .eq('id', user.id)
          .maybeSingle();

      final int existing = (userDoc?['coins'] as num?)?.toInt() ?? 0;

      // 2. +50 Coins update karein aur date save karein
      await SupabaseService.client.from('users').update({
        'coins': existing + 50,
        'last_stay_bonus_date': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      // 3. Screen par Celebration Banner Dikhayein (2 seconds mein auto-hide)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00FF88),
            behavior: SnackBarBehavior.floating,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 2),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.monetization_on_rounded, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '10 Minutes Completed! 🎉',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '+50 Coins added to your wallet!',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[StayReward Error]: $e');
    }
  }
}
