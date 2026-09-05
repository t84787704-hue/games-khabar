import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // 5-day cycle for giveaways
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

class StreakService {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  static const String _keyStreak = 'dailyStreak';
  static const String _keyLastOpened = 'lastOpenedDate';
  static const String _keyCoins = 'coins';
  static const String _keyArticlesRead = 'articlesReadToday';
  static const String _keyReadDate = 'lastReadDate';
  static const String _keyReadIds = 'readArticleIdsToday';
  static const String _keyTaskCompleted = 'taskCompletedToday';

  static final ValueNotifier<StreakData> streakNotifier = ValueNotifier<StreakData>(
    const StreakData(
      dailyStreak: 3,
      lastOpenedDate: '',
      coins: 150,
      articlesReadToday: 1,
      readArticleIdsToday: [],
      taskCompletedToday: false,
    ),
  );

  static final ValueNotifier<bool> celebrationNotifier = ValueNotifier<bool>(false);

  String _formatToday() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _formatToday();

      // Default to 3-day streak and 150 coins to showcase the habit feature
      int streak = prefs.getInt(_keyStreak) ?? 3;
      final lastOpened = prefs.getString(_keyLastOpened) ?? todayStr;
      int coins = prefs.getInt(_keyCoins) ?? 150;
      final lastReadDate = prefs.getString(_keyReadDate) ?? '';

      int articlesRead = 0;
      List<String> readIds = [];
      bool taskCompleted = false;

      // Check if day changed
      if (lastReadDate == todayStr) {
        articlesRead = prefs.getInt(_keyArticlesRead) ?? 0;
        readIds = prefs.getStringList(_keyReadIds) ?? [];
        taskCompleted = prefs.getBool(_keyTaskCompleted) ?? (articlesRead >= 3);
      } else {
        // Reset daily task for new day
        articlesRead = 0;
        readIds = [];
        taskCompleted = false;
        await prefs.setInt(_keyArticlesRead, 0);
        await prefs.setStringList(_keyReadIds, []);
        await prefs.setBool(_keyTaskCompleted, false);
        await prefs.setString(_keyReadDate, todayStr);
      }

      // Check date continuity for streak
      if (lastOpened.isNotEmpty && lastOpened != todayStr) {
        try {
          final lastDate = DateTime.parse(lastOpened);
          final diffDays = DateTime.now().difference(lastDate).inDays;
          if (diffDays > 1) {
            // Missed more than 1 day, reset to 1
            streak = 1;
            await prefs.setInt(_keyStreak, streak);
          }
        } catch (_) {}
      }

      await prefs.setString(_keyLastOpened, todayStr);
      await prefs.setInt(_keyStreak, streak);
      await prefs.setInt(_keyCoins, coins);

      streakNotifier.value = StreakData(
        dailyStreak: streak,
        lastOpenedDate: todayStr,
        coins: coins,
        articlesReadToday: articlesRead,
        readArticleIdsToday: readIds,
        taskCompletedToday: taskCompleted,
      );
    } catch (e) {
      debugPrint('[StreakService] Init error: $e');
    }
  }

  Future<bool> recordArticleRead(String articleId) async {
    try {
      final current = streakNotifier.value;
      if (current.readArticleIdsToday.contains(articleId)) {
        return false; // Already counted this article today
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
        newStreak += 1;
        newCoins += 50; // 50 coins reward
        await prefs.setInt(_keyStreak, newStreak);
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
