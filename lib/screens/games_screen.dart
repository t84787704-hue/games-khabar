import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../widgets/game_card.dart';
import 'tournaments_screen.dart'; // ٹورنامنٹس والے صفحے کا امپورٹ شامل کیا

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  // یہاں آپ گیمز کی لسٹ میں اپنی مرضی سے اضافہ کر سکتے ہیں
  final List<GameModel> games = const [
    GameModel(
      title: 'Free Fire',
      // اصلی تصویر کا لنک
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // گہرا ڈارک بیک گراؤنڈ
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
            crossAxisCount: 2, // ایک لائن میں دو گیمز
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: games.length,
          itemBuilder: (context, index) {
            return GameCard(
              game: games[index],
              onTap: () {
                // جب صارف گیم پر کلک کرے گا تو ٹورنامنٹس والے صفحے پر چلا جائے گا
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TournamentsScreen(),
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