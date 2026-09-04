import 'package:cloud_firestore/cloud_firestore.dart';

class NewsModel {
  final String id;
  final String title;
  final String description;
  final Map<String, String> titleMap;
  final Map<String, String> descriptionMap;
  final bool isFeatured;
  final bool isAuto;
  final bool isFree;
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
    this.title = '',
    this.description = '',
    Map<String, String>? titleMap,
    Map<String, String>? descriptionMap,
    this.isFeatured = false,
    this.isAuto = false,
    this.isFree = false,
    this.videoUrl,
    this.imageUrl = '',
    this.category = 'Action Games',
    this.appid = 0,
    this.url = '',
    this.views = 0,
    this.timestamp = 0,
    this.timeAgo = '',
  }) : titleMap = titleMap?? {'en': title, 'ur': title, 'ro': title},
        descriptionMap = descriptionMap?? {'en': description, 'ur': description, 'ro': description};

  // Screens yehi 2 method dhoond rahi hain
  String getTitle(String langCode) {
    return titleMap[langCode]?? titleMap['en']?? title;
  }

  String getDescription(String langCode) {
    return descriptionMap[langCode]?? descriptionMap['en']?? description;
  }

  NewsModel copyWith({
    String? id,
    String? title,
    String? description,
    Map<String, String>? titleMap,
    Map<String, String>? descriptionMap,
    bool? isFeatured,
    bool? isAuto,
    bool? isFree,
    String? videoUrl,
    String? imageUrl,
    String? category,
    int? appid,
    String? url,
    int? views,
    int? timestamp,
    String? timeAgo,
  }) {
    return NewsModel(
      id: id?? this.id,
      title: title?? this.title,
      description: description?? this.description,
      titleMap: titleMap?? this.titleMap,
      descriptionMap: descriptionMap?? this.descriptionMap,
      isFeatured: isFeatured?? this.isFeatured,
      isAuto: isAuto?? this.isAuto,
      isFree: isFree?? this.isFree,
      videoUrl: videoUrl?? this.videoUrl,
      imageUrl: imageUrl?? this.imageUrl,
      category: category?? this.category,
      appid: appid?? this.appid,
      url: url?? this.url,
      views: views?? this.views,
      timestamp: timestamp?? this.timestamp,
      timeAgo: timeAgo?? this.timeAgo,
    );
  }

  factory NewsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>??? {};

    Map<String, String> buildMap(String enKey, String urKey, String roKey, String fallbackKey, String mapKey) {
      if (data[mapKey]!= null) {
        return Map<String, String>.from((data[mapKey] as Map).map((k, v) => MapEntry(k.toString(), v.toString())));
      }
      return {
        'en': (data[enKey]?? data[fallbackKey]?? '').toString(),
        'ur': (data[urKey]?? data[fallbackKey]?? '').toString(),
        'ro': (data[roKey]?? data[fallbackKey]?? '').toString(),
      };
    }

    return NewsModel(
      id: data['id']?.toString()?? doc.id,
      title: (data['title']?? '').toString(),
      description: (data['description']?? data['description_en']?? '').toString(),
      titleMap: buildMap('title_en', 'title_ur', 'title_ro', 'title', 'titleMap'),
      descriptionMap: buildMap('description_en', 'description_ur', 'description_ro', 'description', 'descriptionMap'),
      isFeatured: data['isFeatured']?? false,
      isAuto: data['isAuto']?? false,
      isFree: data['isFree']?? false,
      videoUrl: data['videoUrl']?.toString(),
      imageUrl: (data['imageUrl']?? '').toString(),
      category: (data['category']?? 'Action Games').toString(),
      appid: data['appid'] is int? data['appid'] : int.tryParse(data['appid'].toString())?? 0,
      url: (data['url']?? '').toString(),
      views: data['views'] is int? data['views'] : int.tryParse(data['views'].toString())?? 0,
      timestamp: data['timestamp'] is int? data['timestamp'] : 0,
      timeAgo: (data['timeAgo']?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'titleMap': titleMap,
      'descriptionMap': descriptionMap,
      'isFeatured': isFeatured,
      'isAuto': isAuto,
      'isFree': isFree,
      'videoUrl': videoUrl,
      'imageUrl': imageUrl,
      'category': category,
      'appid': appid,
      'url': url,
      'views': views,
      'timestamp': timestamp,
      'timeAgo': timeAgo,
    };
  }
}