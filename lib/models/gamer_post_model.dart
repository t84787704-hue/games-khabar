import 'package:cloud_firestore/cloud_firestore.dart';

class GamerPost {
  final String postId;
  final String userId;
  final String username;
  final String userPhoto;
  final String displayName;
  final String text;
  final String gameTag;
  final int likesCount;
  final int commentsCount;
  final DateTime? createdAt;

  const GamerPost({
    required this.postId,
    required this.userId,
    required this.username,
    this.userPhoto = '',
    required this.displayName,
    required this.text,
    this.gameTag = 'BGMI',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.createdAt,
  });

  factory GamerPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated);
    }

    return GamerPost(
      postId: data['postId'] ?? doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'gamer',
      userPhoto: data['userPhoto'] ?? '',
      displayName: data['displayName'] ?? 'Gamer',
      text: data['text'] ?? '',
      gameTag: data['gameTag'] ?? 'BGMI',
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'username': username,
      'userPhoto': userPhoto,
      'displayName': displayName,
      'text': text.trim(),
      'gameTag': gameTag,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  GamerPost copyWith({
    String? postId,
    String? userId,
    String? username,
    String? userPhoto,
    String? displayName,
    String? text,
    String? gameTag,
    int? likesCount,
    int? commentsCount,
    DateTime? createdAt,
  }) {
    return GamerPost(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userPhoto: userPhoto ?? this.userPhoto,
      displayName: displayName ?? this.displayName,
      text: text ?? this.text,
      gameTag: gameTag ?? this.gameTag,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
