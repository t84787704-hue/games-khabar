class CommunityPostModel {
  final String id;
  final String userId;
  final String userName;
  final bool isVIP;
  final String gameName;
  final String text;
  final String? imageUrl;
  final int likes;
  final int commentCount;
  final int helpfulCount;
  final int reportCount;
  final bool isApproved;
  final DateTime createdAt;

  CommunityPostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.isVIP,
    required this.gameName,
    required this.text,
    this.imageUrl,
    this.likes = 0,
    this.commentCount = 0,
    this.helpfulCount = 0,
    this.reportCount = 0,
    this.isApproved = true,
    required this.createdAt,
  });

  factory CommunityPostModel.fromFirestore(dynamic doc) {
    if (doc == null) return CommunityPostModel.fromMap({}, '');
    try {
      final data = (doc as dynamic).data();
      if (data is Map<String, dynamic>) {
        return CommunityPostModel.fromMap(data, (doc as dynamic).id?.toString());
      }
    } catch (_) {}
    if (doc is Map<String, dynamic>) {
      return CommunityPostModel.fromMap(doc, doc['id']?.toString());
    }
    return CommunityPostModel.fromMap({}, '');
  }

  factory CommunityPostModel.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime parsedDate = DateTime.now();
    final rawCreated = data['createdAt'] ?? data['created_at'];
    if (rawCreated is DateTime) {
      parsedDate = rawCreated;
    } else if (rawCreated is String) {
      parsedDate = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else if (rawCreated is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else {
      try {
        parsedDate = (rawCreated as dynamic)?.toDate() ?? DateTime.now();
      } catch (_) {
        parsedDate = DateTime.now();
      }
    }

    return CommunityPostModel(
      id: id ?? data['id']?.toString() ?? '',
      userId: data['userId'] as String? ?? data['user_id'] as String? ?? '',
      userName: data['userName'] as String? ?? data['user_name'] as String? ?? 'Gamer',
      isVIP: data['isVIP'] as bool? ?? data['is_vip'] as bool? ?? false,
      gameName: data['gameName'] as String? ?? data['game_name'] as String? ?? 'All',
      text: data['text'] as String? ?? data['content'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? data['image_url'] as String?,
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? (data['comment_count'] as num?)?.toInt() ?? 0,
      helpfulCount: (data['helpfulCount'] as num?)?.toInt() ?? (data['helpful_count'] as num?)?.toInt() ?? 0,
      reportCount: (data['reportCount'] as num?)?.toInt() ?? (data['report_count'] as num?)?.toInt() ?? 0,
      isApproved: data['isApproved'] as bool? ?? data['is_approved'] as bool? ?? true,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'user_id': userId,
      'userName': userName,
      'user_name': userName,
      'isVIP': isVIP,
      'is_vip': isVIP,
      'gameName': gameName,
      'game_name': gameName,
      'text': text,
      'content': text,
      if (imageUrl != null && imageUrl!.isNotEmpty) ...{
        'imageUrl': imageUrl,
        'image_url': imageUrl,
      },
      'likes': likes,
      'commentCount': commentCount,
      'comment_count': commentCount,
      'helpfulCount': helpfulCount,
      'helpful_count': helpfulCount,
      'reportCount': reportCount,
      'report_count': reportCount,
      'isApproved': isApproved,
      'is_approved': isApproved,
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class CommunityCommentModel {
  final String id;
  final String userId;
  final String userName;
  final bool isVIP;
  final String text;
  final DateTime createdAt;

  CommunityCommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.isVIP,
    required this.text,
    required this.createdAt,
  });

  factory CommunityCommentModel.fromFirestore(dynamic doc) {
    if (doc == null) return CommunityCommentModel.fromMap({}, '');
    try {
      final data = (doc as dynamic).data();
      if (data is Map<String, dynamic>) {
        return CommunityCommentModel.fromMap(data, (doc as dynamic).id?.toString());
      }
    } catch (_) {}
    if (doc is Map<String, dynamic>) {
      return CommunityCommentModel.fromMap(doc, doc['id']?.toString());
    }
    return CommunityCommentModel.fromMap({}, '');
  }

  factory CommunityCommentModel.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime parsedDate = DateTime.now();
    final rawCreated = data['createdAt'] ?? data['created_at'];
    if (rawCreated is DateTime) {
      parsedDate = rawCreated;
    } else if (rawCreated is String) {
      parsedDate = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else if (rawCreated is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else {
      try {
        parsedDate = (rawCreated as dynamic)?.toDate() ?? DateTime.now();
      } catch (_) {
        parsedDate = DateTime.now();
      }
    }

    return CommunityCommentModel(
      id: id ?? data['id']?.toString() ?? '',
      userId: data['userId'] as String? ?? data['user_id'] as String? ?? '',
      userName: data['userName'] as String? ?? data['user_name'] as String? ?? 'Gamer',
      isVIP: data['isVIP'] as bool? ?? data['is_vip'] as bool? ?? false,
      text: data['text'] as String? ?? data['comment'] as String? ?? '',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'user_id': userId,
      'userName': userName,
      'user_name': userName,
      'isVIP': isVIP,
      'is_vip': isVIP,
      'text': text,
      'comment': text,
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
