import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CountdownGame {
  final String id;
  final String name;
  final DateTime releaseDate;
  final String platform;
  final String? bannerUrl;

  const CountdownGame({
    required this.id,
    required this.name,
    required this.releaseDate,
    required this.platform,
    this.bannerUrl,
  });

  Duration get remainingTime {
    final now = DateTime.now();
    if (releaseDate.isBefore(now)) return Duration.zero;
    return releaseDate.difference(now);
  }

  bool get isReleased => releaseDate.isBefore(DateTime.now());
}

class CountdownService {
  static final CountdownService _instance = CountdownService._internal();
  factory CountdownService() => _instance;
  CountdownService._internal();

  static final List<CountdownGame> defaultUpcomingGames = [
    CountdownGame(
      id: 'gta_6',
      name: 'Grand Theft Auto VI',
      releaseDate: DateTime(2025, 10, 15, 0, 0, 0),
      platform: 'PS5 / Xbox Series X',
      bannerUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e',
    ),
    CountdownGame(
      id: 'death_stranding_2',
      name: 'Death Stranding 2',
      releaseDate: DateTime(2025, 11, 20, 0, 0, 0),
      platform: 'PS5',
    ),
    CountdownGame(
      id: 'monster_hunter_wilds',
      name: 'Monster Hunter Wilds',
      releaseDate: DateTime(2025, 2, 28, 0, 0, 0),
      platform: 'PC / PS5 / Xbox',
    ),
    CountdownGame(
      id: 'witcher_4',
      name: 'The Witcher 4 (Polaris)',
      releaseDate: DateTime(2026, 6, 1, 0, 0, 0),
      platform: 'PC / PS5',
    ),
  ];

  static final ValueNotifier<CountdownGame> pinnedGameNotifier =
      ValueNotifier<CountdownGame>(defaultUpcomingGames.first);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('widget_game_name');
      final savedEpoch = prefs.getInt('widget_release_epoch_seconds');

      if (savedName != null && savedEpoch != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(savedEpoch * 1000);
        pinnedGameNotifier.value = CountdownGame(
          id: 'custom_pinned',
          name: savedName,
          releaseDate: date,
          platform: prefs.getString('widget_game_platform') ?? 'Upcoming',
        );
      }
    } catch (e) {
      debugPrint('[CountdownService] Init error: $e');
    }
  }

  Future<void> pinToHomeWidget(CountdownGame game) async {
    try {
      pinnedGameNotifier.value = game;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_game_name', game.name);
      await prefs.setInt(
        'widget_release_epoch_seconds',
        game.releaseDate.millisecondsSinceEpoch ~/ 1000,
      );
      await prefs.setString('widget_game_platform', game.platform);
    } catch (e) {
      debugPrint('[CountdownService] pinToHomeWidget error: $e');
    }
  }
}
