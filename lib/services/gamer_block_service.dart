import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Play Store compliant Block Service.
/// 
/// Provides:
/// - Block / Unblock users
/// - Check if a user is blocked
/// - Get list of blocked user IDs
/// - Stream of blocked user IDs (realtime)
/// 
/// Blocks are stored in `public.blocked_users` table.
class GamerBlockService {
  static final GamerBlockService _instance = GamerBlockService._internal();
  factory GamerBlockService() => _instance;
  GamerBlockService._internal();

  /// Block a user
  Future<bool> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    if (blockerId.isEmpty || blockedId.isEmpty || blockerId == blockedId) {
      return false;
    }

    try {
      final blockerUuid = SupabaseService.toUuid(blockerId);
      final blockedUuid = SupabaseService.toUuid(blockedId);

      await SupabaseService.client.from('blocked_users').insert({
        'blocker_id': blockerUuid,
        'blocked_id': blockedUuid,
      });

      debugPrint('[BlockService] Blocked: $blockerUuid -> $blockedUuid');
      return true;
    } catch (e) {
      debugPrint('[BlockService] Block error: $e');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    if (blockerId.isEmpty || blockedId.isEmpty) return false;

    try {
      final blockerUuid = SupabaseService.toUuid(blockerId);
      final blockedUuid = SupabaseService.toUuid(blockedId);

      await SupabaseService.client
          .from('blocked_users')
          .delete()
          .eq('blocker_id', blockerUuid)
          .eq('blocked_id', blockedUuid);

      debugPrint('[BlockService] Unblocked: $blockerUuid -> $blockedUuid');
      return true;
    } catch (e) {
      debugPrint('[BlockService] Unblock error: $e');
      return false;
    }
  }

  /// Check if a user is blocked by current user
  Future<bool> isUserBlocked({
    required String blockerId,
    required String blockedId,
  }) async {
    if (blockerId.isEmpty || blockedId.isEmpty) return false;

    try {
      final blockerUuid = SupabaseService.toUuid(blockerId);
      final blockedUuid = SupabaseService.toUuid(blockedId);

      final res = await SupabaseService.client
          .from('blocked_users')
          .select('id')
          .eq('blocker_id', blockerUuid)
          .eq('blocked_id', blockedUuid)
          .maybeSingle();

      return res != null;
    } catch (e) {
      debugPrint('[BlockService] isBlocked error: $e');
      return false;
    }
  }

  /// Get all blocked user IDs (only the blocked_id column)
  Future<Set<String>> getBlockedUserIds(String blockerId) async {
    if (blockerId.isEmpty) return {};

    try {
      final blockerUuid = SupabaseService.toUuid(blockerId);
      final rows = await SupabaseService.client
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', blockerUuid);

      return (rows as List)
          .map((r) => r['blocked_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('[BlockService] getBlockedUserIds error: $e');
      return {};
    }
  }

  /// Realtime stream: get list of blocked user IDs
  Stream<Set<String>> getBlockedUserIdsStream(String blockerId) {
    if (blockerId.isEmpty) return Stream.value({});

    final blockerUuid = SupabaseService.toUuid(blockerId);

    return SupabaseService.client
        .from('blocked_users')
        .stream(primaryKey: ['id'])
        .eq('blocker_id', blockerUuid)
        .map((rows) {
      return rows
          .map((r) => r['blocked_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    });
  }

  /// Get full blocked users profiles (for Blocked List screen)
  Future<List<Map<String, dynamic>>> getBlockedUsersWithProfiles(
      String blockerId) async {
    if (blockerId.isEmpty) return [];

    try {
      final blockerUuid = SupabaseService.toUuid(blockerId);

      // 1. Get blocked users
      final blockedRows = await SupabaseService.client
          .from('blocked_users')
          .select('id, blocked_id, created_at')
          .eq('blocker_id', blockerUuid)
          .order('created_at', ascending: false);

      final blockedList = List<Map<String, dynamic>>.from(blockedRows);
      if (blockedList.isEmpty) return [];

      final blockedIds = blockedList
          .map((r) => r['blocked_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      // 2. Get profiles
      Map<String, Map<String, dynamic>> profiles = {};
      try {
        final usersData = await SupabaseService.client
            .from('users')
            .select('id, username, display_name, avatar_url')
            .inFilter('id', blockedIds);

        for (final u in (usersData as List)) {
          if (u is Map<String, dynamic> && u['id'] != null) {
            profiles[u['id'].toString()] = u;
          }
        }
      } catch (e) {
        debugPrint('[BlockService] Profiles fetch error: $e');
      }

      // 3. Merge
      return blockedList.map((b) {
        final blockedId = b['blocked_id']?.toString() ?? '';
        final profile = profiles[blockedId] ?? {};
        return {
          'block_id': b['id'],
          'blocked_id': blockedId,
          'created_at': b['created_at'],
          'username': profile['username'] ?? 'gamer',
          'display_name': profile['display_name'] ?? 'Gamer',
          'avatar_url': profile['avatar_url'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('[BlockService] getBlockedUsersWithProfiles error: $e');
      return [];
    }
  }
}