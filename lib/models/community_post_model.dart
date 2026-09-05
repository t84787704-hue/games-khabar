import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory CommunityPostModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime parsedDate;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      parsedDate = rawCreated.toDate();
    } else if (rawCreated is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else {
      parsedDate = DateTime.now();
    }

    return CommunityPostModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Gamer',
      isVIP: data['isVIP'] as bool? ?? false,
      gameName: data['gameName'] as String? ?? 'All',
      text: data['text'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      helpfulCount: (data['helpfulCount'] as num?)?.toInt() ?? 0,
      reportCount: (data['reportCount'] as num?)?.toInt() ?? 0,
      isApproved: data['isApproved'] as bool? ?? true,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'isVIP': isVIP,
      'gameName': gameName,
      'text': text,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      'likes': likes,
      'commentCount': commentCount,
      'helpfulCount': helpfulCount,
      'reportCount': reportCount,
      'isApproved': isApproved,
      'createdAt': FieldValue.serverTimestamp(),
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

  factory CommunityCommentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime parsedDate;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      parsedDate = rawCreated.toDate();
    } else if (rawCreated is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else {
      parsedDate = DateTime.now();
    }

    return CommunityCommentModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Gamer',
      isVIP: data['isVIP'] as bool? ?? false,
      text: data['text'] as String? ?? '',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'isVIP': isVIP,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
