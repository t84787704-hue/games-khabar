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

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (!snapshot.exists) {
          throw "Post does not exist";
        }
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        final ownerId = (data['ownerId'] ?? data['userId'] ?? '').toString();
        final List<dynamic> members = List.from(data['members'] ?? []);
        final List<dynamic> joinRequests = List.from(data['joinRequests'] ?? []);

        if (currentUserId == ownerId) {
          throw "You are owner";
        }
        if (members.length >= 4) {
          throw "Squad is full";
        }
        if (joinRequests.contains(currentUserId)) {
          return;
        }

        final int curRequested = (data['requestedCount'] as num?)?.toInt() ?? joinRequests.length;

        transaction.update(postRef, {
          'joinRequests': FieldValue.arrayUnion([currentUserId]),
          'requestedCount': curRequested + 1,
        });
      });

      // Mirror to squadRef & requests subcollections
      try {
        final batch = _firestore.batch();
        batch.set(squadRef, {
          'joinRequests': FieldValue.arrayUnion([currentUserId]),
          'requestedCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
        if (applicantData != null) {
          batch.set(postRef.collection('requests').doc(currentUserId), applicantData, SetOptions(merge: true));
          batch.set(squadRef.collection('requests').doc(currentUserId), applicantData, SetOptions(merge: true));
        }
        await batch.commit();
      } catch (_) {}

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
      final chatRef = _firestore.collection('chats').doc(postId);
      final squadRef = _firestore.collection('squads').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (!snapshot.exists) {
          throw "Post does not exist";
        }
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        final ownerId = (data['ownerId'] ?? data['userId'] ?? leaderUid).toString();
        if (currentUid != null && ownerId.isNotEmpty && currentUid != ownerId) {
          throw "Only owner can accept";
        }

        final List<dynamic> members = List.from(data['members'] ?? []);
        final List<dynamic> joinRequests = List.from(data['joinRequests'] ?? []);
        final int curReq = (data['requestedCount'] as num?)?.toInt() ?? joinRequests.length;
        final int safeRequestedCount = math.max(0, curReq - 1);

        // If requesterUid == ownerId: just remove from joinRequests, requestedCount--, return
        if (requesterId == ownerId) {
          transaction.update(postRef, {
            'joinRequests': FieldValue.arrayRemove([requesterId, requestDocId]),
            'requestedCount': safeRequestedCount,
          });
          return;
        }

        // If members.contains(requesterUid): remove from joinRequests, requestedCount--, return
        if (members.contains(requesterId)) {
          transaction.update(postRef, {
            'joinRequests': FieldValue.arrayRemove([requesterId, requestDocId]),
            'requestedCount': safeRequestedCount,
          });
          return;
        }

        // Normal accept
        if (members.length >= 4) {
          throw "Squad is full";
        }

        final int newMembersCount = members.length + 1;
        final bool isNowFull = newMembersCount >= 4;

        // lfg_posts update: arrayUnion members requesterUid, membersCount++, arrayRemove joinRequests requesterUid, requestedCount-- (if requestedCount <0 set 0)
        // If membersCount == 4 after accept: set isActive=false
        transaction.update(postRef, {
          'members': FieldValue.arrayUnion([requesterId]),
          'membersCount': newMembersCount,
          'joinRequests': FieldValue.arrayRemove([requesterId, requestDocId]),
          'requestedCount': safeRequestedCount,
          if (isNowFull) 'isActive': false,
        });

        // chats/{postId} update: if doc exists, arrayUnion members requesterUid, else create doc with members [ownerId, requesterUid]
        final chatSnap = await transaction.get(chatRef);
        if (chatSnap.exists) {
          transaction.update(chatRef, {
            'members': FieldValue.arrayUnion([requesterId]),
            'lastMessage': '$requesterName joined the squad!',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final Set<String> initialMembers = {ownerId, requesterId};
          initialMembers.remove('');
          transaction.set(chatRef, {
            'chatId': postId,
            'postId': postId,
            'members': initialMembers.toList(),
            'leaderUid': ownerId,
            'ownerId': ownerId,
            'title': data['ownerBgmiName'] ?? data['displayName'] != null ? "${data['ownerBgmiName'] ?? data['displayName']}'s Squad" : 'Squad Chat',
            'mode': mode.isNotEmpty ? mode : (data['mode'] ?? 'Classic Squad'),
            'inGameUid': inGameUid.isNotEmpty ? inGameUid : (data['bgmiUidToCopy'] ?? data['inGameUid'] ?? ''),
            'bgmiUidToCopy': inGameUid.isNotEmpty ? inGameUid : (data['bgmiUidToCopy'] ?? data['inGameUid'] ?? ''),
            'lastMessage': '$requesterName joined the squad!',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Cleanup subcollections & mirror to squadRef
      final actualDocId = requestDocId.isNotEmpty ? requestDocId : requesterId;
      postRef.collection('requests').doc(actualDocId).delete().catchError((_) {});
      if (actualDocId != requesterId) {
        postRef.collection('requests').doc(requesterId).delete().catchError((_) {});
      }
      squadRef.collection('requests').doc(actualDocId).delete().catchError((_) {});
      squadRef.set({
        'members': FieldValue.arrayUnion([requesterId]),
        'joinRequests': FieldValue.arrayRemove([requesterId, actualDocId]),
      }, SetOptions(merge: true)).catchError((_) {});

      // Add system message to chat messages subcollection
      chatRef.collection('messages').add({
        'senderId': 'system',
        'senderUid': 'system',
        'senderName': 'Squad Bot',
        'text': 'Welcome @$requesterName to the squad!',
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});

      // Send accepted notification
      try {
        final postSnap = await postRef.get();
        final data = postSnap.data() as Map<String, dynamic>? ?? {};
        final ownerName = (data['ownerBgmiName'] ?? data['displayName'] ?? data['username'] ?? 'Leader').toString();
        final notifMessage = "Your request to join $ownerName's squad was accepted! Tap to chat.";

        await _firestore.collection('notifications').add({
          'recipientUid': requesterId,
          'senderUid': leaderUid.isNotEmpty ? leaderUid : (currentUid ?? ''),
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

  /// Declines / rejects a request from lfg_posts using transaction
  Future<void> rejectRequest({
    required String postId,
    required String requesterId,
    String? requestDocId,
  }) async {
    try {
      debugPrint("START REJECT postId=$postId requesterId=$requesterId");
      final postRef = _firestore.collection('lfg_posts').doc(postId);
      final squadRef = _firestore.collection('squads').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (!snapshot.exists) return;
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        final List<dynamic> joinRequests = List.from(data['joinRequests'] ?? []);
        final int curReq = (data['requestedCount'] as num?)?.toInt() ?? joinRequests.length;
        final int safeCount = math.max(0, curReq - 1);

        transaction.update(postRef, {
          'joinRequests': FieldValue.arrayRemove([requesterId, if (requestDocId != null) requestDocId]),
          'requestedCount': safeCount,
        });
      });

      final actualDocId = requestDocId ?? requesterId;
      postRef.collection('requests').doc(actualDocId).delete().catchError((_) {});
      if (actualDocId != requesterId) {
        postRef.collection('requests').doc(requesterId).delete().catchError((_) {});
      }
      squadRef.collection('requests').doc(actualDocId).delete().catchError((_) {});
      squadRef.update({
        'joinRequests': FieldValue.arrayRemove([requesterId, actualDocId]),
        'requestedCount': FieldValue.increment(-1),
      }).catchError((_) {});
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

  /// Close LFG: set isActive = false so post hides from feed
  Future<void> closeLfg(String postId) async {
    await _squadService.closeSquadPost(postId);
  }

  /// Delete Permanently:
  /// Confirms ownerId == auth.uid
  /// Batch deletes chats/{postId}/messages
  /// Deletes chats/{postId}
  /// Batch deletes lfg_posts/{postId}/requests
  /// Deletes lfg_posts/{postId}
  /// Deletes squads/{postId}
  Future<void> deletePermanently(String postId, String postOwnerId) async {
    await _squadService.deleteSquadPermanently(postId: postId, ownerId: postOwnerId);
  }
}
