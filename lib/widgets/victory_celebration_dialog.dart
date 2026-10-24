import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';

class VictoryCelebrationDialog extends StatefulWidget {
  final String tournamentTitle;
  final String winningTeamName;
  final int prizeCoins;
  final String? runnerUpTeamName;
  final String? mvpPlayerName;

  const VictoryCelebrationDialog({
    super.key,
    required this.tournamentTitle,
    required this.winningTeamName,
    required this.prizeCoins,
    this.runnerUpTeamName,
    this.mvpPlayerName,
  });

  static void show(
    BuildContext context, {
    required String tournamentTitle,
    required String winningTeamName,
    required int prizeCoins,
    String? runnerUpTeamName,
    String? mvpPlayerName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => VictoryCelebrationDialog(
        tournamentTitle: tournamentTitle,
        winningTeamName: winningTeamName,
        prizeCoins: prizeCoins,
        runnerUpTeamName: runnerUpTeamName,
        mvpPlayerName: mvpPlayerName,
      ),
    );
  }

  @override
  State<VictoryCelebrationDialog> createState() => _VictoryCelebrationDialogState();
}

class _VictoryCelebrationDialogState extends State<VictoryCelebrationDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _shareVictory() {
    final text = '🏆 CHAMPIONS ALERT! 🏆\n\n'
        'Squad "${widget.winningTeamName}" has won the ${widget.tournamentTitle}!\n'
        '💰 Prize Won: ${widget.prizeCoins} Coins\n\n'
        'Join the tournament battles on Gamers ID Network!';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B10), Color(0xFF11141C), Color(0xFF0A0E17)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFD700).withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: const Text('👑', style: TextStyle(fontSize: 48)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'TOURNAMENT CHAMPIONS',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.tournamentTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.winningTeamName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFD700)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '+${widget.prizeCoins} Coins Won',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('🥈', style: TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(
                              widget.runnerUpTeamName ?? 'Finalist',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 60,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                border: Border.all(color: Colors.white24),
                              ),
                              alignment: Alignment.center,
                              child: const Text('2nd Place', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 32)),
                            const SizedBox(height: 4),
                            Text(
                              widget.winningTeamName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 90,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700).withOpacity(0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('1st Place', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
                                  Text('CHAMPION', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 9.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (widget.mvpPlayerName != null && widget.mvpPlayerName!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flash_on_rounded, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'TOURNAMENT MVP: ${widget.mvpPlayerName}',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareVictory,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFFD700)),
                            foregroundColor: const Color(0xFFFFD700),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Share Victory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF88),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: pi / 2,
          maxBlastForce: 5,
          minBlastForce: 2,
          emissionFrequency: 0.05,
          numberOfParticles: 25,
          gravity: 0.2,
          colors: const [
            Color(0xFFFFD700),
            Color(0xFF00FF88),
            Color(0xFF38BDF8),
            Color(0xFFFF4655),
            Colors.white,
          ],
        ),
      ],
    );
  }
}
