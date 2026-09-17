import 'package:flutter/material.dart';

class MobileGamesRankData {
  static const List<String> games = [
    'BGMI (Battlegrounds Mobile India)',
    'Free Fire',
    'PUBG Mobile',
    'Call of Duty Mobile (COD)',
    'Valorant Mobile',
    'Clash of Clans',
    'Clash Royale',
    'Pokémon Unite',
    'Mobile Legends',
    'Genshin Impact',
    'Fortnite Mobile',
    'Apex Legends Mobile',
    'New State Mobile',
    'PES / eFootball',
    'Asphalt 9',
  ];

  static const Map<String, String> gameIcons = {
    'BGMI (Battlegrounds Mobile India)': '🎖️',
    'Free Fire': '🔥',
    'PUBG Mobile': '🪂',
    'Call of Duty Mobile (COD)': '🎯',
    'Valorant Mobile': '⚡',
    'Clash of Clans': '🏰',
    'Clash Royale': '👑',
    'Pokémon Unite': '⚡',
    'Mobile Legends': '⚔️',
    'Genshin Impact': '✨',
    'Fortnite Mobile': '⛏️',
    'Apex Legends Mobile': '🏆',
    'New State Mobile': '🚀',
    'PES / eFootball': '⚽',
    'Asphalt 9': '🏎️',
  };

  static const Map<String, Color> gameColors = {
    'BGMI (Battlegrounds Mobile India)': Color(0xFFFF9900),
    'Free Fire': Color(0xFFFF3B30),
    'PUBG Mobile': Color(0xFFF59E0B),
    'Call of Duty Mobile (COD)': Color(0xFF00D2FF),
    'Valorant Mobile': Color(0xFFFF4655),
    'Clash of Clans': Color(0xFFFFCC00),
    'Clash Royale': Color(0xFF3B82F6),
    'Pokémon Unite': Color(0xFFF59E0B),
    'Mobile Legends': Color(0xFF8B5CF6),
    'Genshin Impact': Color(0xFF38BDF8),
    'Fortnite Mobile': Color(0xFFA855F7),
    'Apex Legends Mobile': Color(0xFFEF4444),
    'New State Mobile': Color(0xFF06B6D4),
    'PES / eFootball': Color(0xFF10B981),
    'Asphalt 9': Color(0xFFEC4899),
  };

  static const Map<String, List<String>> ranksByGame = {
    'BGMI (Battlegrounds Mobile India)': [
      'Bronze',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Crown',
      'Ace',
      'Ace Master',
      'Ace Dominator',
      'Conqueror',
    ],
    'Free Fire': [
      'Bronze',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Heroic',
      'Elite Heroic',
      'Master',
      'Grandmaster',
      'Grandmaster+',
    ],
    'PUBG Mobile': [
      'Bronze',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Crown',
      'Ace',
      'Ace Master',
      'Ace Dominator',
      'Conqueror',
    ],
    'Call of Duty Mobile (COD)': [
      'Rookie',
      'Veteran',
      'Elite',
      'Pro',
      'Master',
      'Grandmaster',
      'Legendary',
    ],
    'Valorant Mobile': [
      'Iron',
      'Bronze',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Ascendant',
      'Immortal',
      'Radiant',
    ],
    'Clash of Clans': [
      'Town Hall 7',
      'TH 8',
      'TH 9',
      'TH 10',
      'TH 11',
      'TH 12',
      'TH 13',
      'TH 14',
      'TH 15',
      'TH 16',
    ],
    'Clash Royale': [
      'Arena 10',
      'Arena 11',
      'Arena 12',
      'Arena 13',
      'Arena 14',
      'Challenger',
      'Master',
      'Champion',
      'Grand Champion',
      'Ultimate Champion',
    ],
    'Pokémon Unite': [
      'Beginner',
      'Great',
      'Expert',
      'Veteran',
      'Ultra',
      'Master',
    ],
    'Mobile Legends': [
      'Warrior',
      'Elite',
      'Master',
      'Grandmaster',
      'Epic',
      'Legend',
      'Mythic',
      'Mythical Honor',
      'Mythical Glory',
      'Mythical Immortal',
    ],
    'Genshin Impact': [
      'AR 20+',
      'AR 30+',
      'AR 40+',
      'AR 45+',
      'AR 50+',
      'AR 55+',
      'AR 56+',
      'AR 58+',
      'AR 60',
    ],
    'Fortnite Mobile': [
      'Bronze',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Elite',
      'Champion',
      'Unreal',
    ],
    'Apex Legends Mobile': [
      'Iron',
      'Bronze',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Master',
      'Apex Predator',
    ],
    'New State Mobile': [
      'Bronze',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Master',
      'Grand Master',
      'Challenger',
      'Conqueror',
    ],
    'PES / eFootball': [
      'Division 10',
      'Division 9',
      'Division 8',
      'Division 7',
      'Division 6',
      'Division 5',
      'Division 4',
      'Division 3',
      'Division 2',
      'Division 1',
    ],
    'Asphalt 9': [
      'Amateur',
      'Rookie',
      'Pro',
      'Elite',
      'Master',
      'Legend',
    ],
  };

  static List<String> getRanksForGame(String gameName) {
    if (ranksByGame.containsKey(gameName)) {
      return ranksByGame[gameName]!;
    }
    // Match partial names (e.g. "BGMI", "Free Fire", "COD", "PUBG")
    for (final entry in ranksByGame.entries) {
      if (entry.key.toLowerCase().contains(gameName.toLowerCase()) ||
          gameName.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return ranksByGame['BGMI (Battlegrounds Mobile India)']!;
  }

  static String resolveGameName(String raw) {
    if (games.contains(raw)) return raw;
    final lower = raw.toLowerCase().trim();
    for (final g in games) {
      if (g.toLowerCase() == lower || g.toLowerCase().contains(lower) || lower.contains(g.toLowerCase())) {
        return g;
      }
    }
    return games.first;
  }
}
