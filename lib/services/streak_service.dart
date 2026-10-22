import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'coin_wallet_service.dart';

class StreakData {
  final int dailyStreak;
  final String lastOpenedDate;
  final int coins;
  final int articlesReadToday;
  final List<String> readArticleIdsToday;
  final bool taskCompletedToday;

  const StreakData({
    required this.dailyStreak,
    required this.lastOpenedDate,
    required this.coins,
    required this.articlesReadToday,
    required this.readArticleIdsToday,
    required this.taskCompletedToday,
  });

  int get daysUntilGiveaway {
    final rem = 5 - (dailyStreak % 5);
    return rem == 0 ? 5 : rem;
  }

  StreakData copyWith({
    int? dailyStreak,
    String? lastOpenedDate,
    int? coins,
    int? articlesReadToday,
    List<String>? readArticleIdsToday,
    bool? taskCompletedToday,
  }) {
    return StreakData(
      dailyStreak: dailyStreak ?? this.dailyStreak,
      lastOpenedDate: lastOpenedDate ?? this.lastOpenedDate,
      coins: coins ?? this.coins,
      articlesReadToday: articlesReadToday ?? this.articlesReadToday,
      readArticleIdsToday: readArticleIdsToday ?? this.readArticleIdsToday,
      taskCompletedToday: taskCompletedToday ?? this.taskCompletedToday,
    );
  }
}

class StreakRewardResult {
  final bool isClaimedToday;
  final int streakDays;
  final int coinsEarned;
  final bool isStreakReset;

  StreakRewardResult({
    required this.isClaimedToday,
    required this.streakDays,
    required this.coinsEarned,
    required this.isStreakReset,
  });
}

class StreakService {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  SupabaseClient get _supabase => SupabaseService.client;

  static const String _keyStreak = 'dailyStreak';
  static const String _keyLastOpened = 'lastOpenedDate';
  static const String _keyCoins = 'coins';
  static const String _keyArticlesRead = 'articlesReadToday';
  static const String _keyReadDate = 'lastReadDate';
  static const String _keyReadIds = 'readArticleIdsToday';
  static const String _keyTaskCompleted = 'taskCompletedToday';

  static final ValueNotifier<StreakData> streakNotifier = ValueNotifier<StreakData>(
    const StreakData(
      dailyStreak: 1,
      lastOpenedDate: '',
      coins: 0,
      articlesReadToday: 0,
      readArticleIdsToday: [],
      taskCompletedToday: false,
    ),
  );

  static final ValueNotifier<bool> celebrationNotifier = ValueNotifier<bool>(false);

  // Day 1 se Day 7 tak ka coin reward table
  static const Map<int, int> streakCoinTable = {
    1: 10,
    2: 20,
    3: 35,
    4: 50,
    5: 75,
    6: 100,
    7: 200,
  };

