import 'package:flutter/material.dart';
import '../models/gamer_user_model.dart';

class RankBadgeWidget extends StatelessWidget {
  final GamerRankBadge badge;
  final double size;
  final bool showLabel;

  const RankBadgeWidget({
    super.key,
    required this.badge,
    this.size = 14,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!badge.isVisible) return const SizedBox.shrink();

    return Tooltip(
      message: 'Rank Tier: ${badge.label}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 6 : 4,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: badge.backgroundColor,
          borderRadius: BorderRadius.circular(showLabel ? 6 : 4),
          border: Border.all(color: badge.borderColor, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: badge.primaryColor.withOpacity(0.25),
              blurRadius: 4,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              badge.emoji,
              style: TextStyle(
                fontSize: size - 2,
                height: 1.0,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Text(
                badge.label.toUpperCase(),
                style: TextStyle(
                  color: badge.primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: size - 3.5,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
