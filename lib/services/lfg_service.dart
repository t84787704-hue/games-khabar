import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/squad_post_model.dart';
import '../models/squad_request_model.dart';
import 'squad_service.dart';

/// LFG Service providing specialized transaction-based request handling for lfg_posts
class LfgService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SquadService _squadService = SquadService();

  static final LfgService _instance = LfgService._internal();
  factory LfgService() => _instance;
  LfgService._internal();

  /// Accepts a request from lfg_posts subcollection using a transaction as requested
  Future<void> acceptRequest({
    required String postId,
    required String requesterId,
    String requesterName = 'Gamer',
    String leaderUid = '',
    String inGameUid = '',
    String mode = 'Classic Squad',
  }) async {
    try {
      debugPrint("[LfgService] Starting acceptRequest for $requesterName ($requesterId) on post $postId");

      // Check both 'lfg_posts' and 'squads' collections
      final postRef = _firestore.collection('lfg_posts').doc(postId);
      final squadRef = _firestore.collection('squads').doc(postId);

      await _firestore.runTransaction((tx) async {
        DocumentSnapshot postSnap = await tx.get(postRef);
        DocumentReference activeRef = postRef;

        if (!postSnap.exists) {
          // Check squads collection if not found in lfg_posts
          final squadSnap = await tx.get(squadRef);
          if (squadSnap.exists) {
            postSnap = squadSnap;
            activeRef = squadRef;
          } else {
            // If neither exists yet (e.g. test post or mocked ID), initialize it
            tx.set(postRef, {
              'id': postId,
              'userId': leaderUid.isNotEmpty ? leaderUid : 'leader',
              'members': [leaderUid.isNotEmpty ? leaderUid : 'leader', requesterId],
              'membersCount': 2,
              'requestedCount': 0,
              'joinRequests': [],
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            return;
          }
        }

        final data = postSnap.data() as Map<String, dynamic>? ?? {};
        List<dynamic> members = List.from(data['members'] ?? []);
        
        if (members.isEmpty) {
          final ownerId = data['userId']?.toString() ?? leaderUid;
          if (ownerId.isNotEmpty) {
            members.add(ownerId);
          }
        }

        if (members.length >= 4) {
          throw "Squad Full";
        }
        if (members.contains(requesterId)) {
          throw "Already in squad";
        }

        final updateData = {
          'members': FieldValue.arrayUnion([requesterId]),
          'joinRequests': FieldValue.arrayRemove([requesterId]),
          'membersCount': FieldValue.increment(1),
          'requestedCount': FieldValue.increment(-1),
        };

        // Update in active collection
        tx.update(activeRef, updateData);

        // Also update the other collection for sync if it exists
        if (activeRef == postRef) {
          tx.set(squadRef, {
            'members': FieldValue.arrayUnion([requesterId]),
            'joinRequests': FieldValue.arrayRemove([requesterId]),
            'membersCount': FieldValue.increment(1),
            'requestedCount': FieldValue.increment(-1),
          }, SetOptions(merge: true));
        } else {
          tx.set(postRef, {
            'members': FieldValue.arrayUnion([requesterId]),
            'joinRequests': FieldValue.arrayRemove([requesterId]),
            'membersCount': FieldValue.increment(1),
            'requestedCount': FieldValue.increment(-1),
          }, SetOptions(merge: true));
        }

        // Delete request doc from subcollections
        final requestRefLfg = postRef.collection('requests').doc(requesterId);
        final requestRefSquad = squadRef.collection('requests').doc(requesterId);
        tx.delete(requestRefLfg);
        tx.delete(requestRefSquad);
      });

      // Send accepted notification outside transaction
      try {
        await _firestore.collection('notifications').add({
          'recipientUid': requesterId,
          'senderUid': leaderUid,
          'type': 'squad_accepted',
          'message': 'accepted your request to join squad ($mode)! Leader BGMI UID: $inGameUid',
          'postId': postId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (ne) {
        debugPrint("[LfgService] Notification send error: $ne");
      }

      debugPrint("[LfgService] Accepted $requesterName to $postId");
    } catch (e) {
      debugPrint("[LfgService] ACCEPT ERROR: $e");
      rethrow;
    }
  }

  /// Declines / rejects a request from lfg_posts subcollection
  Future<void> declineRequest({
    required String postId,
    required String requesterId,
  }) async {
    try {
      debugPrint("[LfgService] Declining request $requesterId for post $postId");
      await _squadService.rejectSquadRequest(
        postId: postId,
        requestId: requesterId,
        userId: requesterId,
      );
      debugPrint("[LfgService] Successfully declined request $requesterId");
    } catch (e) {
      debugPrint("[LfgService] DECLINE ERROR: $e");
      rethrow;
    }
  }
}
