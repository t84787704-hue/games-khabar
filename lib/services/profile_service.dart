import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/clip_model.dart';
import '../models/gamer_post_model.dart';

/// Unified model for an item displayed in the Gamer Profile Posts tab.
/// Can represent either a text/image post from 'posts' or a video clip from 'clips'.
class ProfileFeedItem {
  final String id;
  final String userId;
  final String username;
  final String displayName;
  final String userPhoto;
  final String text; // Post caption / text
  final String videoUrl; // If video clip
  final String mediaUrl;
  final String thumbnail;
  final String gameTag;
  final String songTitle;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final bool isVerified;
  final bool isClip; // true if video clip from 'clips' collection
  final DateTime? createdAt;
  final GamerPost? originalPost;
  final GamerClip? originalClip;

  ProfileFeedItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    this.userPhoto = '',
    this.text = '',
    this.videoUrl = '',
    this.mediaUrl = '',
    this.thumbnail = '',
    this.gameTag = 'BGMI',
    this.songTitle = 'Original Audio',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    this.isVerified = false,
    this.isClip = false,
    this.createdAt,
    this.originalPost,
    this.originalClip,
  });

  factory ProfileFeedItem.fromFirestoreDoc(DocumentSnapshot doc, {required bool isClipDoc}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated);
    }

    final String videoUrl = data['videoUrl']?.toString() ??
        (isClipDoc ? (data['mediaUrl']?.toString() ?? '') : '');
    final String mediaUrl = data['mediaUrl']?.toString() ?? videoUrl;
    final String text = data['text']?.toString() ??
        data['caption']?.toString() ??
        data['title']?.toString() ??
        '';

    final bool hasVideo = isClipDoc ||
        videoUrl.isNotEmpty ||
        mediaUrl.toLowerCase().contains('.mp4') ||
        mediaUrl.toLowerCase().contains('/video/upload/');

    return ProfileFeedItem(
      id: doc.id,
      userId: data['userId']?.toString() ?? data['authorId']?.toString() ?? '',
      username: data['username']?.toString() ?? 'gamer',
      displayName: data['displayName']?.toString() ?? 'Gamer',
      userPhoto: data['userPhoto']?.toString() ?? data['userAvatar']?.toString() ?? '',
      text: text,
      videoUrl: videoUrl.isNotEmpty ? videoUrl : (hasVideo ? mediaUrl : ''),
      mediaUrl: mediaUrl,
      thumbnail: data['thumbnail']?.toString() ?? '',
      gameTag: data['gameTag']?.toString() ?? 'BGMI',
      songTitle: data['songTitle']?.toString() ?? 'Original Audio',
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      sharesCount: (data['sharesCount'] as num?)?.toInt() ?? 0,
      viewsCount: (data['viewsCount'] as num?)?.toInt() ?? 0,
      isVerified: data['isVerified'] == true,
      isClip: hasVideo,
      createdAt: created,
      originalPost: !hasVideo ? GamerPost.fromFirestore(doc) : null,
      originalClip: hasVideo ? GamerClip.fromFirestore(doc) : null,
    );
  }
}

