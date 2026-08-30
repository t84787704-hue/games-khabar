import 'package:cloud_firestore/cloud_firestore.dart';

class NewsModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String imageUrl;
  final String? videoUrl;
  final String? youtubeId;
  final String timeAgo;
  final int views;
  final double? rating;
  final String? originalPrice;
  final bool isFree;
  final String? timeLeft;
  final String? storeName;
  final String? downloadSize;
  final String? sourceUrl;
  final Timestamp? timestamp;

  NewsModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    this.videoUrl,
    this.youtubeId,
    required this.timeAgo,
    this.views = 0,
    this.rating,
    this.originalPrice,
    this.isFree = false,
    this.timeLeft,
    this.storeName,
    this.downloadSize,
    this.sourceUrl,
    this.timestamp,
  });

  factory NewsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Calculate relative time if timestamp exists
    String formattedTime = data['timeAgo'] as String? ?? 'Abhi abhi';
    final ts = data['timestamp'] as Timestamp?;
    if (ts != null) {
      final diff = DateTime.now().difference(ts.toDate());
      if (diff.inMinutes < 60) {
        formattedTime = '${diff.inMinutes <= 0 ? 1 : diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        formattedTime = '${diff.inHours}h ago';
      } else {
        formattedTime = '${diff.inDays}d ago';
      }
    }

    return NewsModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'Gaming News',
      imageUrl: (data['imageUrl'] as String? ?? '').isNotEmpty
          ? data['imageUrl'] as String
          : 'https://picsum.photos/800/600?random=1',
      videoUrl: data['videoUrl'] as String?,
      youtubeId: data['youtubeId'] as String?,
      timeAgo: formattedTime,
      views: (data['views'] as num?)?.toInt() ?? 0,
      rating: (data['rating'] as num?)?.toDouble(),
      originalPrice: data['originalPrice'] as String?,
      isFree: data['isFree'] as bool? ?? false,
      timeLeft: data['timeLeft'] as String?,
      storeName: data['storeName'] as String?,
      downloadSize: data['downloadSize'] as String?,
      sourceUrl: data['sourceUrl'] as String?,
      timestamp: ts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'youtubeId': youtubeId,
      'timeAgo': timeAgo,
      'views': views,
      'rating': rating,
      'originalPrice': originalPrice,
      'isFree': isFree,
      'timeLeft': timeLeft,
      'storeName': storeName,
      'downloadSize': downloadSize,
      'sourceUrl': sourceUrl,
      'timestampMillis': timestamp?.millisecondsSinceEpoch,
    };
  }

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    Timestamp? ts;
    if (json['timestampMillis'] != null) {
      ts = Timestamp.fromMillisecondsSinceEpoch(json['timestampMillis'] as int);
    }
    return NewsModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Gaming News',
      imageUrl: json['imageUrl'] as String? ?? 'https://picsum.photos/800/600?random=1',
      videoUrl: json['videoUrl'] as String?,
      youtubeId: json['youtubeId'] as String?,
      timeAgo: json['timeAgo'] as String? ?? 'Recently',
      views: (json['views'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
      originalPrice: json['originalPrice'] as String?,
      isFree: json['isFree'] as bool? ?? false,
      timeLeft: json['timeLeft'] as String?,
      storeName: json['storeName'] as String?,
      downloadSize: json['downloadSize'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      timestamp: ts,
    );
  }
}
