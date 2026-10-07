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
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(input)) return input.toLowerCase();

    final bytes = utf8.encode('gamer_user_namespace:$input');
    final digest = md5.convert(bytes).bytes;
    final hexList =
        digest.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();

    hexList[6] = '4' + hexList[6].substring(1);
    final variantByte = (digest[8] & 0x3f) | 0x80;
    hexList[8] = variantByte.toRadixString(16).padLeft(2, '0');

    final h = hexList.join('');
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
  }

  final ValueNotifier<int> feedRefreshNotifier = ValueNotifier<int>(0);

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
          'username': username.isNotEmpty
              ? username
              : 'gamer_${userId.substring(0, userId.length > 5 ? 5 : userId.length)}',
          'display_name': displayName.isNotEmpty ? displayName : 'Gamer',
          'avatar_url': userPhoto,
          'created_at': DateTime.now().toIso8601String(),
        };
        await _supabase.from('users').upsert(insertPayload);
        debugPrint(
            '[GamerSocialService] Synced user to Supabase: $userId ($validUuid)');
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
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return false;
    }
    try {
      final followerUuid = stringToUuid(currentUid);
      final followingUuid = stringToUuid(targetUid);
      final res = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', followerUuid)
          .eq('following_id', followingUuid)
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
    if (currentUid == targetUid || currentUid.isEmpty || targetUid.isEmpty) {
      return;
    }
    try {
      final followerUuid = stringToUuid(currentUid);
      final followingUuid = stringToUuid(targetUid);

      debugPrint('[Follow] Inserting: $followerUuid -> $followingUuid');

      // Prevent duplicate follow
      final existing = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', followerUuid)
          .eq('following_id', followingUuid)
          .maybeSingle();
      if (existing != null) {
        debugPrint('[Follow] Already following, skipping');
        return;
      }

      // Insert into follows table
      await _supabase.from('follows').insert({
        'follower_id': followerUuid,
        'following_id': followingUuid,
      });

      // Update following_count for current user
      await _incrementCounter(
        userId: followerUuid,
        column: 'following_count',
        delta: 1,
      );

      // Update followers_count for target user
      await _incrementCounter(
        userId: followingUuid,
        column: 'followers_count',
        delta: 1,
      );

      debugPrint('[Follow] Success!');
    } catch (e) {
      debugPrint('Error following user: $e');
    }
  }

  Future<void> unfollowUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid == targetUid || currentUid.isEmpty || targetUid.isEmpty) {
      return;
    }
    try {
      final followerUuid = stringToUuid(currentUid);
      final followingUuid = stringToUuid(targetUid);

      // Delete from follows table
      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', followerUuid)
          .eq('following_id', followingUuid);

      // Update following_count for current user
      await _incrementCounter(
        userId: followerUuid,
        column: 'following_count',
        delta: -1,
      );

      // Update followers_count for target user
      await _incrementCounter(
        userId: followingUuid,
        column: 'followers_count',
        delta: -1,
      );
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
    }
  }

  /// Safely increment/decrement a counter column on the users table.
  /// Tries RPC first (atomic), falls back to manual fetch+update.
  Future<void> _incrementCounter({
    required String userId,
    required String column,
    required int delta,
  }) async {
    final rpcName = delta > 0
        ? (column == 'following_count'
            ? 'increment_following_count'
            : 'increment_followers_count')
        : (column == 'following_count'
            ? 'decrement_following_count'
            : 'decrement_followers_count');

    try {
      await _supabase.rpc(rpcName, params: {'user_id': userId});
      debugPrint('[Counter] RPC $rpcName success for $userId');
      return;
    } catch (e) {
      debugPrint('[Counter] RPC $rpcName failed: $e — using manual fallback');
    }

    // Manual fallback
    try {
      final row = await _supabase
          .from('users')
          .select(column)
          .eq('id', userId)
          .maybeSingle();
      final current = (row?[column] as num?)?.toInt() ?? 0;
      final updated = (current + delta).clamp(0, 999999999);
      await _supabase.from('users').update({column: updated}).eq('id', userId);
      debugPrint('[Counter] Manual $column=$updated for $userId');
    } catch (e) {
      debugPrint('[Counter] Manual update failed: $e');
    }
  }

  Stream<List<String>> getFollowingUserIdsStream(String uid) async* {
    if (uid.isEmpty) {
      yield [];
      return;
    }
    while (true) {
      try {
        final followerUuid = stringToUuid(uid);
        final res = await _supabase
            .from('follows')
            .select('following_id')
            .eq('follower_id', followerUuid);
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
  // POSTS & FEED SYSTEM
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
    final finalGame =
        (gameTag.isNotEmpty && gameTag != 'BGMI') ? gameTag : (game ?? gameTag);
    final finalMedia = imageUrl ?? mediaUrl;
    final finalVideo = videoUrl;

    final effectiveUserId = (_supabase.auth.currentUser?.id?.isNotEmpty == true)
        ? _supabase.auth.currentUser!.id
        : userId;

    final postUuid = stringToUuid(effectiveUserId);

    debugPrint(
        '[GamerSocialService] Attempting to create post for user: $effectiveUserId (UUID: $postUuid)');

    await _ensureUserExists(
      userId: effectiveUserId,
      username: username,
      displayName: displayName,
      userPhoto: userPhoto,
    );

    try {
      final response = await _supabase
          .from('posts')
          .insert({
            'user_id': postUuid,
            'content': postContent,
            'image_url': finalMedia,
            'video_url': finalVideo,
            'game': finalGame,
            'media_url': finalMedia ?? finalVideo,
            'likes_count': 0,
            'comments_count': 0,
          })
          .select()
          .single();

      debugPrint(
          '[GamerSocialService] Post saved successfully: ${response['id']}');
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
        final data =
            await query.order('created_at', ascending: false).limit(100);
        final list =
            (data as List).map((map) => GamerPost.fromMap(map)).toList();
        yield list;
      } catch (e) {
        debugPrint('[GamerSocialService] getAllPosts error: $e');
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Stream<List<GamerPost>> getVideosStream({String? gameTag}) async* {
    while (true) {
      try {
        var query =
            _supabase.from('posts').select().not('video_url', 'is', null);
        if (gameTag != null && gameTag != 'All') {
          query = query.eq('game', gameTag);
        }
        final data =
            await query.order('created_at', ascending: false).limit(100);
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

  /// FIXED: only returns posts whose user_id exactly equals this user's UUID.
  Stream<List<GamerPost>> getUserPostsStream(String userId,
      [String? username]) async* {
    while (true) {
      try {
        final uuid = stringToUuid(userId);
        final data = await _supabase
            .from('posts')
            .select()
            .eq('user_id', uuid) // strict match — no more foreign posts
            .order('created_at', ascending: false);
        final list =
            (data as List).map((map) => GamerPost.fromMap(map)).toList();
        yield list;
      } catch (e) {
        debugPrint('[GamerSocialService] getUserPostsStream error: $e');
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> deletePost(
      {required String postId, required String userId}) async {
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
        final list =
            (data as List).map((map) => PostComment.fromMap(map)).toList();
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