/// Service dedicated to querying and syncing Profile posts and clips.
/// Solves the mismatch where posts are saved with username "@sha" or "sha"
/// while FirebaseAuth UID or authorId differs, and merges both 'posts' and 'clips'.
class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Resolves the current user's UID and username handles (@sha and sha).
  Future<({String uid, String rawUsername, String atUsername})> _resolveUserIdentifiers({
    String? userId,
    String? username,
  }) async {
    String uid = (userId ?? '').trim();
    if (uid.isEmpty) {
      uid = _auth.currentUser?.uid ?? '';
    }

    String raw = (username ?? '').trim();
    if (raw.startsWith('@')) {
      raw = raw.substring(1).trim();
    }

    // If username is empty, try to fetch from user doc
    if (raw.isEmpty && uid.isNotEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final u = doc.data()?['username']?.toString() ?? '';
          raw = u.replaceAll('@', '').trim();
        }
      } catch (e) {
        debugPrint('⚠️ [PROFILE_SERVICE] Could not resolve username from user doc: $e');
      }
    }

    final atUser = raw.isNotEmpty ? '@$raw' : '';
    return (uid: uid, rawUsername: raw, atUsername: atUser);
  }

  /// Real-time stream of all user posts and clips merged into one list, sorted by timestamp desc.
  Stream<List<ProfileFeedItem>> getUserPostsAndClipsStream({
    String? userId,
    String? username,
  }) async* {
    final ids = await _resolveUserIdentifiers(userId: userId, username: username);
    final uid = ids.uid;
    final rawUser = ids.rawUsername;
    final atUser = ids.atUsername;

    debugPrint('🔍 [PROFILE_SERVICE] Listening for posts & clips for uid: "$uid", username: "$rawUser" / "$atUser"');

    // Build filter sets for both collections
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

    // Compose OR filter
    Filter combinedFilter = filters.first;
    for (int i = 1; i < filters.length; i++) {
      combinedFilter = Filter.or(combinedFilter, filters[i]);
    }

    // Set up streams for 'posts' and 'clips'
    Stream<QuerySnapshot> postsStream;
    Stream<QuerySnapshot> clipsStream;

    try {
      postsStream = _firestore.collection('posts').where(combinedFilter).snapshots();
    } catch (e) {
      debugPrint('⚠️ [PROFILE_SERVICE] posts Filter.or failed ($e), falling back to user queries');
      postsStream = _fallbackStream('posts', uid, rawUser, atUser);
    }

    try {
      clipsStream = _firestore.collection('clips').where(combinedFilter).snapshots();
    } catch (e) {
      debugPrint('⚠️ [PROFILE_SERVICE] clips Filter.or failed ($e), falling back to user queries');
      clipsStream = _fallbackStream('clips', uid, rawUser, atUser);
    }

    // Also listen to legacy 'gamer_clips' to catch any legacy uploaded clips
    Stream<QuerySnapshot> legacyClipsStream;
    try {
      legacyClipsStream = _firestore.collection('gamer_clips').where(combinedFilter).snapshots();
    } catch (_) {
      legacyClipsStream = const Stream.empty();
    }

    final controller = StreamController<List<ProfileFeedItem>>();
    List<DocumentSnapshot> lastPosts = [];
    List<DocumentSnapshot> lastClips = [];
    List<DocumentSnapshot> lastLegacyClips = [];

    void emitMerged() {
      final Map<String, ProfileFeedItem> itemMap = {};

      // 1. Process 'posts' collection
      for (final doc in lastPosts) {
        if (!doc.exists) continue;
        itemMap[doc.id] = ProfileFeedItem.fromFirestoreDoc(doc, isClipDoc: false);
      }

      // 2. Process 'clips' collection
      for (final doc in lastClips) {
        if (!doc.exists) continue;
        itemMap[doc.id] = ProfileFeedItem.fromFirestoreDoc(doc, isClipDoc: true);
      }

      // 3. Process 'gamer_clips' collection
      for (final doc in lastLegacyClips) {
        if (!doc.exists || itemMap.containsKey(doc.id)) continue;
        itemMap[doc.id] = ProfileFeedItem.fromFirestoreDoc(doc, isClipDoc: true);
      }

      final items = itemMap.values.toList();
      items.sort((a, b) {
        final timeA = a.createdAt ?? DateTime(1970);
        final timeB = b.createdAt ?? DateTime(1970);
        return timeB.compareTo(timeA);
      });

      debugPrint('✅ [PROFILE_SERVICE] Emitting ${items.length} merged items (${lastPosts.length} posts, ${lastClips.length} clips)');
      if (!controller.isClosed) {
        controller.add(items);
      }
    }

    final sub1 = postsStream.listen((snap) {
      lastPosts = snap.docs;
      emitMerged();
    }, onError: (err) {
      debugPrint('⚠️ [PROFILE_SERVICE] postsStream error: $err');
    });

    final sub2 = clipsStream.listen((snap) {
      lastClips = snap.docs;
      emitMerged();
    }, onError: (err) {
      debugPrint('⚠️ [PROFILE_SERVICE] clipsStream error: $err');
    });

    final sub3 = legacyClipsStream.listen((snap) {
      lastLegacyClips = snap.docs;
      emitMerged();
    }, onError: (err) {
      debugPrint('⚠️ [PROFILE_SERVICE] legacyClipsStream error: $err');
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
    };

    yield* controller.stream;
  }

  /// Fallback stream for individual query merges if compound Filter.or is unsupported by backend rules
  Stream<QuerySnapshot> _fallbackStream(String collection, String uid, String rawUser, String atUser) {
    if (uid.isNotEmpty) {
      return _firestore.collection(collection).where('userId', isEqualTo: uid).snapshots();
    }
    if (rawUser.isNotEmpty) {
      return _firestore.collection(collection).where('username', isEqualTo: rawUser).snapshots();
    }
    return const Stream.empty();
  }

  /// One-time fetch of all posts & clips merged for a user
  Future<List<ProfileFeedItem>> getUserPostsAndClips({
    String? userId,
    String? username,
  }) async {
    final ids = await _resolveUserIdentifiers(userId: userId, username: username);
    final uid = ids.uid;
    final rawUser = ids.rawUsername;
    final atUser = ids.atUsername;

    final Map<String, ProfileFeedItem> itemMap = {};

    Future<void> fetchInto(String collection, bool isClip) async {
      try {
        final List<Future<QuerySnapshot>> queries = [];
        if (uid.isNotEmpty) {
          queries.add(_firestore.collection(collection).where('userId', isEqualTo: uid).get());
          queries.add(_firestore.collection(collection).where('authorId', isEqualTo: uid).get());
        }
        if (rawUser.isNotEmpty) {
          queries.add(_firestore.collection(collection).where('username', isEqualTo: rawUser).get());
          queries.add(_firestore.collection(collection).where('username', isEqualTo: atUser).get());
          queries.add(_firestore.collection(collection).where('userId', isEqualTo: rawUser).get());
          queries.add(_firestore.collection(collection).where('userId', isEqualTo: atUser).get());
        }

        final results = await Future.wait(queries);
        for (final snap in results) {
          for (final doc in snap.docs) {
            itemMap[doc.id] = ProfileFeedItem.fromFirestoreDoc(doc, isClipDoc: isClip);
          }
        }
      } catch (e) {
        debugPrint('⚠️ [PROFILE_SERVICE] Error fetching from $collection: $e');
      }
    }

    await Future.wait([
      fetchInto('posts', false),
      fetchInto('clips', true),
      fetchInto('gamer_clips', true),
    ]);

    final items = itemMap.values.toList();
    items.sort((a, b) {
      final timeA = a.createdAt ?? DateTime(1970);
      final timeB = b.createdAt ?? DateTime(1970);
      return timeB.compareTo(timeA);
    });

    return items;
  }
}
