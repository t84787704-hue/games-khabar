import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/squad_post_model.dart';
import '../models/squad_request_model.dart';
import 'gamer_auth_service.dart';
import 'supabase_service.dart';

class SquadService {
  /// Disabled auto-repair/auto-create to prevent duplicate posts
  Future<void> repairBrokenSquads([String? specificSquadId]) async {
    // Intentionally no-op: LFG posts must ONLY be created when user taps NEED SQUAD button.
  }

  /// Disabled auto-create cleanup to prevent duplicate posts
  Future<void> cleanupCorruptedPosts([String? currentAuthUid]) async {
    // Intentionally no-op: No automatic creation
  }

  bool isCreating = false;

  Future<void> createSquad({
    String? squadId,
    SquadPost? post,
    String? title,
    String? mode,
    String? inGameUid,
    String? description,
    String? tier,
    double? kd,
    bool? micOn,
    String? language,
  }) async {
    if (isCreating) return;
    isCreating = true;

    try {
      final user = SupabaseService.client.auth.currentUser;
      final currentUid = user?.id ?? GamerAuthService().currentUid;
      if (currentUid == null || currentUid.isEmpty) return;

      final now = DateTime.now();

      // 1. Pehle check karo kahin pehle se to squad nahi hai
      try {
        final existing = await SupabaseService.client
            .from('lfg_posts')
            .select()
            .or('id.eq.$currentUid,userId.eq.$currentUid,hostId.eq.$currentUid')
            .eq('isActive', true)
            .limit(1);

        if (existing.isNotEmpty) {
          debugPrint("Squad pehle se hai in lfg_posts");
          isCreating = false;
          return;
        }
      } catch (_) {}

      // 2. Ab PARENT document banao - Use currentUid as default doc ID
      final String sId = (squadId != null && squadId.isNotEmpty) ? squadId : currentUid;
      final cleanMembers = [currentUid];

      final Map<String, dynamic> docData = {
        'id': sId,
        'squadId': sId,
        'chatId': sId,
        'postId': sId,
        'hostId': currentUid,
        'userId': currentUid,
        'ownerId': currentUid,
        'leaderUid': currentUid,
        'hostEmail': user?.email ?? '',
        'ownerEmail': user?.email ?? '',
        'createdAt': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'members': cleanMembers,
        'memberCount': 1,
        'membersCount': 1,
        'isActive': true,
        'title': title ?? post?.displayName ?? "${post?.username ?? 'Gamer'}'s Squad",
        'displayName': title ?? post?.displayName ?? "${post?.username ?? 'Gamer'}'s Squad",
        'username': post?.username ?? 'gamer',
        'ownerTag': post?.username ?? 'gamer',
        'userAvatar': post?.userAvatar ?? '',
        'avatar': post?.userAvatar ?? '',
        'userRank': tier ?? post?.userRank ?? 'Ace',
        'tier': tier ?? post?.tierNeeded ?? 'Ace+',
        'tierNeeded': tier ?? post?.tierNeeded ?? 'Ace+',
        'kd': kd ?? post?.kdNeeded ?? 3.0,
        'kdNeeded': kd ?? post?.kdNeeded ?? 3.0,
        'micMandatory': micOn ?? post?.micOn ?? true,
        'micOn': micOn ?? post?.micOn ?? true,
        'lang': language ?? post?.language ?? 'Hindi',
        'language': language ?? post?.language ?? 'Hindi',
        'mode': mode ?? post?.mode ?? 'Classic Squad',
        'description': description ?? post?.description ?? 'Looking for active teammates!',
        'bgmiUid': inGameUid ?? post?.inGameUid ?? '',
        'inGameUid': inGameUid ?? post?.inGameUid ?? '',
        'bgmiUidToCopy': inGameUid ?? post?.inGameUid ?? '',
        'joinRequests': <String>[],
        'requestedCount': 0,
        'lastMessage': 'Squad created!',
        'lastMessageTime': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Upsert to lfg_posts and squads
      try {
        await SupabaseService.client.from('lfg_posts').upsert(docData);
      } catch (e) {
        debugPrint('[SquadService] lfg_posts save error: $e');
      }
      try {
        await SupabaseService.client.from('squads').upsert(docData);
      } catch (e) {
        debugPrint('[SquadService] squads save error: $e');
      }

      // Sync room to Supabase rooms and room_members table
      try {
        await SupabaseService.saveRoom({
          'room_id': sId,
          'title': title ?? post?.displayName ?? "${post?.username ?? 'Gamer'}'s Squad",
          'game': 'PUBG Mobile',
          'mode': mode ?? post?.mode ?? 'Classic Squad',
          'host_id': currentUid,
          'host_name': post?.username ?? 'gamer',
          'max_players': 4,
          'current_players': 1,
          'status': 'Open',
          'created_at': now.toIso8601String(),
        });
        await SupabaseService.addRoomMember({
          'room_id': sId,
          'user_id': currentUid,
          'username': post?.username ?? 'gamer',
          'joined_at': now.toIso8601String(),
        });
      } catch (_) {}

      // Initial message
      try {
        await SupabaseService.client.from('messages').insert({
          'squad_id': sId,
          'chat_id': sId,
          'room_id': sId,
          'text': 'Squad created!',
          'senderId': currentUid,
          'senderUid': currentUid,
          'timestamp': now.toIso8601String(),
          'created_at': now.toIso8601String(),
        });
      } catch (_) {}

    } finally {
      isCreating = false;
    }
  }

  /// Backward-compatible method
  Future<void> createSquadPost(SquadPost post) async {
    await createSquad(
      squadId: post.id,
      post: post,
      title: post.displayName,
      mode: post.mode,
      inGameUid: post.inGameUid,
      description: post.description,
      tier: post.tierNeeded,
      kd: post.kdNeeded,
      micOn: post.micOn,
      language: post.language,
    );
  }

  /// Real-time stream of all posts where isActive == true (and owner's posts regardless of isActive)
  Stream<List<SquadPost>> getActiveSquadsStream() {
    try {
      return SupabaseService.client
          .from('lfg_posts')
          .stream(primaryKey: ['id'])
          .map((rows) {
        final currentUid = GamerAuthService().currentUid ??
            SupabaseService.client.auth.currentUser?.id ??
            '';
        final now = DateTime.now();
        final List<SquadPost> result = [];

        for (final row in rows) {
          final post = SquadPost.fromFirestore(row);
          final isOwner = currentUid.isNotEmpty &&
              (post.ownerId == currentUid || post.userId == currentUid);

          // Auto-expire: if post is older than 2 hours and isActive==true
          if (post.createdAt != null &&
              now.difference(post.createdAt!).inHours >= 2 &&
              post.isActive) {
            SupabaseService.client
                .from('lfg_posts')
                .update({'isActive': false, 'is_active': false})
                .eq('id', post.id)
                .catchError((_) {});
            if (!isOwner) continue;
          }

          if ((post.membersCount >= 4 || post.members.length >= 4) && post.isActive) {
            SupabaseService.client
                .from('lfg_posts')
                .update({'isActive': false, 'is_active': false})
                .eq('id', post.id)
                .catchError((_) {});
          }

          if (post.isActive || isOwner) {
            result.add(post);
          }
        }

        result.sort((a, b) {
          final aTime = a.createdAt ?? DateTime(1970);
          final bTime = b.createdAt ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

        return result;
      });
    } catch (e) {
      debugPrint('[SquadService] getActiveSquadsStream error: $e');
      return Stream.value([]);
    }
  }

  Future<List<SquadPost>> fetchSquadsOnce() async {
    try {
      final rows = await SupabaseService.client
          .from('lfg_posts')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final currentUid = GamerAuthService().currentUid ??
          SupabaseService.client.auth.currentUser?.id ??
          '';
      final now = DateTime.now();
      final List<SquadPost> result = [];

      for (final r in rows) {
        final p = SquadPost.fromFirestore(r);
        final isOwner = currentUid.isNotEmpty &&
            (p.ownerId == currentUid || p.userId == currentUid);

        if (p.createdAt != null && now.difference(p.createdAt!).inHours >= 2 && p.isActive) {
          SupabaseService.client
              .from('lfg_posts')
              .update({'isActive': false, 'is_active': false})
              .eq('id', p.id)
              .catchError((_) {});
          if (!isOwner) continue;
        }

        if (p.isActive || isOwner) {
          result.add(p);
        }
      }

      result.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      return result;
    } catch (e) {
      debugPrint('[SquadService] Error fetching squads once: $e');
      return [];
    }
  }

  Future<void> requestJoinSquad({
    required String postId,
    required String leaderUid,
    required String applicantUid,
    required String applicantName,
    String applicantUsername = '',
    String applicantAvatar = '',
    String applicantTier = 'Ace',
    double applicantKd = 3.0,
    String applicantGameId = '',
  }) async {
    try {
      final gamer = GamerAuthService().currentGamer;
      final effectiveName = applicantName.isNotEmpty
          ? applicantName
          : (gamer?.displayName.isNotEmpty == true ? gamer!.displayName : 'Gamer');
      final effectiveUsername = applicantUsername.isNotEmpty
          ? applicantUsername
          : (gamer?.username ?? '');
      final effectiveAvatar = applicantAvatar.isNotEmpty
          ? applicantAvatar
          : (gamer?.photoUrl ?? '');
      final effectiveTier = applicantTier.isNotEmpty
          ? applicantTier
          : (gamer?.rank ?? 'Ace');
      final effectiveKd = applicantKd > 0
          ? applicantKd
          : (gamer?.kdRatio ?? 3.0);
      final effectiveGameId = applicantGameId.isNotEmpty
          ? applicantGameId
          : (gamer?.gameId ?? '');

      final now = DateTime.now();
      final reqId = '${postId}_$applicantUid';

      final reqData = {
        'id': reqId,
        'postId': postId,
        'post_id': postId,
        'userId': applicantUid,
        'user_id': applicantUid,
        'applicantUid': applicantUid,
        'name': effectiveName,
        'displayName': effectiveName,
        'username': effectiveUsername,
        'userAvatar': effectiveAvatar,
        'photoUrl': effectiveAvatar,
        'tier': effectiveTier,
        'userRank': effectiveTier,
        'kd': effectiveKd,
        'kdRatio': effectiveKd,
        'inGameUid': effectiveGameId,
        'gameId': effectiveGameId,
        'status': 'pending',
        'createdAt': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      // 1. Write to squad_requests table in Supabase
      try {
        await SupabaseService.client.from('squad_requests').upsert(reqData);
      } catch (e) {
        debugPrint('[SquadService] squad_requests save notice: $e');
      }

      // 2. Fetch post to append joinRequests and increment requestedCount
      try {
        final existingPost = await SupabaseService.client
            .from('lfg_posts')
            .select('joinRequests, requestedCount')
            .eq('id', postId)
            .maybeSingle();

        List<dynamic> currentRequests = [];
        int currentCount = 0;
        if (existingPost != null) {
          currentRequests = List.from(existingPost['joinRequests'] ?? []);
          currentCount = (existingPost['requestedCount'] as num?)?.toInt() ?? 0;
        }

        if (!currentRequests.contains(applicantUid)) {
          currentRequests.add(applicantUid);
          currentCount += 1;
        }

        await SupabaseService.client.from('lfg_posts').update({
          'joinRequests': currentRequests,
          'requestedCount': currentCount,
          'updated_at': now.toIso8601String(),
        }).eq('id', postId);

        await SupabaseService.client.from('squads').update({
          'joinRequests': currentRequests,
          'requestedCount': currentCount,
          'updated_at': now.toIso8601String(),
        }).eq('id', postId);
      } catch (e) {
        debugPrint('[SquadService] joinRequests sync notice: $e');
      }

      // 3. Send notification to squad leader
      if (leaderUid != applicantUid && leaderUid.isNotEmpty) {
        try {
          await SupabaseService.sendNotification({
            'recipientUid': leaderUid,
            'recipient_id': leaderUid,
            'senderUid': applicantUid,
            'sender_id': applicantUid,
            'type': 'squad_request',
            'title': 'New Squad Request! 🎮',
            'message': '$effectiveName requested to join your Squad!',
            'body': '$effectiveName requested to join your Squad!',
            'postId': postId,
            'post_id': postId,
            'read': false,
            'created_at': now.toIso8601String(),
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SquadService] Error requesting join: $e');
    }
  }

  /// Real-time stream of all requests for postId
  Stream<List<SquadJoinRequest>> getSquadRequestsStream(
    String postId, [
    List<String>? initialJoinRequests,
  ]) {
    try {
      return SupabaseService.client
          .from('squad_requests')
          .stream(primaryKey: ['id'])
          .map((rows) {
        final matching = rows.where((r) =>
            (r['postId'] ?? r['post_id'])?.toString() == postId);

        final list = matching.map((r) => SquadJoinRequest.fromMap(r)).toList();
        list.sort((a, b) {
          final tA = a.createdAt ?? DateTime(1970);
          final tB = b.createdAt ?? DateTime(1970);
          return tB.compareTo(tA);
        });
        return list;
      });
    } catch (e) {
      debugPrint('[SquadService] getSquadRequestsStream notice: $e');
      return Stream.value([]);
    }
  }

  /// Accept join request: add to squad members, delete request doc, send notification
  Future<void> acceptSquadRequest({
    required String postId,
    required SquadJoinRequest request,
    required SquadPost squad,
  }) async {
    try {
      debugPrint('[SquadService] acceptSquadRequest: postId=$postId, requesterId=${request.userId}');

      final currentUid = GamerAuthService().currentUid;
      if (currentUid != null && currentUid != squad.userId && currentUid != squad.ownerId) {
        throw "Only owner can accept";
      }

      final now = DateTime.now();

      // 1. Fetch current members
      final postRow = await SupabaseService.client
          .from('lfg_posts')
          .select('members, joinRequests, requestedCount')
          .eq('id', postId)
          .maybeSingle();

      List<dynamic> members = [];
      List<dynamic> joinReqs = [];
      int reqCount = 0;

      if (postRow != null) {
        members = List.from(postRow['members'] ?? []);
        joinReqs = List.from(postRow['joinRequests'] ?? []);
        reqCount = (postRow['requestedCount'] as num?)?.toInt() ?? 0;
      }
      if (members.isEmpty) {
        members.add(squad.userId);
      }

      if (members.contains(request.userId)) {
        joinReqs.remove(request.userId);
        joinReqs.remove(request.id);
        reqCount = reqCount <= 1 ? 0 : reqCount - 1;
        await SupabaseService.client.from('lfg_posts').update({
          'joinRequests': joinReqs,
          'requestedCount': reqCount,
        }).eq('id', postId);
        return;
      }

      if (members.length >= 4) {
        throw "Squad Full";
      }

      members.add(request.userId);
      joinReqs.remove(request.userId);
      joinReqs.remove(request.id);
      reqCount = reqCount <= 1 ? 0 : reqCount - 1;

      final updateMap = {
        'members': members,
        'joinRequests': joinReqs,
        'membersCount': members.length,
        'memberCount': members.length,
        'requestedCount': reqCount,
        'isActive': true,
        'updated_at': now.toIso8601String(),
      };

      await SupabaseService.client.from('lfg_posts').update(updateMap).eq('id', postId);
      await SupabaseService.client.from('squads').update(updateMap).eq('id', postId);

      // Delete from squad_requests
      try {
        await SupabaseService.client
            .from('squad_requests')
            .delete()
            .or('id.eq.${request.id},id.eq.${postId}_${request.userId}');
      } catch (_) {}

      // Add as room member in Supabase
      try {
        await SupabaseService.addRoomMember({
          'room_id': postId,
          'user_id': request.userId,
          'username': request.name,
          'joined_at': now.toIso8601String(),
        });
      } catch (_) {}

      // Send notification to applicant
      try {
        await SupabaseService.sendNotification({
          'recipientUid': request.userId,
          'recipient_id': request.userId,
          'senderUid': squad.userId,
          'sender_id': squad.userId,
          'type': 'squad_accepted',
          'title': 'Squad Request Accepted! 🎮',
          'message': 'accepted your request to join squad (${squad.mode})! Leader BGMI UID: ${squad.inGameUid}',
          'body': 'accepted your request to join squad (${squad.mode})! Leader BGMI UID: ${squad.inGameUid}',
          'postId': postId,
          'post_id': postId,
          'read': false,
          'created_at': now.toIso8601String(),
        });
      } catch (_) {}

      debugPrint('[SquadService] Successfully accepted squad request ${request.id} for post $postId');
    } catch (e) {
      debugPrint('[SquadService] Error accepting squad request: $e');
      rethrow;
    }
  }

  /// Reject join request
  Future<void> rejectSquadRequest({
    required String postId,
    required String requestId,
    required String userId,
  }) async {
    try {
      final now = DateTime.now();

      // Delete from squad_requests
      try {
        await SupabaseService.client
            .from('squad_requests')
            .delete()
            .or('id.eq.$requestId,id.eq.${postId}_$userId');
      } catch (_) {}

      // Update lfg_posts
      try {
        final postRow = await SupabaseService.client
            .from('lfg_posts')
            .select('joinRequests, requestedCount')
            .eq('id', postId)
            .maybeSingle();

        if (postRow != null) {
          final List<dynamic> joinReqs = List.from(postRow['joinRequests'] ?? []);
          joinReqs.remove(userId);
          joinReqs.remove(requestId);
          int reqCount = (postRow['requestedCount'] as num?)?.toInt() ?? 0;
          reqCount = reqCount <= 1 ? 0 : reqCount - 1;

          await SupabaseService.client.from('lfg_posts').update({
            'joinRequests': joinReqs,
            'requestedCount': reqCount,
            'updated_at': now.toIso8601String(),
          }).eq('id', postId);

          await SupabaseService.client.from('squads').update({
            'joinRequests': joinReqs,
            'requestedCount': reqCount,
            'updated_at': now.toIso8601String(),
          }).eq('id', postId);
        }
      } catch (_) {}

      debugPrint('[SquadService] Successfully rejected squad request $requestId');
    } catch (e) {
      debugPrint('[SquadService] Error rejecting squad request: $e');
      rethrow;
    }
  }

  Future<void> closeSquadPost(String postId) async {
    try {
      final now = DateTime.now();
      await SupabaseService.client
          .from('lfg_posts')
          .update({'isActive': false, 'is_active': false, 'updated_at': now.toIso8601String()})
          .eq('id', postId);

      await SupabaseService.client
          .from('squads')
          .update({'isActive': false, 'is_active': false, 'updated_at': now.toIso8601String()})
          .eq('id', postId);

      debugPrint('[SquadService] Closed squad post $postId');
    } catch (e) {
      debugPrint('[SquadService] Error closing squad post: $e');
    }
  }

  /// Delete Permanently
  Future<void> deleteSquadPermanently({required String postId, required String ownerId}) async {
    final currentUid = GamerAuthService().currentUid ??
        SupabaseService.client.auth.currentUser?.id;
    if (currentUid == null || (currentUid != ownerId && ownerId.isNotEmpty)) {
      throw 'Only the squad leader can permanently delete this squad.';
    }

    try {
      // 1. Delete messages
      try {
        await SupabaseService.client
            .from('messages')
            .delete()
            .or('squad_id.eq.$postId,chat_id.eq.$postId,room_id.eq.$postId');
      } catch (_) {}

      // 2. Delete squad requests
      try {
        await SupabaseService.client
            .from('squad_requests')
            .delete()
            .or('postId.eq.$postId,post_id.eq.$postId');
      } catch (_) {}

      // 3. Delete from lfg_posts and squads
      await SupabaseService.client.from('lfg_posts').delete().eq('id', postId);
      await SupabaseService.client.from('squads').delete().eq('id', postId);

      debugPrint('[SquadService] Permanently deleted squad post $postId');
    } catch (e) {
      debugPrint('[SquadService] Error deleting squad permanently: $e');
      rethrow;
    }
  }

  Future<void> deleteSquadPost(String postId) async {
    try {
      await SupabaseService.client.from('lfg_posts').delete().eq('id', postId);
      await SupabaseService.client.from('squads').delete().eq('id', postId);
      debugPrint('[SquadService] Deleted squad post $postId');
    } catch (e) {
      debugPrint('[SquadService] Error deleting squad post: $e');
    }
  }
}
