import 'package:cloud_firestore/cloud_firestore.dart';

class NewsModel {
  final String id;
  final String title;
  final String description;
  final Map<String, String> titleMap;
  final Map<String, String> descriptionMap;
  final bool isFeatured;
  final String? videoUrl;
  final String imageUrl;
  final String category;
  final int appid;
  final String url;
  final int views;
  final int timestamp;
  final String timeAgo;

  NewsModel({
    required this.id,
    required this.title,
    required this.description,
    required this.titleMap,
    required this.descriptionMap,
    required this.isFeatured,
    this.videoUrl,
    required this.imageUrl,
    required this.category,
    required this.appid,
    required this.url,
    required this.views,
    required this.timestamp,
    required this.timeAgo,
  });

  factory NewsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Purani half news aur nayi full news dono ko support karega
    Map<String, String> buildDescMap() {
      if (data['descriptionMap'] != null) {
        return Map<String, String>.from(data['descriptionMap']);
      }
      return {
        'en': (data['description_en'] ?? data['description'] ?? '').toString(),
        'ur': (data['description_ur'] ?? data['description'] ?? '').toString(),
        'ro': (data['description_ro'] ?? data['description'] ?? '').toString(),
      };
    }

    Map<String, String> buildTitleMap() {
      if (data['titleMap'] != null) {
        return Map<String, String>.from(data['titleMap']);
      }
      return {
        'en': (data['title_en'] ?? data['title'] ?? '').toString(),
        'ur': (data['title_ur'] ?? data['title'] ?? '').toString(),
        'ro': (data['title_ro'] ?? data['title'] ?? '').toString(),
      };
    }

    return NewsModel(
      id: data['id'] ?? doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? data['description_en'] ?? '',
      titleMap: buildTitleMap(),
      descriptionMap: buildDescMap(),
      isFeatured: data['isFeatured'] ?? false,
      videoUrl: data['videoUrl'],
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] ?? 'Action Games',
      appid: (data['appid'] is int) ? data['appid'] : int.tryParse(data['appid'].toString()) ?? 0,
      url: data['url'] ?? '',
      views: (data['views'] is int) ? data['views'] : int.tryParse(data['views'].toString()) ?? 0,
      timestamp: (data['timestamp'] is int) ? data['timestamp'] : 0,
      timeAgo: data['timeAgo'] ?? '',
    );
  }
}