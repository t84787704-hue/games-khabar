import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_model.dart';

class FollowingService {
  static final FollowingService _instance = FollowingService._internal();
  factory FollowingService() => _instance;
  FollowingService._internal();

  static const String _prefsKey = 'followed_games_v1';

  static final ValueNotifier<Set<String>> followedGamesNotifier = ValueNotifier<Set<String>>({});

  static const List<String> popularGames = [
    'GTA VI',
    'Call of Duty',
    'Fall Guys',
    'VALORANT',
    'Fortnite',
    'BGMI / PUBG',
    'Minecraft',
    'Elden Ring',
    'Apex Legends',
    'Counter-Strike 2',
    'Tekken 8',
    'EA Sports FC',
    'Genshin Impact',
    'Palworld',
    'Helldivers 2',
    'Cyberpunk 2077',
    'God of War',
    'Rocket League',
    'Roblox',
    'Free Fire',
  ];

  bool _isLoaded = false;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? [];
      followedGamesNotifier.value = Set<String>.from(list);
      _isLoaded = true;
    } catch (_) {}
  }

  bool isFollowing(String game) {
    final lower = game.toLowerCase().trim();
    return followedGamesNotifier.value.any((g) => g.toLowerCase().trim() == lower);
  }

  Future<bool> toggleFollow(String game) async {
    if (!_isLoaded) await init();
    final current = Set<String>.from(followedGamesNotifier.value);
    final trimmed = game.trim();
    bool nowFollowing = false;

    if (current.any((g) => g.toLowerCase() == trimmed.toLowerCase())) {
      current.removeWhere((g) => g.toLowerCase() == trimmed.toLowerCase());
      nowFollowing = false;
    } else {
      current.add(trimmed);
      nowFollowing = true;
    }

    followedGamesNotifier.value = current;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, current.toList());
    } catch (_) {}

    return nowFollowing;
  }

  Future<void> setFollowedGames(Set<String> games) async {
    followedGamesNotifier.value = Set<String>.from(games);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, games.toList());
    } catch (_) {}
  }

  bool matchesFollowed(NewsModel news) {
    final followed = followedGamesNotifier.value;
    if (followed.isEmpty) return false;

    final game = (news.gameName ?? '').toLowerCase();
    final title = news.title.toLowerCase();
    final cat = news.category.toLowerCase();
    final desc = news.description.toLowerCase();

    for (final f in followed) {
      final query = f.toLowerCase().trim();
      if (query.isEmpty) continue;

      // Handle split patterns e.g. "BGMI / PUBG"
      final parts = query.split('/').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      for (final part in parts) {
        if (game.contains(part) ||
            title.contains(part) ||
            cat.contains(part) ||
            desc.contains(part)) {
          return true;
        }
      }
    }
    return false;
  }

  List<NewsModel> filterNews(List<NewsModel> newsList) {
    if (followedGamesNotifier.value.isEmpty) {
      return [];
    }
    return newsList.where(matchesFollowed).toList();
  }
}
