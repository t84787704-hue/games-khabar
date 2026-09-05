import 'package:flutter/material.dart';
import '../services/streak_service.dart';
import '../services/theme_service.dart';
import '../services/coin_reward_service.dart';
import '../screens/earn_screen.dart';

class StreakBannerWidget extends StatelessWidget {
  const StreakBannerWidget({super.key});

  Color get cardDark => ThemeService.card;
  Color get borderDark => ThemeService.border;
  Color get neonGreen => ThemeService.primaryGreen;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;

  void _showStreakModal(BuildContext context, StreakData data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D121B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: neonGreen.withOpacity(0.4), width: 1.2),
        ),
        title: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              '${data.dailyStreak} Day Streak!',
              style: TextStyle(color: textWhite, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: neonGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: neonGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${data.daysUntilGiveaway} more days to enter the Rs. 5,000 Steam / PSN Gift Card Giveaway!',
                      style: TextStyle(color: textWhite, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'How to keep your streak:',
              style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '• Read at least 3 gaming news articles every day.\n'
              '• Every 3 articles completed = +50 Coins.\n'
              '• Complete 5 days in a row for automated VIP Giveaway entry!',
              style: TextStyle(color: textGray, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161E2C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Coin Balance:', style: TextStyle(color: textGray, fontSize: 12)),
                  ValueListenableBuilder<int>(
                    valueListenable: CoinRewardService().coinsNotifier,
                    builder: (context, coins, _) {
                      return Row(
                        children: [
                          const Text('🪙 ', style: TextStyle(fontSize: 14)),
                          Text(
                            '$coins Coins',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: neonGreen,
              foregroundColor: const Color(0xFF05080D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Samajh Gaya!', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StreakData>(
      valueListenable: StreakService.streakNotifier,
      builder: (context, data, _) {
        final readCount = data.articlesReadToday.clamp(0, 3);
        final isCompleted = data.taskCompletedToday;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: InkWell(
            onTap: () => _showStreakModal(context, data),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF131D17),
                    cardDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCompleted ? neonGreen : neonGreen.withOpacity(0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: neonGreen.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Streak title & Coins
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.withOpacity(0.4)),
                        ),
                        child: const Text(
                          '🔥 STREAK',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🔥 ${data.dailyStreak} Day Streak - ${data.daysUntilGiveaway} more for Giveaway!',
                          style: TextStyle(
                            color: textWhite,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Coins badge (opens EarnScreen)
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EarnScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: ValueListenableBuilder<int>(
                            valueListenable: CoinRewardService().coinsNotifier,
                            builder: (context, coins, _) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🪙', style: TextStyle(fontSize: 11)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$coins',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Daily task row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isCompleted
                              ? '🎉 Daily task done! Streak alive for today (+50 Coins)'
                              : 'Daily task: Read 3 articles to keep streak alive ($readCount/3)',
                          style: TextStyle(
                            color: isCompleted ? neonGreen : textGray,
                            fontSize: 11,
                            fontWeight: isCompleted ? FontWeight.bold : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 3 Mini Task Dots
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTaskDot(1 <= readCount),
                          const SizedBox(width: 4),
                          _buildTaskDot(2 <= readCount),
                          const SizedBox(width: 4),
                          _buildTaskDot(3 <= readCount),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskDot(bool isDone) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: isDone ? neonGreen : const Color(0xFF0D141F),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDone ? neonGreen : borderDark,
          width: 1.2,
        ),
      ),
      child: isDone
          ? const Icon(Icons.check_rounded, size: 10, color: Color(0xFF05080D))
          : null,
    );
  }
}
