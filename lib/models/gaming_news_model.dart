import 'package:cloud_firestore/cloud_firestore.dart';

class GamingNewsModel {
  final String id;
  final String titleEn;
  final String titleUr;
  final String category;
  final String platform;
  final String imageUrl;
  final String summary;
  final String fullContent;
  final String sourceUrl;
  final DateTime timestamp;
  final int views;

  GamingNewsModel({
    required this.id,
    required this.titleEn,
    required this.titleUr,
    required this.category,
    required this.platform,
    required this.imageUrl,
    required this.summary,
    this.fullContent = '',
    required this.sourceUrl,
    required this.timestamp,
    this.views = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title_en': titleEn,
      'title_ur': titleUr,
      'category': category,
      'platform': platform,
      'imageUrl': imageUrl,
      'summary': summary,
      'fullContent': fullContent.isNotEmpty ? fullContent : summary,
      'sourceUrl': sourceUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'views': views,
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

    return GamingNewsModel(
      id: docId ?? map['id'] ?? '',
      titleEn: map['title_en'] ?? map['title'] ?? '',
      titleUr: map['title_ur'] ?? '',
      category: map['category'] ?? 'FEATURED',
      platform: map['platform'] ?? 'Multiplatform',
      imageUrl: map['imageUrl'] ?? map['image'] ?? '',
      summary: map['summary'] ?? map['description'] ?? '',
      fullContent: (map['fullContent'] ?? map['content'] ?? map['description'] ?? map['summary'] ?? '').toString(),
      sourceUrl: map['sourceUrl'] ?? map['url'] ?? '',
      timestamp: parsedTime,
      views: (map['views'] is num) ? (map['views'] as num).toInt() : 0,
    );
  }

  /// Returns fullContent if available, otherwise summary, or a default text
  String get displayContent {
    if (fullContent.trim().isNotEmpty) return fullContent.trim();
    if (summary.trim().isNotEmpty) return summary.trim();
    return 'Detailed gaming article will appear here shortly.';
  }

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
    String? category,
    String? platform,
    String? imageUrl,
    String? summary,
    String? fullContent,
    String? sourceUrl,
    DateTime? timestamp,
    int? views,
  }) {
    return GamingNewsModel(
      id: id ?? this.id,
      titleEn: titleEn ?? this.titleEn,
      titleUr: titleUr ?? this.titleUr,
      category: category ?? this.category,
      platform: platform ?? this.platform,
      imageUrl: imageUrl ?? this.imageUrl,
      summary: summary ?? this.summary,
      fullContent: fullContent ?? this.fullContent,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      timestamp: timestamp ?? this.timestamp,
      views: views ?? this.views,
    );
  }
}
