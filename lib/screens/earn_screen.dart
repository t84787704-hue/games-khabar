import 'package:flutter/material.dart';
import '../services/coin_reward_service.dart';
import '../services/theme_service.dart';

class EarnScreen extends StatelessWidget {
  const EarnScreen({super.key});

  Color get bgDark => ThemeService.bg;
  Color get cardDark => ThemeService.card;
  Color get cardDark2 => const Color(0xFF131822);
  Color get borderDark => ThemeService.border;
  Color get neonGreen => ThemeService.primaryGreen;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;
  Color get gold => const Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final coinService = CoinRewardService();

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text('🪙', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Earn GK Coins',
              style: TextStyle(
                color: textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coin Balance Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B2A1E), Color(0xFF101720)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: neonGreen.withOpacity(0.4), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: neonGreen.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'TOTAL COIN BALANCE',
                    style: TextStyle(
                      color: neonGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🪙', style: TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(width: 12),
                      ValueListenableBuilder<int>(
                        valueListenable: coinService.coinsNotifier,
                        builder: (context, coins, _) {
                          return Text(
                            '$coins',
                            style: TextStyle(
                              color: textWhite,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderDark),
                    ),
                    child: Text(
                      'Har roz app istemal karein aur free coins kamayein!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textGray, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section Header: Daily Tasks
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: neonGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily Activities & Rewards',
                  style: TextStyle(
                    color: textWhite,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Niche di gayi activities complete karein aur foran coins paayein.',
              style: TextStyle(color: textGray, fontSize: 12),
            ),

            const SizedBox(height: 14),

            // Task 1: Daily Login (20 Coins)
            ValueListenableBuilder<bool>(
              valueListenable: coinService.isDailyLoginClaimedNotifier,
              builder: (context, isClaimed, _) {
                return _buildTaskCard(
                  context: context,
                  emoji: '📅',
                  title: 'Daily Login',
                  rewardText: '+20 Coins',
                  description: 'Har roz app open karne par 20 coins milte hain.',
                  statusBadge: isClaimed
                      ? _buildBadge('Completed ✓', neonGreen, Colors.black)
                      : InkWell(
                          onTap: () => coinService.checkDailyLogin(context),
                          borderRadius: BorderRadius.circular(8),
                          child: _buildBadge('Claim Now', gold, const Color(0xFF0D121B)),
                        ),
                  progressWidget: null,
                );
              },
            ),

            const SizedBox(height: 12),

            // Task 2: Read News (10 Coins, Max 5 per day)
            ValueListenableBuilder<int>(
              valueListenable: coinService.todayNewsCountNotifier,
              builder: (context, count, _) {
                final double progress = (count / 5).clamp(0.0, 1.0);
                return _buildTaskCard(
                  context: context,
                  emoji: '📰',
                  title: 'Read News',
                  rewardText: '+10 Coins / News',
                  description: 'Gaming news parhein aur mazeed updates jaanien (Max 5 articles).',
                  statusBadge: count >= 5
                      ? _buildBadge('5 / 5 Done ✓', neonGreen, Colors.black)
                      : _buildBadge('$count / 5 Today', const Color(0xFF4A90E2), Colors.white),
                  progressWidget: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: cardDark2,
                      valueColor: AlwaysStoppedAnimation<Color>(count >= 5 ? neonGreen : const Color(0xFF4A90E2)),
                      minHeight: 6,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Task 3: Create Post (20 Coins, Max 3 per day)
            ValueListenableBuilder<int>(
              valueListenable: coinService.todayPostCountNotifier,
              builder: (context, count, _) {
                final double progress = (count / 3).clamp(0.0, 1.0);
                return _buildTaskCard(
                  context: context,
                  emoji: '✍️',
                  title: 'Create Post',
                  rewardText: '+20 Coins / Post',
                  description: 'Community Wall par squad ID ya tip share karein (>20 characters, Max 3 per day).',
                  statusBadge: count >= 3
                      ? _buildBadge('3 / 3 Done ✓', neonGreen, Colors.black)
                      : _buildBadge('$count / 3 Today', const Color(0xFFFF9800), Colors.white),
                  progressWidget: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: cardDark2,
                      valueColor: AlwaysStoppedAnimation<Color>(count >= 3 ? neonGreen : const Color(0xFFFF9800)),
                      minHeight: 6,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Task 4: Helpful Post (5 Coins)
            _buildTaskCard(
              context: context,
              emoji: '💡',
              title: 'Helpful Received',
              rewardText: '+5 Coins / Vote',
              description: 'Jab dusre gamers aapke community post ya tip ko "Helpful" mark karein.',
              statusBadge: _buildBadge('Community Perk', gold, const Color(0xFF0D121B)),
              progressWidget: null,
            ),

            const SizedBox(height: 24),

            // Rewards & Perks Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Coins Se Kya Milta Hai?',
                        style: TextStyle(
                          color: textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildPerkItem('🎁 Weekly Rs. 5,000 Steam / PSN Gift Card Giveaways'),
                  const SizedBox(height: 6),
                  _buildPerkItem('👑 VIP Golden Gamer Badge on Community Wall'),
                  const SizedBox(height: 6),
                  _buildPerkItem('⚡ Early access to game sales, freebies & price drops'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required BuildContext context,
    required String emoji,
    required String title,
    required String rewardText,
    required String description,
    required Widget? statusBadge,
    required Widget? progressWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cardDark2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderDark),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rewardText,
                      style: TextStyle(
                        color: gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusBadge != null) statusBadge,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: textGray, fontSize: 11.5, height: 1.3),
          ),
          if (progressWidget != null) ...[
            const SizedBox(height: 10),
            progressWidget,
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildPerkItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_rounded, color: neonGreen, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: textGray, fontSize: 12, height: 1.3),
          ),
        ),
      ],
    );
  }
}
