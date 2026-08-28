import 'package:cloud_firestore/cloud_firestore.dart';

enum NewsCategory {
  ALL,
  NEWS,
  FREE,
  REVIEW,
  TRAILER,
  DISCOUNT,
  LOW_MB,
}

extension NewsCategoryExtension on NewsCategory {
  String get displayName {
    switch (this) {
      case NewsCategory.ALL:
        return 'All';
      case NewsCategory.NEWS:
        return 'Taza Khabar';
      case NewsCategory.FREE:
        return 'Free Games';
      case NewsCategory.REVIEW:
        return 'Reviews';
      case NewsCategory.TRAILER:
        return 'Trailers';
      case NewsCategory.DISCOUNT:
        return 'Discounts';
      case NewsCategory.LOW_MB:
        return 'Low MB Games';
    }
  }

  String get badgeName {
    switch (this) {
      case NewsCategory.ALL:
        return 'ALL';
      case NewsCategory.NEWS:
        return 'NEWS';
      case NewsCategory.FREE:
        return 'FREE';
      case NewsCategory.REVIEW:
        return 'REVIEW';
      case NewsCategory.TRAILER:
        return 'TRAILER';
      case NewsCategory.DISCOUNT:
        return 'DISCOUNT';
      case NewsCategory.LOW_MB:
        return 'LOW MB';
    }
  }

  static NewsCategory fromString(String? val) {
    if (val == null) return NewsCategory.NEWS;
    switch (val.toUpperCase()) {
      case 'NEWS':
      case 'TAZA KHABAR':
        return NewsCategory.NEWS;
      case 'FREE':
      case 'FREE GAMES':
        return NewsCategory.FREE;
      case 'REVIEW':
      case 'REVIEWS':
        return NewsCategory.REVIEW;
      case 'TRAILER':
      case 'TRAILERS':
        return NewsCategory.TRAILER;
      case 'DISCOUNT':
      case 'DISCOUNTS':
        return NewsCategory.DISCOUNT;
      case 'LOW_MB':
      case 'LOW MB':
      case 'LOW MB GAMES':
        return NewsCategory.LOW_MB;
      default:
        return NewsCategory.NEWS;
    }
  }
}

class NewsModel {
  final String id;
  final String title;
  final String description;
  final NewsCategory category;
  final String imageUrl;
  final String? youtubeId;
  final String timeAgo;
  final int views;
  final double? rating;
  final String? originalPrice;
  final bool isFree;
  final String? timeLeft;
  final String? storeName;
  final String? downloadSize;
  final Timestamp? timestamp;

  NewsModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    this.youtubeId,
    required this.timeAgo,
    this.views = 0,
    this.rating,
    this.originalPrice,
    this.isFree = false,
    this.timeLeft,
    this.storeName,
    this.downloadSize,
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
        formattedTime = '${diff.inMinutes} min pehle';
      } else if (diff.inHours < 24) {
        formattedTime = '${diff.inHours} ghante pehle';
      } else {
        formattedTime = '${diff.inDays} din pehle';
      }
    }

    return NewsModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: NewsCategoryExtension.fromString(data['category'] as String?),
      imageUrl: data['imageUrl'] as String? ?? 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
      youtubeId: data['youtubeId'] as String?,
      timeAgo: formattedTime,
      views: (data['views'] as num?)?.toInt() ?? 0,
      rating: (data['rating'] as num?)?.toDouble(),
      originalPrice: data['originalPrice'] as String?,
      isFree: data['isFree'] as bool? ?? false,
      timeLeft: data['timeLeft'] as String?,
      storeName: data['storeName'] as String?,
      downloadSize: data['downloadSize'] as String?,
      timestamp: ts,
    );
  }
}
