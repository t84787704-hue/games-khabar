import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_post_model.dart';
import '../utils/admin_security.dart';
import 'ad_free_service.dart';

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

      // Check FirebaseAuth uid first if signed in
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null && authUser.uid.isNotEmpty) {
        _userId = authUser.uid;
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

      _likedPostIds = (prefs.getStringList(_prefsLikedPostsKey) ?? {}).toSet();
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
    final collection = FirebaseFirestore.instance.collection(_collectionName);

    Query<Map<String, dynamic>> query = collection.where('isApproved', isEqualTo: true);

    if (selectedFilter != 'All') {
      query = query.where('gameName', isEqualTo: selectedFilter);
    }

    return query.snapshots().map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => CommunityPostModel.fromFirestore(doc))
          .toList();

      // Sort client-side by createdAt descending to guarantee chronological order
      // without requiring Firestore composite indexes
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

    final post = CommunityPostModel(
      id: '',
      userId: _userId,
      userName: _userName,
      isVIP: isUserVIP,
      gameName: gameName,
      text: trimmed,
      imageUrl: imageUrl,
      likes: 0,
      reportCount: 0,
      isApproved: true,
      createdAt: DateTime.now(),
    );

    await FirebaseFirestore.instance.collection(_collectionName).add(post.toMap());
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
      await FirebaseFirestore.instance.collection(_collectionName).doc(postId).update({
        'likes': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  bool isPostLiked(String postId) {
    return _likedPostIds.contains(postId);
  }

  /// Report post: increments reportCount, if >=3 sets isApproved=false (auto hide)
  Future<bool> reportPost(String postId, int currentReportCount) async {
    try {
      final newReportCount = currentReportCount + 1;
      final updateData = <String, dynamic>{
        'reportCount': FieldValue.increment(1),
      };

      if (newReportCount >= 3) {
        updateData['isApproved'] = false;
      }

      await FirebaseFirestore.instance.collection(_collectionName).doc(postId).update(updateData);
      return newReportCount >= 3;
    } catch (_) {
      return false;
    }
  }
}
