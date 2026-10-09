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

  factory PostComment.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime? created;
    final raw = data['created_at'] ?? data['createdAt'];
    if (raw is DateTime) {
      created = raw;
    } else if (raw is String) {
      created = DateTime.tryParse(raw);
    } else if (raw is int) {
      created = DateTime.fromMillisecondsSinceEpoch(raw);
    } else {
      try {
        final dt = (raw as dynamic)?.toDate();
        if (dt is DateTime) created = dt;
      } catch (_) {}
    }

    return PostComment(
      commentId: (id ?? data['id'] ?? data['comment_id'] ?? data['commentId'] ?? '').toString(),
      userId: (data['user_id'] ?? data['userId'] ?? '').toString(),
      username: data['username'] ?? 'gamer',
      displayName: data['displayName'] ?? data['display_name'] ?? data['username'] ?? 'Gamer',
      userPhoto: data['user_avatar'] ?? data['userPhoto'] ?? data['avatar_url'] ?? '',
      text: data['content'] ?? data['text'] ?? '',
      createdAt: created,
    );
  }

  factory PostComment.fromFirestore(dynamic doc) => PostComment.fromSupabase(doc);
  factory PostComment.fromSupabase(dynamic doc) {
    if (doc == null) return PostComment.fromMap({}, '');
    try {
      final data = (doc as dynamic).data();
      if (data is Map<String, dynamic>) {
        return PostComment.fromMap(data, (doc as dynamic).id?.toString());
      }
    } catch (_) {}
    if (doc is Map<String, dynamic>) {
      return PostComment.fromMap(doc, doc['id']?.toString());
    }
    return PostComment.fromMap({}, '');
  }

  Map<String, dynamic> toMap() {
    final timeStr = (createdAt ?? DateTime.now()).toIso8601String();
    return {
      'commentId': commentId,
      'comment_id': commentId,
      'id': commentId,
      'userId': userId,
      'user_id': userId,
      'username': username,
      'displayName': displayName,
      'display_name': displayName,
      'userPhoto': userPhoto,
      'user_avatar': userPhoto,
      'avatar_url': userPhoto,
      'text': text.trim(),
      'content': text.trim(),
      'createdAt': timeStr,
      'created_at': timeStr,
    };
  }
}
