import 'dart:math';
import 'gamer_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_post_model.dart';
import '../utils/admin_security.dart';
import 'ad_free_service.dart';
import 'supabase_service.dart';

class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  static const String _collectionName = 'community_posts';
  static const String _prefsUserIdKey = 'community_user_id';
  static const String _prefsUserNameKey = 'community_user_name';
  static const String _prefsLikedPostsKey = 'community_liked_posts';

  static const List<String> badWords = ['gali', 'bc', 'mc'];

  String _userId = '';
  String _userName = '';
  Set<String> _likedPostIds = {};
  bool _initialized = false;

  String get userId => _userId;
  String get userName => _userName;
  Set<String> get likedPostIds => _likedPostIds;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check signed in user
      final currentUid = GamerAuthService().currentUid ?? SupabaseService.client.auth.currentUser?.id;
      if (currentUid != null && currentUid.isNotEmpty) {
        _userId = currentUid;
      } else {
        _userId = prefs.getString(_prefsUserIdKey) ?? '';
        if (_userId.isEmpty) {
          final randomSuffix = Random().nextInt(90000) + 10000;
          _userId = 'gamer_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix';
          await prefs.setString(_prefsUserIdKey, _userId);
        }
      }

      _userName = prefs.getString(_prefsUserNameKey) ?? '';
      if (_userName.isEmpty) {
        final randomNum = Random().nextInt(9000) + 1000;
        _userName = 'Gamer #$randomNum';
        await prefs.setString(_prefsUserNameKey, _userName);
      }

      _likedPostIds = prefs.getStringList(_prefsLikedPostsKey)?.toSet() ?? <String>{};
      _initialized = true;
    } catch (_) {
      if (_userId.isEmpty) _userId = 'gamer_guest_${DateTime.now().millisecondsSinceEpoch}';
      if (_userName.isEmpty) _userName = 'Gamer';
    }
  }

  Future<void> setUserName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    _userName = trimmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsUserNameKey, _userName);
    } catch (_) {}
  }

  bool get isUserVIP {
    return AdFreeService().isAdFree || isAdminUser();
  }

  /// Check if text contains bad words: ["gali", "bc", "mc"]
  bool hasBadWords(String input) {
    final lower = input.toLowerCase();
    for (final word in badWords) {
      // Check word boundary or direct token
      final regex = RegExp('(^|[^a-zA-Z0-9])${RegExp.escape(word)}([^a-zA-Z0-9]|\$)', caseSensitive: false);
      if (regex.hasMatch(lower) || lower.split(RegExp(r'\s+')).contains(word)) {
        return true;
      }
    }
    return false;
  }

  /// Real-time stream of community posts
  Stream<List<CommunityPostModel>> streamPosts({required String selectedFilter}) {
    return SupabaseService.client
        .from(_collectionName)
        .stream(primaryKey: ['id'])
        .map((list) {
      final posts = list
          .where((data) => data['isApproved'] != false)
          .where((data) => selectedFilter == 'All' || data['gameName'] == selectedFilter)
          .map((data) => CommunityPostModel.fromFirestore(data))
          .toList();

      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  /// Create a new community post
  Future<void> createPost({
    required String text,
    required String gameName,
    String? imageUrl,
  }) async {
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      throw 'Please enter a message';
    }

    if (trimmed.length > 200) {
      throw 'Text cannot exceed 200 characters';
    }

    if (hasBadWords(trimmed)) {
      throw 'Tehzeeb se likho';
    }

    await init();

    final newId = 'post_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final postMap = {
      'id': newId,
      'userId': _userId,
      'userName': _userName,
      'isVIP': isUserVIP,
      'gameName': gameName,
      'text': trimmed,
      'imageUrl': imageUrl,
      'likes': 0,
      'reportCount': 0,
      'isApproved': true,
      'createdAt': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };

    await SupabaseService.client.from(_collectionName).upsert(postMap);

    // Sync to Supabase posts table
    try {
      await SupabaseService.savePost({
        'post_id': newId,
        'user_id': _userId,
        'username': _userName,
        'content': trimmed,
        'media_url': imageUrl,
        'media_type': 'image',
        'game': gameName,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[CommunityService] Supabase post sync notice: $e');
    }
  }

  /// Like a post
  Future<void> likePost(String postId) async {
    if (_likedPostIds.contains(postId)) return;

    _likedPostIds.add(postId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsLikedPostsKey, _likedPostIds.toList());
    } catch (_) {}

    try {
      final postData = await SupabaseService.client
          .from(_collectionName)
          .select('likes')
          .or('id.eq.$postId')
          .maybeSingle();
      final currentLikes = (postData?['likes'] as num?)?.toInt() ?? 0;
      await SupabaseService.client
          .from(_collectionName)
          .update({'likes': currentLikes + 1})
          .or('id.eq.$postId');
    } catch (_) {}

    // Sync to Supabase likes table
    try {
      await SupabaseService.toggleLike(postId: postId, userId: _userId, username: _userName);
    } catch (e) {
      debugPrint('[CommunityService] Supabase like sync notice: $e');
    }
  }

  bool isPostLiked(String postId) {
    return _likedPostIds.contains(postId);
  }

  /// Report post: increments reportCount, if >=3 sets isApproved=false (auto hide)
  Future<bool> reportPost(String postId, int currentReportCount) async {
    try {
      final newReportCount = currentReportCount + 1;
      final updateData = <String, dynamic>{
        'reportCount': newReportCount,
      };

      if (newReportCount >= 3) {
        updateData['isApproved'] = false;
      }

      await SupabaseService.client
          .from(_collectionName)
          .update(updateData)
          .or('id.eq.$postId');
      return newReportCount >= 3;
    } catch (_) {
      return false;
    }
  }

  /// Real-time stream of comments for a post
  Stream<List<CommunityCommentModel>> streamComments(String postId) {
    return SupabaseService.client
        .from('community_comments')
        .stream(primaryKey: ['id'])
        .eq('postId', postId)
        .map((list) {
      final comments = list
          .map((doc) => CommunityCommentModel.fromFirestore(doc))
          .toList();
      comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return comments;
    });
  }

  /// Add a comment to a post
  Future<void> addComment(String postId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (hasBadWords(trimmed)) {
      throw 'Tehzeeb se likho';
    }

    await init();

    final commentId = 'comment_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final comment = CommunityCommentModel(
      id: commentId,
      userId: _userId,
      userName: _userName,
      isVIP: isUserVIP,
      text: trimmed,
      createdAt: DateTime.now(),
    );

    final commentMap = {
      'id': commentId,
      'postId': postId,
      'userId': _userId,
      'userName': _userName,
      'isVIP': isUserVIP,
      'text': trimmed,
      'createdAt': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };

    await SupabaseService.client.from('community_comments').upsert(commentMap);

    try {
      final postData = await SupabaseService.client
          .from(_collectionName)
          .select('commentCount')
          .or('id.eq.$postId')
          .maybeSingle();
      final currentComments = (postData?['commentCount'] as num?)?.toInt() ?? 0;
      await SupabaseService.client
          .from(_collectionName)
          .update({
            'commentCount': currentComments + 1,
          }).or('id.eq.$postId');
    } catch (_) {}

    // Sync comment to Supabase comments table
    try {
      await SupabaseService.addComment(
        postId: postId,
        userId: _userId,
        username: _userName,
        content: trimmed,
      );
    } catch (e) {
      debugPrint('[CommunityService] Supabase comment sync notice: $e');
    }
  }
}
