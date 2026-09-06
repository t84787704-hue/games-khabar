import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/squad_post_model.dart';

class SquadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _squadRef => _firestore.collection('squad_posts');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  Future<void> createSquadPost(SquadPost post) async {
    try {
      final doc = post.id.isNotEmpty ? _squadRef.doc(post.id) : _squadRef.doc();
      final finalPost = post.id.isEmpty ? post.copyWith(id: doc.id) : post;
      await doc.set(finalPost.toMap());
    } catch (_) {}
  }

  Stream<List<SquadPost>> getActiveSquadsStream() {
    return _squadRef
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SquadPost.fromFirestore(d)).toList());
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
    } catch (_) {}
  }

  Future<void> closeSquadPost(String postId) async {
    try {
      await _squadRef.doc(postId).update({'isActive': false});
    } catch (_) {}
  }

  Future<void> deleteSquadPost(String postId) async {
    try {
      await _squadRef.doc(postId).delete();
    } catch (_) {}
  }
}
