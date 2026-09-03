import 'package:cloud_firestore/cloud_firestore.dart';

class NewsModel {
  final String id;
  final Map<String, String> titleMap;
  final Map<String, String> descriptionMap;
  final String category;
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
    this.timestamp,
    this.appId,
  }) : titleMap = titleMap?? _createDefaultMap(title?? ''),
        descriptionMap = descriptionMap?? _createDefaultMap(description?? '');

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

  String getTitle([String? langCode]) {
    if (langCode!= null && langCode.isNotEmpty) {
      final code = langCode.toLowerCase();
      if (titleMap.containsKey(code) && titleMap[code]!.trim().isNotEmpty) {
        return titleMap[code]!;
      }
    }
    return titleMap['roman']??
        titleMap['en']??
        (titleMap.values.isNotEmpty? titleMap.values.first : '');
  }

  String getDescription([String? langCode]) {
    if (langCode!= null && langCode.isNotEmpty) {
      final code = langCode.toLowerCase();
      if (descriptionMap.containsKey(code) && descriptionMap[code]!.trim().isNotEmpty) {
        return descriptionMap[code]!;
      }
    }
    return descriptionMap['roman']??
        descriptionMap['en']??
        (descriptionMap.values.isNotEmpty? descriptionMap.values.first : '');
  }

  String getContent([String? langCode]) => getDescription(langCode);

  factory NewsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>??? {};

    String formattedTime = (data['timeAgo'] as String?)?? 'Abhi abhi';
    final ts = data['timestamp'] as Timestamp?;
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
        if (res.containsKey('roman') &&!res.containsKey('ro')) {
          res['ro'] = res['roman']!;
        }
        if (res.containsKey('ro') &&!res.containsKey('roman')) {
          res['roman'] = res['ro']!;
        }
        return res;
      } else if (val is String && val.isNotEmpty) {
        return _createDefaultMap(val);
      }
      return _createDefaultMap(fallback);
    }

    String finalImageUrl = (data['imageUrl'] as String?)?? '';
    if (finalImageUrl.isEmpty && data['appId']!= null) {
      finalImageUrl = 'https://cdn.akamai.steamstatic.com/steam/apps/${data['appId']}/header.jpg';
    }
    if (finalImageUrl.isEmpty) {
      finalImageUrl = 'https://picsum.photos/seed/${doc.id}/800/600';
    }

    return NewsModel(
      id: doc.id,
      titleMap: parseTextMap(data['title'], ''),
      descriptionMap: parseTextMap(data['content']?? data['description'], ''),
      category: (data['category'] as String?)?? 'Gaming News',
      imageUrl: finalImageUrl,
      videoUrl: data['videoUrl'] as String?,
      youtubeId: data['youtubeId'] as String?,
      timeAgo: formattedTime,
      views: (data['views'] as num?)?.toInt()?? 0,
      rating: (data['rating'] as num?)?.toDouble(),
      originalPrice: data['originalPrice'] as String?,
      isFree: (data['isFree'] as bool?)?? false,
      isFeatured: (data['isFeatured'] as bool?)?? false,
      timeLeft: data['timeLeft'] as String?,
      storeName: data['storeName'] as String?,
      downloadSize: data['downloadSize'] as String?,
      sourceUrl: data['sourceUrl'] as String?,
      isAuto: (data['isAuto'] as bool?)?? false,
      timestamp: ts,
      appId: (data['appId'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': titleMap,
      'content': descriptionMap,
      'description': descriptionMap,
      'category': category,
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
    if (json['timestampMillis']!= null) {
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

    String finalImageUrl = (json['imageUrl'] as String?)?? '';
    if (finalImageUrl.isEmpty && json['appId']!= null) {
      finalImageUrl = 'https://cdn.akamai.steamstatic.com/steam/apps/${json['appId']}/header.jpg';
    }
    if (finalImageUrl.isEmpty) {
      finalImageUrl = 'https://picsum.photos/seed/${json['id']}/800/600';
    }

    return NewsModel(
      id: (json['id'] as String?)?? '',
      titleMap: parseTextMap(json['title'], ''),
      descriptionMap: parseTextMap(json['content']?? json['description'], ''),
      category: (json['category'] as String?)?? 'Gaming News',
      imageUrl: finalImageUrl,
      videoUrl: json['videoUrl'] as String?,
      youtubeId: json['youtubeId'] as String?,
      timeAgo: (json['timeAgo'] as String?)?? 'Recently',
      views: (json['views'] as num?)?.toInt()?? 0,
      appId: (json['appId'] as num?)?.toInt(),
      timestamp: ts,
    );
  }

  NewsModel copyWith({
    String? id,
    String? title,
    Map<String, String>? titleMap,
    String? description,
    Map<String, String>? descriptionMap,
    String? category,
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
    Timestamp? timestamp,
    int? appId,
  }) {
    return NewsModel(
      id: id?? this.id,
      titleMap: titleMap?? (title!= null? _createDefaultMap(title) : this.titleMap),
      descriptionMap: descriptionMap?? (description!= null? _createDefaultMap(description) : this.descriptionMap),
      category: category?? this.category,
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
}