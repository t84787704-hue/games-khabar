// ═══════════════════════════════════════════════════════════════════════════════
// EXACT DIFF:
// - Replaced .eq('id', userId) with .or('id.eq.$userId,uid.eq.$userId') on users table
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';
import '../models/gamer_user_model.dart';
import '../models/gamer_post_model.dart';
import '../models/post_comment_model.dart';
import 'supabase_service.dart';
import 'gamer_auth_service.dart';
import 'notification_service.dart';

class SocialGraphUpdate {
  final String actorUid;
  final String targetUid;
  final bool isAllied;
  final int? targetSquadCount;
  final int? actorAlliesCount;
  final DateTime timestamp;

  const SocialGraphUpdate({
    required this.actorUid,
    required this.targetUid,
    required this.isAllied,
    this.targetSquadCount,
    this.actorAlliesCount,
    required this.timestamp,
  });
}

class SocialCounts {
  final int squadCount;
  final int alliesCount;

  const SocialCounts({
    required this.squadCount,
    required this.alliesCount,
  });
}

class _SyncPairResult {
  final int? squadCount;
  final int? alliesCount;

  const _SyncPairResult({
    this.squadCount,
    this.alliesCount,
  });
}

class GamerSocialService {
  static final GamerSocialService _instance = GamerSocialService._internal();
  factory GamerSocialService() => _instance;
  GamerSocialService._internal();

  static const String primaryFollowsTable = 'user_follows';
  static const String legacyFollowsTable = 'follows';

  String _resolvedFollowsTable = primaryFollowsTable;
  bool _tableProbed = false;
  String? lastSocialError;

  String get activeFollowsTable => _resolvedFollowsTable;

  SupabaseClient get _supabase => SupabaseService.client;

  final StreamController<SocialGraphUpdate> _socialGraphController =
      StreamController<SocialGraphUpdate>.broadcast();

  Stream<SocialGraphUpdate> get socialGraphUpdatesStream =>
      _socialGraphController.stream;

  bool _isMissingTableError(Object error) {
    final msg = error.toString().toLowerCase();
    if (error is PostgrestException) {
      if (error.code == '42P01' || error.code == 'PGRST205') return true;
    }
    return msg.contains('42p01') ||
        msg.contains('pgrst205') ||
        (msg.contains('user_follows') &&
            (msg.contains('does not exist') ||
                msg.contains('not find the table') ||
                msg.contains('schema cache')));
  }

  Future<String> resolveFollowsTable() async {
    if (_tableProbed) return _resolvedFollowsTable;
    try {
      await _supabase.from(primaryFollowsTable).select('id').limit(1);
      _resolvedFollowsTable = primaryFollowsTable;
    } catch (e) {
      if (_isMissingTableError(e)) {
        _resolvedFollowsTable = legacyFollowsTable;
      }
    }
    _tableProbed = true;
    return _resolvedFollowsTable;
  }

  Future<T> _runFollowsQuery<T>(
      Future<T> Function(String table) operation) async {
    final table = await resolveFollowsTable();
    try {
      return await operation(table);
    } catch (e) {
      if (table == primaryFollowsTable && _isMissingTableError(e)) {
        debugPrint(
            '[GamerSocialService] $primaryFollowsTable not found; using $legacyFollowsTable fallback');
        _resolvedFollowsTable = legacyFollowsTable;
        _tableProbed = true;
        return await operation(legacyFollowsTable);
      }
      rethrow;
    }
  }

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
  // SQUAD & ALLIES SOCIAL SYSTEM (Supabase: user_follows table)
  // ==========================================
  // DB Mapping:
  //   - user_follows.follower_id  -> player adding an ally
  //   - user_follows.following_id -> target player whose Squad grows
  //   - users.followers_count     -> Squad count
  //   - users.following_count     -> Allies count

  Stream<bool> isAllyStream(String currentUid, String targetUid) {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return Stream.value(false);
    }

    final allySourceUuid = stringToUuid(currentUid);
    final targetUuid = stringToUuid(targetUid);
    final controller = StreamController<bool>();
    StreamSubscription? realtimeSub;
    StreamSubscription? localSub;
    bool? lastEmitted;

