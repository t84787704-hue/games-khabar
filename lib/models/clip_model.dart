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
  final int viewsCount;
  final List<String> likedBy;
  final DateTime? createdAt;
  final double duration;
  final double originalDuration;
  final String publicId;
  final bool isGamingClip;

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
    this.viewsCount = 0,
    this.likedBy = const [],
    this.createdAt,
    this.duration = 0.0,
    this.originalDuration = 0.0,
    this.publicId = '',
    this.isGamingClip = true,
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

    final titleText = data['caption']?.toString() ?? data['title']?.toString() ?? 'Gaming Clip 🔥';
    final videoUrlText = data['videoUrl']?.toString() ?? data['mediaUrl']?.toString() ?? '';
    final thumbText = data['thumbnail']?.toString() ?? data['thumbnailUrl']?.toString() ?? '';

    return GamerClip(
      id: data['id'] ?? doc.id,
      userId: data['userId'] ?? data['uploaderId'] ?? '',
      username: data['username'] ?? 'gamer',
      displayName: data['displayName'] ?? 'Gamer',
      userAvatar: data['userAvatar'] ?? '',
      title: titleText,
      mediaUrl: videoUrlText,
      thumbnail: thumbText,
      gameTag: data['gameTag'] ?? 'BGMI',
      songTitle: data['songTitle'] ?? 'BGMI Theme Trap Beat (Remix)',
      likesCount: (data['likesCount'] as num?)?.toInt() ?? (data['likes'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      sharesCount: (data['sharesCount'] as num?)?.toInt() ?? 0,
      viewsCount: (data['viewsCount'] as num?)?.toInt() ?? (data['views'] as num?)?.toInt() ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      createdAt: created,
      duration: (data['duration'] as num?)?.toDouble() ?? 0.0,
      originalDuration: (data['originalDuration'] as num?)?.toDouble() ?? 0.0,
      publicId: data['publicId']?.toString() ?? '',
      isGamingClip: data['isGamingClip'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'uploaderId': userId,
      'username': username,
      'displayName': displayName,
      'userAvatar': userAvatar,
      'caption': title.trim(),
      'title': title.trim(),
      'videoUrl': mediaUrl,
      'mediaUrl': mediaUrl,
      'thumbnail': thumbnail,
      'thumbnailUrl': thumbnail,
      'publicId': publicId,
      'gameTag': gameTag,
      'songTitle': songTitle,
      'duration': duration,
      'originalDuration': originalDuration,
      'isGamingClip': isGamingClip,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'viewsCount': viewsCount,
      'likes': likesCount,
      'views': viewsCount,
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
    int? viewsCount,
    List<String>? likedBy,
    DateTime? createdAt,
    double? duration,
    double? originalDuration,
    String? publicId,
    bool? isGamingClip,
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
      viewsCount: viewsCount ?? this.viewsCount,
      likedBy: likedBy ?? this.likedBy,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
      originalDuration: originalDuration ?? this.originalDuration,
      publicId: publicId ?? this.publicId,
      isGamingClip: isGamingClip ?? this.isGamingClip,
    );
  }
}
