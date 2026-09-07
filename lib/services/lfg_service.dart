import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'squad_service.dart';
import 'notification_service.dart';

/// LFG Service providing specialized transaction/batch-based request handling for lfg_posts
class LfgService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
      final postRef = _firestore.collection('lfg_posts').doc(postId);
      final squadRef = _firestore.collection('squads').doc(postId);

      final batch = _firestore.batch();
      batch.update(postRef, {
        'joinRequests': FieldValue.arrayUnion([currentUserId]),
        'requestedCount': FieldValue.increment(1),
      });

      batch.set(squadRef, {
        'joinRequests': FieldValue.arrayUnion([currentUserId]),
        'requestedCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (applicantData != null) {
        batch.set(postRef.collection('requests').doc(currentUserId), applicantData, SetOptions(merge: true));
        batch.set(squadRef.collection('requests').doc(currentUserId), applicantData, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint("JOIN REQUEST SUCCESS");

      if (leaderUid != null && leaderUid.isNotEmpty && leaderUid != currentUserId) {
        final applicantName = (applicantData?['displayName'] ?? applicantData?['name'] ?? 'A Gamer').toString();
        await _firestore.collection('notifications').add({
          'recipientUid': leaderUid,
          'senderUid': currentUserId,
          'type': 'squad_request',
          'title': 'New Squad Request 🎮',
          'message': '$applicantName requested to join your squad',
          'postId': postId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});

        NotificationService().showSquadNotification(
          title: 'New Squad Request 🎮',
          body: '$applicantName requested to join your squad',
          postId: postId,
          recipientUid: leaderUid,
        );
      }
    } catch (e, stack) {
      debugPrint("JOIN REQUEST FAILED: $e");
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// 2. On Accept (in owner account):
  /// if (members.length >= 4) throw "Full"
  /// batch.update(postRef, {
  ///   'joinRequests': FieldValue.arrayRemove([requesterId]),
  ///   'members': FieldValue.arrayUnion([requesterId]),
  ///   'requestedCount': FieldValue.increment(-1),
  ///   'membersCount': FieldValue.increment(1),
  ///   'isActive': true,
  /// });
  /// Also add security: if requestedCount < 0 then set to 0.
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

      final currentUid = _auth.currentUser?.uid;
      final postRef = _firestore.collection('lfg_posts').doc(postId);
      final squadRef = _firestore.collection('squads').doc(postId);

      // Verify post and owner permissions
      DocumentSnapshot postSnap = await postRef.get();
      if (!postSnap.exists) {
        final sSnap = await squadRef.get();
        if (sSnap.exists) {
          postSnap = sSnap;
        }
      }

      final data = postSnap.data() as Map<String, dynamic>? ?? {};
      final postOwnerId = (data['ownerId'] ?? data['userId'] ?? leaderUid).toString();
      if (currentUid != null && postOwnerId.isNotEmpty && currentUid != postOwnerId) {
        throw "Only owner can accept";
      }

      final int currentRequested = (data['requestedCount'] as num?)?.toInt() ?? 0;
      List<dynamic> members = List.from(data['members'] ?? []);
      if (members.isEmpty && postOwnerId.isNotEmpty) {
        members.add(postOwnerId);
      }

      // 1. If requester is owner: clean from joinRequests and return
      if (postOwnerId == requesterId) {
        debugPrint("[LfgService] Requester is post owner. Cleaning from joinRequests.");
        final batch = _firestore.batch();
        final safeCount = math.max(0, currentRequested - 1);
        final cleanMap = <String, dynamic>{
          'joinRequests': FieldValue.arrayRemove([requesterId, requestDocId]),
          'requestedCount': safeCount,
        };
        batch.update(postRef, cleanMap);
        batch.delete(postRef.collection('requests').doc(requestDocId));
        if (requestDocId != requesterId) {
          batch.delete(postRef.collection('requests').doc(requesterId));
        }
        batch.set(squadRef, cleanMap, SetOptions(merge: true));
        batch.delete(squadRef.collection('requests').doc(requestDocId));
        if (requestDocId != requesterId) {
          batch.delete(squadRef.collection('requests').doc(requesterId));
        }
        await batch.commit();
        return;
      }

      // 2. If requester is already in members: clean from joinRequests, decrement requestedCount, return
      if (members.contains(requesterId)) {
        debugPrint("[LfgService] Requester already in members. Cleaning from joinRequests.");
        final batch = _firestore.batch();
        final dynamic safeRequestedDecrement = (currentRequested <= 1) ? 0 : FieldValue.increment(-1);
        final cleanMap = <String, dynamic>{
          'joinRequests': FieldValue.arrayRemove([requesterId, requestDocId]),
          'requestedCount': safeRequestedDecrement,
        };
        batch.update(postRef, cleanMap);
        batch.delete(postRef.collection('requests').doc(requestDocId));
        if (requestDocId != requesterId) {
          batch.delete(postRef.collection('requests').doc(requesterId));
        }
        batch.set(squadRef, cleanMap, SetOptions(merge: true));
        batch.delete(squadRef.collection('requests').doc(requestDocId));
        if (requestDocId != requesterId) {
          batch.delete(squadRef.collection('requests').doc(requesterId));
        }
        await batch.commit();
        return;
      }

      // 3. Normal Accept: check capacity
      if (members.length >= 4) {
        throw "Full";
      }

      // Ensure requestedCount never goes below 0
      final dynamic safeRequestedDecrement = (currentRequested <= 1)
          ? 0
          : FieldValue.increment(-1);

      final bool isNowFull = (members.length + 1) >= 4;
      final batch = _firestore.batch();

      final updateMap = <String, dynamic>{
        'joinRequests': FieldValue.arrayRemove([requesterId, requestDocId]),
        'members': FieldValue.arrayUnion([requesterId]),
        'requestedCount': safeRequestedDecrement,
        'membersCount': FieldValue.increment(1),
        'isActive': !isNowFull,
      };

      // 1. Update in lfg_posts
      batch.update(postRef, updateMap);

      // 2. Delete request doc from subcollection using actual requestDocId
      final requestRef = postRef.collection('requests').doc(requestDocId);
      batch.delete(requestRef);
      if (requestDocId != requesterId) {
        batch.delete(postRef.collection('requests').doc(requesterId));
      }

      // 3. Mirror update in squads collection for consistency
      batch.set(squadRef, updateMap, SetOptions(merge: true));
      batch.delete(squadRef.collection('requests').doc(requestDocId));
      if (requestDocId != requesterId) {
        batch.delete(squadRef.collection('requests').doc(requesterId));
      }

      await batch.commit();
      debugPrint("ACCEPT SUCCESS - SQUAD NOW FULL: $isNowFull");

      // 4. Chat Room Creation: doc in chats/{postId} with members array
      try {
        final chatRef = _firestore.collection('chats').doc(postId);
        final Set<String> chatMembers = {...members.map((e) => e.toString()), requesterId};
        if (postOwnerId.isNotEmpty) chatMembers.add(postOwnerId);

        await chatRef.set({
          'postId': postId,
          'members': chatMembers.toList(),
          'leaderUid': postOwnerId,
          'title': data['displayName'] != null ? "${data['displayName']}'s Squad" : 'Squad Chat',
          'mode': mode,
          'inGameUid': inGameUid.isNotEmpty ? inGameUid : (data['inGameUid'] ?? ''),
          'lastMessage': '$requesterName joined the squad!',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Add welcome message in chat
        await chatRef.collection('messages').add({
          'senderUid': 'system',
          'senderName': 'Squad Bot',
          'text': '$requesterName joined the squad! Welcome to the team.',
          'type': 'system',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (ce) {
        debugPrint("[LfgService] Chat room creation error: $ce");
      }

      // 5. Send accepted push notification: "You joined {ownerName}'s squad"
      try {
        final ownerName = (data['displayName'] ?? data['username'] ?? 'Leader').toString();
        final notifMessage = 'You joined $ownerName\'s squad';

        await _firestore.collection('notifications').add({
          'recipientUid': requesterId,
          'senderUid': postOwnerId.isNotEmpty ? postOwnerId : (currentUid ?? ''),
          'type': 'squad_accepted',
          'title': 'Squad Request Accepted! 🎮',
          'message': notifMessage,
          'postId': postId,
          'inGameUid': inGameUid.isNotEmpty ? inGameUid : (data['inGameUid'] ?? ''),
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        NotificationService().showSquadNotification(
          title: 'Squad Request Accepted! 🎮',
          body: notifMessage,
          postId: postId,
          recipientUid: requesterId,
        );
      } catch (ne) {
        debugPrint("[LfgService] Notification send error: $ne");
      }
    } catch (e, stack) {
      debugPrint("ACCEPT FAILED: $e");
      debugPrint(stack.toString());
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
      final postRef = _firestore.collection('lfg_posts').doc(postId);
      final squadRef = _firestore.collection('squads').doc(postId);
      final chatRef = _firestore.collection('chats').doc(postId);

      final updateMap = <String, dynamic>{
        'members': FieldValue.arrayRemove([memberUid]),
        'membersCount': FieldValue.increment(-1),
        'isActive': true, // Re-open squad since a slot opened
      };

      final batch = _firestore.batch();
      batch.update(postRef, updateMap);
      batch.set(squadRef, updateMap, SetOptions(merge: true));
      batch.set(chatRef, {
        'members': FieldValue.arrayRemove([memberUid]),
      }, SetOptions(merge: true));
      await batch.commit();

      // System message in chat
      await chatRef.collection('messages').add({
        'senderUid': 'system',
        'senderName': 'Squad Bot',
        'text': '$memberName was removed from the squad.',
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});

      // Notify kicked player
      await _firestore.collection('notifications').add({
        'recipientUid': memberUid,
        'senderUid': leaderUid,
        'type': 'squad_kick',
        'title': 'Squad Update',
        'message': 'You were removed from the squad.',
        'postId': postId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});

      NotificationService().showSquadNotification(
        title: 'Squad Update',
        body: 'You were removed from the squad.',
        postId: postId,
        recipientUid: memberUid,
      );
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
      final postRef = _firestore.collection('lfg_posts').doc(postId);
      final squadRef = _firestore.collection('squads').doc(postId);
      final chatRef = _firestore.collection('chats').doc(postId);

      final updateMap = <String, dynamic>{
        'members': FieldValue.arrayRemove([memberUid]),
        'membersCount': FieldValue.increment(-1),
        'isActive': true, // Re-open squad since a slot opened
      };

      final batch = _firestore.batch();
      batch.update(postRef, updateMap);
      batch.set(squadRef, updateMap, SetOptions(merge: true));
      batch.set(chatRef, {
        'members': FieldValue.arrayRemove([memberUid]),
      }, SetOptions(merge: true));
      await batch.commit();

      // System message in chat
      await chatRef.collection('messages').add({
        'senderUid': 'system',
        'senderName': 'Squad Bot',
        'text': '$memberName left the squad.',
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});

      // Notify leader
      if (leaderUid.isNotEmpty && leaderUid != memberUid) {
        await _firestore.collection('notifications').add({
          'recipientUid': leaderUid,
          'senderUid': memberUid,
          'type': 'squad_leave',
          'title': 'Squad Update',
          'message': '$memberName left your squad.',
          'postId': postId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});

        NotificationService().showSquadNotification(
          title: 'Squad Update',
          body: '$memberName left your squad.',
          postId: postId,
          recipientUid: leaderUid,
        );
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
      await _squadService.rejectSquadRequest(
        postId: postId,
        requestId: requestDocId ?? requesterId,
        userId: requesterId,
      );
      debugPrint("[LfgService] Successfully declined request $requesterId");
    } catch (e) {
      debugPrint("[LfgService] DECLINE ERROR: $e");
      rethrow;
    }
  }
}
