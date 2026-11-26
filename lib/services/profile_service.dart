import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart'; // Added for localization
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
      username: data['username']?.toString() ?? 'user_gamer'.tr(),
      displayName: data['display_name']?.toString() ??
          data['displayName']?.toString() ??
          data['username']?.toString() ??
          'user_gamer'.tr(),
      userPhoto: data['user_avatar']?.toString() ??
          data['userPhoto']?.toString() ??
          data['avatar_url']?.toString() ??
          '',
      text: data['content']?.toString() ?? data['text']?.toString() ?? '',
      mediaUrl:
          data['media_url']?.toString() ?? data['mediaUrl']?.toString() ?? '',
      gameTag:
          data['game']?.toString() ?? data['gameTag']?.toString() ?? 'BGMI',
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

/// Service dedicated to querying and syncing Profile posts with TTL caching
/// and pagination to minimize mobile data usage.
class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  static const int defaultPageSize = 15;
  static const Duration _cacheTtl = Duration(seconds: 60);

  final Map<String, List<ProfileFeedItem>> _userPostsCache = {};
  final Map<String, DateTime> _cacheTimestamp = {};

  bool _isCacheValid(String uuid) {
    final ts = _cacheTimestamp[uuid];
    if (ts == null || !_userPostsCache.containsKey(uuid)) return false;
    return DateTime.now().difference(ts) < _cacheTtl;
  }

  /// Clears cached profile posts for [userId] (or all users if null) on explicit refresh.
  void invalidateCache([String? userId]) {
    if (userId == null || userId.trim().isEmpty) {
      _userPostsCache.clear();
      _cacheTimestamp.clear();
      return;
    }
    final uuid = SupabaseService.toUuid(userId.trim());
    _userPostsCache.remove(uuid);
    _cacheTimestamp.remove(uuid);
  }

  /// Paginated fetch of user posts from Supabase `posts` table.
  /// Guarded by [page] and [pageSize] (default 15) to reduce mobile data usage.
  Future<List<ProfileFeedItem>> fetchUserPostsPage({
    required String userId,
    int page = 0,
    int pageSize = defaultPageSize,
    bool forceRefresh = false,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) return [];
    final uuid = SupabaseService.toUuid(uid);

    if (page == 0 && !forceRefresh && _isCacheValid(uuid)) {
      final cached = _userPostsCache[uuid]!;
      return cached.length > pageSize ? cached.sublist(0, pageSize) : cached;
    }

    try {
      final int start = page * pageSize;
      final int end = start + pageSize - 1;

      final rows = await SupabaseService.client
          .from('posts')
          .select()
          .eq('user_id', uuid)
          .order('created_at', ascending: false)
          .range(start, end);

      final items = (rows as List)
          .map((r) => ProfileFeedItem.fromMap(Map<String, dynamic>.from(r)))
          .toList();

      if (page == 0) {
        _userPostsCache[uuid] = items;
        _cacheTimestamp[uuid] = DateTime.now();
      } else {
        final existing = List<ProfileFeedItem>.from(_userPostsCache[uuid] ?? []);
        final existingIds = existing.map((e) => e.id).toSet();
        for (final item in items) {
          if (!existingIds.contains(item.id)) {
            existing.add(item);
          }
        }
        _userPostsCache[uuid] = existing;
        _cacheTimestamp[uuid] = DateTime.now();
      }

      return items;
    } catch (e) {
      debugPrint('ProfileService fetchUserPostsPage error: $e');
      if (page == 0 && _userPostsCache.containsKey(uuid)) {
        return _userPostsCache[uuid]!;
      }
      return [];
    }
  }

  /// Fetch user posts directly from Supabase posts table (bounded + cached).
  /// STRICT: only fetches posts where user_id equals this user's UUID.
  Future<List<ProfileFeedItem>> getUserPostsFromSupabase(
    String userId, {
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    return fetchUserPostsPage(
      userId: userId,
      page: 0,
      pageSize: limit,
      forceRefresh: forceRefresh,
    );
  }

  /// Stream of user posts from Supabase with TTL deduplication, bounded limit,
  /// and automatic cancellation when the widget leaves the screen.
  Stream<List<ProfileFeedItem>> getUserPostsAndClipsStream({
    String? userId,
    String? username,
    int limit = 20,
  }) {
    Stream<List<ProfileFeedItem>> stream() async* {
      final uid =
          (userId != null && userId.trim().isNotEmpty) ? userId.trim() : '';

      if (uid.isEmpty) {
        yield <ProfileFeedItem>[];
        return;
      }

      final uuid = SupabaseService.toUuid(uid);

      // Immediately emit cached data if available to avoid blank flicker on tab switch
      if (_userPostsCache.containsKey(uuid)) {
        yield _userPostsCache[uuid]!;
      }

      while (true) {
        try {
          if (!_isCacheValid(uuid)) {
            final items = await fetchUserPostsPage(
              userId: uid,
              page: 0,
              pageSize: limit,
              forceRefresh: true,
            );
            yield items;
          }
        } catch (e) {
          debugPrint('[ProfileService] Stream error: $e');
          yield _userPostsCache[uuid] ?? <ProfileFeedItem>[];
        }
        await Future.delayed(const Duration(seconds: 60));
      }
    }

    return stream().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  /// One-shot fetch of user posts (uses TTL cache unless [forceRefresh] is true).
  /// STRICT: only fetches posts where user_id equals this user's UUID.
  Future<List<ProfileFeedItem>> getUserPostsAndClips({
    String? userId,
    String? username,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final uid =
        (userId != null && userId.trim().isNotEmpty) ? userId.trim() : '';

    if (uid.isEmpty) return [];

    return fetchUserPostsPage(
      userId: uid,
      page: 0,
      pageSize: limit,
      forceRefresh: forceRefresh,
    );
  }
}