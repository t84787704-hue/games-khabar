import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../widgets/game_card.dart';
import 'tournaments_screen.dart';
import '../services/theme_service.dart'; // 👈 تھیم سروس کا امپورٹ شامل کیا

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final List<GameModel> games = const [
    GameModel(
      title: 'Free Fire',
      imageUrl: 'https://cdn.wildflamestudio.com/common/web_event/official2.ff.garena.all/20269/53c120cc950c9ead6beb2f5f6d8aadff.jpg',
      playedCount: '5.9M',
    ),
    GameModel(
      title: 'PUBG Mobile',
      imageUrl: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ-BQE_ofOS2fsnUVUfY1sVMcGi0_v4MvjecvwhU1mAcQR-zTlZtlDU48OP&s=10',
      playedCount: '3.9M',
    ),
    GameModel(
      title: 'Call Of Duty',
      imageUrl: 'https://i.pinimg.com/736x/2c/68/00/2c68004e2013ffe544dd18688a4527d5.jpg',
      playedCount: '1.8M',
    ),
    GameModel(
      title: 'Clash Royale',
      imageUrl: 'https://e.snmc.io/lk/f/x/88886e931ef24bc6ddad648cdcf565c8/5296160',
      playedCount: '1.2M',
    ),
    GameModel(
      title: 'BGMI',
      imageUrl: 'https://i.pinimg.com/736x/59/0c/a7/590ca77b4d95284a9e16017234f683c5.jpg',
      playedCount: '4.5M',
    ),
    GameModel(
      title: 'Garena Free Fire Max',
      imageUrl: 'https://original.fontsinuse.com/fontsinuse.com/use-images/95/95495/95495.jpeg',
      playedCount: '2.1M',
    ),
    GameModel(
      title: 'Clash of Clans',
      imageUrl: 'https://i.ytimg.com/vi/5mLrLB1boAc/maxresdefault.jpg',
      playedCount: '2.8M',
    ),
    GameModel(
      title: 'Minecraft',
      imageUrl: 'https://thumbs.dreamstime.com/b/minecraft-logo-online-game-dirt-block-illustrations-concept-design-isolated-186775550.jpg',
      playedCount: '6.2M',
    ),
    GameModel(
      title: 'eFootball',
      imageUrl: 'https://images.igdb.com/igdb/image/upload/t_1080p/co52c8.jpg',
      playedCount: '1.5M',
    ),
    GameModel(
      title: 'Asphalt 9',
      imageUrl: 'https://www.cybersmile.org/wp-content/uploads/2022/09/Cybersmile-x-Asphalt-9-NFT-Fundraising-campaign-announcement.png',
      playedCount: '900K',
    ),
    GameModel(
      title: 'Brawl Stars',
      imageUrl: 'https://cdna.artstation.com/p/assets/images/images/016/603/776/large/nebojsa-bosnjak-brawl-stars-logo.jpg?1552776881',
      playedCount: '3.1M',
    ),
    GameModel(
      title: 'Stumble Guys',
      imageUrl: 'https://live-assets2.web.stumbleguys.com/cms/STG_Reward_Rush_Weekend_1920x1080_57ad1ab000.png',
      playedCount: '1.9M',
    ),
    GameModel(
      title: 'Ludo',
      imageUrl: 'https://static0.gamerantimages.com/wordpress/wp-content/uploads/2025/03/mixcollage-05-mar-2025-09-03-am-8578.jpg',
      playedCount: '10M+',
    ),
    GameModel(
      title: '8 Ball Pool',
      imageUrl: 'https://static0.gamerantimages.com/wordpress/wp-content/uploads/2025/03/mixcollage-05-mar-2025-09-05-am-9226.jpg?w=1200&h=1200&fit=crop',
      playedCount: '8.5M',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 👇 یہاں ڈارک کلر کی بجائے تھیم سروس کا رنگ لگا دیا ہے
      backgroundColor: ThemeService.bg, 
      appBar: AppBar(
        title: const Text('All Games', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: ThemeService.appBarBg, // 👇 ایپ بار کا رنگ بھی تھیم کے مطابق
        elevation: 0,
        iconTheme: IconThemeData(color: ThemeService.textPrimary), // 👇 آئیکن کا رنگ بھی تھیم کے مطابق
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