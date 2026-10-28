import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../widgets/game_card.dart';
import 'tournaments_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  // 👇 یہاں 12 گیمز کی مکمل لسٹ ہے
  final List<GameModel> games = const [
    GameModel(
      title: 'Free Fire',
      imageUrl: 'https://play-lh.googleusercontent.com/9O2S2g1J2K4l3Q5T8b7V6c5X4z3Y2w1V0u9T8s7R6q5P4o3N2m1L0k',
      playedCount: '5.9M',
    ),
    GameModel(
      title: 'PUBG Mobile',
      imageUrl: 'https://play-lh.googleusercontent.com/2S8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3Q2jS8lO2m0q6g5R4t3z2x1w',
      playedCount: '3.9M',
    ),
    GameModel(
      title: 'Call Of Duty',
      imageUrl: 'https://play-lh.googleusercontent.com/3T8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3Q2jS8lO2m0q6g5R4t3z2x1w',
      playedCount: '1.8M',
    ),
    GameModel(
      title: 'Clash Royale',
      imageUrl: 'https://play-lh.googleusercontent.com/4U8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3Q2jS8lO2m0q6g5R4t3z2x1w',
      playedCount: '1.2M',
    ),
    GameModel(
      title: 'BGMI',
      imageUrl: 'https://play-lh.googleusercontent.com/5V8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3Q2jS8lO2m0q6g5R4t3z2x1w',
      playedCount: '4.5M',
    ),
    GameModel(
      title: 'Garena Free Fire Max',
      imageUrl: 'https://play-lh.googleusercontent.com/6W8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3Q2jS8lO2m0q6g5R4t3z2x1w',
      playedCount: '2.1M',
    ),
    GameModel(
      title: 'Clash of Clans',
      imageUrl: 'https://play-lh.googleusercontent.com/7X8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3Q2jS8lO2m0q6g5R4t3z2x1w',
      playedCount: '2.8M',
    ),
    GameModel(
      title: 'Minecraft',
      imageUrl: 'https://play-lh.googleusercontent.com/8Y8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3Q2jS8lO2m0q6g5R4t3z2x1w',
      playedCount: '6.2M',
    ),
    GameModel(
      title: 'eFootball',
      imageUrl: 'https://play-lh.googleusercontent.com/9Z8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3Q2jS8lO2m0q6g5R4t3z2x1w',
      playedCount: '1.5M',
    ),
    GameModel(
      title: 'Asphalt 9',
      imageUrl: 'https://play-lh.googleusercontent.com/1A8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3Q2jS8lO2m0q6g5R4t3z2x1w',
      playedCount: '900K',
    ),
    GameModel(
      title: 'Brawl Stars',
      imageUrl: 'https://play-lh.googleusercontent.com/2B8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3Q2jS8lO2m0q6g5R4t3z2x1w',
      playedCount: '3.1M',
    ),
    GameModel(
      title: 'Stumble Guys',
      imageUrl: 'https://play-lh.googleusercontent.com/3C8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3Q2jS8lO2m0q6g5R4t3z2x1w',
      playedCount: '1.9M',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('All Games', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: games.length,
          itemBuilder: (context, index) {
            return GameCard(
              game: games[index],
              onTap: () {
                // 👇 گیم کا نام ٹورنامنٹس والی سکرین کو بھیج رہے ہیں
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TournamentsScreen(
                      gameName: games[index].title.trim(),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}