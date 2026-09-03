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
    required this.titleMap,
    required this.descriptionMap,
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
  });

  String get title => getTitle();
  String get description => getDescription();
  String get content => getDescription();
  String get thumbnailUrl => imageUrl;

  String getTitle([String? langCode]) {
    if (langCode!= null && langCode.isNotEmpty) {
      String code = langCode.toLowerCase();
      if (titleMap.containsKey(code)) {
        String v = titleMap[code]!;
        if (v.trim().isNotEmpty) return v;
      }
    }
    if (titleMap.containsKey('roman')) return titleMap['roman']!;
    if (titleMap.containsKey('en')) return titleMap['en']!;
    if (titleMap.isNotEmpty) return titleMap.values.first;
    return '';
  }

  String getDescription([String? langCode]) {
    if (langCode!= null && langCode.isNotEmpty) {
      String code = langCode.toLowerCase();
      if (descriptionMap.containsKey(code)) {
        String v = descriptionMap[code]!;
        if (v.trim().isNotEmpty) return v;
      }
    }
    if (descriptionMap.containsKey('roman')) return descriptionMap['roman']!;
    if (descriptionMap.containsKey('en')) return descriptionMap['en']!;
    if (descriptionMap.isNotEmpty) return descriptionMap.values.first;
    return '';
  }

  String getContent([String? langCode]) {
    return getDescription(langCode);
  }

  factory NewsModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = {};
    if (doc.data()!= null) {
      data = doc.data() as Map<String, dynamic>;
    }

    String timeAgo = 'Abhi abhi';
    if (data['timeAgo'] is String) {
      timeAgo = data['timeAgo'] as String;
    }

    Timestamp? ts;
    if (data['timestamp'] is Timestamp) {
      ts = data['timestamp'] as Timestamp;
      Duration diff = DateTime.now().difference(ts.toDate());
      if (diff.inMinutes < 60) {
        int m = diff.inMinutes <= 0? 1 : diff.inMinutes;
        timeAgo = '$m m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    }

    Map<String, String> parseMap(dynamic val) {
      Map<String, String> res = {};
      if (val is Map) {
        val.forEach((k, v) {
          if (v!= null) res[k.toString()] = v.toString();
        });
      } else if (val is String && val.isNotEmpty) {
        res['roman'] = val;
        res['en'] = val;
      }
      if (res.isEmpty) {
        res['roman'] = '';
      }
      return res;
    }

    String img = '';
    if (data['imageUrl'] is String) img = data['imageUrl'] as String;
    if (img.isEmpty && data['appId']!= null) {
      img = 'https://cdn.akamai.steamstatic.com/steam/apps/${data['appId']}/header.jpg';
    }
    if (img.isEmpty) {
      img = 'https://picsum.photos/seed/${doc.id}/800/600';
    }

    String cat = 'Gaming News';
    if (data['category'] is String) cat = data['category'] as String;

    int v = 0;
    if (data['views'] is num) v = (data['views'] as num).toInt();

    bool free = false;
    if (data['isFree'] is bool) free = data['isFree'] as bool;

    bool featured = false;
    if (data['isFeatured'] is bool) featured = data['isFeatured'] as bool;

    bool auto = false;
    if (data['isAuto'] is bool) auto = data['isAuto'] as bool;

    int? aId;
    if (data['appId'] is num) aId = (data['appId'] as num).toInt();

    return NewsModel(
      id: doc.id,
      titleMap: parseMap(data['title']),
      descriptionMap: parseMap(data['content']!= null? data['content'] : data['description']),
      category: cat,
      imageUrl: img,
      videoUrl: data['videoUrl'] is String? data['videoUrl'] as String : null,
      youtubeId: data['youtubeId'] is String? data['youtubeId'] as String : null,
      timeAgo: timeAgo,
      views: v,
      rating: data['rating'] is num? (data['rating'] as num).toDouble() : null,
      originalPrice: data['originalPrice'] is String? data['originalPrice'] as String : null,
      isFree: free,
      isFeatured: featured,
      timeLeft: data['timeLeft'] is String? data['timeLeft'] as String : null,
      storeName: data['storeName'] is String? data['storeName'] as String : null,
      downloadSize: data['downloadSize'] is String? data['downloadSize'] as String : null,
      sourceUrl: data['sourceUrl'] is String? data['sourceUrl'] as String : null,
      isAuto: auto,
      timestamp: ts,
      appId: aId,
    );
  }
}