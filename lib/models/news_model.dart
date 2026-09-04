import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/translation_service.dart';

class NewsModel {
  final String id;
  final Map<String, String> titleMap;
  final Map<String, String> descriptionMap;
  final String category;
  final String? gameName;
  final String imageUrl;
  final String? videoUrl;
  final String? youtubeId;
  final String timeAgo;
  final int views;
  final double? rating;
  final String? originalPrice;
  final bool isFree;
  final bool isFeatured;
  final String? timeLeft;
  final String? storeName;
  final String? downloadSize;
  final String? sourceUrl;
  final bool isAuto;
  final Timestamp? timestamp;
  final int? appId;

  NewsModel({
    required this.id,
    String? title,
    Map<String, String>? titleMap,
    String? description,
    Map<String, String>? descriptionMap,
    required this.category,
    this.gameName,
    required this.imageUrl,
    this.videoUrl,
    this.youtubeId,
    required this.timeAgo,
    this.views = 0,
    this.rating,
    this.originalPrice,
    this.isFree = false,
    this.isFeatured = false,
    this.timeLeft,
    this.storeName,
    this.downloadSize,
    this.sourceUrl,
    this.isAuto = false,
    dynamic timestamp,
    this.appId,
  })  : titleMap = titleMap ?? _createDefaultMap(title ?? ''),
        descriptionMap = descriptionMap ?? _createDefaultMap(description ?? ''),
        timestamp = timestamp is Timestamp
            ? timestamp
            : (timestamp is int
                ? Timestamp.fromMillisecondsSinceEpoch(timestamp)
                : (timestamp is DateTime
                    ? Timestamp.fromDate(timestamp)
                    : null));

  static Map<String, String> _createDefaultMap(String text) {
    return {
      'roman': text,
      'ro': text,
      'en': text,
      'hi': text,
      'ur': text,
      'bn': text,
      'ar': text,
      'zh': text,
      'zh-cn': text,
    };
  }

  String get title => getTitle();
  String get description => getDescription();
  String get content => getDescription();
  String get thumbnailUrl => imageUrl;
  String get displayGameOrCategory => (gameName != null && gameName!.trim().isNotEmpty) ? gameName!.trim() : category;
  String get cleanDescription => TranslationService.cleanBbCodeAndHtml(getDescription());

  String getCleanDescription([String? langCode]) =>
      TranslationService.cleanBbCodeAndHtml(getDescription(langCode));

  /// Check if this news item is actually translated into the target language script
  bool isTranslatedFor(String langCode) {
    final code = langCode.toLowerCase();
    if (code == 'en' || code == 'ro' || code == 'roman') return true;
    final t = titleMap[code];
    final d = descriptionMap[code];
    if (t == null || t.trim().isEmpty || d == null || d.trim().isEmpty) return false;
    return TranslationService.isTextInLanguage(t, code) &&
        TranslationService.isTextInLanguage(d, code);
  }

  String getTitle([String? langCode]) {
    if (langCode!= null && langCode.isNotEmpty) {
      final code = langCode.toLowerCase();
      if (titleMap.containsKey(code)) {
        final v = titleMap[code];
        if (v!= null && v.trim().isNotEmpty) return v;
      }
      if (code == 'ro' && titleMap.containsKey('roman')) {
        final v = titleMap['roman'];
        if (v!= null && v.trim().isNotEmpty) return v;
      }
      if (code == 'roman' && titleMap.containsKey('ro')) {
        final v = titleMap['ro'];
        if (v!= null && v.trim().isNotEmpty) return v;
      }
    }
    if (titleMap['roman']!= null && titleMap['roman']!.trim().isNotEmpty) return titleMap['roman']!;
    if (titleMap['ro']!= null && titleMap['ro']!.trim().isNotEmpty) return titleMap['ro']!;
    if (titleMap['en']!= null && titleMap['en']!.trim().isNotEmpty) return titleMap['en']!;
    if (titleMap.values.isNotEmpty) return titleMap.values.first;
    return '';
  }

