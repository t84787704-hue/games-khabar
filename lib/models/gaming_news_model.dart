import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/game_bots_100.dart';
import '../data/fallback_images.dart';

class GamingNewsModel {
  final String id;
  final String titleEn;
  final String titleUr;
  final String contentEn;
  final String contentUr;
  final String summary;
  final String source;
  final String sourceUrl;
  final String category;
  final String platform;
  final String imageUrl;
  final DateTime timestamp;
  final int views;
  final String botName;
  final String botAvatar;
  final String botBadge;
  final String botId;

  /// Universal category-based fallback game image map (Guarantees every game card always has high quality pic)
  static String getCategoryFallbackImage(String category, {String? title, String? content}) {
    return getGameFallbackImage(category: category, title: title, content: content);
  }

  /// Guaranteed non-empty, working image URL for the card
  String get effectiveImageUrl {
    if (imageUrl.trim().isNotEmpty &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) &&
        !imageUrl.contains('example.com')) {
      return imageUrl.trim();
    }
    return getGameFallbackImage(category: category, title: titleEn, content: contentEn);
  }

  /// Returns active bot name with automatic detection fallback
  String get effectiveBotName {
    if (botName.trim().isNotEmpty) return botName.trim();
    final bot = findGameBot(title: titleEn, category: category, content: contentEn);
    return bot['name']!;
  }

  /// Returns active bot avatar (Dicebear) with automatic detection fallback
  String get effectiveBotAvatar {
    if (botAvatar.trim().isNotEmpty) return botAvatar.trim();
    final bot = findGameBot(title: titleEn, category: category, content: contentEn);
    return bot['avatar']!;
  }

  /// Returns bot badge text (default "BOT")
  String get effectiveBotBadge {
    if (botBadge.trim().isNotEmpty) return botBadge.trim();
    return 'BOT';
  }

  GamingNewsModel({
    required this.id,
    required this.titleEn,
    required this.titleUr,
    String contentEn = '',
    this.contentUr = '',
    required this.summary,
    this.source = '',
    required this.sourceUrl,
    required this.category,
    required this.platform,
    required this.imageUrl,
    required this.timestamp,
    this.views = 0,
    this.botName = '',
    this.botAvatar = '',
    this.botBadge = 'BOT',
    this.botId = '',
    String? fullContent,
  }) : contentEn = contentEn.isNotEmpty ? contentEn : (fullContent ?? '');

  Map<String, dynamic> toMap() {
    final effectiveEn = contentEn.isNotEmpty ? contentEn : summary;
    final effectiveUr = contentUr;
    final inferredSource = source.isNotEmpty ? source : inferSourceName(sourceUrl, category);
    final finalImg = imageUrl.isNotEmpty ? imageUrl : getCategoryFallbackImage(category);
    final finalBot = findGameBot(title: titleEn, category: category, content: effectiveEn);

    return {
      'id': id,
      'title_en': titleEn,
      'title_ur': titleUr,
      'summary_en': summary,
      'summary': summary,
      'content_en': effectiveEn,
      'fullContent_en': effectiveEn,
      'fullContent': effectiveEn,
      'content_ur': effectiveUr,
      'fullContent_ur': effectiveUr,
      'source': inferredSource,
      'sourceUrl': sourceUrl,
      'category': category,
      'platform': platform,
      'imageUrl': finalImg,
      'timestamp': Timestamp.fromDate(timestamp),
      'views': views,
      'botName': botName.isNotEmpty ? botName : finalBot['name']!,
      'botAvatar': botAvatar.isNotEmpty ? botAvatar : finalBot['avatar']!,
      'botBadge': botBadge.isNotEmpty ? botBadge : (finalBot['badge'] ?? 'BOT'),
      'botId': botId.isNotEmpty ? botId : (finalBot['id'] ?? 'trending_bot'),
    };
  }

  factory GamingNewsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GamingNewsModel.fromMap(data, doc.id);
  }

  factory GamingNewsModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parsedTime;
    final rawTs = map['timestamp'];
    if (rawTs is Timestamp) {
      parsedTime = rawTs.toDate();
    } else if (rawTs is String) {
      parsedTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else if (rawTs is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      parsedTime = DateTime.now();
    }

    final rawEn = (map['fullContent_en'] ??
            map['content_en'] ??
            map['fullContent'] ??
            map['content'] ??
            map['description'] ??
            map['summary'] ??
            '')
        .toString();

    final rawUr = (map['fullContent_ur'] ??
            map['content_ur'] ??
            '')
        .toString();

    final rawSummary = (map['summary_en'] ??
            map['summary'] ??
            map['description'] ??
            (rawEn.length > 220 ? '${rawEn.substring(0, 220)}...' : rawEn))
        .toString();

    final rawSource = (map['source'] ?? map['source_name'] ?? '').toString();
    final rawUrl = (map['sourceUrl'] ?? map['url'] ?? '').toString();
    final rawCategory = (map['category'] ?? 'FEATURED').toString();
    final rawImg = (map['imageUrl'] ?? map['image'] ?? '').toString().trim();
    final resolvedImg = rawImg.isNotEmpty ? rawImg : getCategoryFallbackImage(rawCategory);

    final rawBotName = (map['botName'] ?? map['bot_name'] ?? '').toString().trim();
    final rawBotAvatar = (map['botAvatar'] ?? map['bot_avatar'] ?? '').toString().trim();
    final rawBotBadge = (map['botBadge'] ?? map['bot_badge'] ?? '').toString().trim();
    final rawBotId = (map['botId'] ?? map['bot_id'] ?? '').toString().trim();

    final detectedBot = (rawBotName.isEmpty || rawBotAvatar.isEmpty)
        ? findGameBot(
            title: (map['title_en'] ?? map['title'] ?? '').toString(),
            category: rawCategory,
            content: rawEn,
          )
        : null;

    return GamingNewsModel(
      id: docId ?? map['id'] ?? '',
      titleEn: (map['title_en'] ?? map['title'] ?? '').toString(),
      titleUr: (map['title_ur'] ?? '').toString(),
      contentEn: rawEn,
      contentUr: rawUr,
      summary: rawSummary,
      source: rawSource.isNotEmpty ? rawSource : inferSourceName(rawUrl, rawCategory),
      sourceUrl: rawUrl,
      category: rawCategory,
      platform: (map['platform'] ?? 'Multiplatform').toString(),
      imageUrl: resolvedImg,
      timestamp: parsedTime,
      views: (map['views'] is num) ? (map['views'] as num).toInt() : 0,
      botName: rawBotName.isNotEmpty ? rawBotName : detectedBot!['name']!,
      botAvatar: rawBotAvatar.isNotEmpty ? rawBotAvatar : detectedBot!['avatar']!,
      botBadge: rawBotBadge.isNotEmpty ? rawBotBadge : (detectedBot?['badge'] ?? 'BOT'),
      botId: rawBotId.isNotEmpty ? rawBotId : (detectedBot?['id'] ?? 'trending_bot'),
    );
  }

  /// Helper to infer readable source name like "IGN", "GameSpot", etc.
  static String inferSourceName(String url, String category) {
    final lower = url.toLowerCase();
    if (lower.contains('ign.com')) return 'IGN';
    if (lower.contains('gamespot.com')) return 'GameSpot';
    if (lower.contains('kotaku.com')) return 'Kotaku';
    if (lower.contains('polygon.com')) return 'Polygon';
    if (lower.contains('epicgames.com')) return 'Epic Games';
    if (lower.contains('rockstargames.com')) return 'Rockstar Games';
    if (lower.contains('pcgamer.com')) return 'PC Gamer';
    if (lower.contains('eurogamer.net')) return 'Eurogamer';
    if (lower.contains('nintendolife.com')) return 'Nintendo Life';
    if (lower.contains('gematsu.com')) return 'Gematsu';
    if (category.trim().isNotEmpty && category != 'FEATURED') return category;
    return 'Gaming News';
  }

  String get displaySource {
    if (source.trim().isNotEmpty) return source.trim();
    return inferSourceName(sourceUrl, category);
  }

  /// Returns title for the requested language ('en' or 'ur')
  String getTitle(String langCode) {
    if (langCode == 'ur' && titleUr.trim().isNotEmpty) {
      return titleUr.trim();
    }
    if (titleEn.trim().isNotEmpty) {
      return titleEn.trim();
    }
    return titleUr.trim();
  }

  /// Returns full content for the requested language ('en' or 'ur')
  String getContent(String langCode) {
    if (langCode == 'ur' && contentUr.trim().isNotEmpty) {
      return contentUr.trim();
    }
    if (contentEn.trim().isNotEmpty) {
      return contentEn.trim();
    }
    if (summary.trim().isNotEmpty) {
      return summary.trim();
    }
    return langCode == 'ur'
        ? 'مضمون کی تفصیلات جلد دستیاب ہوں گی۔'
        : 'Detailed gaming article will appear here shortly.';
  }

  String get displayContent {
    if (contentEn.trim().isNotEmpty) return contentEn.trim();
    if (summary.trim().isNotEmpty) return summary.trim();
    return 'Detailed gaming article will appear here shortly.';
  }

  /// Backward compatible getter for full content
  String get fullContent => contentEn.isNotEmpty ? contentEn : summary;

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  String get formattedIsoTimestamp {
    return timestamp.toIso8601String();
  }

  GamingNewsModel copyWith({
    String? id,
    String? titleEn,
    String? titleUr,
    String? contentEn,
    String? contentUr,
    String? summary,
    String? source,
    String? sourceUrl,
    String? category,
    String? platform,
    String? imageUrl,
    DateTime? timestamp,
    int? views,
    String? botName,
    String? botAvatar,
    String? botBadge,
    String? botId,
    String? fullContent,
  }) {
    return GamingNewsModel(
      id: id ?? this.id,
      titleEn: titleEn ?? this.titleEn,
      titleUr: titleUr ?? this.titleUr,
      contentEn: contentEn ?? fullContent ?? this.contentEn,
      contentUr: contentUr ?? this.contentUr,
      summary: summary ?? this.summary,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      category: category ?? this.category,
      platform: platform ?? this.platform,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      views: views ?? this.views,
      botName: botName ?? this.botName,
      botAvatar: botAvatar ?? this.botAvatar,
      botBadge: botBadge ?? this.botBadge,
      botId: botId ?? this.botId,
    );
  }
}
