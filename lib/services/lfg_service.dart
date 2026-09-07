import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/squad_post_model.dart';
import '../models/squad_request_model.dart';
import 'squad_service.dart';

/// LFG Service providing specialized transaction-based request handling for lfg_posts
class LfgService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SquadService _squadService = SquadService();

  static final LfgService _instance = LfgService._internal();
  factory LfgService() => _instance;
  LfgService._internal();

  /// Accepts a request from lfg_posts subcollection using Batch + proper logging
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
      // Use the actual requestDocId passed from bottom sheet, NOT requesterId
      final requestRef = postRef.collection('requests').doc(requestDocId);

      // Security check: verify owner
      final postSnap = await postRef.get();
      if (postSnap.exists) {
        final data = postSnap.data() as Map<String, dynamic>? ?? {};
        final postOwnerId = (data['ownerId'] ?? data['userId'] ?? leaderUid).toString();
        if (currentUid != null && postOwnerId.isNotEmpty && currentUid != postOwnerId) {
          throw "Only owner can accept";
        }
      }

      final batch = _firestore.batch();
      batch.update(postRef, {
        'members': FieldValue.arrayUnion([requesterId]),
        'joinRequests': FieldValue.arrayRemove([requesterId, requestDocId]),
        'membersCount': FieldValue.increment(1),
        'requestedCount': FieldValue.increment(-1),
      });
      batch.delete(requestRef);

      // Also clean up in squads collection if exists to keep collections in sync
      final squadRef = _firestore.collection('squads').doc(postId);
      final squadRequestRef = squadRef.collection('requests').doc(requestDocId);
      batch.set(squadRef, {
        'members': FieldValue.arrayUnion([requesterId]),
        'joinRequests': FieldValue.arrayRemove([requesterId, requestDocId]),
        'membersCount': FieldValue.increment(1),
        'requestedCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));
      batch.delete(squadRequestRef);

      // If doc id != requesterId, also attempt delete by requesterId just in case
      if (requestDocId != requesterId) {
        batch.delete(postRef.collection('requests').doc(requesterId));
        batch.delete(squadRef.collection('requests').doc(requesterId));
      }

      await batch.commit();
      debugPrint("ACCEPT SUCCESS");

      // Send accepted notification
      try {
        await _firestore.collection('notifications').add({
          'recipientUid': requesterId,
          'senderUid': leaderUid.isNotEmpty ? leaderUid : (currentUid ?? ''),
          'type': 'squad_accepted',
          'message': 'accepted your request to join squad ($mode)! Leader BGMI UID: $inGameUid',
          'postId': postId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (ne) {
        debugPrint("[LfgService] Notification send error: $ne");
      }
    } catch (e, stack) {
      debugPrint("ACCEPT FAILED: $e");
      debugPrint(stack.toString());
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
