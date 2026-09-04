class NewsModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String category;
  final String url;
  final int timestamp;
  final int views;
  final Map<String, dynamic>? titleTranslations;
  final Map<String, dynamic>? descTranslations;

  NewsModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.url,
    required this.timestamp,
    required this.views,
    this.titleTranslations,
    this.descTranslations,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      id: json['id'] ?? '',
      title: json['title'] ?? json['title_en'] ?? '',
      description: json['description'] ?? json['description_en'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      category: json['category'] ?? 'Action Games',
      url: json['url'] ?? '',
      timestamp: json['timestamp'] ?? 0,
      views: json['views'] ?? 0,
      titleTranslations: {
        'en': json['title_en'] ?? json['title'] ?? '',
        'ur': json['title_ur'] ?? json['title'] ?? '',
        'ro': json['title_ro'] ?? json['title'] ?? '',
      },
      descTranslations: {
        'en': json['description_en'] ?? json['description'] ?? '',
        'ur': json['description_ur'] ?? json['description'] ?? '',
        'ro': json['description_ro'] ?? json['description'] ?? '',
      },
    );
  }

  String getTitle(String langCode) {
    if (langCode == 'ur') return descTranslations?['ur'] != '' ? titleTranslations?['ur'] ?? title : title;
    if (langCode == 'ro') return titleTranslations?['ro'] ?? title;
    return titleTranslations?['en'] ?? title;
  }

  String getDescription(String langCode) {
    if (langCode == 'ur') return descTranslations?['ur'] ?? description;
    if (langCode == 'ro') return descTranslations?['ro'] ?? description;
    return descTranslations?['en'] ?? description;
  }

  String get timeAgo {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'imageUrl': imageUrl,
    'category': category,
  };
}