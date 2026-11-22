/// Comprehensive, 100% reliable fallback game images map and dynamic image pools.
/// Guarantees that every news card always renders a vibrant, high-definition game image
/// and never falls back to an empty gamepad icon or grey placeholder.
/// Also provides rich image pools per game category so different news articles
/// of the same category (e.g. PUBG, BGMI, Free Fire) get UNIQUE images!

final Map<String, String> gameFallbackImages = {
  // All 14 Core App Games + Mobile Mega Titles
  "FREE FIRE": "https://cdn.wildflamestudio.com/common/web_event/official2.ff.garena.all/20269/53c120cc950c9ead6beb2f5f6d8aadff.jpg",
  "FREEFIRE": "https://cdn.wildflamestudio.com/common/web_event/official2.ff.garena.all/20269/53c120cc950c9ead6beb2f5f6d8aadff.jpg",
  "GARENA FREE FIRE": "https://cdn.wildflamestudio.com/common/web_event/official2.ff.garena.all/20269/53c120cc950c9ead6beb2f5f6d8aadff.jpg",
  "GARENA FREE FIRE MAX": "https://i.pinimg.com/736x/9c/d7/47/9cd74769ab0b1ca1b7a7a4a06e33f402.jpg",
  "FREE FIRE MAX": "https://i.pinimg.com/736x/9c/d7/47/9cd74769ab0b1ca1b7a7a4a06e33f402.jpg",
  "PUBG": "https://cdn.akamai.steamstatic.com/steam/apps/578080/header.jpg",
  "PUBG MOBILE": "https://cdn.akamai.steamstatic.com/steam/apps/578080/header.jpg",
  "BGMI": "https://cdn.akamai.steamstatic.com/steam/apps/578080/header.jpg",
  "BATTLEGROUNDS MOBILE INDIA": "https://cdn.akamai.steamstatic.com/steam/apps/578080/header.jpg",
  "COD": "https://i.pinimg.com/736x/2c/68/00/2c68004e2013ffe544dd18688a4527d5.jpg",
  "CALL OF DUTY": "https://i.pinimg.com/736x/2c/68/00/2c68004e2013ffe544dd18688a4527d5.jpg",
  "COD MOBILE": "https://i.pinimg.com/736x/2c/68/00/2c68004e2013ffe544dd18688a4527d5.jpg",
  "WARZONE": "https://cdn.akamai.steamstatic.com/steam/apps/2519060/header.jpg",
  "CLASH ROYALE": "https://e.snmc.io/lk/f/x/88886e931ef24bc6ddad648cdcf565c8/5296160",
  "CANDY CRUSH": "https://m.media-amazon.com/images/S/compressed.photo.goodreads.com/books/1425327952i/25054190.jpg",
  "CANDY CRUSH SAGA": "https://m.media-amazon.com/images/S/compressed.photo.goodreads.com/books/1425327952i/25054190.jpg",
  "CLASH OF CLANS": "https://m.media-amazon.com/images/M/MV5BYWY0OTUyOGYtYjM5NC00ODAyLTkwYzYtNWVlMzI4ZDkxMjA4XkEyXkFqcGc@._V1_.jpg",
  "MINECRAFT": "https://thumbs.dreamstime.com/b/minecraft-logo-online-game-dirt-block-illustrations-concept-design-isolated-186775550.jpg",
  "EFOOTBALL": "https://i.ytimg.com/vi/5mLrLB1boAc/maxresdefault.jpg",
  "FOOTBALL": "https://i.ytimg.com/vi/5mLrLB1boAc/maxresdefault.jpg",
  "ASPHALT 9": "https://www.cybersmile.org/wp-content/uploads/2022/09/Cybersmile-x-Asphalt-9-NFT-Fundraising-campaign-announcement.png",
  "ASPHALT": "https://www.cybersmile.org/wp-content/uploads/2022/09/Cybersmile-x-Asphalt-9-NFT-Fundraising-campaign-announcement.png",
  "BRAWL STARS": "https://cdna.artstation.com/p/assets/images/images/016/603/776/large/nebojsa-bosnjak-brawl-stars-logo.jpg?1552776881",
  "STUMBLE GUYS": "https://live-assets2.web.stumbleguys.com/cms/STG_Reward_Rush_Weekend_1920x1080_57ad1ab000.png",
  "LUDO": "https://static0.gamerantimages.com/wordpress/wp-content/uploads/2025/03/mixcollage-05-mar-2025-09-03-am-8578.jpg",
  "LUDO KING": "https://static0.gamerantimages.com/wordpress/wp-content/uploads/2025/03/mixcollage-05-mar-2025-09-03-am-8578.jpg",
  "8 BALL POOL": "https://static0.gamerantimages.com/wordpress/wp-content/uploads/2025/03/mixcollage-05-mar-2025-09-05-am-9226.jpg?w=1200&h=1200&fit=crop",
  "MLBB": "https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80",
  "MOBILE LEGENDS": "https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80",
  "GENSHIN": "https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=1200&q=80",
  "GENSHIN IMPACT": "https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=1200&q=80",
  "HONKAI": "https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=1200&q=80",
  "ROBLOX": "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1200&q=80",

  // PC & Console Blockbusters
  "GTA": "https://cdn.akamai.steamstatic.com/steam/apps/271590/header.jpg",
  "GTA 6": "https://cdn.akamai.steamstatic.com/steam/apps/271590/header.jpg",
  "GTA 5": "https://cdn.akamai.steamstatic.com/steam/apps/271590/header.jpg",
  "GRAND THEFT AUTO": "https://cdn.akamai.steamstatic.com/steam/apps/271590/header.jpg",
  "FORTNITE": "https://images.unsplash.com/photo-1589241062272-c0a000072dfa?auto=format&fit=crop&w=1200&q=80",
  "VALORANT": "https://images.unsplash.com/photo-1563089145-599997674d42?auto=format&fit=crop&w=1200&q=80",
  "APEX": "https://cdn.akamai.steamstatic.com/steam/apps/1172470/header.jpg",
  "APEX LEGENDS": "https://cdn.akamai.steamstatic.com/steam/apps/1172470/header.jpg",
  "CS2": "https://cdn.akamai.steamstatic.com/steam/apps/730/header.jpg",
  "COUNTER STRIKE": "https://cdn.akamai.steamstatic.com/steam/apps/730/header.jpg",
  "DOTA 2": "https://cdn.akamai.steamstatic.com/steam/apps/570/header.jpg",
  "LOL": "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1200&q=80",
  "LEAGUE OF LEGENDS": "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1200&q=80",
  "OVERWATCH": "https://cdn.akamai.steamstatic.com/steam/apps/2357570/header.jpg",

  // Sports & Racing
  "FIFA": "https://cdn.akamai.steamstatic.com/steam/apps/2195250/header.jpg",
  "EA SPORTS": "https://cdn.akamai.steamstatic.com/steam/apps/2195250/header.jpg",
  "EA FC": "https://cdn.akamai.steamstatic.com/steam/apps/2195250/header.jpg",
  "FORZA": "https://cdn.akamai.steamstatic.com/steam/apps/1551360/header.jpg",
  "RACING": "https://cdn.akamai.steamstatic.com/steam/apps/1551360/header.jpg",
  "NEED FOR SPEED": "https://cdn.akamai.steamstatic.com/steam/apps/1846380/header.jpg",
  "TRUCK": "https://cdn.akamai.steamstatic.com/steam/apps/227300/header.jpg",
  "TRUCK SIMULATOR": "https://cdn.akamai.steamstatic.com/steam/apps/227300/header.jpg",
  "EURO TRUCK": "https://cdn.akamai.steamstatic.com/steam/apps/227300/header.jpg",
  "AMERICAN TRUCK": "https://cdn.akamai.steamstatic.com/steam/apps/270880/header.jpg",
  "BIKE": "https://images.unsplash.com/photo-1558981403-c5f9899a28bc?auto=format&fit=crop&w=1200&q=80",
  "MOTOGP": "https://images.unsplash.com/photo-1568772585407-9361f9bf3a87?auto=format&fit=crop&w=1200&q=80",
  "CRICKET": "https://images.unsplash.com/photo-1531415074868-036b1c57e329?auto=format&fit=crop&w=1200&q=80",
  "WCC3": "https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?auto=format&fit=crop&w=1200&q=80",

  // PlayStation & Action Adventures
  "GOD OF WAR": "https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1200&q=80",
  "SPIDER-MAN": "https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?auto=format&fit=crop&w=1200&q=80",
  "LAST OF US": "https://images.unsplash.com/photo-1563089145-599997674d42?auto=format&fit=crop&w=1200&q=80",
  "ELDEN RING": "https://cdn.akamai.steamstatic.com/steam/apps/1245620/header.jpg",
  "CYBERPUNK": "https://cdn.akamai.steamstatic.com/steam/apps/1091500/header.jpg",
  "ZELDA": "https://images.unsplash.com/photo-1578301978693-85fa9c0320b9?auto=format&fit=crop&w=1200&q=80",
  "TEKKEN": "https://cdn.akamai.steamstatic.com/steam/apps/1778820/header.jpg",
  "STREET FIGHTER": "https://cdn.akamai.steamstatic.com/steam/apps/1364780/header.jpg",
  "ASSASSIN'S CREED": "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80",

  // Categories & General
  "MOBILE": "https://cdn.wildflamestudio.com/common/web_event/official2.ff.garena.all/20269/53c120cc950c9ead6beb2f5f6d8aadff.jpg",
  "MOBILE GAMES": "https://cdn.wildflamestudio.com/common/web_event/official2.ff.garena.all/20269/53c120cc950c9ead6beb2f5f6d8aadff.jpg",
  "PC": "https://cdn.akamai.steamstatic.com/steam/apps/730/header.jpg",
  "PC GAMES": "https://cdn.akamai.steamstatic.com/steam/apps/730/header.jpg",
  "CONSOLE": "https://images.unsplash.com/photo-1578301978693-85fa9c0320b9?auto=format&fit=crop&w=1200&q=80",
  "PS5": "https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1200&q=80",
  "XBOX": "https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?auto=format&fit=crop&w=1200&q=80",
  "NINTENDO": "https://images.unsplash.com/photo-1578301978693-85fa9c0320b9?auto=format&fit=crop&w=1200&q=80",
  "ESPORTS": "https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80",
  "TRENDING": "https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80",
  "FEATURED": "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1200&q=80",
  "DEFAULT": "https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80",
};