  String getDescription([String? langCode]) {
    if (langCode!= null && langCode.isNotEmpty) {
      final code = langCode.toLowerCase();
      if (descriptionMap.containsKey(code)) {
        final v = descriptionMap[code];
        if (v!= null && v.trim().isNotEmpty) return v;
      }
    }
    if (descriptionMap['roman']!= null && descriptionMap['roman']!.trim().isNotEmpty) return descriptionMap['roman']!;
    if (descriptionMap['ro']!= null && descriptionMap['ro']!.trim().isNotEmpty) return descriptionMap['ro']!;
    if (descriptionMap['en']!= null && descriptionMap['en']!.trim().isNotEmpty) return descriptionMap['en']!;
    if (descriptionMap.values.isNotEmpty) return descriptionMap.values.first;
    return '';
  }

  String getContent([String? langCode]) => getDescription(langCode);

  factory NewsModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data() as Map<String, dynamic>?;
    final data = rawData!= null? rawData : <String, dynamic>{};

    String formattedTime = 'Abhi abhi';
    if (data['timeAgo'] is String) {
      formattedTime = data['timeAgo'] as String;
    }
    final ts = data['timestamp'] is Timestamp? data['timestamp'] as Timestamp : null;
    if (ts!= null) {
      final diff = DateTime.now().difference(ts.toDate());
      if (diff.inMinutes < 60) {
        formattedTime = '${diff.inMinutes <= 0? 1 : diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        formattedTime = '${diff.inHours}h ago';
      } else {
        formattedTime = '${diff.inDays}d ago';
      }
    }

    Map<String, String> parseTextMap(dynamic val, String fallback) {
      if (val is Map) {
        final res = <String, String>{};
        val.forEach((k, v) {
          if (v!= null) res[k.toString()] = v.toString();
        });
        if (res.containsKey('roman') &&!res.containsKey('ro')) res['ro'] = res['roman']!;
        if (res.containsKey('ro') &&!res.containsKey('roman')) res['roman'] = res['ro']!;
        return res;
      } else if (val is String && val.isNotEmpty) {
        return _createDefaultMap(val);
      }
      return _createDefaultMap(fallback);
    }

    String img = '';
    if (data['imageUrl'] is String) img = data['imageUrl'] as String;
    if (img.isEmpty && data['appId']!= null) {
      img = 'https://cdn.akamai.steamstatic.com/steam/apps/${data['appId']}/header.jpg';
    }
    if (img.isEmpty) {
      img = 'https://picsum.photos/seed/${doc.id}/800/600';
    }

    int views = 0;
    if (data['views'] is num) views = (data['views'] as num).toInt();

    double? rating;
    if (data['rating'] is num) rating = (data['rating'] as num).toDouble();

    bool isFree = false;
    if (data['isFree'] is bool) isFree = data['isFree'] as bool;

    bool isFeatured = false;
    if (data['isFeatured'] is bool) isFeatured = data['isFeatured'] as bool;

    bool isAuto = false;
    if (data['isAuto'] is bool) isAuto = data['isAuto'] as bool;

    int? appId;
    if (data['appId'] is num) appId = (data['appId'] as num).toInt();

