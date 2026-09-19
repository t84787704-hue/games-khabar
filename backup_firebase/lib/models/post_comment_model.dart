import 'package:cloud_firestore/cloud_firestore.dart';

class PostComment {
  final String commentId;
  final String userId;
  final String username;
  final String displayName;
  final String userPhoto;
  final String text;
  final DateTime? createdAt;

  const PostComment({
    required this.commentId,
    required this.userId,
    required this.username,
    required this.displayName,
    this.userPhoto = '',
    required this.text,
    this.createdAt,
  });

  factory PostComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? created;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is String) {
      created = DateTime.tryParse(raw);
    }

    return PostComment(
      commentId: data['commentId'] ?? doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'gamer',
      displayName: data['displayName'] ?? 'Gamer',
      userPhoto: data['userPhoto'] ?? '',
      text: data['text'] ?? '',
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'userPhoto': userPhoto,
      'text': text.trim(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