  String _formatToday() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  /// App start hote hi Supabase se verify aur claim karega
  Future<StreakRewardResult?> checkAndClaimDailyStreak() async {
    final user = _supabase.auth.currentUser;
    final todayStr = _formatToday();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Local daily task tracking
      final lastReadDate = prefs.getString(_keyReadDate) ?? '';
      int articlesRead = 0;
      List<String> readIds = [];
      bool taskCompleted = false;

      if (lastReadDate == todayStr) {
        articlesRead = prefs.getInt(_keyArticlesRead) ?? 0;
        readIds = prefs.getStringList(_keyReadIds) ?? [];
        taskCompleted = prefs.getBool(_keyTaskCompleted) ?? (articlesRead >= 3);
      } else {
        await prefs.setInt(_keyArticlesRead, 0);
        await prefs.setStringList(_keyReadIds, []);
        await prefs.setBool(_keyTaskCompleted, false);
        await prefs.setString(_keyReadDate, todayStr);
      }

      if (user == null) {
        streakNotifier.value = StreakData(
          dailyStreak: 1,
          lastOpenedDate: todayStr,
          coins: 0,
          articlesReadToday: articlesRead,
          readArticleIdsToday: readIds,
          taskCompletedToday: taskCompleted,
        );
        return null;
      }

      final String userId = user.id;

      final data = await _supabase
          .from('users')
          .select('current_streak, last_login_date, coins')
          .or('id.eq.$userId,uid.eq.$userId')
          .maybeSingle();

      int streak = (data?['current_streak'] as int?) ?? 0;
      int dbCoins = (data?['coins'] as int?) ?? 0;
      final String? lastDateStr = data?['last_login_date']?.toString();

      // Agar aaj ka reward pehle hi claim ho chuka hai
      if (lastDateStr == todayStr) {
        streakNotifier.value = StreakData(
          dailyStreak: streak > 0 ? streak : 1,
          lastOpenedDate: todayStr,
          coins: dbCoins,
          articlesReadToday: articlesRead,
          readArticleIdsToday: readIds,
          taskCompletedToday: taskCompleted,
        );
        return StreakRewardResult(
          isClaimedToday: true,
          streakDays: streak,
          coinsEarned: 0,
          isStreakReset: false,
        );
      }

      bool streakBroken = false;

      if (lastDateStr != null && lastDateStr.isNotEmpty) {
        final lastDate = DateTime.tryParse(lastDateStr);
        if (lastDate != null) {
          final now = DateTime.now();
          final differenceInDays = DateTime(now.year, now.month, now.day)
              .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
              .inDays;

          if (differenceInDays == 1) {
            streak = (streak >= 7) ? 1 : streak + 1;
          } else if (differenceInDays > 1) {
            streak = 1;
            streakBroken = true;
          }
        }
      } else {
        streak = 1;
      }

      final int rewardCoins = streakCoinTable[streak] ?? 10;

      // Supabase update
      await _supabase.from('users').update({
        'current_streak': streak,
        'last_login_date': todayStr,
      }).or('id.eq.$userId,uid.eq.$userId');

      // Coins award
      await CoinWalletService.updateCoins(
        userId: userId,
        amount: rewardCoins,
        type: 'daily_streak',
        title: 'Day $streak Login Streak',
        description: 'Daily login bonus earned!',
      );

      // Local storage sync
      await prefs.setString(_keyLastOpened, todayStr);
      await prefs.setInt(_keyStreak, streak);
      await prefs.setInt(_keyCoins, dbCoins + rewardCoins);

      streakNotifier.value = StreakData(
        dailyStreak: streak,
        lastOpenedDate: todayStr,
        coins: dbCoins + rewardCoins,
        articlesReadToday: articlesRead,
        readArticleIdsToday: readIds,
        taskCompletedToday: taskCompleted,
      );

      return StreakRewardResult(
        isClaimedToday: false,
        streakDays: streak,
        coinsEarned: rewardCoins,
        isStreakReset: streakBroken,
      );
    } catch (e) {
      debugPrint('[StreakService] Error processing daily streak: $e');
      return null;
    }
  }

  Future<void> init() async {
    await checkAndClaimDailyStreak();
  }

  Future<bool> recordArticleRead(String articleId) async {
    try {
      final current = streakNotifier.value;
      if (current.readArticleIdsToday.contains(articleId)) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final todayStr = _formatToday();

      final updatedIds = List<String>.from(current.readArticleIdsToday)..add(articleId);
      final newReadCount = updatedIds.length;

      bool taskJustCompleted = false;
      int newStreak = current.dailyStreak;
      int newCoins = current.coins;
      bool taskCompleted = current.taskCompletedToday;

      if (newReadCount >= 3 && !current.taskCompletedToday) {
        taskCompleted = true;
        taskJustCompleted = true;
        newCoins += 50;

        final user = _supabase.auth.currentUser;
        if (user != null) {
          await CoinWalletService.updateCoins(
            userId: user.id,
            amount: 50,
            type: 'article_read_bonus',
            title: 'Daily Reader Bonus',
            description: 'Read 3 articles today',
          );
        }

        await prefs.setInt(_keyCoins, newCoins);
        await prefs.setBool(_keyTaskCompleted, true);
      }

      await prefs.setInt(_keyArticlesRead, newReadCount);
      await prefs.setStringList(_keyReadIds, updatedIds);
      await prefs.setString(_keyReadDate, todayStr);

      streakNotifier.value = current.copyWith(
        dailyStreak: newStreak,
        coins: newCoins,
        articlesReadToday: newReadCount,
        readArticleIdsToday: updatedIds,
        taskCompletedToday: taskCompleted,
      );

      if (taskJustCompleted) {
        celebrationNotifier.value = true;
        Future.delayed(const Duration(milliseconds: 1500), () {
          celebrationNotifier.value = false;
        });
      }

      return taskJustCompleted;
    } catch (e) {
      debugPrint('[StreakService] recordArticleRead error: $e');
      return false;
    }
  }
}
