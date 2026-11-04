import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../services/theme_service.dart';

class GameCard extends StatelessWidget {
  final GameModel game;
  final VoidCallback onTap;
  final bool isTournamentAvailable;
  final int tournamentCount;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.isTournamentAvailable = false,
    this.tournamentCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTournamentAvailable
                ? const Color(0xFF00FF88).withOpacity(0.4)
                : ThemeService.border,
            width: isTournamentAvailable ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isTournamentAvailable
                  ? const Color(0xFF00FF88).withOpacity(0.08)
                  : Colors.black.withOpacity(ThemeService.isDarkMode ? 0.25 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Image with Top Status Badge
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                      child: Image.network(
                        game.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: ThemeService.cardSecondary,
                            child: Center(
                              child: Icon(
                                Icons.sports_esports,
                                color: ThemeService.textSecondary,
                                size: 36,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Subtle gradient overlay at top for badge readability
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top Status Pill
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isTournamentAvailable
                            ? const Color(0xFF00FF88)
                            : Colors.black.withOpacity(0.70),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isTournamentAvailable
                              ? const Color(0xFF00FF88)
                              : Colors.white24,
                          width: 0.8,
                        ),
                        boxShadow: isTournamentAvailable
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00FF88).withOpacity(0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTournamentAvailable
                                ? Icons.emoji_events_rounded
                                : Icons.schedule_rounded,
                            size: 11,
                            color: isTournamentAvailable
                                ? const Color(0xFF0B0F14)
                                : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTournamentAvailable
                                ? (tournamentCount > 1 ? '$tournamentCount LIVE' : 'AVAILABLE')
                                : 'SOON',
                            style: TextStyle(
                              color: isTournamentAvailable
                                  ? const Color(0xFF0B0F14)
                                  : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 9.5,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Game Name & Tournament Status Row
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    game.title,
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isTournamentAvailable
                              ? const Color(0xFF00FF88)
                              : const Color(0xFFFF9900),
                          boxShadow: isTournamentAvailable
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00FF88).withOpacity(0.6),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          isTournamentAvailable
                              ? 'Tournament Available'
                              : 'Tournament Coming Soon',
                          style: TextStyle(
                            color: isTournamentAvailable
                                ? const Color(0xFF00FF88)
                                : const Color(0xFFFFB800),
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}