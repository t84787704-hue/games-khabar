import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gamer_user_model.dart';
import '../models/gamer_post_model.dart';
import '../models/post_comment_model.dart';

class GamerSocialService {
  static final GamerSocialService _instance = GamerSocialService._internal();
  factory GamerSocialService() => _instance;
  GamerSocialService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // FOLLOW SYSTEM
  // ==========================================

  String _followDocId(String followerId, String followingId) => '${followerId}_$followingId';

  Stream<bool> isFollowingStream(String currentUid, String targetUid) {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return Stream.value(false);
    }
    return _firestore
        .collection('follows')
        .doc(_followDocId(currentUid, targetUid))
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<bool> isFollowing(String currentUid, String targetUid) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) return false;
    try {
      final doc = await _firestore.collection('follows').doc(_followDocId(currentUid, targetUid)).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking follow status: $e');
      return false;
    }
  }

  Future<void> followUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid == targetUid) return;

    final followRef = _firestore.collection('follows').doc(_followDocId(currentUid, targetUid));
    final currentUserRef = _firestore.collection('users').doc(currentUid);
    final targetUserRef = _firestore.collection('users').doc(targetUid);

    final batch = _firestore.batch();

    batch.set(followRef, {
      'followerId': currentUid,
      'followingId': targetUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(currentUserRef, {
      'followingCount': FieldValue.increment(1),
    });

    batch.update(targetUserRef, {
      'followersCount': FieldValue.increment(1),
    });

    // Also record notification
    final notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'id': notifRef.id,
      'recipientUid': targetUid,
      'senderUid': currentUid,
      'type': 'follow',
      'title': 'New Follower',
      'message': 'started following your Gamer ID!',
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    await batch.commit();
  }

  Future<void> unfollowUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid == targetUid) return;

    final followRef = _firestore.collection('follows').doc(_followDocId(currentUid, targetUid));
    final currentUserRef = _firestore.collection('users').doc(currentUid);
    final targetUserRef = _firestore.collection('users').doc(targetUid);

    final batch = _firestore.batch();
    batch.delete(followRef);

    batch.update(currentUserRef, {
      'followingCount': FieldValue.increment(-1),
    });

    batch.update(targetUserRef, {
      'followersCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  Stream<List<String>> getFollowingUserIdsStream(String uid) {
    return _firestore
        .collection('follows')
        .where('followerId', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()['followingId'] as String).toList());
  }

  Future<List<GamerUser>> getFollowers(String targetUid) async {
    try {
      final snap = await _firestore
          .collection('follows')
          .where('followingId', isEqualTo: targetUid)
          .limit(50)
          .get();

      final followerIds = snap.docs.map((d) => d.data()['followerId'] as String).toList();
      if (followerIds.isEmpty) return [];

      final users = <GamerUser>[];
      for (final fid in followerIds) {
        final uDoc = await _firestore.collection('users').doc(fid).get();
        if (uDoc.exists && uDoc.data() != null) {
          users.add(GamerUser.fromFirestore(uDoc));
        }
      }
      return users;
    } catch (e) {
      debugPrint('Error getting followers: $e');
      return [];
    }
  }

  Future<List<GamerUser>> getFollowing(String followerUid) async {
    try {
      final snap = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: followerUid)
          .limit(50)
          .get();

      final followingIds = snap.docs.map((d) => d.data()['followingId'] as String).toList();
      if (followingIds.isEmpty) return [];

      final users = <GamerUser>[];
      for (final fid in followingIds) {
        final uDoc = await _firestore.collection('users').doc(fid).get();
        if (uDoc.exists && uDoc.data() != null) {
          users.add(GamerUser.fromFirestore(uDoc));
        }
      }
      return users;
    } catch (e) {
      debugPrint('Error getting following: $e');
      return [];
    }
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
  }) async {
    final postRef = _firestore.collection('posts').doc();
    final userRef = _firestore.collection('users').doc(userId);

    final post = GamerPost(
      postId: postRef.id,
      userId: userId,
      username: username,
      displayName: displayName,
      userPhoto: userPhoto,
      text: text,
      gameTag: gameTag,
      likesCount: 0,
      commentsCount: 0,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.set(postRef, post.toMap());
    batch.update(userRef, {
      'postsCount': FieldValue.increment(1),
    });

    await batch.commit();
    return postRef.id;
  }

  Future<void> deletePost({
    required String postId,
    required String userId,
  }) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final userRef = _firestore.collection('users').doc(userId);

    final batch = _firestore.batch();
    batch.delete(postRef);
    batch.update(userRef, {
      'postsCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  Stream<bool> isPostLikedStream(String postId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleLike({
    required String postId,
    required String userId,
    required String postAuthorId,
  }) async {
    final likeRef = _firestore.collection('posts').doc(postId).collection('likes').doc(userId);
    final postRef = _firestore.collection('posts').doc(postId);

    final snap = await likeRef.get();
    if (snap.exists) {
      // Unlike
      await likeRef.delete();
      await postRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      // Like
      await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
      await postRef.update({'likesCount': FieldValue.increment(1)});

      // Notification
      if (postAuthorId != userId && postAuthorId.isNotEmpty) {
        _firestore.collection('notifications').add({
          'recipientUid': postAuthorId,
          'senderUid': userId,
          'postId': postId,
          'type': 'like',
          'title': 'Post Liked',
          'message': 'liked your gaming post!',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    }
  }

  Stream<List<GamerPost>> getAllPostsStream({String? gameTag}) {
    Query query = _firestore.collection('posts').orderBy('createdAt', descending: true);
    if (gameTag != null && gameTag != 'All' && gameTag.isNotEmpty) {
      query = query.where('gameTag', isEqualTo: gameTag);
    }
    return query.limit(100).snapshots().map((snap) {
      return snap.docs.map((d) => GamerPost.fromFirestore(d)).toList();
    });
  }

  Stream<List<GamerPost>> getUserPostsStream(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GamerPost.fromFirestore(d)).toList());
  }

  // ==========================================
  // COMMENTS SYSTEM
  // ==========================================

  Stream<List<PostComment>> getCommentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PostComment.fromFirestore(d)).toList());
  }

  Future<void> addComment({
    required String postId,
    required String postAuthorId,
    required String userId,
    required String username,
    required String displayName,
    required String userPhoto,
    required String text,
  }) async {
    final commentRef = _firestore.collection('posts').doc(postId).collection('comments').doc();
    final postRef = _firestore.collection('posts').doc(postId);

    final comment = PostComment(
      commentId: commentRef.id,
      userId: userId,
      username: username,
      displayName: displayName,
      userPhoto: userPhoto,
      text: text,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.set(commentRef, comment.toMap());
    batch.update(postRef, {'commentsCount': FieldValue.increment(1)});

    if (postAuthorId != userId && postAuthorId.isNotEmpty) {
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'id': notifRef.id,
        'recipientUid': postAuthorId,
        'senderUid': userId,
        'postId': postId,
        'type': 'comment',
        'title': 'New Comment',
        'message': 'commented: "$text"',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }

    await batch.commit();
  }

  // ==========================================
  // SEARCH & EXPLORE
  // ==========================================

  Future<List<GamerUser>> searchUsers(String query) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    try {
      // Query by username prefix
      final snapUsername = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: q)
          .where('username', isLessThanOrEqualTo: '$q\uf8ff')
          .limit(20)
          .get();

      final users = snapUsername.docs.map((d) => GamerUser.fromFirestore(d)).toList();

      // If needed, also search displayName
      final snapDisplayName = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      for (final doc in snapDisplayName.docs) {
        if (!users.any((u) => u.uid == doc.id)) {
          users.add(GamerUser.fromFirestore(doc));
        }
      }

      return users;
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  Stream<List<GamerUser>> getSuggestedGamersStream({int limit = 15}) {
    return _firestore
        .collection('users')
        .orderBy('followersCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GamerUser.fromFirestore(d)).toList());
  }
}
