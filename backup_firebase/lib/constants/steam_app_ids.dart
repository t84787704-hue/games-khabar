// lib/constants/steam_app_ids.dart - Top 100 Games for Games Khabar

const Map<String, int> allGamesAppIds = {
  // --- Driving / Racing Games (15) ---
  'Forza Horizon 5': 1551360,
  'Forza Horizon 4': 1293830,
  'Euro Truck Simulator 2': 227300,
  'American Truck Simulator': 270880,
  'Assetto Corsa': 244210,
  'Assetto Corsa Competizione': 805550,
  'BeamNG.drive': 284160,
  'CarX Drift Racing Online': 635260,
  'F1 23': 2108330,
  'DiRT Rally 2.0': 690790,
  'Wreckfest': 228380,
  'The Crew 2': 646910,
  'Need for Speed Heat': 1222680,
  'Need for Speed Unbound': 1846380,
  'SnowRunner': 1465360,

  // --- Simulator Games (20) ---
  'Farming Simulator 22': 1248130,
  'Microsoft Flight Simulator': 1250410,
  'PowerWash Simulator': 1290000,
  'Cities Skylines': 255710,
  'Cities Skylines 2': 949230,
  'Bus Simulator 21': 1535560,
  'MudRunner': 675010,
  'Car Mechanic Simulator 2021': 1196330,
  'PC Building Simulator': 621060,
  'House Flipper': 613100,
  'Teardown': 1167630,
  'My Summer Car': 516750,
  'Supermarket Simulator': 2679760,
  'Goat Simulator 3': 2056920,
  'Construction Simulator': 1273400,
  'Project CARS 2': 378860,
  'rFactor 2': 365960,
  'Farming Simulator 19': 787860,
  'Lawn Mowing Simulator': 1480560,
  'Gas Station Simulator': 1149620,

  // --- Open World (25) ---
  'GTA 5': 271590,
  'Red Dead Redemption 2': 1174180,
  'Cyberpunk 2077': 1091500,
  'Elden Ring': 1245620,
  'The Witcher 3': 292030,
  'Skyrim Special Edition': 489830,
  'Fallout 4': 377160,
  'Rust': 252490,
  'DayZ': 221100,
  'ARK Survival Evolved': 346680,
  'Valheim': 892970,
  'Sons Of The Forest': 1326470,
  'The Forest': 242760,
  'Hogwarts Legacy': 990080,
  'Palworld': 1623730,
  'Baldur\'s Gate 3': 1086940,
  'Starfield': 1716740,
  'No Man\'s Sky': 275850,
  'Terraria': 105600,
  'Subnautica': 264710,
  'Fallout 76': 1151340,
  'Red Dead Online': 2668510,
  'Grand Theft Auto 4': 12210,
  'Hogwarts Legacy Deluxe': 990080,
  'Stardew Valley': 413150,

  // --- Battle Royale / FPS / Shooting (25) ---
  'PUBG': 578080,
  'Apex Legends': 1172470,
  'Counter Strike 2': 730,
  'Call of Duty HQ': 2519060,
  'Overwatch 2': 2357570,
  'Team Fortress 2': 440,
  'Destiny 2': 1085660,
  'War Thunder': 236390,
  'Helldivers 2': 553850,
  'Lethal Company': 1966720,
  'Phasmophobia': 739630,
  'Rainbow Six Siege': 359550,
  'DOTA 2': 570,
  'Warframe': 230410,
  'Path of Exile': 238960,
  'Unturned': 304930,
  'Garry\'s Mod': 4000,
  'Left 4 Dead 2': 550,
  'Borderlands 3': 397540,
  'Borderlands 2': 49520,
  'Content Warning': 2881650,
  'Among Us': 945360,
  'Fall Guys': 1097150,
  'Rocket League': 252950,
  'eFootball 2024': 1665460,

  // --- Extra Popular (15) ---
  'EA FC 24': 2195250,
  'NBA 2K24': 2338770,
  'Tekken 8': 1778820,
  'Street Fighter 6': 1364780,
  'Mortal Kombat 1': 1971870,
  'Resident Evil 4 Remake': 2050650,
  'Resident Evil Village': 1196590,
  'Lethal Company': 1966720,
  'Schedule I': 3164500,
  'Supermarket Simulator': 2679760,
  'Palworld': 1623730,
  'Helldivers 2': 553850,
  'Warframe': 230410,
  'Destiny 2': 1085660,
  'War Thunder': 236390,
};

// Auto category mapping
String getCategoryForAppId(int appId) {
  if ([1551360, 1293830, 227300, 270880, 244210, 805550, 284160, 635260, 2108330, 690790, 228380, 646910, 1222680, 1846380, 1465360].contains(appId)) {
    return 'Driving Games';
  } else if ([1248130, 1250410, 1290000, 255710, 949230, 1535560, 675010, 1196330, 621060, 613100, 1167630, 516750, 2679760, 2056920, 1273400].contains(appId)) {
    return 'Simulator Games';
  } else if ([271590, 1174180, 1091500, 1245620, 292030, 489830, 377160, 252490, 221100, 346680, 892970].contains(appId)) {
    return 'Open World';
  } else {
    return 'Action Games';
  }
}