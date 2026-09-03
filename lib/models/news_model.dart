import 'package:cloud_firestore/cloud_firestore.dart';

class NewsModel {
  final String id;
  final Map<String, String> titleMap;
  final Map<String, String> descriptionMap;
  final String category;
  final String imageUrl;
  final String timeAgo;
  final int views;
  final Timestamp? timestamp;
  final int? appId;

  NewsModel({
    required this.id,
    required this.titleMap,
    required this.descriptionMap,
    required this.category,
    required this.imageUrl,
    required this.timeAgo,
    this.views = 0,
    this.timestamp,
    this.appId,
  });

  static Map<String, String> _createDefaultMap(String text) {
    return {
      'roman': text,
      'en': text,
    };
  }

  String get title {
    if (titleMap.containsKey('roman')) return titleMap['roman']!;
    return titleMap.values.first;
  }

  String get description {
    if (descriptionMap.containsKey('roman')) return descriptionMap['roman']!;
    return descriptionMap.values.first;
  }

  String get thumbnailUrl => imageUrl;

  factory NewsModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = {};
    if (doc.data() != null) {
      data = doc.data() as Map<String, dynamic>;
    }

    String time = 'Abhi abhi';
    if (data['timeAgo'] != null) {
      time = data['timeAgo'] as String;
    }

    Timestamp? ts;
    if (data['timestamp'] != null) {
      ts = data['timestamp'] as Timestamp;
      Duration diff = DateTime.now().difference(ts.toDate());
      if (diff.inMinutes < 60) {
        int m = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
        time = '$m m ago';
      } else if (diff.inHours < 24) {
        time = '${diff.inHours}h ago';
      } else {
        time = '${diff.inDays}d ago';
      }
    }

    Map<String, String> parseMap(dynamic val) {
      Map<String, String> res = {};
      if (val is Map) {
        val.forEach((k, v) {
          if (v != null) res[k.toString()] = v.toString();
        });
      } else if (val is String) {
        res['roman'] = val;
        res['en'] = val;
      }
      if (res.isEmpty) res['roman'] = '';
      return res;
    }

    String img = '';
    if (data['imageUrl'] != null) img = data['imageUrl'] as String;
    if (img.isEmpty && data['appId'] != null) {
      img = 'https://cdn.akamai.steamstatic.com/steam/apps/${data['appId']}/header.jpg';
    }
    if (img.isEmpty) {
      img = 'https://picsum.photos/seed/${doc.id}/800/600';
    }

    String cat = 'Gaming News';
    if (data['category'] != null) cat = data['category'] as String;

    int v = 0;
    if (data['views'] != null) v = (data['views'] as num).toInt();

    int? aId;
    if (data['appId'] != null) aId = (data['appId'] as num).toInt();

    return NewsModel(
      id: doc.id,
      titleMap: parseMap(data['title']),
      descriptionMap: parseMap(data['content']),
      category: cat,
      imageUrl: img,
      timeAgo: time,
      views: v,
      timestamp: ts,
      appId: aId,
    );
  }
}