    void emitIfChanged(bool val) {
      if (!controller.isClosed && lastEmitted != val) {
        lastEmitted = val;
        controller.add(val);
      }
    }

    controller.onListen = () async {
      final initial = await isAlly(currentUid, targetUid);
      emitIfChanged(initial);

      localSub = socialGraphUpdatesStream.listen((event) {
        final actorUuid = stringToUuid(event.actorUid);
        final evTargetUuid = stringToUuid(event.targetUid);
        if (actorUuid == allySourceUuid && evTargetUuid == targetUuid) {
          emitIfChanged(event.isAllied);
        }
      });

      try {
        final table = await resolveFollowsTable();
        realtimeSub = _supabase
            .from(table)
            .stream(primaryKey: ['id'])
            .eq('follower_id', allySourceUuid)
            .listen(
          (rows) {
            final found = rows.any(
              (r) =>
                  (r['following_id']?.toString().toLowerCase() ?? '') ==
                  targetUuid,
            );
            emitIfChanged(found);
          },
          onError: (e) {
            debugPrint('[GamerSocialService] isAllyStream realtime note: $e');
          },
        );
      } catch (e) {
        debugPrint('[GamerSocialService] isAllyStream setup note: $e');
      }
    };

    controller.onCancel = () async {
      await realtimeSub?.cancel();
      await localSub?.cancel();
      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  Stream<bool> isFollowingStream(String currentUid, String targetUid) =>
      isAllyStream(currentUid, targetUid);

  Future<bool> isAlly(String currentUid, String targetUid) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return false;
    }
    try {
      final allySourceUuid = stringToUuid(currentUid);
      final targetUuid = stringToUuid(targetUid);
      final res = await _runFollowsQuery((table) => _supabase
          .from(table)
          .select('id')
          .eq('follower_id', allySourceUuid)
          .eq('following_id', targetUuid)
          .maybeSingle());
      return res != null;
    } catch (e) {
      debugPrint('Error checking ally status: $e');
      return false;
    }
  }

  Future<bool> isFollowing(String currentUid, String targetUid) =>
      isAlly(currentUid, targetUid);

  Future<bool> addAlly({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid == targetUid || currentUid.isEmpty || targetUid.isEmpty) {
      return false;
    }
    lastSocialError = null;
    try {
      final allySourceUuid = stringToUuid(currentUid);
      final targetUuid = stringToUuid(targetUid);
      if (allySourceUuid == targetUuid) return false;

      final existing = await _runFollowsQuery((table) => _supabase
          .from(table)
          .select('id')
          .eq('follower_id', allySourceUuid)
          .eq('following_id', targetUuid)
          .maybeSingle());

      if (existing == null) {
        await _runFollowsQuery((table) => _supabase.from(table).insert({
              'follower_id': allySourceUuid,
              'following_id': targetUuid,
            }));
      }

      final synced = await _syncPairCounts(
        allySourceUuid: allySourceUuid,
        targetUuid: targetUuid,
        rawActorUid: currentUid,
        rawTargetUid: targetUid,
      );

      if (!_socialGraphController.isClosed) {
        _socialGraphController.add(SocialGraphUpdate(
          actorUid: currentUid,
          targetUid: targetUid,
          isAllied: true,
          targetSquadCount: synced?.squadCount,
          actorAlliesCount: synced?.alliesCount,
          timestamp: DateTime.now(),
        ));
      }

      try {
        final currentGamer = GamerAuthService().currentGamer;
        unawaited(NotificationService().sendFollowNotification(
          targetUserId: targetUid,
          followerId: currentUid,
          followerName: currentGamer?.displayName ?? 'A Gamer',
          followerAvatar: currentGamer?.photoUrl,
        ));
      } catch (_) {}

      return true;
    } catch (e) {
      lastSocialError = e.toString();
      debugPrint('Error adding ally: $e');
      return false;
    }
  }

  Future<bool> followUser({
    required String currentUid,
    required String targetUid,
  }) =>
      addAlly(currentUid: currentUid, targetUid: targetUid);

  Future<bool> removeAlly({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid == targetUid || currentUid.isEmpty || targetUid.isEmpty) {
      return false;
    }
    lastSocialError = null;
    try {
      final allySourceUuid = stringToUuid(currentUid);
      final targetUuid = stringToUuid(targetUid);
      if (allySourceUuid == targetUuid) return false;

      await _runFollowsQuery((table) => _supabase
          .from(table)
          .delete()
          .eq('follower_id', allySourceUuid)
          .eq('following_id', targetUuid));

      final synced = await _syncPairCounts(
        allySourceUuid: allySourceUuid,
        targetUuid: targetUuid,
        rawActorUid: currentUid,
        rawTargetUid: targetUid,
      );

      if (!_socialGraphController.isClosed) {
        _socialGraphController.add(SocialGraphUpdate(
          actorUid: currentUid,
          targetUid: targetUid,
          isAllied: false,
          targetSquadCount: synced?.squadCount,
          actorAlliesCount: synced?.alliesCount,
          timestamp: DateTime.now(),
        ));
      }

      return true;
    } catch (e) {
      lastSocialError = e.toString();
      debugPrint('Error removing ally: $e');
      return false;
    }
  }

  Future<bool> unfollowUser({
    required String currentUid,
    required String targetUid,
  }) =>
      removeAlly(currentUid: currentUid, targetUid: targetUid);

  Future<SocialCounts?> fetchSocialCounts(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final userUuid = stringToUuid(userId);
      final results = await Future.wait([
        _runFollowsQuery((table) =>
            _supabase.from(table).select('id').eq('following_id', userUuid)),
        _runFollowsQuery((table) =>
            _supabase.from(table).select('id').eq('follower_id', userUuid)),
      ]);
      final squadCount = (results[0] as List).length;
      final alliesCount = (results[1] as List).length;
      return SocialCounts(squadCount: squadCount, alliesCount: alliesCount);
    } catch (e) {
      debugPrint('[GamerSocialService] fetchSocialCounts error: $e');
      return null;
    }
  }

  Future<_SyncPairResult?> _syncPairCounts({
    required String allySourceUuid,
    required String targetUuid,
    String? rawActorUid,
    String? rawTargetUid,
  }) async {
    try {
      final results = await Future.wait([
        _runFollowsQuery((table) =>
            _supabase.from(table).select('id').eq('following_id', targetUuid)),
        _runFollowsQuery((table) => _supabase
            .from(table)
            .select('id')
            .eq('follower_id', allySourceUuid)),
      ]);

      final int targetSquadCount = (results[0] as List).length;
      final int actorAlliesCount = (results[1] as List).length;
      bool isDemoTarget = false;

      // Best-effort sync to public.users (idempotent exact count — safe even alongside DB trigger)
      try {
        final targetFilter = (rawTargetUid != null &&
                rawTargetUid.isNotEmpty &&
                rawTargetUid != targetUuid)
            ? 'id.eq.$targetUuid,uid.eq.$targetUuid,uid.eq.$rawTargetUid'
            : 'id.eq.$targetUuid,uid.eq.$targetUuid';
        final targetRow = await _supabase
            .from('users')
            .select()
            .or(targetFilter)
            .maybeSingle();
        isDemoTarget = targetRow?['isDemoAccount'] == true ||
            targetRow?['is_demo_account'] == true;
        if (targetRow != null && !isDemoTarget) {
          final currentDbCount =
              (targetRow['followers_count'] as num?)?.toInt() ?? -1;
          if (currentDbCount != targetSquadCount) {
            await _supabase
                .from('users')
                .update({'followers_count': targetSquadCount})
                .eq('id', targetRow['id'].toString());
          }
        }
      } catch (_) {}

      try {
        final actorFilter = (rawActorUid != null &&
                rawActorUid.isNotEmpty &&
                rawActorUid != allySourceUuid)
            ? 'id.eq.$allySourceUuid,uid.eq.$allySourceUuid,uid.eq.$rawActorUid'
            : 'id.eq.$allySourceUuid,uid.eq.$allySourceUuid';
        final actorRow = await _supabase
            .from('users')
            .select()
            .or(actorFilter)
            .maybeSingle();
        if (actorRow != null) {
          final currentDbAllies =
              (actorRow['following_count'] as num?)?.toInt() ?? -1;
          if (currentDbAllies != actorAlliesCount) {
            await _supabase
                .from('users')
                .update({'following_count': actorAlliesCount})
                .eq('id', actorRow['id'].toString());
          }
        }
      } catch (_) {}

      // Keep local auth gamer profile notifier instantly synchronized
      try {
        final authService = GamerAuthService();
        final cur = authService.currentGamer;
        if (cur != null) {
          final curUuid = stringToUuid(cur.uid);
          if (curUuid == allySourceUuid) {
            authService.currentGamerNotifier.value =
                cur.copyWith(followingCount: actorAlliesCount);
          } else if (curUuid == targetUuid && !isDemoTarget) {
            authService.currentGamerNotifier.value =
                cur.copyWith(followersCount: targetSquadCount);
          }
        }
      } catch (_) {}

      return _SyncPairResult(
        squadCount: isDemoTarget ? null : targetSquadCount,
        alliesCount: actorAlliesCount,
      );
    } catch (e) {
      debugPrint('[GamerSocialService] _syncPairCounts note: $e');
      return null;
    }
  }

  Stream<List<String>> getAlliesUserIdsStream(String uid) async* {
    if (uid.isEmpty) {
      yield [];
      return;
    }
    final playerUuid = stringToUuid(uid);
    while (true) {
      try {
        final res = await _runFollowsQuery((table) => _supabase
            .from(table)
            .select('following_id')
            .eq('follower_id', playerUuid));
        final list = (res as List)
            .map((item) => item['following_id'].toString())
            .where((id) => id.isNotEmpty && id != playerUuid)
            .toList();
        yield list;
      } catch (e) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Stream<List<String>> getFollowingUserIdsStream(String uid) =>
      getAlliesUserIdsStream(uid);

  Future<List<GamerUser>> getSquadMembers(String targetUid) async {
    if (targetUid.isEmpty) return [];
    try {
      final targetUuid = stringToUuid(targetUid);

      final squadRows = await _runFollowsQuery((table) => _supabase
          .from(table)
          .select('follower_id')
          .eq('following_id', targetUuid));

      if (squadRows.isEmpty) return [];

      final squadMemberUuids = squadRows
          .map((r) => r['follower_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty && id != targetUuid)
          .toSet()
          .toList();

      if (squadMemberUuids.isEmpty) return [];

      final userRows = await _supabase
          .from('users')
          .select()
          .inFilter('id', squadMemberUuids);

      final users = (userRows as List)
          .map((row) => _rowToGamerUser(row))
          .whereType<GamerUser>()
          .where((u) => u.uid != targetUuid && u.uid != targetUid)
          .toList();

      return users;
    } catch (e) {
      debugPrint('[GamerSocialService] getSquadMembers error: $e');
      return [];
    }
  }

  Future<List<GamerUser>> getFollowers(String targetUid) =>
      getSquadMembers(targetUid);

  Future<List<GamerUser>> getAllies(String playerUid) async {
    if (playerUid.isEmpty) return [];
    try {
      final playerUuid = stringToUuid(playerUid);

      final allyRows = await _runFollowsQuery((table) => _supabase
          .from(table)
          .select('following_id')
          .eq('follower_id', playerUuid));

      if (allyRows.isEmpty) return [];

      final allyUuids = allyRows
          .map((r) => r['following_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty && id != playerUuid)
          .toSet()
          .toList();

      if (allyUuids.isEmpty) return [];

      final userRows =
          await _supabase.from('users').select().inFilter('id', allyUuids);

      final users = (userRows as List)
          .map((row) => _rowToGamerUser(row))
          .whereType<GamerUser>()
          .where((u) => u.uid != playerUuid && u.uid != playerUid)
          .toList();

      return users;
    } catch (e) {
      debugPrint('[GamerSocialService] getAllies error: $e');
      return [];
    }
  }

  Future<List<GamerUser>> getFollowing(String followerUid) =>
      getAllies(followerUid);

  GamerUser? _rowToGamerUser(Map<String, dynamic> row) {
    try {
      final rawUid = (row['id'] ?? row['uid'] ?? '').toString();
      if (rawUid.isEmpty) return null;

      return GamerUser(
        uid: rawUid,
        username: (row['username'] ?? 'gamer').toString(),
        displayName:
            (row['display_name'] ?? row['username'] ?? 'Gamer').toString(),
        photoUrl: (row['avatar_url'] ?? '').toString(),
        coverUrl: (row['cover_url'] ?? '').toString(),
        bio: (row['bio'] ?? '').toString(),
        favoriteGame: (row['favorite_game'] ?? 'BGMI').toString(),
        selectedGame: (row['selected_game'] ?? '').toString(),
        selectedRank: (row['selected_rank'] ?? '').toString(),
        rank: (row['rank'] ?? '').toString(),
        rankStatus: (row['rank_status'] ?? 'None').toString(),
        isRankVerified: row['is_rank_verified'] == true,
        gameId: (row['game_id'] ?? '').toString(),
        coins: (row['coins'] as num?)?.toInt() ?? 0,
        followersCount:
            ((row['followers_count'] ?? row['followersCount']) as num?)
                    ?.toInt() ??
                0,
        followingCount:
            ((row['following_count'] ?? row['followingCount']) as num?)
                    ?.toInt() ??
                0,
        postsCount: (row['posts_count'] as num?)?.toInt() ?? 0,
        isVerified: row['is_verified'] == true,
        verificationStatus: (row['blue_tick_status'] ?? 'none').toString(),
        activeFrame: (row['active_frame'] ?? '').toString(),
        activeBadge: (row['active_badge'] ?? '').toString(),
        isDemoAccount:
            row['isDemoAccount'] == true || row['is_demo_account'] == true,
        createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
        isBioPublic: row['is_bio_public'] != false,
        isGamePublic: row['is_game_public'] != false,
        isFollowersPublic:
            (row['is_followers_public'] ?? row['show_followers']) != false,
        isFollowingPublic:
            (row['is_following_public'] ?? row['show_following']) != false,
      );
    } catch (e) {
      debugPrint('[GamerSocialService] _rowToGamerUser error: $e');
      return null;
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
    String? imageUrl,
    String? mediaUrl,
    String? videoUrl,
    String? content,
    String? game,
  }) async {
    // ============ FIX: Sirf auth.currentUser.id — koi fallback nahi ============
    final authUserId = _supabase.auth.currentUser?.id;

    if (authUserId == null || authUserId.isEmpty) {
      throw Exception(
          'User not authenticated. Please log in again to publish a post.');
    }

    final effectiveUserId = authUserId;
    final postUuid = stringToUuid(effectiveUserId);

    // ============ FIX: users table se FRESH display_name aur avatar lo ============
    String freshUsername = username;
    String freshDisplayName = displayName;
    String freshAvatar = userPhoto;

    try {
      final userRow = await _supabase
          .from('users')
          .select('username, display_name, avatar_url')
          .eq('id', effectiveUserId)
          .maybeSingle();

      if (userRow != null) {
        final u = (userRow['username'] ?? '').toString();
        final d = (userRow['display_name'] ?? '').toString();
        final a = (userRow['avatar_url'] ?? '').toString();
        if (u.isNotEmpty) freshUsername = u;
        if (d.isNotEmpty) freshDisplayName = d;
        if (a.isNotEmpty) freshAvatar = a;
      }
    } catch (e) {
      debugPrint('[GamerSocialService] Note fetching fresh user data: $e');
    }

    final postContent = text.isNotEmpty ? text : (content ?? '');
    final finalGame =
        (gameTag.isNotEmpty && gameTag != 'BGMI') ? gameTag : (game ?? gameTag);
    final finalMedia = imageUrl ?? mediaUrl;
    final finalVideo = videoUrl;

    await _ensureUserExists(
      userId: effectiveUserId,
      username: freshUsername,
      displayName: freshDisplayName,
      userPhoto: freshAvatar,
    );

    try {
      final response = await _supabase
          .from('posts')
          .insert({
            'user_id': postUuid,
            'username': freshUsername,
            'display_name': freshDisplayName,
            'user_avatar': freshAvatar,
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

  Stream<List<GamerPost>> getUserPostsStream(String userId,
      [String? username]) async* {
    while (true) {
      try {
        final uuid = stringToUuid(userId);
        final data = await _supabase
            .from('posts')
            .select()
            .eq('user_id', uuid)
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
      feedRefreshNotifier.value++;
    } catch (e) {
      debugPrint('[GamerSocialService] Error deleting post: $e');
    }
  }

  // ==========================================
  // REPOST / QUOTE POST SYSTEM
  // ==========================================

  Future<String> createRepost({
    required String originalPostId,
    required String originalAuthorId,
    required String originalAuthorUsername,
    String? originalAuthorAvatar,
    String? originalContent,
    String? originalImageUrl,
    String? originalGame,
    String? quoteText,
  }) async {
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId == null || authUserId.isEmpty) {
      throw Exception('User not authenticated. Please log in to repost.');
    }

    final postUuid = stringToUuid(authUserId);
    String freshUsername = 'gamer';
    String freshDisplayName = 'Gamer';
    String freshAvatar = '';

    try {
      final userRow = await _supabase
          .from('users')
          .select('username, display_name, avatar_url')
          .eq('id', authUserId)
          .maybeSingle();

      if (userRow != null) {
        freshUsername = (userRow['username'] ?? '').toString();
        freshDisplayName = (userRow['display_name'] ?? '').toString();
        freshAvatar = (userRow['avatar_url'] ?? '').toString();
      }
    } catch (_) {}

    await _ensureUserExists(
      userId: authUserId,
      username: freshUsername,
      displayName: freshDisplayName,
      userPhoto: freshAvatar,
    );

    final isQuote = quoteText != null && quoteText.trim().isNotEmpty;
    final finalContent = isQuote ? quoteText.trim() : (originalContent ?? '');
    final finalGame = (originalGame != null && originalGame.isNotEmpty) ? originalGame : 'BGMI';

    Map<String, dynamic>? response;
    try {
      // 1. Try full schema with repost columns
      response = await _supabase
          .from('posts')
          .insert({
            'user_id': postUuid,
            'username': freshUsername,
            'display_name': freshDisplayName,
            'user_avatar': freshAvatar,
            'content': finalContent,
            'image_url': originalImageUrl,
            'media_url': originalImageUrl,
            'game': finalGame,
            'likes_count': 0,
            'comments_count': 0,
            'reposts_count': 0,
            'shares_count': 0,
            'is_repost': true,
            'repost_of_id': originalPostId,
            'repost_type': isQuote ? 'quote' : 'instant',
            'original_author_id': originalAuthorId,
            'original_author_username': originalAuthorUsername,
            'original_author_avatar': originalAuthorAvatar,
            'original_content': originalContent,
            'original_image_url': originalImageUrl,
          })
          .select()
          .single();
    } catch (e) {
      debugPrint('[GamerSocialService] Extended repost schema fallback: $e');
      // Fallback if some custom columns not yet in DB table
      final fallbackContent = isQuote
          ? '${quoteText.trim()}\n\n🔁 Reposted from @$originalAuthorUsername:\n${originalContent ?? ""}'
          : '🔁 Reposted from @$originalAuthorUsername:\n${originalContent ?? ""}';
      response = await _supabase
          .from('posts')
          .insert({
            'user_id': postUuid,
            'username': freshUsername,
            'display_name': freshDisplayName,
            'user_avatar': freshAvatar,
            'content': fallbackContent,
            'image_url': originalImageUrl,
            'media_url': originalImageUrl,
            'game': finalGame,
            'likes_count': 0,
            'comments_count': 0,
          })
          .select()
          .single();
    }

    // 2. Track in reposts table
    try {
      await _supabase.from('reposts').insert({
        'post_id': originalPostId,
        'user_id': authUserId,
        'username': freshUsername,
      });
    } catch (_) {}

    // 3. Increment shares_count / reposts_count on original post
    try {
      final origRow = await _supabase
          .from('posts')
          .select('shares_count, reposts_count')
          .eq('id', originalPostId)
          .maybeSingle();

      if (origRow != null) {
        final curShares = (origRow['shares_count'] as num?)?.toInt() ?? 0;
        final curReposts = (origRow['reposts_count'] as num?)?.toInt() ?? 0;
        await _supabase.from('posts').update({
          'shares_count': curShares + 1,
          'reposts_count': curReposts + 1,
        }).eq('id', originalPostId);
      }
    } catch (_) {}

    // 4. Send notification to original post author
    if (originalAuthorId.isNotEmpty && originalAuthorId != authUserId) {
      try {
        final snippet = (originalContent != null && originalContent.length > 40)
            ? '${originalContent.substring(0, 40)}...'
            : (originalContent ?? 'post');
        NotificationService().sendNotification(
          userId: originalAuthorId,
          senderId: authUserId,
          senderName: freshDisplayName,
          senderAvatar: freshAvatar,
          title: '🔁 New Repost!',
          body: isQuote
              ? '@$freshUsername quoted your post: "$snippet"'
              : '@$freshUsername reposted your post: "$snippet"',
          type: 'social',
          data: {'post_id': originalPostId, 'type': 'repost'},
        );
      } catch (_) {}
    }

    feedRefreshNotifier.value++;
    return response['id']?.toString() ?? '';
  }

  Future<bool> undoRepost({
    required String originalPostId,
    required String userId,
  }) async {
    final authUserId = _supabase.auth.currentUser?.id ?? userId;
    final postUuid = stringToUuid(authUserId);

    try {
      // 1. Remove from reposts tracking table
      try {
        await _supabase
            .from('reposts')
            .delete()
            .eq('post_id', originalPostId)
            .eq('user_id', authUserId);
      } catch (_) {}

      // 2. Remove the reposted post item from posts table
      try {
        await _supabase
            .from('posts')
            .delete()
            .eq('user_id', postUuid)
            .eq('repost_of_id', originalPostId);
      } catch (_) {
        // Fallback search
        await _supabase
            .from('posts')
            .delete()
            .eq('user_id', postUuid)
            .ilike('content', '%@%');
      }

      // 3. Decrement shares_count / reposts_count on original post
      try {
        final origRow = await _supabase
            .from('posts')
            .select('shares_count, reposts_count')
            .eq('id', originalPostId)
            .maybeSingle();

        if (origRow != null) {
          final curShares = (origRow['shares_count'] as num?)?.toInt() ?? 0;
          final curReposts = (origRow['reposts_count'] as num?)?.toInt() ?? 0;
          await _supabase.from('posts').update({
            if (curShares > 0) 'shares_count': curShares - 1,
            if (curReposts > 0) 'reposts_count': curReposts - 1,
          }).eq('id', originalPostId);
        }
      } catch (_) {}

      feedRefreshNotifier.value++;
      return true;
    } catch (e) {
      debugPrint('[GamerSocialService] undoRepost error: $e');
      return false;
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

        if (postAuthorId != null && postAuthorId.isNotEmpty && postAuthorId != userId) {
          try {
            final currentGamer = GamerAuthService().currentGamer;
            NotificationService().sendLikeNotification(
              targetUserId: postAuthorId,
              likerId: userId,
              likerName: currentGamer?.displayName ?? 'A Gamer',
              postId: postId,
              likerAvatar: currentGamer?.photoUrl,
            );
          } catch (_) {}
        }
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

      if (postAuthorId != null && postAuthorId.isNotEmpty && postAuthorId != userId) {
        try {
          NotificationService().sendCommentNotification(
            targetUserId: postAuthorId,
            commenterId: userId,
            commenterName: displayName ?? username,
            postId: postId,
            commentText: text,
            commenterAvatar: userPhoto,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[GamerSocialService] addComment error: $e');
    }
  }

  Future<List<GamerUser>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final q = query.trim().toLowerCase();
      final rows = await _supabase
          .from('users')
          .select()
          .or('username.ilike.%$q%,display_name.ilike.%$q%')
          .limit(20);

      return (rows as List)
          .map((r) => _rowToGamerUser(r))
          .whereType<GamerUser>()
          .toList();
    } catch (e) {
      debugPrint('[GamerSocialService] searchUsers error: $e');
      return [];
    }
  }

  Stream<List<GamerUser>> getSuggestedGamersStream({int limit = 15}) {
    return Stream.value([]);
  }

  Future<int> fixOldNewsImages() async {
    return 0;
  }
}