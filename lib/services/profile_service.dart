import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gamer_post_model.dart';
import 'supabase_service.dart';

/// Model for an item displayed in the Gamer Profile Posts tab.
class ProfileFeedItem {
  final String id;
  final String userId;
  final String username;
  final String displayName;
  final String userPhoto;
  final String text;
  final String mediaUrl;
  final String gameTag;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isVerified;
  final DateTime? createdAt;
  final GamerPost? originalPost;

  ProfileFeedItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    this.userPhoto = '',
    this.text = '',
    this.mediaUrl = '',
    this.gameTag = 'BGMI',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isVerified = false,
    this.createdAt,
    this.originalPost,
  });

  factory ProfileFeedItem.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime? created;
    final rawCreated = data['created_at'] ?? data['createdAt'];
    if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated);
    }

    return ProfileFeedItem(
      id: id ?? data['post_id']?.toString() ?? data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? data['userId']?.toString() ?? '',
      username: data['username']?.toString() ?? 'gamer',
      displayName: data['display_name']?.toString() ??
          data['displayName']?.toString() ??
          data['username']?.toString() ??
          'Gamer',
      userPhoto: data['user_avatar']?.toString() ??
          data['userPhoto']?.toString() ??
          data['avatar_url']?.toString() ??
          '',
      text: data['content']?.toString() ?? data['text']?.toString() ?? '',
      mediaUrl: data['media_url']?.toString() ?? data['mediaUrl']?.toString() ?? '',
      gameTag: data['game']?.toString() ?? data['gameTag']?.toString() ?? 'BGMI',
      likesCount: (data['likes_count'] as num?)?.toInt() ??
          (data['likesCount'] as num?)?.toInt() ??
          0,
      commentsCount: (data['comments_count'] as num?)?.toInt() ??
          (data['commentsCount'] as num?)?.toInt() ??
          0,
      sharesCount: (data['shares_count'] as num?)?.toInt() ??
          (data['sharesCount'] as num?)?.toInt() ??
          0,
      isVerified: data['is_verified'] == true || data['isVerified'] == true,
      createdAt: created,
    );
  }
}

/// Service dedicated to querying and syncing Profile posts.
class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  /// Fetch user posts directly from Supabase posts table
  Future<List<ProfileFeedItem>> getUserPostsFromSupabase(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final uuid = SupabaseService.toUuid(userId);
      final rows = await SupabaseService.client
          .from('posts')
          .select()
          .or('user_id.eq.$userId,user_id.eq.$uuid')
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => ProfileFeedItem.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('ProfileService getUserPostsFromSupabase error: $e');
      return [];
    }
  }

  /// Real-time stream of user posts directly from Supabase.
  Stream<List<ProfileFeedItem>> getUserPostsAndClipsStream({
    String? userId,
    String? username,
  }) async* {
    final uid =
        (userId != null && userId.trim().isNotEmpty) ? userId.trim() : '';

    if (uid.isEmpty) {
      yield [];
      return;
    }

    final uuid = SupabaseService.toUuid(uid);

    while (true) {
      try {
        final rows = await SupabaseService.client
            .from('posts')
            .select()
            .or('user_id.eq.$uid,user_id.eq.$uuid')
            .order('created_at', ascending: false);

        final items = (rows as List)
            .map((r) => ProfileFeedItem.fromMap(Map<String, dynamic>.from(r)))
            .toList();

        yield items;
      } catch (e) {
        debugPrint('[ProfileService] Stream error: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Future<List<ProfileFeedItem>> getUserPostsAndClips({
    String? userId,
    String? username,
  }) async {
    final uid =
        (userId != null && userId.trim().isNotEmpty) ? userId.trim() : '';

    if (uid.isEmpty) return [];

    try {
      final uuid = SupabaseService.toUuid(uid);

      final rows = await SupabaseService.client
          .from('posts')
          .select()
          .or('user_id.eq.$uid,user_id.eq.$uuid')
          .order('created_at', ascending: false);

      return (rows as List)
          .map((r) => ProfileFeedItem.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('[ProfileService] Error fetching user posts: $e');
      return [];
    }
  }
}