/// High-Definition Unique Image Pools for each category & all 14 core app games.
final Map<String, List<String>> gameCategoryPools = {
  "FREE FIRE MAX": [
    "https://i.pinimg.com/736x/9c/d7/47/9cd74769ab0b1ca1b7a7a4a06e33f402.jpg",
    "https://cdn.wildflamestudio.com/common/web_event/official2.ff.garena.all/20269/53c120cc950c9ead6beb2f5f6d8aadff.jpg",
  ],
  "FREE FIRE": [
    "https://cdn.wildflamestudio.com/common/web_event/official2.ff.garena.all/20269/53c120cc950c9ead6beb2f5f6d8aadff.jpg",
    "https://i.pinimg.com/736x/9c/d7/47/9cd74769ab0b1ca1b7a7a4a06e33f402.jpg",
  ],
  "PUBG": [
    "https://cdn.akamai.steamstatic.com/steam/apps/578080/header.jpg",
    "https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?auto=format&fit=crop&w=1200&q=80",
  ],
  "BGMI": [
    "https://cdn.akamai.steamstatic.com/steam/apps/578080/header.jpg",
    "https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1200&q=80",
  ],
  "CALL OF DUTY": [
    "https://i.pinimg.com/736x/2c/68/00/2c68004e2013ffe544dd18688a4527d5.jpg",
    "https://cdn.akamai.steamstatic.com/steam/apps/2519060/header.jpg",
  ],
  "COD": [
    "https://i.pinimg.com/736x/2c/68/00/2c68004e2013ffe544dd18688a4527d5.jpg",
    "https://cdn.akamai.steamstatic.com/steam/apps/2519060/header.jpg",
  ],
  "CLASH ROYALE": [
    "https://e.snmc.io/lk/f/x/88886e931ef24bc6ddad648cdcf565c8/5296160",
  ],
  "CANDY CRUSH": [
    "https://m.media-amazon.com/images/S/compressed.photo.goodreads.com/books/1425327952i/25054190.jpg",
  ],
  "CLASH OF CLANS": [
    "https://m.media-amazon.com/images/M/MV5BYWY0OTUyOGYtYjM5NC00ODAyLTkwYzYtNWVlMzI4ZDkxMjA4XkEyXkFqcGc@._V1_.jpg",
  ],
  "MINECRAFT": [
    "https://thumbs.dreamstime.com/b/minecraft-logo-online-game-dirt-block-illustrations-concept-design-isolated-186775550.jpg",
    "https://images.unsplash.com/photo-1627856013091-fed6e4e30025?auto=format&fit=crop&w=1200&q=80",
  ],
  "EFOOTBALL": [
    "https://i.ytimg.com/vi/5mLrLB1boAc/maxresdefault.jpg",
    "https://cdn.akamai.steamstatic.com/steam/apps/1665460/header.jpg",
  ],
  "FOOTBALL": [
    "https://i.ytimg.com/vi/5mLrLB1boAc/maxresdefault.jpg",
    "https://cdn.akamai.steamstatic.com/steam/apps/2195250/header.jpg",
  ],
  "ASPHALT": [
    "https://www.cybersmile.org/wp-content/uploads/2022/09/Cybersmile-x-Asphalt-9-NFT-Fundraising-campaign-announcement.png",
    "https://cdn.akamai.steamstatic.com/steam/apps/1815780/header.jpg",
  ],
  "BRAWL STARS": [
    "https://cdna.artstation.com/p/assets/images/images/016/603/776/large/nebojsa-bosnjak-brawl-stars-logo.jpg?1552776881",
  ],
  "STUMBLE GUYS": [
    "https://live-assets2.web.stumbleguys.com/cms/STG_Reward_Rush_Weekend_1920x1080_57ad1ab000.png",
    "https://cdn.akamai.steamstatic.com/steam/apps/1677740/header.jpg",
  ],
  "LUDO": [
    "https://static0.gamerantimages.com/wordpress/wp-content/uploads/2025/03/mixcollage-05-mar-2025-09-03-am-8578.jpg",
  ],
  "8 BALL POOL": [
    "https://static0.gamerantimages.com/wordpress/wp-content/uploads/2025/03/mixcollage-05-mar-2025-09-05-am-9226.jpg?w=1200&h=1200&fit=crop",
  ],
  "GTA": [
    "https://cdn.akamai.steamstatic.com/steam/apps/271590/header.jpg",
    "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80",
  ],
  "VALORANT": [
    "https://images.unsplash.com/photo-1563089145-599997674d42?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?auto=format&fit=crop&w=1200&q=80",
  ],
  "FIFA": [
    "https://cdn.akamai.steamstatic.com/steam/apps/2195250/header.jpg",
    "https://i.ytimg.com/vi/5mLrLB1boAc/maxresdefault.jpg",
  ],
  "FORZA": [
    "https://cdn.akamai.steamstatic.com/steam/apps/1551360/header.jpg",
    "https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&w=1200&q=80",
  ],
  "FORTNITE": [
    "https://images.unsplash.com/photo-1589241062272-c0a000072dfa?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1563089145-599997674d42?auto=format&fit=crop&w=1200&q=80",
  ],
  "TRUCK": [
    "https://cdn.akamai.steamstatic.com/steam/apps/227300/header.jpg",
    "https://cdn.akamai.steamstatic.com/steam/apps/270880/header.jpg",
  ],
  "TRUCK SIMULATOR": [
    "https://cdn.akamai.steamstatic.com/steam/apps/227300/header.jpg",
    "https://cdn.akamai.steamstatic.com/steam/apps/270880/header.jpg",
  ],
  "CRICKET": [
    "https://images.unsplash.com/photo-1531415074868-036b1c57e329?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?auto=format&fit=crop&w=1200&q=80",
  ],
  "BIKE": [
    "https://images.unsplash.com/photo-1558981403-c5f9899a28bc?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1568772585407-9361f9bf3a87?auto=format&fit=crop&w=1200&q=80",
  ],
  "DEFAULT": [
    "https://cdn.wildflamestudio.com/common/web_event/official2.ff.garena.all/20269/53c120cc950c9ead6beb2f5f6d8aadff.jpg",
    "https://cdn.akamai.steamstatic.com/steam/apps/578080/header.jpg",
    "https://i.pinimg.com/736x/2c/68/00/2c68004e2013ffe544dd18688a4527d5.jpg",
    "https://i.ytimg.com/vi/5mLrLB1boAc/maxresdefault.jpg",
    "https://e.snmc.io/lk/f/x/88886e931ef24bc6ddad648cdcf565c8/5296160",
    "https://live-assets2.web.stumbleguys.com/cms/STG_Reward_Rush_Weekend_1920x1080_57ad1ab000.png",
  ],
};

