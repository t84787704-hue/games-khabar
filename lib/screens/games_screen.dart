import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../widgets/game_card.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  // یہاں آپ گیمز کی لسٹ میں اپنی مرضی سے اضافہ کر سکتے ہیں
  final List<GameModel> games = const [
    GameModel(
      title: 'Free Fire',
      // یہاں آپ کسی بھی گیم کی اصلی تصویر کا لنک (URL) ڈال سکتے ہیں
      imageUrl: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ2jS8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3&s', 
      playedCount: '5.9M',
    ),
    GameModel(
      title: 'PUBG Mobile',
      imageUrl: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ2jS8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3&s',
      playedCount: '3.9M',
    ),
    GameModel(
      title: 'Call Of Duty',
      imageUrl: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ2jS8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3&s',
      playedCount: '1.8M',
    ),
    GameModel(
      title: 'Clash Royale',
      imageUrl: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ2jS8lO2m0q6g5R4t3z2x1w9y8v7u6t5s4r3&s',
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
                // جب صارف گیم پر کلک کرے گا تو یہ کوڈ چلے گا
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${games[index].title} selected!')),
                );
              },
            );
          },
        ),
      ),
    );
  }
}