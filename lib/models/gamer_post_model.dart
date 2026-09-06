import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gamer_user_model.dart';

class GamerPost {
  final String postId;
  final String userId;
  final String username;
  final String userPhoto;
  final String displayName;
  final String text;
  final String gameTag;
  final String userRank;
  final double userKd;
  final int likesCount;
  final int commentsCount;
  final bool isVerified;
  final DateTime? createdAt;

  const GamerPost({
    required this.postId,
    required this.userId,
    required this.username,
    this.userPhoto = '',
    required this.displayName,
    required this.text,
    this.gameTag = 'BGMI',
    this.userRank = 'Ace',
    this.userKd = 0.0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isVerified = false,
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
      userRank: data['userRank'] ?? 'Ace',
      userKd: (data['userKd'] as num?)?.toDouble() ?? 0.0,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      isVerified: data['isVerified'] == true,
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
      'userRank': userRank,
      'userKd': userKd,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'isVerified': isVerified,
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
    String? userRank,
    double? userKd,
    int? likesCount,
    int? commentsCount,
    bool? isVerified,
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
      userRank: userRank ?? this.userRank,
      userKd: userKd ?? this.userKd,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
