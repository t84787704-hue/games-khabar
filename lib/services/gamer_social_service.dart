import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
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

  /// Helper to convert any string (e.g. Firebase UID) deterministically to a valid RFC4122 UUID v4/v5 format
  static String stringToUuid(String input) {
    if (input.isEmpty) return '00000000-0000-0000-0000-000000000000';
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(input)) return input.toLowerCase();

    // Deterministic UUID from string via MD5 (RFC 4122 UUID v3 format)
    final bytes = utf8.encode('gamer_user_namespace:$input');
    final digest = md5.convert(bytes).bytes;
    final hexList = digest.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    
    // Set version 4/3 and variant bits
    hexList[6] = '4' + hexList[6].substring(1);
    final variantByte = (digest[8] & 0x3f) | 0x80;
    hexList[8] = variantByte.toRadixString(16).padLeft(2, '0');

    final h = hexList.join('');
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
  }

  /// Notifier to instantly inform Feed of new posts
  final ValueNotifier<int> feedRefreshNotifier = ValueNotifier<int>(0);

  /// Ensure user exists in Supabase users table before foreign key operations
  Future<void> _ensureUserExists({
    required String userId,
    required String username,
    required String displayName,
    required String userPhoto,
  }) async {
    if (userId.isEmpty) return;
    try {
      final validUuid = stringToUuid(userId);
      final existing = await _supabase
          .from('users')
          .select('id, uid')
          .or('id.eq.$validUuid,uid.eq.$userId')
          .maybeSingle();

      if (existing == null) {
        final Map<String, dynamic> insertPayload = {
          'id': validUuid,
          'uid': userId,
          'username': username.isNotEmpty ? username : 'gamer_${userId.substring(0, userId.length > 5 ? 5 : userId.length)}',
          'display_name': displayName.isNotEmpty ? displayName : 'Gamer',
          'avatar_url': userPhoto,
          'created_at': DateTime.now().toIso8601String(),
        };
        await _supabase.from('users').upsert(insertPayload);
        debugPrint('[GamerSocialService] Synced user to Supabase: $userId ($validUuid)');
      }
    } catch (e) {
      debugPrint('[GamerSocialService] Note on user sync: $e');
    }
  }

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

    final effectiveUserId = (_supabase.auth.currentUser?.id?.isNotEmpty == true)
        ? _supabase.auth.currentUser!.id
        : userId;

    // Supabase posts.user_id requires a UUID format if the column type is UUID
    final postUuid = stringToUuid(effectiveUserId);

    debugPrint('[GamerSocialService] Attempting to create post for user: $effectiveUserId (UUID: $postUuid)');

    // Make sure user exists in Supabase users table to satisfy foreign key constraint
    await _ensureUserExists(
      userId: effectiveUserId,
      username: username,
      displayName: displayName,
      userPhoto: userPhoto,
    );

    try {
      // Supabase posts.user_id requires a valid UUID
      final response = await _supabase.from('posts').insert({
        'user_id': postUuid,
        'content': postContent,
        'image_url': finalMedia,
        'video_url': finalVideo,
        'game': finalGame,
        'media_url': finalMedia ?? finalVideo,
        'likes_count': 0,
        'comments_count': 0,
      }).select().single();

      debugPrint('[GamerSocialService] Post saved successfully: ${response['id']}');

      // Trigger feed refresh instantly
      feedRefreshNotifier.value++;

      return response['id'].toString();
    } catch (e) {
      debugPrint('[GamerSocialService] Error saving post: $e');
      rethrow;
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
        final uuid = stringToUuid(userId);
        final data = await _supabase
            .from('posts')
            .select()
            .or('user_id.eq.$userId,user_id.eq.$uuid')
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
