import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://dxdkitnroypbblazblja.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_gL8ImGd6TS-gdPOr92leHQ_Cwjiw25Y';

  /// Web Client ID from Google Cloud Console (OAuth 2.0 Client IDs -> Web application)
  /// Used for Native Google Sign-In with Supabase (signInWithIdToken).
  static const String webClientId = '713301178464-t3qotjr5fice17jfgbm0av73o0c0im3c.apps.googleusercontent.com';

  static final SupabaseClient _fallbackClient = SupabaseClient(supabaseUrl, supabaseAnonKey);

  static SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return _fallbackClient;
    }
  }
  static SupabaseClient get _supabase => client;

  static String toUuid(String id) {
    final clean = id.trim();
    if (clean.isEmpty) return '00000000-0000-0000-0000-000000000000';
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(clean)) return clean.toLowerCase();
    final bytes = md5.convert(utf8.encode(clean)).bytes;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
    } catch (e) {
      debugPrint('Supabase initialize warning: $e');
    }
  }

  static const String bucketAvatars = 'avatars';
  static const String bucketCovers = 'covers';
  static const String bucketPosts = 'posts';
  static const String bucketTeamLogos = 'team-logos';
  static const String bucketScreenshots = 'screenshots';
  static const String bucketUploads = 'posts';
  static const String bucketMatchProofs = 'screenshots';

  static String? lastBanError;

  static Map<String, String> get _headers {
    String token = supabaseAnonKey;
    try {
      final accessToken = client.auth.currentSession?.accessToken;
      if (accessToken != null && accessToken.trim().isNotEmpty) {
        token = accessToken.trim();
      }
    } catch (_) {}
    return {
      'apikey': supabaseAnonKey,
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // STEAM & ALL 14 APP GAMES NEWS METHODS (30-MINUTE AUTO CYCLE)
  // ============================================================
  static List<Map<String, dynamic>> _cachedMergedNews = [];
  static DateTime? _lastNewsMemoryFetch;
  static bool _isSyncing14Games = false;
  static DateTime? _last14GamesSyncTime;

  /// All 14 games present in GamesScreen
  static const List<Map<String, String>> all14AppGamesSpecs = [
    {
      'gameName': 'Free Fire',
      'category': 'Battle Royale',
      'imageUrl': 'https://cdn.wildflamestudio.com/common/web_event/official2.ff.garena.all/20269/53c120cc950c9ead6beb2f5f6d8aadff.jpg',
      'rssQuery': '%22Free+Fire%22+Garena+update+OR+event+OR+OB',
      'defaultTitleEn': 'Garena Free Fire Latest OB Update: New Character Abilities, Weapon Balance & Booyah Pass Rewards',
      'defaultTitleUr': 'گرینا فری فائر نئی OB اپ ڈیٹ: نئے کریکٹر ایبیلیٹیز، ویپن بیلنس اور بویاہ پاس ریوارڈز جاری',
      'defaultDescEn':
          'Garena Free Fire has rolled out its latest seasonal patch and Booyah Pass updates for Battle Royale and Clash Squad players. The update introduces tactical weapon balance adjustments, character skill cooldown refinements, and anti-cheat enhancements across ranked servers.\n\nPlayers participating in daily Free Fire custom rooms, squad matches, and weekly team leaderboards can unlock new seasonal bundles, weapon skins, and event rewards during this 30-minute live update cycle.',
      'defaultDescUr':
          'گرینا فری فائر نے بیٹل رائل اور کلیش اسکواڈ کھلاڑیوں کے لیے اپنی تازہ ترین سیزنل پیچ اور بویاہ پاس اپ ڈیٹس جاری کر دی ہیں۔ اس اپ ڈیٹ میں ویپن بیلنس، کریکٹر اسکلز اور رینکڈ سرورز کے لیے نئے فیچرز شامل کیے گئے ہیں۔',
    },
    {
      'gameName': 'PUBG Mobile',
      'category': 'Battle Royale',
      'imageUrl': 'https://cdn.akamai.steamstatic.com/steam/apps/578080/header.jpg',
      'rssQuery': '%22PUBG+Mobile%22+OR+BGMI+update+OR+Royale+Pass+OR+esports',
      'defaultTitleEn': 'PUBG Mobile Latest Season & Royale Pass Update: New Themed Mode, Erangel Changes & Esports News',
      'defaultTitleUr': 'پب جی موبائل نئے سیزن اور رائل پاس کی اپ ڈیٹ: نیا تھیمڈ موڈ، ارینگل تبدیلیاں اور ای اسپورٹس خبریں',
      'defaultDescEn':
          'PUBG Mobile continues to expand its competitive Battle Royale experience with new themed gameplay mechanics, vehicle handling improvements, and Royale Pass mythic rewards. Squads dropping into Erangel, Livik, and Miramar will notice smoother frame stability and updated loot distribution in high-tier zones.\n\nCompetitive teams and tournament contenders can now test the latest weapon recoil tuning and seasonal ranked milestones.',
      'defaultDescUr':
          'پب جی موبائل نے نئے تھیمڈ موڈ، گاڑیوں کے بہتر کنٹرول اور رائل پاس کے نئے انعامات کے ساتھ اپنی تازہ ترین اپ ڈیٹ جاری کر دی ہے۔ ارینگل، لیوک اور میرامار میں اسکواڈز کو مزیدبہتر فریم ریٹ اور نیا لوٹ سسٹم ملے گا۔',
    },
    {
      'gameName': 'Call Of Duty',
      'category': 'FPS / Shooting',
      'imageUrl': 'https://i.pinimg.com/736x/2c/68/00/2c68004e2013ffe544dd18688a4527d5.jpg',
      'rssQuery': '%22Call+of+Duty+Mobile%22+OR+%22Call+of+Duty%22+season+update',
      'defaultTitleEn': 'Call of Duty Mobile & Warzone New Season Update: Multiplayer Maps, Loadout Meta & Ranked Rewards',
      'defaultTitleUr': 'کال آف ڈیوٹی موبائل اور وارزون نیا سیزن اپ ڈیٹ: نئے ملٹی پلیئر میپس، لوڈ آؤٹ میٹا اور رینکڈ انعامات',
      'defaultDescEn':
          'Call of Duty brings a fresh wave of multiplayer and Battle Royale content with new tactical maps, operator skills, and weapon blueprint rewards. SMG and assault rifle attachments have been rebalanced for competitive ranked play.\n\nPlayers can jump into seasonal playlists, complete weekly clan and squad challenges, and climb the ranked tiers for exclusive Call of Duty rewards.',
      'defaultDescUr':
          'کال آف ڈیوٹی کے نئے سیزن میں نئے ملٹی پلیئر میپس، آپریٹر اسکلز اور ویپن بلیو پرنٹس شامل کیے گئے ہیں۔ رینکڈ میچز کے لیے گنز اور اٹیچمنٹس کو مزید متوازن بنایا گیا ہے۔',
    },
    {
      'gameName': 'Clash Royale',
      'category': 'Strategy Games',
      'imageUrl': 'https://e.snmc.io/lk/f/x/88886e931ef24bc6ddad648cdcf565c8/5296160',
      'rssQuery': '%22Clash+Royale%22+Supercell+card+evolution+OR+balance+update',
      'defaultTitleEn': 'Clash Royale Latest Balance Changes & Card Evolution Meta: Top Ladder Decks and Arena Events',
      'defaultTitleUr': 'کلیش رائل نئی بیلنس اپ ڈیٹ اور کارڈ ایوولوشن میٹا: ٹاپ لیڈر ڈیکس اور ارینا ایونٹس',
      'defaultDescEn':
          'Supercell has released the latest Clash Royale arena balance update, shaking up the competitive 1v1 and 2v2 deck meta with new Card Evolutions and elixir adjustments. Path of Legends and Trophy Road players are adapting to faster cycle decks and upgraded tower troop strategies.\n\nJoin the latest seasonal challenges and tournament events to earn Evolution Shards, chests, and banner tokens.',
      'defaultDescUr':
          'سپر سیل نے کلیش رائل کی تازہ ترین بیلنس اپ ڈیٹ اور کارڈ ایوولوشن تبدیلیاں جاری کر دی ہیں جن سے ٹرافی روڈ اور پاتھ آف لیجنڈز کے ٹاپ ڈیکس میں نیا مقابلہ شروع ہو گیا ہے۔',
    },
    {
      'gameName': 'Candy Crush',
      'category': 'Offline Games',
      'imageUrl': 'https://m.media-amazon.com/images/S/compressed.photo.goodreads.com/books/1425327952i/25054190.jpg',
      'rssQuery': '%22Candy+Crush+Saga%22+OR+%22Candy+Crush%22+King+update+OR+tournament',
      'defaultTitleEn': 'Candy Crush Saga New Episode Levels, All Stars Tournament Qualifier & Sweet Booster Events Live',
      'defaultTitleUr': 'کینڈی کرش ساگا نئے ایپیسوڈ لیولز، آل اسٹارز ٹورنامنٹ اور خصوصی بوسٹر ایونٹس لائیو',
      'defaultDescEn':
          'King has added brand-new episode stages and limited-time Sweet Streak booster challenges to Candy Crush Saga. Millions of puzzle players are competing on the weekly Episode Race leaderboards to collect Gold Bars, Color Bombs, and Party Boosters.\n\nLog in to clear the newest Candy Kingdom chapters and participate in special seasonal collection events.',
      'defaultDescUr':
          'کینڈی کرش ساگا میں نئے ایپیسوڈ لیولز اور خصوصی بوسٹر چیلنجز شامل کر دیے گئے ہیں۔ کھلاڑی ہفتہ وار ایپیسوڈ ریس جیت کر گولڈ بارز اور کلر بم بوسٹرز حاصل کر سکتے ہیں۔',
    },
    {
      'gameName': 'Garena Free Fire Max',
      'category': 'Battle Royale',
      'imageUrl': 'https://i.pinimg.com/736x/9c/d7/47/9cd74769ab0b1ca1b7a7a4a06e33f402.jpg',
      'rssQuery': '%22Free+Fire+MAX%22+Garena+update+OR+Craftland+OR+event',
      'defaultTitleEn': 'Garena Free Fire MAX Ultra HD Update: Firelink Sync, Craftland Custom Rooms & Diamond Events',
      'defaultTitleUr': 'گرینا فری فائر میکس الٹرا ایچ ڈی اپ ڈیٹ: کرافٹ لینڈ کسٹم رومز، فائر لنک اور ڈائمنڈ ایونٹس',
      'defaultDescEn':
          'Garena Free Fire MAX delivers enhanced Ultra HD visual effects, upgraded weapon reload animations, and new Craftland custom room templates. With Firelink technology, Free Fire MAX players can seamlessly squad up with standard Free Fire teammates across all ranked modes.\n\nExplore the latest Free Fire MAX lobby customization features and seasonal Evo Gun skin events.',
      'defaultDescUr':
          'گرینا فری فائر میکس کی نئی اپ ڈیٹ میں الٹرا ایچ ڈی گرافکس، بہتر ویپن اینیمیشنز اور نئے کرافٹ لینڈ کسٹم روم فیچرز شامل کیے گئے ہیں جن سے اسکواڈ گیم پلے مزید شاندار ہو گیا ہے۔',
    },
    {
      'gameName': 'Clash of Clans',
      'category': 'Strategy Games',
      'imageUrl': 'https://m.media-amazon.com/images/M/MV5BYWY0OTUyOGYtYjM5NC00ODAyLTkwYzYtNWVlMzI4ZDkxMjA4XkEyXkFqcGc@._V1_.jpg',
      'rssQuery': '%22Clash+of+Clans%22+Supercell+Town+Hall+OR+Clan+War+update',
      'defaultTitleEn': 'Clash of Clans Latest Update: Hero Equipment Meta, Clan War League Strategies & Town Hall Upgrades',
      'defaultTitleUr': 'کلیش آف کلینز تازہ ترین اپ ڈیٹ: ہیرو ایکوئپمنٹ، کلین وار لیگ اور ٹاؤن ہال اپ گریڈز',
      'defaultDescEn':
          'Clash of Clans continues to evolve base-building and Clan War strategies with new Hero Equipment abilities, troop level upgrades, and defensive building balance changes. Chiefs preparing for Clan War Leagues and Capital Raids can now deploy new attack combinations.\n\nCheck out the latest Trader shop deals, Gold Pass perks, and Clan Games reward tiers this week.',
      'defaultDescUr':
          'کلیش آف کلینز میں نئے ہیرو ایکوئپمنٹ، ٹروپ اپ گریڈز اور کلین وار لیگ کے لیے نئی اسٹریٹجی تبدیلیاں متعارف کرائی گئی ہیں جن سے بیس اٹیک اور ڈیفنس مزید دلچسپ ہو گیا ہے۔',
    },
    {
      'gameName': 'Minecraft',
      'category': 'Adventure Games',
      'imageUrl': 'https://thumbs.dreamstime.com/b/minecraft-logo-online-game-dirt-block-illustrations-concept-design-isolated-186775550.jpg',
      'rssQuery': '%22Minecraft%22+Mojang+Bedrock+OR+Java+update+OR+snapshot',
      'defaultTitleEn': 'Minecraft Bedrock & Java Edition Latest Update: New Biome Features, Trial Chambers & Mob Changes',
      'defaultTitleUr': 'مائن کرافٹ بیڈراک اور جاوا ایڈیشن کی نئی اپ ڈیٹ: نئے بائیوم فیچرز، ٹرائل چیمبرز اور موب تبدیلیاں',
      'defaultDescEn':
          'Mojang Studios has released new features and performance improvements across Minecraft Bedrock and Java Editions. Builders and survival adventurers can explore expanded Trial Chambers, craft new Redstone contraptions, and test updated combat mechanics on multiplayer servers.\n\nCross-platform realms and community mod packs continue to bring new survival and creative experiences.',
      'defaultDescUr':
          'مائن کرافٹ بیڈراک اور جاوا ایڈیشن میں نئے بائیوم فیچرز، ٹرائل چیمبرز اور ملٹی پلیئر سرورز کے لیے پرفارمنس اپ ڈیٹس جاری کر دی گئی ہیں۔',
    },
    {
      'gameName': 'eFootball',
      'category': 'Sports Games',
      'imageUrl': 'https://i.ytimg.com/vi/5mLrLB1boAc/maxresdefault.jpg',
      'rssQuery': '%22eFootball%22+Konami+OR+%22EA+Sports+FC%22+football+update',
      'defaultTitleEn': 'eFootball Latest Season Update: Dream Team Epic Showtime Players, Match Pass & Co-op Football Events',
      'defaultTitleUr': 'ای فٹبال (eFootball) نیا سیزن اپ ڈیٹ: ڈریم ٹیم ایپک کھلاڑی، میچ پاس اور کوآپ فٹبال ایونٹس',
      'defaultDescEn':
          'Konami’s eFootball brings fresh weekly live player ratings, Epic and Showtime card packs, and improved dribbling and passing responsiveness for football fans. Dream Team managers can compete in Division PvP leagues and Co-op match rooms to earn eFootball Coins and Skill Trainers.\n\nUpdated club kits, stadium atmospheres, and tactical manager boosts are now live across mobile and console.',
      'defaultDescUr':
          'ای فٹبال (eFootball) میں نئے ڈریم ٹیم ایپک کارڈز، ہفتہ وار لائیو پلیئر ریٹنگز اور بہتر ڈربلنگ و پاسنگ کنٹرولز کے ساتھ نئے فٹبال ایونٹس شامل کر دیے گئے ہیں۔',
    },
    {
      'gameName': 'Asphalt 9',
      'category': 'Racing Games',
      'imageUrl': 'https://www.cybersmile.org/wp-content/uploads/2022/09/Cybersmile-x-Asphalt-9-NFT-Fundraising-campaign-announcement.png',
      'rssQuery': '%22Asphalt+9%22+OR+%22Asphalt+Legends+Unite%22+Gameloft+update',
      'defaultTitleEn': 'Asphalt 9 Legends Unite Update: New S-Class Hypercars, Cross-Play Multiplayer & Grand Prix Events',
      'defaultTitleUr': 'ایسفالٹ 9 لیجنڈز یونائٹ اپ ڈیٹ: نئی S-Class ہائپر کارز، کراس پلے ملٹی پلیئر اور گراں پری ایونٹس',
      'defaultDescEn':
          'Asphalt 9: Legends (Asphalt Legends Unite) revs up arcade racing with new S-Class and A-Class hypercar blueprints, dynamic track lighting, and cross-platform multiplayer clubs. Racers can compete in time-limited Grand Prix qualifiers and Car Hunt events to unlock rare decals and nitro upgrades.\n\nTeam up with your racing club to climb the seasonal reputation leaderboards.',
      'defaultDescUr':
          'ایسفالٹ 9 لیجنڈز میں نئی ہائپر کارز، کراس پلے ملٹی پلیئر ریسنگ اور گراں پری ایونٹس شروع ہو چکے ہیں جہاں کھلاڑی نئی کار بلیو پرنٹس ان لاک کر سکتے ہیں۔',
    },
    {
      'gameName': 'Brawl Stars',
      'category': 'Action Games',
      'imageUrl': 'https://cdna.artstation.com/p/assets/images/images/016/603/776/large/nebojsa-bosnjak-brawl-stars-logo.jpg?1552776881',
      'rssQuery': '%22Brawl+Stars%22+Supercell+Brawl+Talk+OR+Hypercharge+update',
      'defaultTitleEn': 'Brawl Stars Latest Brawl Talk Update: New Brawlers, Hypercharge Abilities & Ranked Season Skins',
      'defaultTitleUr': 'برال اسٹارز نئی برال ٹاک اپ ڈیٹ: نئے برالرز، ہائپر چارج ایبیلیٹیز اور رینکڈ سیزن اسکنز',
      'defaultDescEn':
          'Brawl Stars kicks off an action-packed season featuring newly released Brawlers, explosive Hypercharge supers, and 3v3 Gem Grab, Brawl Ball, and Showdown map rotations. Supercell has also tuned Ranked matchmaking and Mega Pig club rewards.\n\nComplete daily quests to unlock Starr Drops, Bling, and exclusive Brawl Pass skins.',
      'defaultDescUr':
          'برال اسٹارز کے نئے سیزن میں نئے برالرز، ہائپر چارج سپرز اور 3v3 برال بال و شو ڈاؤن کے نئے میپس اور اسٹار ڈراپ انعامات شامل کیے گئے ہیں۔',
    },
    {
      'gameName': 'Stumble Guys',
      'category': 'Multiplayer Games',
      'imageUrl': 'https://live-assets2.web.stumbleguys.com/cms/STG_Reward_Rush_Weekend_1920x1080_57ad1ab000.png',
      'rssQuery': '%22Stumble+Guys%22+Scopely+update+OR+map+OR+tournament',
      'defaultTitleEn': 'Stumble Guys New Knockout Maps, Special Emotes, Workshop Levels & Tournament Rewards Update',
      'defaultTitleUr': 'اسٹمبل گائز نئے ناک آؤٹ میپس، اسپیشل ایموٹس، ورکشاپ لیولز اور ٹورنامنٹ ریوارڈز اپ ڈیٹ',
      'defaultDescEn':
          'Stumble Guys brings chaotic 32-player party knockout action with brand-new obstacle elimination maps, Mythic Stumbler skins, and Ranked ability tokens. Players can also design and share custom obstacle courses in the Stumble Workshop.\n\nJump into Custom Party rooms with friends or compete in weekend Crown Rush tournaments.',
      'defaultDescUr':
          'اسٹمبل گائز کی نئی اپ ڈیٹ میں 32 کھلاڑیوں کے لیے نئے ناک آؤٹ میپس، میتھک اسکنز اور کسٹم پارٹی رومز کے نئے ٹورنامنٹ ایونٹس شامل کیے گئے ہیں۔',
    },
    {
      'gameName': 'Ludo',
      'category': 'Multiplayer Games',
      'imageUrl': 'https://static0.gamerantimages.com/wordpress/wp-content/uploads/2025/03/mixcollage-05-mar-2025-09-03-am-8578.jpg',
      'rssQuery': '%22Ludo+King%22+OR+%22Ludo%22+mobile+game+update+OR+tournament',
      'defaultTitleEn': 'Ludo King & Multiplayer Ludo Update: Quick Mode Tournaments, Voice Chat Rooms & New Dice Themes',
      'defaultTitleUr': 'لوڈو کنگ اور ملٹی پلیئر لوڈو اپ ڈیٹ: کوئیک موڈ ٹورنامنٹس، وائس چیٹ رومز اور نئے ڈائس تھیمز',
      'defaultDescEn':
          'Ludo continues to dominate casual multiplayer gaming with fast-paced Quick Ludo matches, 4-player voice chat rooms, and seasonal dice and board themes. Players can challenge friends in private room codes or climb the global weekly Ludo coin leaderboards.\n\nNew anti-disconnect protection and tournament Streak rewards are now active for all Ludo players.',
      'defaultDescUr':
          'لوڈو ملٹی پلیئر میں کوئیک موڈ ٹورنامنٹس، 4 پلیئر وائس چیٹ رومز اور نئے ڈائس و بورڈ تھیمز شامل کیے گئے ہیں جہاں کھلاڑی دوستوں کے ساتھ پرائیویٹ رومز میں مقابلہ کر سکتے ہیں۔',
    },
    {
      'gameName': '8 Ball Pool',
      'category': 'Sports Games',
      'imageUrl': 'https://static0.gamerantimages.com/wordpress/wp-content/uploads/2025/03/mixcollage-05-mar-2025-09-05-am-9226.jpg?w=1200&h=1200&fit=crop',
      'rssQuery': '%228+Ball+Pool%22+Miniclip+Pool+Pass+OR+cue+OR+tournament+update',
      'defaultTitleEn': '8 Ball Pool Latest Pool Pass Season: Legendary Cues, Championship Rings & High-Stakes Table Events',
      'defaultTitleUr': '8 بال پول نیا پول پاس سیزن: لیجنڈری کیوز، چیمپئن شپ رنگز اور ہائی اسٹیکس ٹیبل ایونٹس',
      'defaultDescEn':
          'Miniclip’s 8 Ball Pool launches its newest Pool Pass season with high-stat Legendary Cues, exclusive Championship Rings, and special 9-Ball and Cushion Shot tables. Cue sports fans can test their spin and bank-shot accuracy in tournament brackets and club leagues.\n\nWin streak challenges and daily lucky shots offer bonus Pool Coins and Cue pieces every 30-minute cycle.',
      'defaultDescUr':
          '8 بال پول کے نئے پول پاس سیزن میں نئی لیجنڈری کیوز، چیمپئن شپ رنگز اور خصوصی ٹورنامنٹ ٹیبلز متعارف کرائے گئے ہیں جہاں کھلاڑی بڑے انعامات جیت سکتے ہیں۔',
    },
  ];

  static String? detect14AppGameName(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('free fire max') || lower.contains('ff max')) return 'Garena Free Fire Max';
    if (lower.contains('free fire') || lower.contains('freefire')) return 'Free Fire';
    if (lower.contains('pubg') || lower.contains('bgmi')) return 'PUBG Mobile';
    if (lower.contains('call of duty') || lower.contains('cod mobile') || lower.contains('warzone')) return 'Call Of Duty';
    if (lower.contains('clash royale')) return 'Clash Royale';
    if (lower.contains('candy crush')) return 'Candy Crush';
    if (lower.contains('clash of clans')) return 'Clash of Clans';
    if (lower.contains('minecraft')) return 'Minecraft';
    if (lower.contains('efootball') || lower.contains('pes ') || lower.contains('football') || lower.contains('ea sports fc') || lower.contains('fifa')) return 'eFootball';
    if (lower.contains('asphalt')) return 'Asphalt 9';
    if (lower.contains('brawl stars')) return 'Brawl Stars';
    if (lower.contains('stumble guys')) return 'Stumble Guys';
    if (lower.contains('ludo')) return 'Ludo';
    if (lower.contains('8 ball pool') || lower.contains('8ball pool')) return '8 Ball Pool';
    return null;
  }

  /// Build guaranteed latest news items for all 14 app games aligned with the current 30-minute auto-build slot
  static List<Map<String, dynamic>> _build14AppGamesCycleArticles() {
    final nowUtc = DateTime.now().toUtc();
    // 30-minute slot timestamp so timestamps stay stable within each 30-min cycle and refresh every 30 mins
    final int slot30MinEpochSec =
        ((nowUtc.millisecondsSinceEpoch ~/ (30 * 60 * 1000)) * (30 * 60));
    final List<Map<String, dynamic>> items = [];

    for (int i = 0; i < all14AppGamesSpecs.length; i++) {
      final spec = all14AppGamesSpecs[i];
      final String gameName = spec['gameName']!;
      final String category = spec['category']!;
      final String imageUrl = spec['imageUrl']!;
      final String titleEn = spec['defaultTitleEn']!;
      final String titleUr = spec['defaultTitleUr']!;
      final String descEn = spec['defaultDescEn']!;
      final String descUr = spec['defaultDescUr']!;

      // Offset each game by a few minutes within the current 30-minute window so they interleave naturally
      final int itemEpochSec = slot30MinEpochSec - (i * 110);
      final String isoDate =
          DateTime.fromMillisecondsSinceEpoch(itemEpochSec * 1000, isUtc: true)
              .toIso8601String();
      final String uuidId = toUuid('app14_cycle_${gameName}_$slot30MinEpochSec');

      items.add({
        'id': uuidId,
        'title': titleUr,
        'title_en': titleEn,
        'title_ur': titleUr,
        'description': descEn,
        'content_en': descEn,
        'description_ur': descUr,
        'shortDescription': descEn.split('\n\n').first,
        'titleMap': {'en': titleEn, 'ur': titleUr, 'ro': titleEn},
        'descriptionMap': {'en': descEn, 'ur': descUr, 'ro': descEn},
        'imageUrl': imageUrl,
        'image_url': imageUrl,
        'created_at': isoDate,
        'published_at': isoDate,
        'url': '',
        'sourceUrl': '',
        'gameName': gameName,
        'game': gameName,
        'category': category,
        'timestamp': itemEpochSec,
        'timeAgo': isoDate,
        'views': 180 + ((i * 73) % 640),
        'isFeatured': false,
        'isAuto': true,
        'isFree': true,
        'source': gameName,
        'appId': 0,
        'appid': 0,
      });
    }
    return items;
  }

  /// Background 30-minute auto-fetcher for all 14 app games.
  /// Runs asynchronously without blocking UI or slowing down any screen.
  static Future<void> syncAll14AppGamesNewsInBackground({bool force = false}) async {
    if (_isSyncing14Games) return;
    final now = DateTime.now();
    if (!force &&
        _last14GamesSyncTime != null &&
        now.difference(_last14GamesSyncTime!).inMinutes < 28) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final int lastMs = prefs.getInt('last_14_games_auto_sync_ms') ?? 0;
      if (!force &&
          lastMs > 0 &&
          now.millisecondsSinceEpoch - lastMs < 28 * 60 * 1000) {
        _last14GamesSyncTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
        return;
      }

      _isSyncing14Games = true;
      _last14GamesSyncTime = now;
      await prefs.setInt('last_14_games_auto_sync_ms', now.millisecondsSinceEpoch);

      // Fetch live Google News RSS for the 14 games in a single combined lightweight request
      final combinedRssUrl = Uri.parse(
        'https://news.google.com/rss/search?q=%22Free+Fire%22+OR+%22Free+Fire+MAX%22+OR+%22PUBG+Mobile%22+OR+%22Call+of+Duty+Mobile%22+OR+%22Clash+Royale%22+OR+%22Candy+Crush%22+OR+%22Clash+of+Clans%22+OR+%22Minecraft%22+OR+%22eFootball%22+OR+%22Asphalt+9%22+OR+%22Brawl+Stars%22+OR+%22Stumble+Guys%22+OR+%22Ludo+King%22+OR+%228+Ball+Pool%22&hl=en-US&gl=US&ceid=US:en',
      );

      final res = await http
          .get(
            combinedRssUrl,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/122.0.0.0 Mobile Safari/537.36',
              'Accept': 'application/rss+xml, application/xml, text/xml, */*',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final itemReg = RegExp(r'<item[\s\S]*?<\/item>', caseSensitive: false);
        final matches = itemReg.allMatches(res.body).take(20);
        for (final m in matches) {
          final block = m.group(0) ?? '';
          if (block.isEmpty) continue;
          final titleMatch =
              RegExp(r'<title[^>]*>([\s\S]*?)<\/title>', caseSensitive: false)
                  .firstMatch(block);
          final linkMatch =
              RegExp(r'<link[^>]*>([\s\S]*?)<\/link>', caseSensitive: false)
                  .firstMatch(block);
          final pubDateMatch =
              RegExp(r'<pubDate[^>]*>([\s\S]*?)<\/pubDate>', caseSensitive: false)
                  .firstMatch(block);

          String rawTitle = (titleMatch?.group(1) ?? '')
              .replaceAll('<![CDATA[', '')
              .replaceAll(']]>', '')
              .replaceAll('&amp;', '&')
              .replaceAll('&quot;', '"')
              .replaceAll('&#39;', "'")
              .replaceAll(RegExp(r'\s*-\s*[^-]+$'), '')
              .trim();
          final String link = (linkMatch?.group(1) ?? '').trim();
          if (rawTitle.length < 12) continue;

          final String? matchedGame = detect14AppGameName(rawTitle);
          if (matchedGame == null) continue;

          final spec = all14AppGamesSpecs.firstWhere(
            (s) => s['gameName'] == matchedGame,
            orElse: () => all14AppGamesSpecs.first,
          );
          final String cat = spec['category'] ?? 'Multiplayer Games';
          final String fallbackImg = spec['imageUrl'] ?? '';
          final String baseDesc = spec['defaultDescEn'] ?? '';
          final String fullDesc = '$rawTitle\n\n$baseDesc';
          final String shortDesc =
              fullDesc.length > 260 ? '${fullDesc.substring(0, 260)}...' : fullDesc;

          DateTime pubDate = DateTime.now().toUtc();
          final String pubStr = (pubDateMatch?.group(1) ?? '').trim();
          if (pubStr.isNotEmpty) {
            try {
              pubDate = HttpDate.parse(pubStr).toUtc();
            } catch (_) {}
          }
          final String pubIso = pubDate.toIso8601String();
          final int pubTs = (pubDate.millisecondsSinceEpoch / 1000).floor();
          final String uuidId = toUuid('live14_${matchedGame}_$rawTitle');

          final payload = <String, dynamic>{
            'id': uuidId,
            'title': rawTitle,
            'description': fullDesc,
            'shortDescription': shortDesc,
            'titleMap': {'en': rawTitle, 'ur': rawTitle, 'ro': rawTitle},
            'descriptionMap': {'en': fullDesc, 'ur': fullDesc, 'ro': fullDesc},
            'imageUrl': fallbackImg,
            'image_url': fallbackImg,
            'created_at': pubIso,
            'published_at': pubIso,
            'url': link,
            'sourceUrl': link,
            'gameName': matchedGame,
            'category': cat,
            'timestamp': pubTs,
            'timeAgo': pubIso,
            'views': 140 + (rawTitle.hashCode.abs() % 420),
            'isFeatured': false,
            'isAuto': true,
            'isFree': false,
            'source': matchedGame,
            'appId': 0,
            'appid': 0,
          };

          try {
            await client
                .from('steam_news')
                .upsert(payload, onConflict: 'id')
                .timeout(const Duration(seconds: 3));
          } catch (_) {}
        }
      }
      // Invalidate memory cache so next read includes newly synced 14-game items
      _lastNewsMemoryFetch = null;
    } catch (e) {
      debugPrint('Background 14-games 30-min sync notice: $e');
    } finally {
      _isSyncing14Games = false;
    }
  }

  static Future<List<Map<String, dynamic>>> getSteamNews({
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    // Trigger non-blocking 30-minute background sync for all 14 games if due
    unawaited(syncAll14AppGamesNewsInBackground(force: false));

    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedMergedNews.isNotEmpty &&
        _lastNewsMemoryFetch != null &&
        now.difference(_lastNewsMemoryFetch!).inSeconds < 90) {
      return _cachedMergedNews.take(limit).toList();
    }

    List<Map<String, dynamic>> dbSteamNews = [];
    try {
      final res = await client
          .from('steam_news')
          .select('*')
          .not('description', 'is', null)
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 6));
      if (res is List) {
        dbSteamNews = List<Map<String, dynamic>>.from(res);
      }
    } catch (e) {
      debugPrint('Error fetching steam news from client: $e');
      try {
        dbSteamNews = await query(
          'steam_news',
          order: 'created_at.desc',
          limit: limit,
        );
      } catch (_) {}
    }

    // Track which of the 14 core app games already exist in dbSteamNews
    final Set<String> present14Games = {};
    for (final row in dbSteamNews) {
      final gName = (row['gameName'] ?? row['game'] ?? row['category'] ?? '').toString();
      final title = (row['title'] ?? '').toString();
      final detected = detect14AppGameName('$gName $title');
      if (detected != null) {
        present14Games.add(detected);
      }
    }

    // Ensure all 14 app games are present in the feed cycle alongside general gaming news
    final List<Map<String, dynamic>> cycle14Items = _build14AppGamesCycleArticles();
    final List<Map<String, dynamic>> missing14Items = cycle14Items
        .where((item) => !present14Games.contains(item['gameName']))
        .toList();

    // Interleave general news and the 14 app games so the feed shows a balanced mix
    final List<Map<String, dynamic>> merged = [];
    int generalIdx = 0;
    int app14Idx = 0;
    while (generalIdx < dbSteamNews.length || app14Idx < missing14Items.length) {
      // Add 2 general / DB news items
      for (int k = 0; k < 2 && generalIdx < dbSteamNews.length; k++) {
        merged.add(dbSteamNews[generalIdx++]);
      }
      // Add 1 of the 14 app games news items
      if (app14Idx < missing14Items.length) {
        merged.add(missing14Items[app14Idx++]);
      }
    }

    _cachedMergedNews = merged;
    _lastNewsMemoryFetch = now;
    return merged.take(limit).toList();
  }

  // STORAGE — Long-term proper solution using Supabase SDK
  static Future<String?> uploadFile({
    required File file,
    String? folder,
    String bucket = bucketUploads,
    String? customFileName,
  }) async {
    try {
      if (!await file.exists()) {
        debugPrint('❌ [uploadFile] File does not exist: ${file.path}');
        return null;
      }

      final fileBytes = await file.readAsBytes();
      final extension = file.path.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = customFileName ??
          'file_${timestamp}_${fileBytes.length}.$extension';
      final path =
          folder != null && folder.isNotEmpty ? '$folder/$fileName' : fileName;

      final mimeType = _getMimeType(extension);

      await _supabase.storage.from(bucket).uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: mimeType,
            ),
          );

      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(path);
      debugPrint('✅ [uploadFile] Success: $publicUrl');
      return publicUrl;
    } on StorageException catch (e) {
      debugPrint('❌ [uploadFile] StorageException: ${e.message}');
      debugPrint('❌ [uploadFile] StatusCode: ${e.statusCode}');
      debugPrint('❌ [uploadFile] Bucket: $bucket');
      return null;
    } catch (e) {
      debugPrint('❌ [uploadFile] Unknown error: $e');
      return null;
    }
  }

  static String _getMimeType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'image/jpeg';
    }
  }

  // AUTH
  static Future<Map<String, dynamic>?> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? userMetadata,
  }) async {
    try {
      final uri = Uri.parse('$supabaseUrl/auth/v1/signup');
      final body = {
        'email': email.trim(),
        'password': password,
        if (userMetadata != null) 'data': userMetadata,
      };
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _saveAuthToken(data);
        return data;
      } else {
        return {'error': data['error_description'] ?? data['msg'] ?? 'sign_up_failed'.tr()};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password');
      final body = {'email': email.trim(), 'password': password};
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await _saveAuthToken(data);
        return data;
      } else {
        return {'error': data['error_description'] ?? data['msg'] ?? 'login_failed'.tr()};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('supabase_access_token');
    if (token != null) {
      try {
        final uri = Uri.parse('$supabaseUrl/auth/v1/logout');
        await http.post(uri, headers: {..._headers, 'Authorization': 'Bearer $token'});
      } catch (e) {}
    }
    await prefs.remove('supabase_access_token');
    await prefs.remove('supabase_user_id');
  }

  static Future<void> _saveAuthToken(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['access_token'] != null) {
      await prefs.setString('supabase_access_token', data['access_token'].toString());
    }
    if (data['user'] != null && data['user']['id'] != null) {
      await prefs.setString('supabase_user_id', data['user']['id'].toString());
    }
  }

  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('supabase_user_id');
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('supabase_access_token');
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) {
      return {'apikey': supabaseAnonKey, 'Authorization': 'Bearer $token'};
    }
    return Map<String, String>.from(_headers);
  }

  // CRUD
  static Future<bool> insert(String table, Map<String, dynamic> row) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/$table');
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'return=representation'},
        body: jsonEncode(row),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> update(
    String table,
    Map<String, dynamic> row, [
    String? column,
    String? value,
    Map<String, String>? filters,
  ]) async {
    try {
      String queryParams = '';
      if (column != null && value != null) {
        queryParams = '$column=eq.$value';
      } else if (filters != null && filters.isNotEmpty) {
        queryParams = filters.entries.map((e) => '${e.key}=${e.value}').join('&');
      }
      final uri = Uri.parse('$supabaseUrl/rest/v1/$table?$queryParams');
      final response = await http.patch(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'return=representation'},
        body: jsonEncode(row),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> query(
    String table, {
    String select = '*',
    String? order,
    int? limit,
    Map<String, String>? filters,
  }) async {
    try {
      var queryParams = 'select=$select';
      if (order != null) queryParams += '&order=$order';
      if (limit != null) queryParams += '&limit=$limit';
      if (filters != null) {
        filters.forEach((k, v) {
          queryParams += '&$k=$v';
        });
      }
      final uri = Uri.parse('$supabaseUrl/rest/v1/$table?$queryParams');
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {}
    return [];
  }

  static Future<bool> delete(
    String table, [
    String? column,
    String? value,
    Map<String, String>? filters,
  ]) async {
    try {
      String queryParams = '';
      if (column != null && value != null) {
        queryParams = '$column=eq.$value';
      } else if (filters != null && filters.isNotEmpty) {
        queryParams = filters.entries.map((e) => '${e.key}=${e.value}').join('&');
      }
      final uri = Uri.parse('$supabaseUrl/rest/v1/$table?$queryParams');
      final response = await http.delete(uri, headers: _headers);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  // USERS
  static Future<bool> upsertUser(Map<String, dynamic> userData) async {
    try {
      final headers = await getAuthHeaders();
      final uri = Uri.parse('$supabaseUrl/rest/v1/users');
      final response = await http.post(
        uri,
        headers: {...headers, 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: jsonEncode(userData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getUser(String uid) async {
    final list = await query('users', filters: {'uid': 'eq.$uid'}, limit: 1);
    if (list.isNotEmpty) return list.first;
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(uid)) {
      final listById = await query('users', filters: {'id': 'eq.$uid'}, limit: 1);
      if (listById.isNotEmpty) return listById.first;
    }
    return null;
  }

  // POSTS
  static Future<Map<String, dynamic>?> savePost(Map<String, dynamic> postData) async {
    try {
      String? userId = postData['user_id']?.toString();
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (userId == null || !uuidRegex.hasMatch(userId)) {
        final currentSbId = await getCurrentUserId();
        if (currentSbId != null && uuidRegex.hasMatch(currentSbId)) {
          userId = currentSbId;
        } else {
          return null;
        }
      }
      final response = await _supabase.from('posts').insert({
        'user_id': userId,
        'content': postData['content'],
        'image_url': postData['image_url'],
        'video_url': postData['video_url'],
        'game': postData['game'] ?? 'all_games'.tr(),
        'media_url': postData['media_url'] ?? postData['image_url'] ?? postData['video_url'],
        'likes_count': 0,
        'comments_count': 0,
      }).select().single();
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getPosts({int limit = 50, String? gameFilter}) async {
    final Map<String, String> filters = {};
    if (gameFilter != null && gameFilter != 'All' && gameFilter != 'all_games'.tr()) {
      filters['game'] = 'eq.$gameFilter';
    }
    return await query('posts', filters: filters.isNotEmpty ? filters : null, order: 'created_at.desc', limit: limit);
  }

  // LIKES
  static Future<bool> toggleLike({required String postId, required String userId, String? username}) async {
    try {
      final existing = await query('likes', filters: {'post_id': 'eq.$postId', 'user_id': 'eq.$userId'}, limit: 1);
      if (existing.isNotEmpty) {
        final delUri = Uri.parse('$supabaseUrl/rest/v1/likes?post_id=eq.$postId&user_id=eq.$userId');
        await http.delete(delUri, headers: _headers);
        return false;
      } else {
        await insert('likes', {
          'post_id': postId,
          'user_id': userId,
          if (username != null) 'username': username,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isPostLiked(String postId, String userId) async {
    final existing = await query('likes', filters: {'post_id': 'eq.$postId', 'user_id': 'eq.$userId'}, limit: 1);
    return existing.isNotEmpty;
  }

  // COMMENTS
  static Future<bool> addComment({
    required String postId,
    required String userId,
    required String username,
    String? userAvatar,
    required String content,
  }) async {
    return await insert('comments', {
      'comment_id': 'c_${DateTime.now().millisecondsSinceEpoch}',
      'post_id': postId,
      'user_id': userId,
      'username': username,
      'user_avatar': userAvatar ?? '',
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    return await query('comments', filters: {'post_id': 'eq.$postId'}, order: 'created_at.asc');
  }

  // TEAMS
  static Future<bool> saveTeam(Map<String, dynamic> teamData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/teams');
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: jsonEncode(teamData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getTeams({String? gameFilter}) async {
    final Map<String, String> filters = {};
    if (gameFilter != null && gameFilter != 'All') {
      filters['game'] = 'eq.$gameFilter';
    }
    return await query('teams', filters: filters.isNotEmpty ? filters : null, order: 'created_at.desc');
  }

  static Future<Map<String, dynamic>?> getTeam(String teamId) async {
    final list = await query('teams', filters: {'team_id': 'eq.$teamId'}, limit: 1);
    return list.isNotEmpty ? list.first : null;
  }

  // TEAM MEMBERS
  static Future<bool> addTeamMember({
    required String teamId,
    required String userId,
    required String username,
    String? role,
  }) async {
    final effectiveRole = role ?? 'member'.tr();
    return await insert('team_members', {
      'team_id': teamId,
      'user_id': userId,
      'username': username,
      'role': effectiveRole,
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<bool> removeTeamMember(String teamId, String userId) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/team_members?team_id=eq.$teamId&user_id=eq.$userId');
      final resp = await http.delete(uri, headers: _headers);
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
    return await query('team_members', filters: {'team_id': 'eq.$teamId'}, order: 'joined_at.asc');
  }

  // TEAM JOIN REQUESTS
  static Future<bool> createTeamJoinRequest({
    required String teamId,
    String? teamName,
    required String userId,
    required String username,
    String? userAvatar,
  }) async {
    final tUuid = toUuid(teamId);
    final effectiveSupabaseUid = client.auth.currentUser?.id ?? toUuid(userId);
    try {
      await client.from('team_join_requests').insert({
        'team_id': tUuid,
        'user_id': effectiveSupabaseUid,
        'status': 'pending',
      });
      return true;
    } catch (e) {}
    return await insert('team_join_requests', {
      'team_id': tUuid,
      'user_id': effectiveSupabaseUid,
      'status': 'pending',
    });
  }

  static Future<bool> updateTeamJoinRequestStatus(String teamId, String userId, String status) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/team_join_requests?team_id=eq.$teamId&user_id=eq.$userId');
      final resp = await http.patch(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getTeamJoinRequests(String teamId) async {
    return await query('team_join_requests', filters: {'team_id': 'eq.$teamId', 'status': 'eq.pending'});
  }

  // TEAM MATCHES
  static Future<bool> upsertTeamMatch(Map<String, dynamic> matchData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/team_matches');
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: jsonEncode(matchData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getTeamMatches({String? status}) async {
    final Map<String, String> filters = {};
    if (status != null && status != 'All') {
      filters['status'] = 'eq.$status';
    }
    return await query('team_matches', filters: filters.isNotEmpty ? filters : null, order: 'match_time.desc');
  }

  static Future<Map<String, dynamic>?> getTeamMatch(String matchId) async {
    final list = await query('team_matches', filters: {'match_id': 'eq.$matchId'}, limit: 1);
    return list.isNotEmpty ? list.first : null;
  }

  // MATCH CHAT
  static Future<bool> sendMatchChatMessage({
    required String matchId,
    String? roomId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String message,
    String? imageUrl,
    String messageType = 'text',
  }) async {
    return await insert('match_chat', {
      'match_id': matchId,
      if (roomId != null) 'room_id': roomId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar ?? '',
      'message': message,
      if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      'message_type': messageType,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getMatchChat(String matchId, {int limit = 50}) async {
    return await query('match_chat', filters: {'match_id': 'eq.$matchId'}, order: 'created_at.asc', limit: limit);
  }

  // ROOMS
  static Future<bool> saveRoom(Map<String, dynamic> roomData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/rooms');
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: jsonEncode(roomData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getRooms({String? status, String? gameFilter}) async {
    final Map<String, String> filters = {};
    if (status != null && status != 'All') {
      filters['status'] = 'eq.$status';
    }
    if (gameFilter != null && gameFilter != 'All') {
      filters['game'] = 'eq.$gameFilter';
    }
    return await query('rooms', filters: filters.isNotEmpty ? filters : null, order: 'created_at.desc');
  }

  // ROOM MEMBERS
  static Future<bool> addRoomMember(Map<String, dynamic> memberData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/room_members');
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: jsonEncode(memberData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getRoomMembers(String roomId) async {
    return await query('room_members', filters: {'room_id': 'eq.$roomId'}, order: 'joined_at.asc');
  }

  // COIN TRANSACTIONS
  static Future<bool> recordCoinTransaction({
    required String userId,
    required int amount,
    required String type,
    String? description,
    int? balanceAfter,
    String? referenceId,
  }) async {
    return await insert('coin_transactions', {
      'user_id': userId,
      'amount': amount,
      'type': type,
      'description': description ?? '',
      if (balanceAfter != null) 'balance_after': balanceAfter,
      if (referenceId != null) 'reference_id': referenceId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getUserCoinTransactions(String userId, {int limit = 50}) async {
    return await query('coin_transactions', filters: {'user_id': 'eq.$userId'}, order: 'created_at.desc', limit: limit);
  }

  // NOTIFICATIONS
  static Future<bool> sendNotification(Map<String, dynamic> notifData) async {
    return await insert('notifications', {
      'user_id': notifData['userId'] ?? notifData['recipientUid'] ?? '',
      'title': notifData['title'] ?? '',
      'body': notifData['body'] ?? notifData['message'] ?? '',
      'type': notifData['type'] ?? 'general',
      if (notifData['data'] != null) 'data': notifData['data'],
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getUserNotifications(String userId, {int limit = 50}) async {
    return await query('notifications', filters: {'user_id': 'eq.$userId'}, order: 'created_at.desc', limit: limit);
  }

  // REALTIME STREAMS
  static Stream<List<Map<String, dynamic>>> getMatchChatStream(String matchId) {
    Stream<List<Map<String, dynamic>>> stream() async* {
      while (true) {
        final messages = await query(
          'match_chat',
          filters: {'match_id': 'eq.$matchId'},
          order: 'created_at.asc',
          limit: 50,
        );
        yield messages;
        await Future.delayed(const Duration(seconds: 12));
      }
    }

    return stream().asBroadcastStream();
  }

  static Stream<List<Map<String, dynamic>>> getChatMessagesStream(String roomId) => getMatchChatStream(roomId);

  static Stream<Map<String, dynamic>?> getTeamMatchStream(String matchId) {
    Stream<Map<String, dynamic>?> stream() async* {
      while (true) {
        final matches = await query(
          'team_matches',
          filters: {'match_id': 'eq.$matchId'},
          limit: 1,
        );
        yield matches.isNotEmpty ? matches.first : null;
        await Future.delayed(const Duration(seconds: 15));
      }
    }

    return stream().asBroadcastStream();
  }

  // ============================================================
  // ADMIN METHODS
  // ============================================================
  static Future<bool> isAdmin(String userId) async {
    try {
      final user = await query('users', filters: {'id': 'eq.$userId'}, limit: 1);
      if (user.isEmpty) return false;
      final data = user.first;
      return data['is_admin'] == true || data['isAdmin'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isCurrentUserAdmin() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;
      return await isAdmin(userId);
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, int>> getAdminStats() async {
    int totalUsers = 0;
    int totalPosts = 0;
    int totalReports = 0;
    int totalCoins = 0;

    try {
      final users = await query('users', select: 'id,coins', limit: 1000);
      totalUsers = users.length;
      for (final u in users) {
        totalCoins += (u['coins'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {}

    try {
      final posts = await query('posts', select: 'id', limit: 1000);
      totalPosts = posts.length;
    } catch (e) {}

    try {
      final reports = await query('reports', limit: 1000);
      totalReports = reports.where(isRealModerationReport).length;
    } catch (e) {}

    return {
      'totalUsers': totalUsers,
      'totalPosts': totalPosts,
      'totalReports': totalReports,
      'totalCoins': totalCoins,
    };
  }

  static bool _didCleanupStaleRedeemReports = false;

  /// Returns true only for genuine user/post moderation reports (filters out legacy REDEEM_REQUEST entries)
  static bool isRealModerationReport(Map<String, dynamic> r) {
    final reason = (r['reason'] ?? '').toString().trim().toUpperCase();
    final targetId = (r['target_id'] ?? '').toString().trim().toUpperCase();
    final targetType = (r['target_type'] ?? '').toString().trim().toUpperCase();
    final details = (r['details'] ?? '').toString().trim().toUpperCase();
    if (reason.contains('REDEEM_REQUEST') ||
        targetId.contains('REDEEM') ||
        targetType.contains('REDEEM') ||
        details.contains('REDEEM REQUEST:')) {
      return false;
    }
    return true;
  }

  /// Cleans up any legacy automatic REDEEM_REQUEST rows from the reports table once per session
  static Future<void> _cleanupStaleRedeemRequestReports() async {
    if (_didCleanupStaleRedeemReports) return;
    _didCleanupStaleRedeemReports = true;
    try {
      await client.from('reports').delete().eq('reason', 'REDEEM_REQUEST');
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getReports() async {
    await _cleanupStaleRedeemRequestReports();
    final rows = await query('reports', order: 'created_at.desc', limit: 100);
    return rows.where(isRealModerationReport).toList();
  }

  static Future<bool> updateReport({
    required String reportId,
    required String status,
  }) async {
    return await update('reports', {'status': status}, 'id', reportId);
  }

  static Future<bool> deleteReport(String reportId) async {
    return await delete('reports', 'id', reportId);
  }

  static Future<bool> banUser({
    required String userId,
    required String adminId,
    String? reason,
    String? username,
  }) async {
    return await _setUserBanStatus(
      userId: userId,
      isBanned: true,
      adminId: adminId,
      reason: reason ?? 'Violating community guidelines',
      username: username,
    );
  }

  static Future<bool> unbanUser(String userId, {String? username}) async {
    return await _setUserBanStatus(
      userId: userId,
      isBanned: false,
      username: username,
    );
  }

  static void _updateCachedUserBanState({
    required String userId,
    String? resolvedId,
    String? resolvedUid,
    String? username,
    required bool isBanned,
  }) {
    final cleanId = userId.trim();
    final uuidId = cleanId.isNotEmpty ? toUuid(cleanId) : '';
    final cleanUsername = (username ?? '').trim().replaceAll('@', '').toLowerCase();

    for (final row in _cachedUsers) {
      final rId = (row['id'] ?? '').toString().trim();
      final rUid = (row['uid'] ?? '').toString().trim();
      final rUser = (row['username'] ?? '').toString().trim().toLowerCase();

      final matchesId = (cleanId.isNotEmpty && (rId == cleanId || rUid == cleanId || rId == uuidId)) ||
          (resolvedId != null && resolvedId.isNotEmpty && (rId == resolvedId || rUid == resolvedId)) ||
          (resolvedUid != null && resolvedUid.isNotEmpty && (rId == resolvedUid || rUid == resolvedUid)) ||
          (cleanUsername.isNotEmpty && rUser == cleanUsername);

      if (matchesId) {
        row['is_banned'] = isBanned;
        row['isBanned'] = isBanned;
      }
    }
  }

  static Future<bool> _setUserBanStatus({
    required String userId,
    required bool isBanned,
    String? adminId,
    String? reason,
    String? username,
  }) async {
    lastBanError = null;
    final cleanId = userId.trim();
    final cleanUsername = (username ?? '').trim().replaceAll('@', '');
    final uuidId = cleanId.isNotEmpty ? toUuid(cleanId) : '';
    final nowIso = DateTime.now().toIso8601String();

    String? targetId;
    String? targetUid;

    // 1. Locate the exact user row so we know its real primary key `id` and `uid`
    try {
      Map<String, dynamic>? row;
      if (cleanId.isNotEmpty) {
        try {
          row = await client
              .from('users')
              .select('id, uid, username')
              .or('id.eq.$cleanId,uid.eq.$cleanId')
              .limit(1)
              .maybeSingle();
        } catch (_) {}

        if (row == null && uuidId.isNotEmpty && uuidId != cleanId) {
          try {
            row = await client
                .from('users')
                .select('id, uid, username')
                .or('id.eq.$uuidId,uid.eq.$uuidId')
                .limit(1)
                .maybeSingle();
          } catch (_) {}
        }
      }

      if (row == null && cleanUsername.isNotEmpty) {
        try {
          row = await client
              .from('users')
              .select('id, uid, username')
              .ilike('username', cleanUsername)
              .limit(1)
              .maybeSingle();
        } catch (_) {}
      }

      if (row != null) {
        final rawId = (row['id'] ?? '').toString().trim();
        final rawUid = (row['uid'] ?? '').toString().trim();
        if (rawId.isNotEmpty) targetId = rawId;
        if (rawUid.isNotEmpty) targetUid = rawUid;
      }
    } catch (e) {
      debugPrint('User lookup before ban update warning: $e');
    }

    // Build candidate column/value pairs to match the user row reliably
    final List<MapEntry<String, String>> matchTargets = [];
    if (targetId != null && targetId.isNotEmpty) {
      matchTargets.add(MapEntry('id', targetId));
    }
    if (targetUid != null && targetUid.isNotEmpty) {
      matchTargets.add(MapEntry('uid', targetUid));
      if (targetId == null) {
        matchTargets.add(MapEntry('id', targetUid));
      }
    }
    if (cleanId.isNotEmpty) {
      if (!matchTargets.any((e) => e.key == 'id' && e.value == cleanId)) {
        matchTargets.add(MapEntry('id', cleanId));
      }
      if (!matchTargets.any((e) => e.key == 'uid' && e.value == cleanId)) {
        matchTargets.add(MapEntry('uid', cleanId));
      }
      if (uuidId.isNotEmpty && uuidId != cleanId) {
        if (!matchTargets.any((e) => e.key == 'id' && e.value == uuidId)) {
          matchTargets.add(MapEntry('id', uuidId));
        }
      }
    }
    if (cleanUsername.isNotEmpty) {
      matchTargets.add(MapEntry('username', cleanUsername));
    }

    if (matchTargets.isEmpty) {
      lastBanError = 'User ID is missing';
      return false;
    }

    // 2. Perform core ban status update with ONLY core column (`is_banned`, fallback `isBanned`)
    // Avoid bundling non-existent optional columns in the core PATCH request.
    final List<Map<String, dynamic>> corePayloads = [
      {'is_banned': isBanned},
      {'isBanned': isBanned},
    ];

    bool updated = false;
    String? lastErr;

    for (final payload in corePayloads) {
      if (updated) break;
      for (final target in matchTargets) {
        try {
          final List<dynamic> res = await client
              .from('users')
              .update(payload)
              .eq(target.key, target.value)
              .select('id');
          if (res.isNotEmpty) {
            updated = true;
            break;
          }
        } catch (e) {
          lastErr = e.toString();
        }

        // Fallback via direct REST PATCH in case `.select('id')` is restricted by RLS
        try {
          final uri = Uri.parse(
            '$supabaseUrl/rest/v1/users?${target.key}=eq.${Uri.encodeQueryComponent(target.value)}',
          );
          final response = await http.patch(
            uri,
            headers: {
              ..._headers,
              'Content-Type': 'application/json',
              'Prefer': 'return=representation',
            },
            body: jsonEncode(payload),
          );
          if (response.statusCode == 200 || response.statusCode == 204) {
            final body = response.body.trim();
            if (body.isEmpty || body != '[]') {
              updated = true;
              break;
            }
          } else {
            lastErr = 'HTTP ${response.statusCode}: ${response.body}';
          }
        } catch (e) {
          lastErr = e.toString();
        }
      }
    }

    if (!updated) {
      lastBanError = lastErr ?? 'Could not match or update user record';
      debugPrint('banUser/unbanUser failed: $lastBanError');
      return false;
    }

    // 3. Best-effort update for optional audit columns (ignored if columns do not exist in schema)
    final primaryTarget = matchTargets.first;
    final Map<String, dynamic> optionalColumns = {
      'updated_at': nowIso,
      'isBanned': isBanned,
      'banned_at': isBanned ? nowIso : null,
      'banned_by': isBanned ? (adminId?.isNotEmpty == true ? adminId : null) : null,
      'banned_reason': isBanned ? reason : null,
    };

    for (final entry in optionalColumns.entries) {
      try {
        await client
            .from('users')
            .update({entry.key: entry.value})
            .eq(primaryTarget.key, primaryTarget.value);
      } catch (_) {}
    }

    // 4. Immediately update in-memory cached users so UI reflects the change right away
    _updateCachedUserBanState(
      userId: cleanId,
      resolvedId: targetId,
      resolvedUid: targetUid,
      username: cleanUsername,
      isBanned: isBanned,
    );

    return true;
  }

  static Future<bool> approveBlueTick(String userId) async {
    return await update('users', {
      'is_blue_tick_verified': true,
      'blue_tick_status': 'approved',
      'is_verified_blue': true,
      'is_verified': true,
      'verification_status': 'verified',
      'updated_at': DateTime.now().toIso8601String(),
    }, 'id', userId);
  }

  static Future<bool> rejectBlueTick(String userId) async {
    return await update('users', {
      'is_blue_tick_verified': false,
      'blue_tick_status': 'rejected',
      'is_verified_blue': false,
      'verification_status': 'rejected',
      'updated_at': DateTime.now().toIso8601String(),
    }, 'id', userId);
  }

  static Future<bool> approveRank({
    required String userId,
    required String rank,
    required String gameName,
    required String adminName,
  }) async {
    return await update('users', {
      'rank': rank,
      'tier': rank,
      'selected_game': gameName,
      'selected_rank': rank,
      'is_rank_verified': true,
      'rank_status': 'Verified',
      'rank_verified_by': adminName,
      'rank_reject_reason': '',
      'updated_at': DateTime.now().toIso8601String(),
    }, 'id', userId);
  }

  static Future<bool> rejectRank({
    required String userId,
    required String reason,
    required String adminName,
  }) async {
    return await update('users', {
      'is_rank_verified': false,
      'rank_status': 'Rejected',
      'rank_reject_reason': reason,
      'rank_verified_by': adminName,
      'updated_at': DateTime.now().toIso8601String(),
    }, 'id', userId);
  }

  static Future<bool> deletePost(String postId) async {
    return await delete('posts', 'id', postId);
  }

  static Future<bool> awardCoins({
    required String userId,
    required int amount,
    required String adminId,
    String? adminEmail,
  }) async {
    try {
      int currentCoins = 0;
      int currentLifetimeEarned = 0;
      try {
        final walletRow = await client
            .from('coin_wallets')
            .select('g_coins, coins, lifetime_earned')
            .eq('user_id', userId)
            .maybeSingle();
        if (walletRow != null) {
          final int gVal = (walletRow['g_coins'] as num?)?.toInt() ?? 0;
          final int cVal = (walletRow['coins'] as num?)?.toInt() ?? 0;
          currentCoins = gVal > 0 ? gVal : cVal;
          currentLifetimeEarned = (walletRow['lifetime_earned'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      if (currentCoins == 0) {
        final users = await query('users', select: 'coins', filters: {'id': 'eq.$userId'}, limit: 1);
        if (users.isNotEmpty) {
          currentCoins = (users.first['coins'] as num?)?.toInt() ?? 0;
        }
      }

      final int newTotal = (currentCoins + amount).clamp(0, 9999999);
      final int newLifetimeEarned = amount > 0
          ? currentLifetimeEarned + amount
          : currentLifetimeEarned;

      try {
        await client.from('coin_wallets').upsert({
          'user_id': userId,
          'g_coins': newTotal,
          'coins': newTotal,
          'lifetime_earned': newLifetimeEarned,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id');
      } catch (_) {
        try {
          await client.from('coin_wallets').update({
            'g_coins': newTotal,
            'coins': newTotal,
            'lifetime_earned': newLifetimeEarned,
          }).eq('user_id', userId);
        } catch (_) {}
      }

      final ok = await update('users', {
        'coins': newTotal,
        'updated_at': DateTime.now().toIso8601String(),
      }, 'id', userId);

      await recordCoinTransaction(
        userId: userId,
        amount: amount,
        type: 'admin_grant',
        description: 'admin_awarded_coins_desc'.tr(args: ['$amount']),
        balanceAfter: newTotal,
      );
      return ok || newTotal >= 0;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingProofs() async {
    return await query(
      'active_matches',
      filters: {'status': 'eq.under_review'},
      order: 'created_at.desc',
      limit: 50,
    );
  }

  static Future<bool> approveProof({
    required String matchId,
    required String winnerTeamId,
  }) async {
    return await update('active_matches', {
      'proof_status': 'accepted',
      'status': 'completed',
      'winner_team_id': winnerTeamId,
    }, 'id', matchId);
  }

  static Future<bool> rejectProof({
    required String matchId,
    required String reason,
  }) async {
    return await update('active_matches', {
      'status': 'rejected',
      'proof_status': 'rejected',
      'admin_note': reason,
    }, 'id', matchId);
  }

  static Future<void> logProofHistory({
    required String username,
    required String proofType,
    required String status,
    String adminName = 'Admin',
    String? proofUrl,
    String? tournamentId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'username': username.trim().isNotEmpty ? username.trim() : 'User',
        'proof_type': proofType.trim().isNotEmpty ? proofType.trim() : 'Match Proof',
        'status': status.toLowerCase().contains('reject') ? 'rejected' : 'approved',
        'admin_name': adminName.trim().isNotEmpty ? adminName.trim() : 'Admin',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (proofUrl != null && proofUrl.isNotEmpty) {
        payload['proof_url'] = proofUrl;
      }
      if (tournamentId != null && tournamentId.isNotEmpty) {
        payload['tournament_id'] = tournamentId;
      }
      final insertResult = await client.from('proof_history').insert(payload).select();
      if (insertResult is List && insertResult.isNotEmpty) {
        _cachedProofHistory.insert(0, Map<String, dynamic>.from(insertResult.first));
      } else {
        _cachedProofHistory.insert(0, payload);
      }
    } catch (e) {
      debugPrint('[SupabaseService] logProofHistory error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getProofHistoryLogs({int limit = 40}) async {
    try {
      final res = await client
          .from('proof_history')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      if (res is List) {
        _cachedProofHistory = List<Map<String, dynamic>>.from(res);
        return _cachedProofHistory;
      }
    } catch (e) {
      debugPrint('[SupabaseService] getProofHistoryLogs error: $e');
    }
    return _cachedProofHistory;
  }

  // IN-MEMORY CACHES WITH TTL DEDUPLICATION PREVENTING REPEATED FETCHES ON TAB SWITCH
  static const Duration _cacheTtl = Duration(seconds: 45);
  static final Map<String, DateTime> _cacheTimestamps = {};

  static bool _isCacheFresh(String key) {
    final ts = _cacheTimestamps[key];
    if (ts == null) return false;
    return DateTime.now().difference(ts) < _cacheTtl;
  }

  static void _markCacheFresh(String key) {
    _cacheTimestamps[key] = DateTime.now();
  }

  static void invalidateCache([String? key]) {
    if (key == null) {
      _cacheTimestamps.clear();
    } else {
      _cacheTimestamps.remove(key);
    }
  }

  static List<Map<String, dynamic>> _cachedUsers = [];
  static List<Map<String, dynamic>> _cachedPosts = [];
  static List<Map<String, dynamic>> _cachedReports = [];
  static List<Map<String, dynamic>> _cachedCoinTransactions = [];
  static List<Map<String, dynamic>> _cachedNotifications = [];
  static List<Map<String, dynamic>> _cachedRooms = [];
  static List<Map<String, dynamic>> _cachedActiveMatches = [];
  static List<Map<String, dynamic>> _cachedTournaments = [];
  static List<Map<String, dynamic>> _cachedProofHistory = [];
  static List<Map<String, dynamic>> _cachedRewardClaims = [];

  static List<Map<String, dynamic>> get cachedUsers => _cachedUsers;
  static List<Map<String, dynamic>> get cachedPosts => _cachedPosts;
  static List<Map<String, dynamic>> get cachedReports => _cachedReports;
  static List<Map<String, dynamic>> get cachedCoinTransactions => _cachedCoinTransactions;
  static List<Map<String, dynamic>> get cachedNotifications => _cachedNotifications;
  static List<Map<String, dynamic>> get cachedRooms => _cachedRooms;
  static List<Map<String, dynamic>> get cachedActiveMatches => _cachedActiveMatches;
  static List<Map<String, dynamic>> get cachedTournaments => _cachedTournaments;
  static List<Map<String, dynamic>> get cachedProofHistory => _cachedProofHistory;
  static List<Map<String, dynamic>> get cachedRewardClaims => _cachedRewardClaims;

  static void upsertCachedRewardClaim(Map<String, dynamic> claim) {
    final String id = (claim['id'] ?? '').toString().trim();
    final String code = (claim['claim_code'] ?? '').toString().trim();
    if (id.isEmpty && code.isEmpty) return;

    final updated = List<Map<String, dynamic>>.from(_cachedRewardClaims);
    final int idx = updated.indexWhere((c) {
      final cId = (c['id'] ?? '').toString().trim();
      final cCode = (c['claim_code'] ?? '').toString().trim();
      if (id.isNotEmpty && cId.isNotEmpty) return cId == id;
      if (code.isNotEmpty && cCode.isNotEmpty) return cCode == code;
      return false;
    });

    if (idx >= 0) {
      updated[idx] = {...updated[idx], ...claim};
    } else {
      updated.insert(0, Map<String, dynamic>.from(claim));
    }
    _cachedRewardClaims = updated;
    _cacheTimestamps.removeWhere((k, _) => k.startsWith('reward_claims'));
  }

  static Future<List<Map<String, dynamic>>> fetchRewardClaims({
    String? userId,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final String cleanUid = (userId ?? '').trim();
    final String cacheKey =
        cleanUid.isNotEmpty ? 'reward_claims:$cleanUid' : 'reward_claims:all';

    if (!forceRefresh && _isCacheFresh(cacheKey) && _cachedRewardClaims.isNotEmpty) {
      if (cleanUid.isNotEmpty) {
        final cachedForUser = _cachedRewardClaims
            .where((c) => (c['user_id'] ?? '').toString().trim() == cleanUid)
            .toList();
        if (cachedForUser.isNotEmpty) return cachedForUser;
      } else {
        return _cachedRewardClaims;
      }
    }

    try {
      if (cleanUid.isNotEmpty) {
        final int effectiveLimit = limit > 50 ? 25 : limit;
        final res = await client
            .from('reward_claims')
            .select()
            .eq('user_id', cleanUid)
            .order('created_at', ascending: false)
            .limit(effectiveLimit)
            .timeout(const Duration(seconds: 8));
        if (res is List) {
          final list = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          for (final item in list) {
            upsertCachedRewardClaim(item);
          }
          _markCacheFresh(cacheKey);
          if (list.isNotEmpty) return list;
          return _cachedRewardClaims
              .where((c) => (c['user_id'] ?? '').toString().trim() == cleanUid)
              .toList();
        }
      } else {
        final int effectiveLimit = limit > 100 ? 50 : limit;
        final results = await Future.wait<dynamic>([
          client
              .from('reward_claims')
              .select()
              .eq('status', 'pending')
              .order('created_at', ascending: false)
              .limit(effectiveLimit)
              .timeout(const Duration(seconds: 8))
              .catchError((_) => <dynamic>[]),
          client
              .from('reward_claims')
              .select()
              .order('created_at', ascending: false)
              .limit(effectiveLimit)
              .timeout(const Duration(seconds: 8)),
        ]);

        final Map<String, Map<String, dynamic>> mergedMap = {};
        for (final batch in results) {
          if (batch is List) {
            for (final raw in batch) {
              if (raw is Map) {
                final item = Map<String, dynamic>.from(raw);
                final id = (item['id'] ?? '').toString().trim();
                final code = (item['claim_code'] ?? '').toString().trim();
                final key = id.isNotEmpty ? id : code;
                if (key.isNotEmpty) {
                  mergedMap[key] = item;
                }
              }
            }
          }
        }

        final list = mergedMap.values.toList();
        list.sort((a, b) {
          final aTime = (a['created_at'] ?? '').toString();
          final bTime = (b['created_at'] ?? '').toString();
          return bTime.compareTo(aTime);
        });

        if (list.isNotEmpty || _cachedRewardClaims.isEmpty) {
          _cachedRewardClaims = list;
        }
        _markCacheFresh(cacheKey);
        return _cachedRewardClaims;
      }
    } catch (e) {
      debugPrint('[SupabaseService] fetchRewardClaims primary error: $e');
      try {
        final fallback = await query(
          'reward_claims',
          filters: cleanUid.isNotEmpty ? {'user_id': 'eq.$cleanUid'} : null,
          order: 'created_at.desc',
          limit: cleanUid.isNotEmpty ? 25 : 50,
        );
        if (fallback.isNotEmpty) {
          if (cleanUid.isEmpty) {
            _cachedRewardClaims = fallback;
          } else {
            for (final item in fallback) {
              upsertCachedRewardClaim(item);
            }
          }
          _markCacheFresh(cacheKey);
          return fallback;
        }
      } catch (_) {}
    }

    if (cleanUid.isNotEmpty) {
      return _cachedRewardClaims
          .where((c) => (c['user_id'] ?? '').toString().trim() == cleanUid)
          .toList();
    }
    return _cachedRewardClaims;
  }

  // ============================================================
  // BULLETPROOF REALTIME STREAMS (REST-FIRST + TTL CACHE + ONCANCEL CLEANUP)
  // Cancels cleanly when the listening screen/tab is disposed.
  // ============================================================

  static Stream<List<Map<String, dynamic>>> getRealtimeUsers() {
    Stream<List<Map<String, dynamic>>> stream() async* {
      if (_cachedUsers.isNotEmpty) {
        yield _cachedUsers;
      }
      while (true) {
        try {
          if (!_isCacheFresh('users') || _cachedUsers.isEmpty) {
            final res = await client
                .from('users')
                .select()
                .order('created_at', ascending: false)
                .limit(30)
                .timeout(const Duration(seconds: 4));
            if (res is List) {
              final list = List<Map<String, dynamic>>.from(res);
              if (list.isNotEmpty || _cachedUsers.isEmpty) {
                _cachedUsers = list;
                _markCacheFresh('users');
                yield list;
              }
            }
          }
        } catch (e) {
          debugPrint('getRealtimeUsers error: $e');
          if (_cachedUsers.isNotEmpty) {
            yield _cachedUsers;
          }
        }
        await Future.delayed(const Duration(seconds: 60));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  static Stream<List<Map<String, dynamic>>> getRealtimePosts() {
    Stream<List<Map<String, dynamic>>> stream() async* {
      if (_cachedPosts.isNotEmpty) {
        yield _cachedPosts;
      }
      while (true) {
        try {
          if (!_isCacheFresh('posts') || _cachedPosts.isEmpty) {
            final res = await client
                .from('posts')
                .select()
                .order('created_at', ascending: false)
                .limit(20)
                .timeout(const Duration(seconds: 4));
            if (res is List) {
              final list = List<Map<String, dynamic>>.from(res);
              if (list.isNotEmpty || _cachedPosts.isEmpty) {
                _cachedPosts = list;
                _markCacheFresh('posts');
                yield list;
              }
            }
          }
        } catch (e) {
          debugPrint('getRealtimePosts error: $e');
          if (_cachedPosts.isNotEmpty) {
            yield _cachedPosts;
          }
        }
        await Future.delayed(const Duration(seconds: 60));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeReports() {
    Stream<List<Map<String, dynamic>>> stream() async* {
      _cleanupStaleRedeemRequestReports();
      if (_cachedReports.isNotEmpty) {
        yield _cachedReports.where(isRealModerationReport).toList();
      }
      while (true) {
        try {
          if (!_isCacheFresh('reports') || _cachedReports.isEmpty) {
            final res = await client
                .from('reports')
                .select()
                .order('created_at', ascending: false)
                .limit(30)
                .timeout(const Duration(seconds: 4));
            if (res is List) {
              final list = List<Map<String, dynamic>>.from(res)
                  .where(isRealModerationReport)
                  .toList();
              _cachedReports = list;
              _markCacheFresh('reports');
              yield list;
            }
          }
        } catch (e) {
          debugPrint('getRealtimeReports error: $e');
          if (_cachedReports.isNotEmpty) {
            yield _cachedReports.where(isRealModerationReport).toList();
          }
        }
        await Future.delayed(const Duration(seconds: 60));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeCoinTransactions() {
    Stream<List<Map<String, dynamic>>> stream() async* {
      if (_cachedCoinTransactions.isNotEmpty) {
        yield _cachedCoinTransactions;
      }
      while (true) {
        try {
          if (!_isCacheFresh('coin_transactions') || _cachedCoinTransactions.isEmpty) {
            final res = await client
                .from('coin_transactions')
                .select()
                .order('created_at', ascending: false)
                .limit(30)
                .timeout(const Duration(seconds: 4));
            if (res is List) {
              final list = List<Map<String, dynamic>>.from(res);
              if (list.isNotEmpty || _cachedCoinTransactions.isEmpty) {
                _cachedCoinTransactions = list;
                _markCacheFresh('coin_transactions');
                yield list;
              }
            }
          }
        } catch (e) {
          debugPrint('getRealtimeCoinTransactions error: $e');
          if (_cachedCoinTransactions.isNotEmpty) {
            yield _cachedCoinTransactions;
          }
        }
        await Future.delayed(const Duration(seconds: 60));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeNotifications() {
    Stream<List<Map<String, dynamic>>> stream() async* {
      if (_cachedNotifications.isNotEmpty) {
        yield _cachedNotifications;
      }
      while (true) {
        try {
          if (!_isCacheFresh('notifications') || _cachedNotifications.isEmpty) {
            final res = await client
                .from('notifications')
                .select()
                .order('created_at', ascending: false)
                .limit(25)
                .timeout(const Duration(seconds: 4));
            if (res is List) {
              final list = List<Map<String, dynamic>>.from(res);
              if (list.isNotEmpty || _cachedNotifications.isEmpty) {
                _cachedNotifications = list;
                _markCacheFresh('notifications');
                yield list;
              }
            }
          }
        } catch (e) {
          debugPrint('getRealtimeNotifications error: $e');
          if (_cachedNotifications.isNotEmpty) {
            yield _cachedNotifications;
          }
        }
        await Future.delayed(const Duration(seconds: 60));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeRooms() {
    Stream<List<Map<String, dynamic>>> stream() async* {
      if (_cachedRooms.isNotEmpty) {
        yield _cachedRooms;
      }
      while (true) {
        try {
          if (!_isCacheFresh('rooms') || _cachedRooms.isEmpty) {
            final res = await client
                .from('rooms')
                .select()
                .order('created_at', ascending: false)
                .limit(25)
                .timeout(const Duration(seconds: 4));
            if (res is List) {
              final list = List<Map<String, dynamic>>.from(res);
              if (list.isNotEmpty || _cachedRooms.isEmpty) {
                _cachedRooms = list;
                _markCacheFresh('rooms');
                yield list;
              }
            }
          }
        } catch (e) {
          debugPrint('getRealtimeRooms error: $e');
          if (_cachedRooms.isNotEmpty) {
            yield _cachedRooms;
          }
        }
        await Future.delayed(const Duration(seconds: 45));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeActiveMatches() {
    Stream<List<Map<String, dynamic>>> stream() async* {
      if (_cachedActiveMatches.isNotEmpty) {
        yield _cachedActiveMatches;
      }
      while (true) {
        try {
          if (!_isCacheFresh('active_matches') || _cachedActiveMatches.isEmpty) {
            final res = await client
                .from('active_matches')
                .select()
                .order('created_at', ascending: false)
                .limit(20)
                .timeout(const Duration(seconds: 4));
            if (res is List) {
              final list = List<Map<String, dynamic>>.from(res);
              if (list.isNotEmpty || _cachedActiveMatches.isEmpty) {
                _cachedActiveMatches = list;
                _markCacheFresh('active_matches');
                yield list;
              }
            }
          }
        } catch (e) {
          debugPrint('getRealtimeActiveMatches error: $e');
          if (_cachedActiveMatches.isNotEmpty) {
            yield _cachedActiveMatches;
          }
        }
        await Future.delayed(const Duration(seconds: 45));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeTournaments() {
    Stream<List<Map<String, dynamic>>> stream() async* {
      if (_cachedTournaments.isNotEmpty) {
        yield _cachedTournaments;
      }
      while (true) {
        try {
          if (!_isCacheFresh('tournaments') || _cachedTournaments.isEmpty) {
            final res = await client
                .from('tournaments')
                .select()
                .order('created_at', ascending: false)
                .limit(20)
                .timeout(const Duration(seconds: 4));
            if (res is List) {
              final list = List<Map<String, dynamic>>.from(res);
              if (list.isNotEmpty || _cachedTournaments.isEmpty) {
                _cachedTournaments = list;
                _markCacheFresh('tournaments');
                yield list;
              }
            }
          }
        } catch (e) {
          debugPrint('getRealtimeTournaments error: $e');
          if (_cachedTournaments.isNotEmpty) {
            yield _cachedTournaments;
          }
        }
        await Future.delayed(const Duration(seconds: 45));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeProofHistory() {
    Stream<List<Map<String, dynamic>>> stream() async* {
      if (_cachedProofHistory.isNotEmpty) {
        yield _cachedProofHistory;
      }
      while (true) {
        try {
          if (!_isCacheFresh('proof_history') || _cachedProofHistory.isEmpty) {
            final res = await client
                .from('proof_history')
                .select()
                .order('created_at', ascending: false)
                .limit(30)
                .timeout(const Duration(seconds: 4));
            if (res is List) {
              final list = List<Map<String, dynamic>>.from(res);
              _cachedProofHistory = list;
              _markCacheFresh('proof_history');
              yield list;
            }
          }
        } catch (e) {
          debugPrint('getRealtimeProofHistory error: $e');
          if (_cachedProofHistory.isNotEmpty) {
            yield _cachedProofHistory;
          }
        }
        await Future.delayed(const Duration(seconds: 60));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeSingleRoom(String roomId) {
    Stream<List<Map<String, dynamic>>> stream() async* {
      while (true) {
        try {
          final res = await client
              .from('rooms')
              .select()
              .eq('id', roomId)
              .limit(1)
              .timeout(const Duration(seconds: 4));
          if (res is List && res.isNotEmpty) {
            yield List<Map<String, dynamic>>.from(res);
          }
        } catch (e) {
          debugPrint('getRealtimeSingleRoom error: $e');
        }
        await Future.delayed(const Duration(seconds: 20));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeRoomMessages(String roomId) {
    Stream<List<Map<String, dynamic>>> stream() async* {
      while (true) {
        try {
          final res = await client
              .from('messages')
              .select()
              .eq('room_id', roomId)
              .order('created_at', ascending: true)
              .limit(50)
              .timeout(const Duration(seconds: 4));
          if (res is List) {
            yield List<Map<String, dynamic>>.from(res);
          }
        } catch (e) {
          debugPrint('getRealtimeRoomMessages error: $e');
        }
        await Future.delayed(const Duration(seconds: 15));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeRewardClaims({String? userId}) {
    final String cleanUid = (userId ?? '').trim();
    Stream<List<Map<String, dynamic>>> stream() async* {
      if (_cachedRewardClaims.isNotEmpty) {
        if (cleanUid.isEmpty) {
          yield _cachedRewardClaims;
        } else {
          final cachedUserClaims = _cachedRewardClaims
              .where((c) => (c['user_id'] ?? '').toString().trim() == cleanUid)
              .toList();
          if (cachedUserClaims.isNotEmpty) {
            yield cachedUserClaims;
          }
        }
      }
      while (true) {
        final list = await fetchRewardClaims(
          userId: cleanUid.isEmpty ? null : cleanUid,
          limit: cleanUid.isEmpty ? 50 : 20,
        );
        yield list;
        await Future.delayed(const Duration(seconds: 60));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }
}