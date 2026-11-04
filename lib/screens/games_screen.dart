import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../widgets/game_card.dart';
import 'tournaments_screen.dart';
import '../services/theme_service.dart';
import '../services/supabase_service.dart';

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
      title: 'Candy Crush',
      imageUrl: 'https://m.media-amazon.com/images/S/compressed.photo.goodreads.com/books/1425327952i/25054190.jpg',
      playedCount: '10M+',
    ),
    GameModel(
      title: 'Garena Free Fire Max',
      imageUrl: 'https://i.pinimg.com/736x/9c/d7/47/9cd74769ab0b1ca1b7a7a4a06e33f402.jpg',
      playedCount: '2.1M',
    ),
    GameModel(
      title: 'Clash of Clans',
      imageUrl: 'https://m.media-amazon.com/images/M/MV5BYWY0OTUyOGYtYjM5NC00ODAyLTkwYzYtNWVlMzI4ZDkxMjA4XkEyXkFqcGc@._V1_.jpg',
      playedCount: '2.8M',
    ),
    GameModel(
      title: 'Minecraft',
      imageUrl: 'https://thumbs.dreamstime.com/b/minecraft-logo-online-game-dirt-block-illustrations-concept-design-isolated-186775550.jpg',
      playedCount: '6.2M',
    ),
    GameModel(
      title: 'eFootball',
      imageUrl: 'https://i.ytimg.com/vi/5mLrLB1boAc/maxresdefault.jpg',
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

  Map<String, int> _tournamentCounts = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  StreamSubscription? _tournamentsSub;

  @override
  void initState() {
    super.initState();
    _subscribeTournaments();
  }

  @override
  void dispose() {
    _tournamentsSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _subscribeTournaments() {
    _fetchAvailableTournaments();

    try {
      _tournamentsSub?.cancel();
      _tournamentsSub = SupabaseService.client
          .from('tournaments')
          .stream(primaryKey: ['id'])
          .listen((data) {
        _processTournamentData(data);
      }, onError: (err) {
        debugPrint('Tournament stream notice: $err');
      });
    } catch (e) {
      debugPrint('Realtime stream setup exception: $e');
    }

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchAvailableTournaments();
    });
  }

  Future<void> _fetchAvailableTournaments() async {
    try {
      final res = await SupabaseService.client
          .from('tournaments')
          .select();

      _processTournamentData(res);
    } catch (e) {
      debugPrint('Error loading tournament availability: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processTournamentData(dynamic items) {
    final Map<String, int> counts = {};

    if (items is List) {
      for (final item in items) {
        if (item is Map) {
          final status = (item['status'] ?? 'upcoming').toString().trim().toLowerCase();
          // Tournament is active / available if not completed and not cancelled
          if (status != 'completed' && status != 'cancelled') {
            final rawGame = (item['game_name'] ?? item['game'] ?? item['gameName'] ?? '').toString().trim();
            if (rawGame.isNotEmpty) {
              final normKey = _normalizeGameKey(rawGame);
              counts[normKey] = (counts[normKey] ?? 0) + 1;
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _tournamentCounts = counts;
        _isLoading = false;
      });
    }
  }

  String _normalizeGameKey(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.contains('max') && (clean.contains('free fire') || clean.contains('ff') || clean.contains('garena'))) {
      return 'garena free fire max';
    }
    if (clean == 'free fire' || clean == 'freefire' || clean == 'ff' || clean.contains('free fire') || clean.contains('freefire')) {
      return 'free fire';
    }
    if (clean.contains('pubg') || clean.contains('bgmi') || clean.contains('battleground')) {
      return 'pubg mobile';
    }
    if (clean.contains('call of duty') || clean == 'cod' || clean == 'codm' || clean.startsWith('cod ')) {
      return 'call of duty';
    }
    if (clean.contains('clash royale') || clean == 'cr') {
      return 'clash royale';
    }
    if (clean.contains('clash of clans') || clean == 'coc') {
      return 'clash of clans';
    }
    if (clean.contains('candy crush')) {
      return 'candy crush';
    }
    if (clean.contains('minecraft') || clean == 'mc') {
      return 'minecraft';
    }
    if (clean.contains('efootball') || clean.contains('pes')) {
      return 'efootball';
    }
    if (clean.contains('asphalt')) {
      return 'asphalt 9';
    }
    if (clean.contains('brawl')) {
      return 'brawl stars';
    }
    if (clean.contains('stumble')) {
      return 'stumble guys';
    }
    if (clean.contains('ludo')) {
      return 'ludo';
    }
    if (clean.contains('8 ball') || clean.contains('8ball')) {
      return '8 ball pool';
    }
    return clean;
  }

  bool _isTournamentAvailable(String title) {
    return _getTournamentCount(title) > 0;
  }

  int _getTournamentCount(String title) {
    final key = _normalizeGameKey(title);
    if (_tournamentCounts.containsKey(key)) {
      return _tournamentCounts[key]!;
    }
    final rawLower = title.trim().toLowerCase();
    if (_tournamentCounts.containsKey(rawLower)) {
      return _tournamentCounts[rawLower]!;
    }
    for (final entry in _tournamentCounts.entries) {
      if (entry.key.contains(rawLower) || rawLower.contains(entry.key)) {
        return entry.value;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            title: Text(
              'All Games',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ThemeService.textPrimary,
              ),
            ),
            backgroundColor: ThemeService.appBarBg,
            elevation: 0,
            iconTheme: IconThemeData(color: ThemeService.textPrimary),
          ),
          body: RefreshIndicator(
            onRefresh: _fetchAvailableTournaments,
            color: const Color(0xFF00FF88),
            backgroundColor: ThemeService.card,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.77,
              ),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                final isAvailable = _isTournamentAvailable(game.title);
                final count = _getTournamentCount(game.title);

                return GameCard(
                  game: game,
                  isTournamentAvailable: isAvailable,
                  tournamentCount: count,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TournamentsScreen(
                          gameName: game.title.trim(),
                        ),
                      ),
                    ).then((_) => _fetchAvailableTournaments());
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}