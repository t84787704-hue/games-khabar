import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'squad_service.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

/// LFG Service providing specialized request handling for squads and lfg_posts backed by Supabase
class LfgService {
  final SquadService _squadService = SquadService();

  static final LfgService _instance = LfgService._internal();
  factory LfgService() => _instance;
  LfgService._internal();

  /// 1. On Join Request:
  Future<void> joinRequest({
    required String postId,
    required String currentUserId,
    Map<String, dynamic>? applicantData,
    String? leaderUid,
  }) async {
    try {
      debugPrint("START JOIN REQUEST postId=$postId userId=$currentUserId");
      
      final postRows = await SupabaseService.client
          .from('posts')
          .select()
          .or('id.eq.$postId,postId.eq.$postId,squadId.eq.$postId')
          .limit(1);

      Map<String, dynamic> data = postRows.isNotEmpty ? postRows.first : {};
      if (data.isEmpty) {
        final teamRows = await SupabaseService.client
            .from('teams')
            .select()
            .or('id.eq.$postId,teamId.eq.$postId')
            .limit(1);
        if (teamRows.isNotEmpty) data = teamRows.first;
      }

      final ownerId = (data['ownerId'] ?? data['owner_id'] ?? data['userId'] ?? data['user_id'] ?? leaderUid ?? '').toString();
      if (currentUserId == ownerId) {
        throw "Own squad";
      }

      final List<dynamic> members = List.from(data['members'] ?? []);
      final List<dynamic> joinRequests = List.from(data['joinRequests'] ?? data['join_requests'] ?? []);

      if (members.length >= 4) {
        throw "Squad is full";
      }

      if (!joinRequests.contains(currentUserId)) {
        joinRequests.add(currentUserId);
      }

      final int curRequested = joinRequests.length;
      final updatePayload = {
        'joinRequests': joinRequests,
        'join_requests': joinRequests,
        'requestedCount': curRequested,
        'requested_count': curRequested,
      };

      try {
        await SupabaseService.client.from('posts').update(updatePayload).or('id.eq.$postId,postId.eq.$postId');
      } catch (_) {}
      try {
        await SupabaseService.client.from('teams').update(updatePayload).or('id.eq.$postId,teamId.eq.$postId');
      } catch (_) {}

      // Store in team_join_requests
      try {
        await SupabaseService.client.from('team_join_requests').upsert({
          'id': '${postId}_$currentUserId',
          'team_id': postId,
          'teamId': postId,
          'user_id': currentUserId,
          'userId': currentUserId,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          if (applicantData != null) ...applicantData,
        });
      } catch (_) {}

      debugPrint("JOIN REQUEST SUCCESS");

      final effectiveLeader = leaderUid ?? ownerId;
      if (effectiveLeader.isNotEmpty && effectiveLeader != currentUserId) {
        final applicantName = (applicantData?['displayName'] ?? applicantData?['name'] ?? 'A Gamer').toString();
        
        try {
          await SupabaseService.client.from('notifications').insert({
            'recipientUid': effectiveLeader,
            'user_id': effectiveLeader,
            'senderUid': currentUserId,
            'type': 'squad_request',
            'title': 'New Squad Request 🎮',
            'message': '$applicantName requested to join your squad',
            'postId': postId,
            'post_id': postId,
            'read': false,
            'createdAt': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}

        NotificationService().showSquadNotification(
          title: 'New Squad Request 🎮',
          body: '$applicantName requested to join your squad',
          postId: postId,
          recipientUid: effectiveLeader,
        );
      }
    } catch (e, stack) {
      debugPrint("JOIN REQUEST FAILED: $e");
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// 2. On Accept (in owner account):
  Future<void> acceptRequest({
    required String postId,
    required String requesterId,
    required String requestDocId,
    String requesterName = 'Gamer',
    String leaderUid = '',
    String inGameUid = '',
    String mode = 'Classic Squad',
  }) async {
    try {
      debugPrint("START ACCEPT postId=$postId requesterId=$requesterId docId=$requestDocId");

      final currentUid = SupabaseService.client.auth.currentUser?.id;

      final postRows = await SupabaseService.client
          .from('posts')
          .select()
          .or('id.eq.$postId,postId.eq.$postId,squadId.eq.$postId')
          .limit(1);

      Map<String, dynamic> data = postRows.isNotEmpty ? postRows.first : {};
      final ownerId = (data['ownerId'] ?? data['owner_id'] ?? data['userId'] ?? data['user_id'] ?? leaderUid).toString();
      if (currentUid != null && ownerId.isNotEmpty && currentUid != ownerId) {
        throw "Only owner can accept";
      }

      final List<dynamic> members = List.from(data['members'] ?? []);
      final List<dynamic> joinRequests = List.from(data['joinRequests'] ?? data['join_requests'] ?? []);

      joinRequests.remove(requesterId);
      joinRequests.remove(requestDocId);

      if (!members.contains(requesterId) && requesterId != ownerId) {
        if (members.length >= 4) {
          throw "Squad is full";
        }
        members.add(requesterId);
      }

      final int newMembersCount = members.length;
      final bool isNowFull = newMembersCount >= 4;
      final int safeRequestedCount = math.max(0, joinRequests.length);

      final updatePayload = {
        'members': members,
        'membersCount': newMembersCount,
        'members_count': newMembersCount,
        'joinRequests': joinRequests,
        'join_requests': joinRequests,
        'requestedCount': safeRequestedCount,
        'requested_count': safeRequestedCount,
        if (isNowFull) 'isActive': false,
        if (isNowFull) 'is_active': false,
      };

      try {
        await SupabaseService.client.from('posts').update(updatePayload).or('id.eq.$postId,postId.eq.$postId');
      } catch (_) {}
      try {
        await SupabaseService.client.from('teams').update(updatePayload).or('id.eq.$postId,teamId.eq.$postId');
      } catch (_) {}

      // Delete from team_join_requests
      try {
        await SupabaseService.client
            .from('team_join_requests')
            .delete()
            .or('id.eq.${postId}_$requesterId,user_id.eq.$requesterId');
      } catch (_) {}

      // Add system message to chat
      try {
        await SupabaseService.sendMatchChatMessage(
          matchId: postId,
          senderId: 'system',
          senderName: 'Squad Bot',
          message: 'Welcome @$requesterName to the squad!',
          messageType: 'system',
        );
      } catch (_) {}

      // Send accepted notification
      try {
        final notifMessage = "Your request to join the squad was accepted! Tap to chat.";
        await SupabaseService.client.from('notifications').insert({
          'recipientUid': requesterId,
          'user_id': requesterId,
          'senderUid': leaderUid.isNotEmpty ? leaderUid : (currentUid ?? ''),
          'type': 'squad_accepted',
          'title': 'Squad Request Accepted! 🎮',
          'message': notifMessage,
          'postId': postId,
          'post_id': postId,
          'inGameUid': inGameUid,
          'read': false,
          'createdAt': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });

        NotificationService().showSquadNotification(
          title: 'Squad Request Accepted! 🎮',
          body: notifMessage,
          postId: postId,
          recipientUid: requesterId,
        );
      } catch (ne) {
        debugPrint("[LfgService] Notification send error: ne");
      }
    } catch (e, stack) {
      debugPrint("ACCEPT FAILED: $e");
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// Declines / rejects a request from lfg_posts
  Future<void> rejectRequest({
    required String postId,
    required String requesterId,
    String? requestDocId,
  }) async {
    try {
      debugPrint("START REJECT postId=$postId requesterId=$requesterId");

      final postRows = await SupabaseService.client
          .from('posts')
          .select()
          .or('id.eq.$postId,postId.eq.$postId,squadId.eq.$postId')
          .limit(1);

      if (postRows.isNotEmpty) {
        final data = postRows.first;
        final List<dynamic> joinRequests = List.from(data['joinRequests'] ?? data['join_requests'] ?? []);
        joinRequests.remove(requesterId);
        if (requestDocId != null) joinRequests.remove(requestDocId);
        final safeCount = math.max(0, joinRequests.length);

        final updatePayload = {
          'joinRequests': joinRequests,
          'join_requests': joinRequests,
          'requestedCount': safeCount,
          'requested_count': safeCount,
        };

        try {
          await SupabaseService.client.from('posts').update(updatePayload).or('id.eq.$postId,postId.eq.$postId');
        } catch (_) {}
        try {
          await SupabaseService.client.from('teams').update(updatePayload).or('id.eq.$postId,teamId.eq.$postId');
        } catch (_) {}
      }

      try {
        await SupabaseService.client
            .from('team_join_requests')
            .delete()
            .or('id.eq.${postId}_$requesterId,user_id.eq.$requesterId');
      } catch (_) {}
    } catch (e) {
      debugPrint("REJECT FAILED: $e");
      rethrow;
    }
  }

  /// Kick a member from the squad (Owner only)
  Future<void> kickMember({
    required String postId,
    required String memberUid,
    required String leaderUid,
    String memberName = 'A player',
  }) async {
    try {
      debugPrint("[LfgService] Kicking member $memberUid from post $postId");

      final postRows = await SupabaseService.client
          .from('posts')
          .select()
          .or('id.eq.$postId,postId.eq.$postId,squadId.eq.$postId')
          .limit(1);

      if (postRows.isNotEmpty) {
        final data = postRows.first;
        final List<dynamic> members = List.from(data['members'] ?? []);
        members.remove(memberUid);
        final updatePayload = {
          'members': members,
          'membersCount': members.length,
          'members_count': members.length,
          'isActive': true,
          'is_active': true,
        };

        try {
          await SupabaseService.client.from('posts').update(updatePayload).or('id.eq.$postId,postId.eq.$postId');
        } catch (_) {}
        try {
          await SupabaseService.client.from('teams').update(updatePayload).or('id.eq.$postId,teamId.eq.$postId');
        } catch (_) {}
      }

      // System message in chat
      try {
        await SupabaseService.sendMatchChatMessage(
          matchId: postId,
          senderId: 'system',
          senderName: 'Squad Bot',
          message: '$memberName was removed from the squad.',
          messageType: 'system',
        );
      } catch (_) {}

      // Notify kicked player
      try {
        await SupabaseService.client.from('notifications').insert({
          'recipientUid': memberUid,
          'user_id': memberUid,
          'senderUid': leaderUid,
          'type': 'squad_kick',
          'title': 'Squad Update',
          'message': 'You were removed from the squad.',
          'postId': postId,
          'post_id': postId,
          'read': false,
          'createdAt': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });

        NotificationService().showSquadNotification(
          title: 'Squad Update',
          body: 'You were removed from the squad.',
          postId: postId,
          recipientUid: memberUid,
        );
      } catch (_) {}
    } catch (e) {
      debugPrint("[LfgService] KICK ERROR: $e");
      rethrow;
    }
  }

  /// Leave a squad (Member action)
  Future<void> leaveSquad({
    required String postId,
    required String memberUid,
    required String leaderUid,
    String memberName = 'A player',
  }) async {
    try {
      debugPrint("[LfgService] Member $memberUid leaving post $postId");

      final postRows = await SupabaseService.client
          .from('posts')
          .select()
          .or('id.eq.$postId,postId.eq.$postId,squadId.eq.$postId')
          .limit(1);

      if (postRows.isNotEmpty) {
        final data = postRows.first;
        final List<dynamic> members = List.from(data['members'] ?? []);
        members.remove(memberUid);
        final updatePayload = {
          'members': members,
          'membersCount': members.length,
          'members_count': members.length,
          'isActive': true,
          'is_active': true,
        };

        try {
          await SupabaseService.client.from('posts').update(updatePayload).or('id.eq.$postId,postId.eq.$postId');
        } catch (_) {}
        try {
          await SupabaseService.client.from('teams').update(updatePayload).or('id.eq.$postId,teamId.eq.$postId');
        } catch (_) {}
      }

      // System message in chat
      try {
        await SupabaseService.sendMatchChatMessage(
          matchId: postId,
          senderId: 'system',
          senderName: 'Squad Bot',
          message: '$memberName left the squad.',
          messageType: 'system',
        );
      } catch (_) {}

      // Notify leader
      if (leaderUid.isNotEmpty && leaderUid != memberUid) {
        try {
          await SupabaseService.client.from('notifications').insert({
            'recipientUid': leaderUid,
            'user_id': leaderUid,
            'senderUid': memberUid,
            'type': 'squad_leave',
            'title': 'Squad Update',
            'message': '$memberName left your squad.',
            'postId': postId,
            'post_id': postId,
            'read': false,
            'createdAt': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          });

          NotificationService().showSquadNotification(
            title: 'Squad Update',
            body: '$memberName left your squad.',
            postId: postId,
            recipientUid: leaderUid,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("[LfgService] LEAVE ERROR: $e");
      rethrow;
    }
  }

  /// Declines / rejects a request from lfg_posts subcollection
  Future<void> declineRequest({
    required String postId,
    required String requesterId,
    String? requestDocId,
  }) async {
    try {
      debugPrint("[LfgService] Declining request $requesterId for post $postId");
      await rejectRequest(
        postId: postId,
        requesterId: requesterId,
        requestDocId: requestDocId,
      );
      try {
        await _squadService.rejectSquadRequest(
          postId: postId,
          requestId: requestDocId ?? requesterId,
          userId: requesterId,
        );
      } catch (_) {}
      debugPrint("[LfgService] Successfully declined request $requesterId");
    } catch (e) {
      debugPrint("[LfgService] DECLINE ERROR: $e");
      rethrow;
    }
  }

  /// Close LFG: set isActive = false so post hides from feed
  Future<void> closeLfg(String postId) async {
    try {
      await SupabaseService.client
          .from('posts')
          .update({'isActive': false, 'is_active': false})
          .or('id.eq.$postId,postId.eq.$postId');
    } catch (_) {}
    try {
      await _squadService.closeSquadPost(postId);
    } catch (_) {}
  }

  /// Delete Permanently
  Future<void> deletePermanently(String postId, String postOwnerId) async {
    try {
      await SupabaseService.client
          .from('posts')
          .delete()
          .or('id.eq.$postId,postId.eq.$postId');
    } catch (_) {}
    try {
      await SupabaseService.client
          .from('teams')
          .delete()
          .or('id.eq.$postId,teamId.eq.$postId');
    } catch (_) {}
    try {
      await _squadService.deleteSquadPermanently(postId: postId, ownerId: postOwnerId);
    } catch (_) {}
  }
}
