import 'package:cloud_firestore/cloud_firestore.dart';

class GamerClip {
  final String id;
  final String userId;
  final String username;
  final String displayName;
  final String userAvatar;
  final String title;
  final String mediaUrl;
  final String thumbnail;
  final String gameTag;
  final String songTitle;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final List<String> likedBy;
  final DateTime? createdAt;

  const GamerClip({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    this.userAvatar = '',
    required this.title,
    required this.mediaUrl,
    this.thumbnail = '',
    this.gameTag = 'BGMI',
    this.songTitle = 'BGMI Theme Trap Beat (Remix)',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.likedBy = const [],
    this.createdAt,
  });

  factory GamerClip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? created;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is String) {
      created = DateTime.tryParse(raw);
    }

    return GamerClip(
      id: data['id'] ?? doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'gamer',
      displayName: data['displayName'] ?? 'Gamer',
      userAvatar: data['userAvatar'] ?? '',
      title: data['title'] ?? 'Insane 1v4 Clutch! 🔥',
      mediaUrl: data['mediaUrl'] ?? '',
      thumbnail: data['thumbnail'] ?? '',
      gameTag: data['gameTag'] ?? 'BGMI',
      songTitle: data['songTitle'] ?? 'BGMI Theme Trap Beat (Remix)',
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      sharesCount: (data['sharesCount'] as num?)?.toInt() ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'userAvatar': userAvatar,
      'title': title.trim(),
      'mediaUrl': mediaUrl,
      'thumbnail': thumbnail,
      'gameTag': gameTag,
      'songTitle': songTitle,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'likedBy': likedBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  GamerClip copyWith({
    String? id,
    String? userId,
    String? username,
    String? displayName,
    String? userAvatar,
    String? title,
    String? mediaUrl,
    String? thumbnail,
    String? gameTag,
    String? songTitle,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    List<String>? likedBy,
    DateTime? createdAt,
  }) {
    return GamerClip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      userAvatar: userAvatar ?? this.userAvatar,
      title: title ?? this.title,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnail: thumbnail ?? this.thumbnail,
      gameTag: gameTag ?? this.gameTag,
      songTitle: songTitle ?? this.songTitle,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      likedBy: likedBy ?? this.likedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
