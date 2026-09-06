import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/squad_post_model.dart';

class SquadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Primary LFG collection
  CollectionReference get _squadRef => _firestore.collection('squads');
  CollectionReference get _legacySquadRef => _firestore.collection('squad_posts');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  Future<void> createSquadPost(SquadPost post) async {
    try {
      final doc = post.id.isNotEmpty ? _squadRef.doc(post.id) : _squadRef.doc();
      final finalPost = post.id.isEmpty ? post.copyWith(id: doc.id) : post;
      final data = finalPost.toMap();
      await doc.set(data);
      // Also mirror to legacy collection for backward compatibility
      try {
        await _legacySquadRef.doc(doc.id).set(data);
      } catch (_) {}
      debugPrint('[SquadService] Successfully created squad post doc ${doc.id}');
    } catch (e, st) {
      debugPrint('[SquadService] Error creating squad post: $e\n$st');
      rethrow;
    }
  }

  Stream<List<SquadPost>> getActiveSquadsStream() {
    // Firestore query: collection('squads').orderBy('createdAt', descending: true)
    // No where filter for Tier/K/D or isActive so query runs without needing complex composite indexes
    return _squadRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      debugPrint('[SquadService] Fetched squads docs length from Firestore: ${snap.docs.length}');
      return snap.docs.map((d) => SquadPost.fromFirestore(d)).toList();
    });
  }

  Future<List<SquadPost>> fetchSquadsOnce() async {
    try {
      final snap = await _squadRef.orderBy('createdAt', descending: true).get();
      debugPrint('[SquadService] One-time fetched squads docs length: ${snap.docs.length}');
      return snap.docs.map((d) => SquadPost.fromFirestore(d)).toList();
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
  }) async {
    try {
      await _squadRef.doc(postId).update({
        'joinRequests': FieldValue.arrayUnion([applicantUid]),
      });
      try {
        await _legacySquadRef.doc(postId).update({
          'joinRequests': FieldValue.arrayUnion([applicantUid]),
        });
      } catch (_) {}

      if (leaderUid != applicantUid) {
        await _notificationsRef.add({
          'recipientUid': leaderUid,
          'senderUid': applicantUid,
          'type': 'squad_request',
          'message': 'requested to join your Squad!',
          'postId': postId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[SquadService] Error requesting join: $e');
    }
  }

  Future<void> closeSquadPost(String postId) async {
    try {
      await _squadRef.doc(postId).update({'isActive': false});
      try {
        await _legacySquadRef.doc(postId).update({'isActive': false});
      } catch (_) {}
      debugPrint('[SquadService] Closed squad post $postId');
    } catch (e) {
      debugPrint('[SquadService] Error closing squad post: $e');
    }
  }

  Future<void> deleteSquadPost(String postId) async {
    try {
      await _squadRef.doc(postId).delete();
      try {
        await _legacySquadRef.doc(postId).delete();
      } catch (_) {}
      debugPrint('[SquadService] Deleted squad post $postId');
    } catch (e) {
      debugPrint('[SquadService] Error deleting squad post: $e');
    }
  }
}

