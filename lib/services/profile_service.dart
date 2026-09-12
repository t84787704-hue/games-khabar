import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/gamer_post_model.dart';

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

  factory ProfileFeedItem.fromFirestoreDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated);
    }

    final String text = data['text']?.toString() ??
        data['caption']?.toString() ??
        data['title']?.toString() ??
        '';

    return ProfileFeedItem(
      id: doc.id,
      userId: data['userId']?.toString() ?? data['authorId']?.toString() ?? '',
      username: data['username']?.toString() ?? 'gamer',
      displayName: data['displayName']?.toString() ?? 'Gamer',
      userPhoto: data['userPhoto']?.toString() ?? data['userAvatar']?.toString() ?? '',
      text: text,
      mediaUrl: data['mediaUrl']?.toString() ?? '',
      gameTag: data['gameTag']?.toString() ?? 'BGMI',
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      sharesCount: (data['sharesCount'] as num?)?.toInt() ?? 0,
      isVerified: data['isVerified'] == true,
      createdAt: created,
      originalPost: GamerPost.fromFirestore(doc),
    );
  }
}

/// Service dedicated to querying and syncing Profile posts.
class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  Future<({String uid, String rawUsername, String atUsername})> _resolveUserIdentifiers({
    String? userId,
    String? username,
  }) async {
    String uid = (userId != null && userId.trim().isNotEmpty) ? userId.trim() : '';
    String rawUser = (username != null && username.trim().isNotEmpty) ? username.trim() : '';

    if (rawUser.startsWith('@')) {
      rawUser = rawUser.substring(1);
    }

    if (uid.isEmpty && rawUser.isNotEmpty) {
      try {
        final querySnap = await _firestore
            .collection('users')
            .where('username', isEqualTo: rawUser)
            .limit(1)
            .get();
        if (querySnap.docs.isNotEmpty) {
          uid = querySnap.docs.first.id;
        }
      } catch (e) {
        debugPrint('⚠️ [PROFILE_SERVICE] Failed resolving username to UID: $e');
      }
    }

    if (uid.isEmpty) {
      final currentAuth = FirebaseAuth.instance.currentUser;
      if (currentAuth != null) {
        uid = currentAuth.uid;
      }
    }

    final atUser = rawUser.isNotEmpty ? '@$rawUser' : '';
    return (uid: uid, rawUsername: rawUser, atUsername: atUser);
  }

  /// Real-time stream of all user posts, sorted by timestamp desc.
  Stream<List<ProfileFeedItem>> getUserPostsAndClipsStream({
    String? userId,
    String? username,
  }) async* {
    final ids = await _resolveUserIdentifiers(userId: userId, username: username);
    final uid = ids.uid;
    final rawUser = ids.rawUsername;
    final atUser = ids.atUsername;

    final List<Filter> filters = [];
    if (uid.isNotEmpty) {
      filters.add(Filter('userId', isEqualTo: uid));
      filters.add(Filter('authorId', isEqualTo: uid));
    }
    if (rawUser.isNotEmpty) {
      filters.add(Filter('username', isEqualTo: rawUser));
      filters.add(Filter('username', isEqualTo: atUser));
      filters.add(Filter('userId', isEqualTo: rawUser));
      filters.add(Filter('userId', isEqualTo: atUser));
    }

    if (filters.isEmpty) {
      yield [];
      return;
    }

    Filter combinedFilter = filters.first;
    for (int i = 1; i < filters.length; i++) {
      combinedFilter = Filter.or(combinedFilter, filters[i]);
    }

    Stream<QuerySnapshot> postsStream;
    try {
      postsStream = _firestore.collection('posts').where(combinedFilter).snapshots();
    } catch (e) {
      postsStream = _fallbackStream('posts', uid, rawUser, atUser);
    }

    yield* postsStream.map((snap) {
      final items = snap.docs.map((doc) => ProfileFeedItem.fromFirestoreDoc(doc)).toList();
      items.sort((a, b) {
        final timeA = a.createdAt ?? DateTime(1970);
        final timeB = b.createdAt ?? DateTime(1970);
        return timeB.compareTo(timeA);
      });
      return items;
    });
  }

  Stream<QuerySnapshot> _fallbackStream(String collection, String uid, String rawUser, String atUser) {
    if (uid.isNotEmpty) {
      return _firestore.collection(collection).where('userId', isEqualTo: uid).snapshots();
    }
    if (rawUser.isNotEmpty) {
      return _firestore.collection(collection).where('username', isEqualTo: rawUser).snapshots();
    }
    return const Stream.empty();
  }

  Future<List<ProfileFeedItem>> getUserPostsAndClips({
    String? userId,
    String? username,
  }) async {
    final ids = await _resolveUserIdentifiers(userId: userId, username: username);
    final uid = ids.uid;
    final rawUser = ids.rawUsername;
    final atUser = ids.atUsername;

    final Map<String, ProfileFeedItem> itemMap = {};

    try {
      final List<Future<QuerySnapshot>> queries = [];
      if (uid.isNotEmpty) {
        queries.add(_firestore.collection('posts').where('userId', isEqualTo: uid).get());
        queries.add(_firestore.collection('posts').where('authorId', isEqualTo: uid).get());
      }
      if (rawUser.isNotEmpty) {
        queries.add(_firestore.collection('posts').where('username', isEqualTo: rawUser).get());
        queries.add(_firestore.collection('posts').where('username', isEqualTo: atUser).get());
        queries.add(_firestore.collection('posts').where('userId', isEqualTo: rawUser).get());
        queries.add(_firestore.collection('posts').where('userId', isEqualTo: atUser).get());
      }

      final results = await Future.wait(queries);
      for (final snap in results) {
        for (final doc in snap.docs) {
          itemMap[doc.id] = ProfileFeedItem.fromFirestoreDoc(doc);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [PROFILE_SERVICE] Error fetching from posts: $e');
    }

    final items = itemMap.values.toList();
    items.sort((a, b) {
      final timeA = a.createdAt ?? DateTime(1970);
      final timeB = b.createdAt ?? DateTime(1970);
      return timeB.compareTo(timeA);
    });

    return items;
  }
}
