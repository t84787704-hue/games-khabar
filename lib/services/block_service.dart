import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class BlockService {
  static final BlockService _instance = BlockService._internal();
  factory BlockService() => _instance;
  BlockService._internal();

  final _client = SupabaseService.client;

  Future<bool> isBlocked({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty) return false;
    if (currentUid == targetUid) return false;
    try {
      final res = await _client
          .from('blocked_users')
          .select('id')
          .eq('blocker_id', SupabaseService.toUuid(currentUid))
          .eq('blocked_id', SupabaseService.toUuid(targetUid))
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('[BlockService] isBlocked error: $e');
      return false;
    }
  }

  Future<bool> isBlockedBy({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty) return false;
    try {
      final res = await _client
          .from('blocked_users')
          .select('id')
          .eq('blocker_id', SupabaseService.toUuid(targetUid))
          .eq('blocked_id', SupabaseService.toUuid(currentUid))
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('[BlockService] isBlockedBy error: $e');
      return false;
    }
  }

  Future<bool> blockUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty) return false;
    if (currentUid == targetUid) return false;
    try {
      await _client.from('blocked_users').insert({
        'blocker_id': SupabaseService.toUuid(currentUid),
        'blocked_id': SupabaseService.toUuid(targetUid),
        'created_at': DateTime.now().toIso8601String(),
      });

      try {
        await _client
            .from('follows')
            .delete()
            .eq('follower_id', SupabaseService.toUuid(currentUid))
            .eq('following_id', SupabaseService.toUuid(targetUid));

        await _client
            .from('follows')
            .delete()
            .eq('follower_id', SupabaseService.toUuid(targetUid))
            .eq('following_id', SupabaseService.toUuid(currentUid));
      } catch (e) {
        debugPrint('[BlockService] unfollow cleanup: $e');
      }

      return true;
    } catch (e) {
      debugPrint('[BlockService] blockUser error: $e');
      return false;
    }
  }

  Future<bool> unblockUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty) return false;
    try {
      await _client
          .from('blocked_users')
          .delete()
          .eq('blocker_id', SupabaseService.toUuid(currentUid))
          .eq('blocked_id', SupabaseService.toUuid(targetUid));
      return true;
    } catch (e) {
      debugPrint('[BlockService] unblockUser error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers(String currentUid) async {
    if (currentUid.isEmpty) return [];
    try {
      final rows = await _client
          .from('blocked_users')
          .select('blocked_id, created_at')
          .eq('blocker_id', SupabaseService.toUuid(currentUid))
          .order('created_at', ascending: false);

      if (rows.isEmpty) return [];

      final blockedIds =
          rows.map((r) => r['blocked_id'].toString()).toList();

      final users = await _client
          .from('users')
          .select('id, username, display_name, avatar_url, is_verified')
          .inFilter('id', blockedIds);

      final Map<String, Map<String, dynamic>> userMap = {
        for (final u in users)
          u['id'].toString(): Map<String, dynamic>.from(u)
      };

      final result = <Map<String, dynamic>>[];
      for (final r in rows) {
        final uid = r['blocked_id'].toString();
        final u = userMap[uid];
        if (u != null) {
          u['blocked_at'] = r['created_at'];
          result.add(u);
        }
      }
      return result;
    } catch (e) {
      debugPrint('[BlockService] getBlockedUsers error: $e');
      return [];
    }
  }

  Future<Set<String>> getBlockedIds(String currentUid) async {
    if (currentUid.isEmpty) return {};
    try {
      final rows = await _client
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', SupabaseService.toUuid(currentUid));
      return rows.map((r) => r['blocked_id'].toString()).toSet();
    } catch (e) {
      debugPrint('[BlockService] getBlockedIds error: $e');
      return {};
    }
  }
}