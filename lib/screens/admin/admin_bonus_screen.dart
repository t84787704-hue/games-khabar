import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/theme_service.dart';

class AdminBonusScreen extends StatefulWidget {
  const AdminBonusScreen({super.key});

  @override
  State<AdminBonusScreen> createState() => _AdminBonusScreenState();
}

class _AdminBonusScreenState extends State<AdminBonusScreen> {
  final TextEditingController _revenueController = TextEditingController(text: '5.0');
  bool _isDistributing = false;
  String _statusMessage = '';

  Color get bgDark => ThemeService.bg;
  Color get cardDark => ThemeService.card;
  Color get cardDark2 => const Color(0xFF151922);
  Color get borderDark => ThemeService.border;
  Color get neonGreen => ThemeService.primaryGreen;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;
  Color get gold => const Color(0xFFFFD700);
  Color get alertRed => const Color(0xFFFF4655);

  double get actualAvgRevenuePerAd => double.tryParse(_revenueController.text.trim()) ?? 5.0;

  // Math Calculations:
  // finalCoinsPerAd = (actualAvgRevenuePerAd * 0.5) / 0.10
  // instantPerAd = 12 coins
  // bonusPerAd = finalCoinsPerAd - instantPerAd
  double get finalCoinsPerAd => (actualAvgRevenuePerAd * 0.5) / 0.10;
  final int instantPerAd = 12;
  double get bonusPerAd => finalCoinsPerAd - instantPerAd;

  @override
  void dispose() {
    _revenueController.dispose();
    super.dispose();
  }

  Future<void> _distributeBonus() async {
    final rev = actualAvgRevenuePerAd;
    if (rev <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFFF4655),
          content: Text('Please enter a valid revenue per ad in PKR (e.g. 5.0)'),
        ),
      );
      return;
    }

    final calculatedBonusPerAd = ((rev * 0.5) / 0.10) - 12;
    if (calculatedBonusPerAd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF4655),
          content: Text('Bonus per ad is ${calculatedBonusPerAd.toStringAsFixed(1)} (<= 0). No bonus to distribute.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: neonGreen.withOpacity(0.4)),
        ),
        title: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            Text(
              'Distribute Daily Bonus?',
              style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rate: Rs. ${rev.toStringAsFixed(2)} / ad\n'
              'Bonus: ${calculatedBonusPerAd.toStringAsFixed(1)} coins per ad yesterday.\n\n'
              'Are you sure you want to credit all qualifying users now?',
              style: TextStyle(color: textGray, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: neonGreen,
              foregroundColor: const Color(0xFF05080D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Distribute', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isDistributing = true;
      _statusMessage = 'Reading users data...';
    });

    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      int usersRewarded = 0;
      int totalBonusCoinsDistributed = 0;

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final totalAdsYesterday = (data['totalAdsYesterday'] as num?)?.toInt() ?? 0;

        if (totalAdsYesterday > 0) {
          final totalBonus = (calculatedBonusPerAd * totalAdsYesterday).toInt();
          if (totalBonus > 0) {
            // Update coins in user doc
            await doc.reference.update({
              'coins': FieldValue.increment(totalBonus),
            });

            // Send in-app notification without mentioning Ad or 50%
            await FirebaseFirestore.instance.collection('notifications').add({
              'userId': doc.id,
              'title': '🎁 Daily Bonus!',
              'body': '🎁 Daily Bonus! $totalBonus Coins mil gaye! Kal ki activity ka inaam!',
              'type': 'bonus_reward',
              'timestamp': FieldValue.serverTimestamp(),
            });

            usersRewarded += 1;
            totalBonusCoinsDistributed += totalBonus;
          }
        }
      }

      setState(() {
        _isDistributing = false;
        _statusMessage = 'Completed! $usersRewarded users rewarded ($totalBonusCoinsDistributed coins).';
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: cardDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: neonGreen),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 24),
                const SizedBox(width: 8),
                Text(
                  'Bonus Distributed! 🎉',
                  style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: Text(
              'Successfully rewarded $usersRewarded users with a total of $totalBonusCoinsDistributed GK Coins!\n\n'
              'In-app notifications have been delivered to their accounts.',
              style: TextStyle(color: textGray, fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonGreen,
                  foregroundColor: const Color(0xFF05080D),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDistributing = false;
        _statusMessage = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: alertRed,
            content: Text('Failed to distribute bonus: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: neonGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: neonGreen),
              ),
              child: Text(
                'ADMIN',
                style: TextStyle(
                  color: neonGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Daily Bonus Pool',
              style: TextStyle(
                color: textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Explanation Card
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
                      const Icon(Icons.monetization_on_outlined, color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'AdMob Revenue Share Adjustment',
                        style: TextStyle(
                          color: textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Users receive instant rewards upon app actions (12 coins/ad). '
                    'Enter your actual AdMob dashboard eCPM/revenue per ad below to automatically distribute the remaining 50% revenue share bonus to yesterday\'s active users.',
                    style: TextStyle(color: textGray, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Input Field: actualAvgRevenuePerAd
            Text(
              'Actual Average Revenue Per Ad (PKR)',
              style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _revenueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 15),
              decoration: InputDecoration(
                prefixText: 'Rs. ',
                prefixStyle: TextStyle(color: neonGreen, fontWeight: FontWeight.bold, fontSize: 15),
                hintText: 'e.g. 5.0',
                hintStyle: TextStyle(color: textGray.withOpacity(0.5)),
                filled: true,
                fillColor: cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: neonGreen, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Live Math Breakdown Preview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardDark2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CALCULATION BREAKDOWN',
                    style: TextStyle(
                      color: neonGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMathRow('Actual Revenue Per Ad:', 'Rs. ${actualAvgRevenuePerAd.toStringAsFixed(2)}'),
                  _buildMathRow('Target Revenue Share (50%):', 'Rs. ${(actualAvgRevenuePerAd * 0.5).toStringAsFixed(2)}'),
                  _buildMathRow('Coin Value:', 'Rs. 0.10 / coin'),
                  _buildMathRow('Final Target Coins / Ad:', '${finalCoinsPerAd.toStringAsFixed(1)} coins'),
                  _buildMathRow('Instant Reward Already Given:', '$instantPerAd coins'),
                  Divider(color: borderDark, height: 16),
                  _buildMathRow(
                    'Bonus Coins Per Ad (Yesterday):',
                    '+${bonusPerAd.toStringAsFixed(1)} coins',
                    highlight: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Status message if any
            if (_statusMessage.isNotEmpty) ...[
              Center(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.startsWith('Error') ? alertRed : neonGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Button: Distribute Bonus
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonGreen,
                  foregroundColor: const Color(0xFF05080D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: _isDistributing ? null : _distributeBonus,
                icon: _isDistributing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF05080D)),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _isDistributing ? 'Distributing Bonus...' : 'Distribute Bonus',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Privacy & Compliance Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10141D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderDark.withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: textGray, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Automated notifications sent to users will only state: '
                      '"🎁 Daily Bonus! {totalBonus} Coins mil gaye! Kal ki activity ka inaam!" '
                      'and will never disclose internal ad metrics or revenue ratios.',
                      style: TextStyle(color: textGray, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMathRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? textWhite : textGray,
              fontSize: 12.5,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? Colors.amber : textWhite,
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