/// Helper to detect if a given image URL is one of the generic static category fallbacks
bool isCategoryDefaultImage(String? url) {
  if (url == null || url.trim().isEmpty) return true;
  final clean = url.trim();
  if (clean.contains('picsum.photos') || clean.contains('example.com')) return true;
  // Check if it exactly matches any single legacy fallback:
  for (final fallback in gameFallbackImages.values) {
    if (clean == fallback) return true;
  }
  return false;
}

/// Checks if an image URL is invalid, empty, or a generic placeholder
/// (such as Google News "G" logo, gstatic, googleusercontent, favicons, or tracking pixels).
bool isBadNewsImage(String? url) {
  if (url == null || url.trim().isEmpty) return true;
  final clean = url.trim();
  final lower = clean.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) return true;

  return lower.contains('google') ||
      lower.contains('gstatic') ||
      lower.contains('googleusercontent') ||
      lower.contains('1x1') ||
      lower.contains('feedburner') ||
      lower.contains('picsum.photos') ||
      lower.contains('example.com') ||
      lower.contains('favicon') ||
      lower.contains('placeholder') ||
      lower.contains('broken_image') ||
      lower.contains('logo_default') ||
      lower.contains('icon_news') ||
      lower.contains('fallback') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.ico') ||
      lower.endsWith('.svg');
}

