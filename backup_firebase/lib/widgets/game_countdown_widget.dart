import 'dart:async';
import 'package:flutter/material.dart';
import '../services/countdown_service.dart';
import '../services/theme_service.dart';

class GameCountdownWidget extends StatefulWidget {
  final DateTime targetDate;
  final String gameName;
  final String? subtitle;
  final VoidCallback? onPinSuccess;

  const GameCountdownWidget({
    super.key,
    required this.targetDate,
    required this.gameName,
    this.subtitle,
    this.onPinSuccess,
  });

  @override
  State<GameCountdownWidget> createState() => _GameCountdownWidgetState();
}

class _GameCountdownWidgetState extends State<GameCountdownWidget> {
  late Timer _timer;
  late Duration _remaining;

  Color get cardDark => ThemeService.card;
  Color get borderDark => ThemeService.border;
  Color get neonGreen => ThemeService.primaryGreen;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;

  @override
  void initState() {
    super.initState();
    _calcRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _calcRemaining();
        });
      }
    });
  }

  void _calcRemaining() {
    final now = DateTime.now();
    if (widget.targetDate.isBefore(now)) {
      _remaining = Duration.zero;
    } else {
      _remaining = widget.targetDate.difference(now);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    final isReleased = _remaining == Duration.zero;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neonGreen.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: neonGreen.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isReleased ? Colors.redAccent : neonGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isReleased ? Colors.redAccent : neonGreen).withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isReleased ? 'LAUNCHED / AVAILABLE' : 'LIVE RELEASE COUNTDOWN',
                style: TextStyle(
                  color: isReleased ? Colors.redAccent : neonGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Icon(Icons.timer_outlined, color: neonGreen, size: 16),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            widget.gameName,
            style: TextStyle(
              color: textWhite,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),

          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              widget.subtitle!,
              style: TextStyle(color: textGray, fontSize: 11),
            ),
          ],

          const SizedBox(height: 14),

          // 4 Countdown Units
          if (!isReleased)
            Row(
              children: [
                _buildTimeUnit(days.toString().padLeft(2, '0'), 'DAYS'),
                _buildDivider(),
                _buildTimeUnit(hours.toString().padLeft(2, '0'), 'HOURS'),
                _buildDivider(),
                _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'MINS'),
                _buildDivider(),
                _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'SECS', isLive: true),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: neonGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: neonGreen),
              ),
              alignment: Alignment.center,
              child: Text(
                '🚀 GAME IS OUT NOW!',
                style: TextStyle(
                  color: neonGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ),

          const SizedBox(height: 14),

          // Action: Pin to Home Widget
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: () async {
                await CountdownService().pinToHomeWidget(
                  CountdownGame(
                    id: widget.gameName.toLowerCase().replaceAll(' ', '_'),
                    name: widget.gameName,
                    releaseDate: widget.targetDate,
                    platform: widget.subtitle ?? 'Upcoming',
                  ),
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: cardDark,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: neonGreen, width: 1.2),
                      ),
                      content: Row(
                        children: [
                          Icon(Icons.widgets_rounded, color: neonGreen, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${widget.gameName} countdown pinned to Android Home Widget! 📲',
                              style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: neonGreen.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(Icons.widgets_outlined, color: neonGreen, size: 16),
              label: Text(
                'Pin to Android Home Widget',
                style: TextStyle(color: neonGreen, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label, {bool isLive = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF070B11),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLive ? neonGreen.withOpacity(0.6) : borderDark,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: isLive ? neonGreen : textWhite,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: textGray,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          color: neonGreen,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
