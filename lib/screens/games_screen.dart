import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../widgets/game_card.dart';
import 'tournaments_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
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
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client.from('games').select().order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.amber));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No games found. Add from Admin Panel.', style: TextStyle(color: Colors.white)));
            }

            final gamesData = snapshot.data!;

            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: gamesData.length,
              itemBuilder: (context, index) {
                final gameMap = gamesData[index];
                
                final game = GameModel(
                  title: gameMap['title'] ?? 'Unknown',
                  imageUrl: gameMap['image_url'] ?? '',
                  playedCount: gameMap['played_count'] ?? '0',
                );

                return GameCard(
                  game: game,
                  onTap: () {
                    // 👇 یہاں گیم کا نام صحیح طریقے سے بھیج رہے ہیں
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TournamentsScreen(
                          gameName: game.title.trim(), // trim() سے اضافی سپیس ختم ہو جاتی ہے
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}