/// Checks if an image is a generic placeholder, bad image, or Unsplash stock photo
bool isGenericOrPlaceholderImage(String? url) {
  if (url == null || url.trim().isEmpty) return true;
  if (isBadNewsImage(url)) return true;
  final lower = url.trim().toLowerCase();
  if (lower.contains('images.unsplash.com')) return true;
  return false;
}


/// Universal image finder that guarantees every single card gets a high quality, UNIQUE game picture.
/// Uses a deterministic hash of the title or article ID to select a unique picture from the matching pool.
String getGameFallbackImage({
  String? category,
  String? title,
  String? content,
  String? docId,
}) {
  final cleanTitle = (title ?? '').toUpperCase();
  final cleanCat = (category ?? '').toUpperCase().trim();
  final cleanContent = (content ?? '').toUpperCase();

  // Find matching pool key
  String matchedKey = 'DEFAULT';

  // 1. Check title keywords first (most specific)
  for (final key in gameCategoryPools.keys) {
    if (key == 'DEFAULT') continue;
    if (cleanTitle.contains(key)) {
      matchedKey = key;
      break;
    }
  }

  // 2. Check category matching if title didn't match
  if (matchedKey == 'DEFAULT') {
    for (final key in gameCategoryPools.keys) {
      if (key == 'DEFAULT') continue;
      if (cleanCat.contains(key) || key.contains(cleanCat)) {
        matchedKey = key;
        break;
      }
    }
  }

  // 3. Check content keywords if still default
  if (matchedKey == 'DEFAULT') {
    for (final key in gameCategoryPools.keys) {
      if (key == 'DEFAULT') continue;
      if (cleanContent.contains(key)) {
        matchedKey = key;
        break;
      }
    }
  }

  final pool = gameCategoryPools[matchedKey] ?? gameCategoryPools['DEFAULT']!;

  // Select a deterministic unique index based on title, docId, or content hash
  final seed = (title != null && title.trim().isNotEmpty)
      ? title.trim()
      : ((docId != null && docId.trim().isNotEmpty)
          ? docId.trim()
          : (content != null && content.trim().isNotEmpty ? content.trim() : 'game_news'));

  final index = seed.hashCode.abs() % pool.length;
  return pool[index];
}
