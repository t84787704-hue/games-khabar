import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class MatchRulesDialog {
  /// Match create karne ya start karne se pehle yeh popup dikhane ke liye function
  static void show(
    BuildContext context, {
    required String title,
    required VoidCallback onProceed,
  }) {
    final bgDark = ThemeService.bg;
    final primaryGreen = ThemeService.primaryGreen;
    final cardDark = ThemeService.card;
    final borderDark = ThemeService.border;
    final textWhite = ThemeService.textPrimary;
    final textGray = ThemeService.textSecondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: bgDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderDark, width: 1.2),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_rounded, color: primaryGreen, size: 24),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Fair Play & Token Verification Rules',
                          style: TextStyle(color: textGray, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 4 Verification Rules Cards
              _buildRuleTile(
                number: '1',
                title: 'In-Game Name (IGN) Match',
                desc: 'Aapka Gamers ID profile name aur in-game kill feed naam bilkul match hona chahiye.',
                primaryGreen: primaryGreen,
                cardDark: cardDark,
                borderDark: borderDark,
                textWhite: textWhite,
                textGray: textGray,
              ),
              const SizedBox(height: 10),

              _buildRuleTile(
                number: '2',
                title: 'Full Screen POV & Controls (HUD)',
                desc: 'Screen recording mein on-screen game buttons aur controls saaf dikhna lazmi hain.',
                primaryGreen: primaryGreen,
                cardDark: cardDark,
                borderDark: borderDark,
                textWhite: textWhite,
                textGray: textGray,
              ),
              const SizedBox(height: 10),

              _buildRuleTile(
                number: '3',
                title: 'No Cropped / Watermarked Clips',
                desc: 'Internet se download ki gayi, cropped ya doosre creators ke watermark wali clip reject hogi.',
                primaryGreen: primaryGreen,
                cardDark: cardDark,
                borderDark: borderDark,
                textWhite: textWhite,
                textGray: textGray,
              ),
              const SizedBox(height: 10),

              _buildRuleTile(
                number: '4',
                title: 'Career Results Proof (Dispute)',
                desc: 'Kisi bhi lafray ya shak par in-game Career Results ka timestamp wala screenshot mangwaya jayega.',
                primaryGreen: primaryGreen,
                cardDark: cardDark,
                borderDark: borderDark,
                textWhite: textWhite,
                textGray: textGray,
              ),

              const SizedBox(height: 20),

              // Accept / Continue Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onProceed(); // Agla action continue karein
                  },
                  child: const Text(
                    'I Understand & Accept Rules',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildRuleTile({
    required String number,
    required String title,
    required String desc,
    required Color primaryGreen,
    required Color cardDark,
    required Color borderDark,
    required Color textWhite,
    required Color textGray,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                color: primaryGreen,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
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
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(color: textGray, fontSize: 11.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
