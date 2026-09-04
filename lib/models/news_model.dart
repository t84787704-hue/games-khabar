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
  final String? sourceUrl;
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
    this.sourceUrl,
    this.imageUrl = '',
    this.category = 'Action Games',
    this.appid = 0,
    this.url = '',
    this.views = 0,
    this.timestamp = 0,
    this.timeAgo = '',
  }) : titleMap = titleMap!= null? titleMap : {'en': title, 'ur': title, 'ro': title},
        descriptionMap = descriptionMap!= null? descriptionMap : {'en': description, 'ur': description, 'ro': description};

  String getTitle(String langCode) {
    if (titleMap.containsKey(langCode)) {
      return titleMap[langCode]!;
    }
    if (titleMap.containsKey('en')) {
      return titleMap['en']!;
    }
    return title;
  }

  String getDescription(String langCode) {
    if (descriptionMap.containsKey(langCode)) {
      return descriptionMap[langCode]!;
    }
    if (descriptionMap.containsKey('en')) {
      return descriptionMap['en']!;
    }
    return description;
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
    String? sourceUrl,
    String? imageUrl,
    String? category,
    int? appid,
    String? url,
    int? views,
    int? timestamp,
    String? timeAgo,
  }) {
    return NewsModel(
      id: id!= null? id : this.id,
      title: title!= null? title : this.title,
      description: description!= null? description : this.description,
      titleMap: titleMap!= null? titleMap : this.titleMap,
      descriptionMap: descriptionMap!= null? descriptionMap : this.descriptionMap,
      isFeatured: isFeatured!= null? isFeatured : this.isFeatured,
      isAuto: isAuto!= null? isAuto : this.isAuto,
      isFree: isFree!= null? isFree : this.isFree,
      videoUrl: videoUrl!= null? videoUrl : this.videoUrl,
      sourceUrl: sourceUrl!= null? sourceUrl : this.sourceUrl,
      imageUrl: imageUrl!= null? imageUrl : this.imageUrl,
      category: category!= null? category : this.category,
      appid: appid!= null? appid : this.appid,
      url: url!= null? url : this.url,
      views: views!= null? views : this.views,
      timestamp: timestamp!= null? timestamp : this.timestamp,
      timeAgo: timeAgo!= null? timeAgo : this.timeAgo,
    );
  }

  factory NewsModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>?;
    Map<String, dynamic> data = {};
    if (raw!= null) {
      data = raw;
    }
    return NewsModel.fromJson(data, docId: doc.id);
  }

  factory NewsModel.fromJson(Map<String, dynamic> data, {String? docId}) {
    Map<String, String> buildMap(String enKey, String urKey, String roKey, String fallbackKey, String mapKey) {
      if (data[mapKey]!= null && data[mapKey] is Map) {
        Map<String, String> result = {};
        (data[mapKey] as Map).forEach((k, v) {
          result[k.toString()] = v.toString();
        });
        return result;
      }
      String en = data[enKey]!= null? data[enKey].toString() : '';
      String ur = data[urKey]!= null? data[urKey].toString() : '';
      String ro = data[roKey]!= null? data[roKey].toString() : '';
      String fb = data[fallbackKey]!= null? data[fallbackKey].toString() : '';
      if (en == '') en = fb;
      if (ur == '') ur = fb;
      if (ro == '') ro = fb;
      return {'en': en, 'ur': ur, 'ro': ro};
    }

    String idVal = '';
    if (data['id']!= null) idVal = data['id'].toString();
    else if (docId!= null) idVal = docId;

    String titleVal = data['title']!= null? data['title'].toString() : '';
    String descVal = '';
    if (data['description']!= null) descVal = data['description'].toString();
    else if (data['description_en']!= null) descVal = data['description_en'].toString();

    return NewsModel(
      id: idVal,
      title: titleVal,
      description: descVal,
      titleMap: buildMap('title_en', 'title_ur', 'title_ro', 'title', 'titleMap'),
      descriptionMap: buildMap('description_en', 'description_ur', 'description_ro', 'description', 'descriptionMap'),
      isFeatured: data['isFeatured'] == true,
      isAuto: data['isAuto'] == true,
      isFree: data['isFree'] == true,
      videoUrl: data['videoUrl']!= null? data['videoUrl'].toString() : null,
      sourceUrl: data['sourceUrl']!= null? data['sourceUrl'].toString() : null,
      imageUrl: data['imageUrl']!= null? data['imageUrl'].toString() : '',
      category: data['category']!= null? data['category'].toString() : 'Action Games',
      appid: data['appid'] is int? data['appid'] : 0,
      url: data['url']!= null? data['url'].toString() : '',
      views: data['views'] is int? data['views'] : 0,
      timestamp: data['timestamp'] is int? data['timestamp'] : 0,
      timeAgo: data['timeAgo']!= null? data['timeAgo'].toString() : '',
    );
  }

  Map<String, dynamic> toJson() {
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
      'sourceUrl': sourceUrl,
      'imageUrl': imageUrl,
      'category': category,
      'appid': appid,
      'url': url,
      'views': views,
      'timestamp': timestamp,
      'timeAgo': timeAgo,
    };
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }
}