    return NewsModel(
      id: doc.id,
      titleMap: parseTextMap(data['title'], ''),
      descriptionMap: parseTextMap(data['content']!= null? data['content'] : data['description'], ''),
      category: data['category'] is String? data['category'] as String : 'Gaming News',
      gameName: data['gameName'] is String? data['gameName'] as String : null,
      imageUrl: img,
      videoUrl: data['videoUrl'] is String? data['videoUrl'] as String : null,
      youtubeId: data['youtubeId'] is String? data['youtubeId'] as String : null,
      timeAgo: formattedTime,
      views: views,
      rating: rating,
      originalPrice: data['originalPrice'] is String? data['originalPrice'] as String : null,
      isFree: isFree,
      isFeatured: isFeatured,
      timeLeft: data['timeLeft'] is String? data['timeLeft'] as String : null,
      storeName: data['storeName'] is String? data['storeName'] as String : null,
      downloadSize: data['downloadSize'] is String? data['downloadSize'] as String : null,
      sourceUrl: data['sourceUrl'] is String? data['sourceUrl'] as String : null,
      isAuto: isAuto,
      timestamp: ts,
      appId: appId,
    );
  }

  NewsModel copyWith({
    String? id,
    String? title,
    Map<String, String>? titleMap,
    String? description,
    Map<String, String>? descriptionMap,
    String? category,
    String? gameName,
    String? imageUrl,
    String? videoUrl,
    String? youtubeId,
    String? timeAgo,
    int? views,
    double? rating,
    String? originalPrice,
    bool? isFree,
    bool? isFeatured,
    String? timeLeft,
    String? storeName,
    String? downloadSize,
    String? sourceUrl,
    bool? isAuto,
    dynamic timestamp,
    int? appId,
  }) {
    return NewsModel(
      id: id?? this.id,
      titleMap: titleMap?? (title!= null? _createDefaultMap(title) : this.titleMap),
      descriptionMap: descriptionMap?? (description!= null? _createDefaultMap(description) : this.descriptionMap),
      category: category?? this.category,
      gameName: gameName?? this.gameName,
      imageUrl: imageUrl?? this.imageUrl,
      videoUrl: videoUrl?? this.videoUrl,
      youtubeId: youtubeId?? this.youtubeId,
      timeAgo: timeAgo?? this.timeAgo,
      views: views?? this.views,
      rating: rating?? this.rating,
      originalPrice: originalPrice?? this.originalPrice,
      isFree: isFree?? this.isFree,
      isFeatured: isFeatured?? this.isFeatured,
      timeLeft: timeLeft?? this.timeLeft,
      storeName: storeName?? this.storeName,
      downloadSize: downloadSize?? this.downloadSize,
      sourceUrl: sourceUrl?? this.sourceUrl,
      isAuto: isAuto?? this.isAuto,
      timestamp: timestamp?? this.timestamp,
      appId: appId?? this.appId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': titleMap,
      'content': descriptionMap,
      'description': descriptionMap,
      'category': category,
      'gameName': gameName,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'youtubeId': youtubeId,
      'timeAgo': timeAgo,
      'views': views,
      'rating': rating,
      'originalPrice': originalPrice,
      'isFree': isFree,
      'isFeatured': isFeatured,
      'timeLeft': timeLeft,
      'storeName': storeName,
      'downloadSize': downloadSize,
      'sourceUrl': sourceUrl,
      'isAuto': isAuto,
      'appId': appId,
      'timestampMillis': timestamp?.millisecondsSinceEpoch,
    };
  }

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    Timestamp? ts;
    if (json['timestampMillis'] is int) {
      ts = Timestamp.fromMillisecondsSinceEpoch(json['timestampMillis'] as int);
    }

    Map<String, String> parseTextMap(dynamic val, String fallback) {
      if (val is Map) {
        final res = <String, String>{};
        val.forEach((k, v) {
          if (v!= null) res[k.toString()] = v.toString();
        });
        return res;
      } else if (val is String && val.isNotEmpty) {
        return _createDefaultMap(val);
      }
      return _createDefaultMap(fallback);
    }

    String img = '';
    if (json['imageUrl'] is String) img = json['imageUrl'] as String;
    if (img.isEmpty && json['appId']!= null) {
      img = 'https://cdn.akamai.steamstatic.com/steam/apps/${json['appId']}/header.jpg';
    }
    if (img.isEmpty) {
      img = 'https://picsum.photos/seed/${json['id']}/800/600';
    }

    int views = 0;
    if (json['views'] is num) views = (json['views'] as num).toInt();

    return NewsModel(
      id: json['id'] is String? json['id'] as String : '',
      titleMap: parseTextMap(json['title'], ''),
      descriptionMap: parseTextMap(json['content']!= null? json['content'] : json['description'], ''),
      category: json['category'] is String? json['category'] as String : 'Gaming News',
      gameName: json['gameName'] is String? json['gameName'] as String : null,
      imageUrl: img,
      videoUrl: json['videoUrl'] is String? json['videoUrl'] as String : null,
      youtubeId: json['youtubeId'] is String? json['youtubeId'] as String : null,
      timeAgo: json['timeAgo'] is String? json['timeAgo'] as String : 'Recently',
      views: views,
      appId: json['appId'] is num? (json['appId'] as num).toInt() : null,
      timestamp: ts,
    );
  }
}