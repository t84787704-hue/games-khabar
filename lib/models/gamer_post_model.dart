import 'package:flutter/material.dart';
import 'gamer_user_model.dart';

class GamerPost {
  final String postId;
  final String userId;
  final String username;
  final String userPhoto;
  final String displayName;
  final String text;
  final String? imageUrl;
  final String? videoUrl;
  final String gameTag;
  final String userRank;
  final double userKd;
  final int likesCount;
  final int commentsCount;
  final bool isVerified;
  final bool isDemoAccount;
  final DateTime? createdAt;

  const GamerPost({
    required this.postId,
    required this.userId,
    required this.username,
    this.userPhoto = '',
    required this.displayName,
    required this.text,
    this.imageUrl,
    this.videoUrl,
    this.gameTag = 'BGMI',
    this.userRank = 'Ace',
    this.userKd = 0.0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isVerified = false,
    this.isDemoAccount = false,
    this.createdAt,
  });

  GamerRankBadge getRankBadge() {
    final lowerRank = userRank.toLowerCase().trim();
    if (userKd > 5.0 || lowerRank.contains('kd king') || lowerRank.contains('5+')) {
      return const GamerRankBadge(
        type: RankBadgeType.kdKing,
        label: 'K/D King',
        emoji: '💀',
        icon: Icons.dangerous_rounded,
        primaryColor: Color(0xFFFF2D55),
        backgroundColor: Color(0x33FF2D55),
        borderColor: Color(0x88FF2D55),
      );
    }
    if (lowerRank.contains('conqueror')) {
      return const GamerRankBadge(
        type: RankBadgeType.conqueror,
        label: 'Conqueror',
        emoji: '👑',
        icon: Icons.military_tech_rounded,
        primaryColor: Color(0xFFFF334B),
        backgroundColor: Color(0x33FF334B),
        borderColor: Color(0x99FF334B),
      );
    }
    if (lowerRank.contains('ace') || lowerRank.contains('pro') || lowerRank.isNotEmpty) {
      return const GamerRankBadge(
        type: RankBadgeType.ace,
        label: 'Ace',
        emoji: '⭐',
        icon: Icons.star_rounded,
        primaryColor: Color(0xFFFF9500),
        backgroundColor: Color(0x33FF9500),
        borderColor: Color(0x88FF9500),
      );
    }
    return const GamerRankBadge(
      type: RankBadgeType.none,
      label: '',
      emoji: '',
      icon: Icons.shield,
      primaryColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
    );
  }

  factory GamerPost.fromMap(Map<String, dynamic> data) {
    DateTime? created;
    final rawCreated = data['created_at'] ?? data['createdAt'];
    if (rawCreated is DateTime) {
      created = rawCreated;
    } else if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated);
    } else if (rawCreated != null) {
      try {
        created = (rawCreated as dynamic).toDate();
      } catch (_) {}
    }
    return GamerPost(
      postId: (data['id'] ?? data['post_id'] ?? data['postId'] ?? '').toString(),
      userId: (data['user_id'] ?? data['userId'] ?? '').toString(),
      username: data['username'] ?? 'gamer',
      userPhoto: data['user_avatar'] ?? data['userPhoto'] ?? '',
      displayName: data['displayName'] ?? data['username'] ?? 'Gamer',
      text: data['content'] ?? data['text'] ?? '',
      imageUrl: (data['image_url'] ?? data['imageUrl'] ?? data['media_url']) as String?,
      videoUrl: (data['video_url'] ?? data['videoUrl'] ?? data['mediaUrl']) as String?,
      gameTag: data['game'] ?? data['gameTag'] ?? data['game_tag'] ?? 'BGMI',
      userRank: data['userRank'] ?? data['user_rank'] ?? 'Ace',
      userKd: (data['userKd'] ?? data['user_kd'] as num?)?.toDouble() ?? 0.0,
      likesCount: (data['likes_count'] ?? data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['comments_count'] ?? data['commentsCount'] as num?)?.toInt() ?? 0,
      isVerified: data['isVerified'] == true || data['is_verified'] == true,
      isDemoAccount: data['isDemoAccount'] == true || data['is_demo_account'] == true,
      createdAt: created,
    );
  }

  factory GamerPost.fromFirestore(dynamic doc) {
    Map<String, dynamic> data = {};
    String docId = '';
    try {
      docId = doc.id?.toString() ?? '';
      data = doc.data() as Map<String, dynamic>? ?? {};
    } catch (_) {
      if (doc is Map<String, dynamic>) {
        data = doc;
        docId = data['postId']?.toString() ?? data['id']?.toString() ?? '';
      }
    }
    DateTime? created;
    final rawCreated = data['createdAt'] ?? data['created_at'];
    if (rawCreated != null) {
      if (rawCreated is DateTime) {
        created = rawCreated;
      } else if (rawCreated is String) {
        created = DateTime.tryParse(rawCreated);
      } else {
        try {
          created = (rawCreated as dynamic).toDate();
        } catch (_) {}
      }
    }
    return GamerPost(
      postId: data['postId'] ?? data['id'] ?? docId,
      userId: data['userId'] ?? data['user_id'] ?? '',
      username: data['username'] ?? 'gamer',
      userPhoto: data['userPhoto'] ?? data['user_avatar'] ?? '',
      displayName: data['displayName'] ?? 'Gamer',
      text: data['text'] ?? data['content'] ?? '',
      imageUrl: (data['imageUrl'] ?? data['image_url']) as String?,
      videoUrl: (data['videoUrl'] ?? data['video_url'] ?? data['mediaUrl']) as String?,
      gameTag: data['gameTag'] ?? data['game'] ?? 'BGMI',
      userRank: data['userRank'] ?? 'Ace',
      userKd: (data['userKd'] as num?)?.toDouble() ?? 0.0,
      likesCount: (data['likesCount'] ?? data['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] ?? data['comments_count'] as num?)?.toInt() ?? 0,
      isVerified: data['isVerified'] == true,
      isDemoAccount: data['isDemoAccount'] == true,
      createdAt: created,
    );
  }

  // YE SUPABASE KE LIYE SAHI MAP HAI
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'username': username,
      'user_avatar': userPhoto,
      'display_name': displayName,
      'content': text,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'media_url': videoUrl,
      'game': gameTag,
      'game_tag': gameTag,
      'user_rank': userRank,
      'user_kd': userKd,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'is_verified': isVerified,
      'is_demo_account': isDemoAccount,
    };
  }

  GamerPost copyWith({
    String? postId,
    String? userId,
    String? username,
    String? userPhoto,
    String? displayName,
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? gameTag,
    String? userRank,
    double? userKd,
    int? likesCount,
    int? commentsCount,
    bool? isVerified,
    bool? isDemoAccount,
    DateTime? createdAt,
  }) {
    return GamerPost(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userPhoto: userPhoto ?? this.userPhoto,
      displayName: displayName ?? this.displayName,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      gameTag: gameTag ?? this.gameTag,
      userRank: userRank ?? this.userRank,
      userKd: userKd ?? this.userKd,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isVerified: isVerified ?? this.isVerified,
      isDemoAccount: isDemoAccount ?? this.isDemoAccount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}