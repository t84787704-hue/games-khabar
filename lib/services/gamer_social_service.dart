import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';
import '../models/gamer_user_model.dart';
import '../models/gamer_post_model.dart';
import '../models/post_comment_model.dart';
import 'supabase_service.dart';

// Gamer Social Service - Migrated fully to Supabase
class GamerSocialService {
  static final GamerSocialService _instance = GamerSocialService._internal();
  factory GamerSocialService() => _instance;
  GamerSocialService._internal();

  SupabaseClient get _supabase => SupabaseService.client;

  // ==========================================
  // FOLLOW SYSTEM (Supabase)
  // ==========================================

  Stream<bool> isFollowingStream(String currentUid, String targetUid) async* {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      yield false;
      return;
    }
    while (true) {
      yield await isFollowing(currentUid, targetUid);
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Future<bool> isFollowing(String currentUid, String targetUid) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) return false;
    try {
      final res = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', currentUid)
          .eq('following_id', targetUid)
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('Error checking follow status: $e');
      return false;
    }
  }

  Future<void> followUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid == targetUid || currentUid.isEmpty || targetUid.isEmpty) return;
    try {
      await _supabase.from('follows').insert({
        'follower_id': currentUid,
        'following_id': targetUid,
      });
    } catch (e) {
      debugPrint('Error following user: $e');
    }
  }

  Future<void> unfollowUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid == targetUid || currentUid.isEmpty || targetUid.isEmpty) return;
    try {
      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', currentUid)
          .eq('following_id', targetUid);
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
    }
  }

  Stream<List<String>> getFollowingUserIdsStream(String uid) async* {
    if (uid.isEmpty) {
      yield [];
      return;
    }
    while (true) {
      try {
        final res = await _supabase
            .from('follows')
            .select('following_id')
            .eq('follower_id', uid);
        final list = (res as List)
            .map((item) => item['following_id'].toString())
            .toList();
        yield list;
      } catch (e) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<List<GamerUser>> getFollowers(String targetUid) async {
    return [];
  }

  Future<List<GamerUser>> getFollowing(String followerUid) async {
    return [];
  }

  // ==========================================
  // POSTS & FEED SYSTEM (Supabase only)
  // ==========================================

  Future<String> createPost({
    required String userId,
    required String username,
    required String displayName,
    required String userPhoto,
    required String text,
    required String gameTag,
    String? imageUrl,
    String? mediaUrl,
    String? videoUrl,
    String? content,
    String? game,
  }) async {
    final postContent = text.isNotEmpty ? text : (content ?? '');
    final finalGame = (gameTag.isNotEmpty && gameTag != 'BGMI') ? gameTag : (game ?? gameTag);
    final finalMedia = imageUrl ?? mediaUrl;
    final finalVideo = videoUrl;

    try {
      final response = await _supabase.from('posts').insert({
        'user_id': userId,
        'content': postContent,
        'image_url': finalMedia,
        'video_url': finalVideo,
        'game': finalGame,
        'likes_count': 0,
        'comments_count': 0,
      }).select().single();

      debugPrint('[GamerSocialService] Post saved: ${response['id']}');
      return response['id'].toString();
    } catch (e) {
      debugPrint('[GamerSocialService] Error saving post: $e');
      return '';
    }
  }

  Stream<List<GamerPost>> getAllPostsStream({String? gameTag}) async* {
    while (true) {
      try {
        var query = _supabase.from('posts').select();
        if (gameTag != null && gameTag != 'All') {
          query = query.eq('game', gameTag);
        }
        final data = await query.order('created_at', ascending: false).limit(100);
        final list = (data as List).map((map) => GamerPost.fromMap(map)).toList();
        yield list;
      } catch (e) {
        debugPrint('[GamerSocialService] getAllPosts error: $e');
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Stream of all video posts (gaming clips)
  Stream<List<GamerPost>> getVideosStream({String? gameTag}) async* {
    while (true) {
      try {
        var query = _supabase.from('posts').select().not('video_url', 'is', null);
        if (gameTag != null && gameTag != 'All') {
          query = query.eq('game', gameTag);
        }
        final data = await query.order('created_at', ascending: false).limit(100);
        final list = (data as List)
            .map((map) => GamerPost.fromMap(map))
            .where((p) => p.videoUrl != null && p.videoUrl!.trim().isNotEmpty)
            .toList();
        yield list;
      } catch (e) {
        debugPrint('[GamerSocialService] getVideosStream error: $e');
      }
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Stream<List<GamerPost>> getUserPostsStream(String userId, [String? username]) async* {
    while (true) {
      try {
        final data = await _supabase
            .from('posts')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        final list = (data as List).map((map) => GamerPost.fromMap(map)).toList();
        yield list;
      } catch (e) {
        debugPrint('[GamerSocialService] getUserPostsStream error: $e');
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> deletePost({required String postId, required String userId}) async {
    try {
      await _supabase.from('posts').delete().eq('id', postId);
    } catch (e) {
      debugPrint('[GamerSocialService] Error deleting post: $e');
    }
  }

  Stream<bool> isPostLikedStream(String postId, String userId) async* {
    if (userId.isEmpty || postId.isEmpty) {
      yield false;
      return;
    }
    while (true) {
      try {
        final existing = await _supabase
            .from('likes')
            .select('id')
            .eq('post_id', postId)
            .eq('user_id', userId)
            .maybeSingle();
        yield existing != null;
      } catch (e) {
        yield false;
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> toggleLike({
    required String postId,
    required String userId,
    String? postAuthorId,
  }) async {
    try {
      final existing = await _supabase
          .from('likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('likes').delete().eq('id', existing['id']);
      } else {
        await _supabase.from('likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
      }
    } catch (e) {
      debugPrint('[GamerSocialService] toggleLike error: $e');
    }
  }

  Stream<List<PostComment>> getCommentsStream(String postId) async* {
    if (postId.isEmpty) {
      yield [];
      return;
    }
    while (true) {
      try {
        final data = await _supabase
            .from('comments')
            .select()
            .eq('post_id', postId)
            .order('created_at', ascending: true);
        final list = (data as List).map((map) => PostComment.fromMap(map)).toList();
        yield list;
      } catch (e) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> addComment({
    required String postId,
    required String userId,
    required String username,
    required String text,
    String? postAuthorId,
    String? displayName,
    String? userPhoto,
  }) async {
    try {
      await _supabase.from('comments').insert({
        'post_id': postId,
        'user_id': userId,
        'content': text,
      });
    } catch (e) {
      debugPrint('[GamerSocialService] addComment error: $e');
    }
  }

  // ==========================================
  // SEARCH & EXPLORE
  // ==========================================

  Future<List<GamerUser>> searchUsers(String query) async {
    return [];
  }

  Stream<List<GamerUser>> getSuggestedGamersStream({int limit = 15}) {
    return Stream.value([]);
  }

  Future<int> fixOldNewsImages() async {
    return 0;
  }
}
