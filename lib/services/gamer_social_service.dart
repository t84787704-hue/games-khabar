import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gamer_user_model.dart';
import '../models/gamer_post_model.dart';
import '../models/post_comment_model.dart';
import 'supabase_service.dart';

class GamerSocialService {
  static final GamerSocialService _instance = GamerSocialService._internal();
  factory GamerSocialService() => _instance;
  GamerSocialService._internal();

  SupabaseClient get _supabase => SupabaseService.client;

  // ==========================================
  // FOLLOW SYSTEM (Supabase)
  // ==========================================

  Stream<bool> isFollowingStream(String currentUid, String targetUid) {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return Stream.value(false);
    }
    return _supabase
        .from('follows')
        .stream(primaryKey: ['id'])
        .eq('follower_id', currentUid)
        .map((list) => list.any((item) => item['following_id'] == targetUid));
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

  Stream<List<String>> getFollowingUserIdsStream(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    return _supabase
        .from('follows')
        .stream(primaryKey: ['id'])
        .eq('follower_id', uid)
        .map((list) => list.map((item) => item['following_id'].toString()).toList());
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

  Stream<List<GamerPost>> getAllPostsStream({String? gameTag}) {
    var query = _supabase.from('posts').select();
    if (gameTag != null && gameTag != 'All') {
      query = query.eq('game', gameTag);
    }
    return query
        .order('created_at', ascending: false)
        .limit(100)
        .stream(primaryKey: ['id'])
        .map((data) {
      return data.map((map) => GamerPost.fromMap(map)).toList();
    });
  }

  /// Stream of all video posts (gaming clips)
  Stream<List<GamerPost>> getVideosStream({String? gameTag}) {
    var query = _supabase.from('posts').select().not('video_url', 'is', null);
    if (gameTag != null && gameTag != 'All') {
      query = query.eq('game', gameTag);
    }
    return query
        .order('created_at', ascending: false)
        .limit(100)
        .stream(primaryKey: ['id'])
        .map((data) {
      return data
          .map((map) => GamerPost.fromMap(map))
          .where((p) => p.videoUrl != null && p.videoUrl!.trim().isNotEmpty)
          .toList();
    });
  }

  Stream<List<GamerPost>> getUserPostsStream(String userId, [String? username]) {
    return _supabase
        .from('posts')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((map) => GamerPost.fromMap(map)).toList());
  }

  Future<void> deletePost({required String postId, required String userId}) async {
    try {
      await _supabase.from('posts').delete().eq('id', postId);
    } catch (e) {
      debugPrint('[GamerSocialService] Error deleting post: $e');
    }
  }

  Stream<bool> isPostLikedStream(String postId, String userId) {
    if (userId.isEmpty || postId.isEmpty) return Stream.value(false);
    return _supabase
        .from('likes')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .map((list) => list.any((item) => item['user_id'] == userId));
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

  Stream<List<PostComment>> getCommentsStream(String postId) {
    if (postId.isEmpty) return Stream.value([]);
    return _supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .map((data) => data.map((map) => PostComment.fromMap(map)).toList());
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
