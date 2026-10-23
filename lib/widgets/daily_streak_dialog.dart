import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../services/streak_service.dart';

class DailyStreakDialog extends StatelessWidget {
  final StreakRewardResult result;

  const DailyStreakDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: GamerTheme.bgDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: GamerTheme.accentOrange.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: GamerTheme.accentOrange.withOpacity(0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 64,
              color: GamerTheme.accentOrange,
            ),
            const SizedBox(height: 12),
            Text(
              result.isStreakReset ? 'Streak Reset! ⚠️' : 'Daily Streak Claimed! 🔥',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result.isStreakReset
                  ? 'Aapne kal login miss kiya tha. Day 1 se shuruat karein!'
                  : 'Aap lagaataar ${result.streakDays} din se active hain!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: GamerTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // 7 Days Visual Box Tracker (Showing Coins per Day)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final dayNumber = index + 1;
                final bool isCompleted = dayNumber <= result.streakDays;
                final bool isCurrent = dayNumber == result.streakDays;
                final int dayCoins = 50 + (index * 10); // Day 1 = 50, Day 2 = 60, Day 3 = 70 ... Day 7 = 110

                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 58,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? GamerTheme.accentOrange
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: isCurrent
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCompleted
                                ? Icons.check_rounded
                                : Icons.lock_outline_rounded,
                            size: 16,
                            color: isCompleted ? Colors.black : Colors.white54,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+$dayCoins',
                            style: TextStyle(
                              color: isCompleted ? Colors.black87 : Colors.amber,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'D$dayNumber',
                      style: TextStyle(
                        color: isCurrent ? GamerTheme.accentOrange : Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }),
            ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: GamerTheme.accentOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: Colors.amber,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${result.coinsEarned} G-Coins Added!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GamerTheme.accentOrange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Collect & Continue',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
