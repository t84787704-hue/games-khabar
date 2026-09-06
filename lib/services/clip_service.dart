import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clip_model.dart';

class ClipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _clipsRef => _firestore.collection('gamer_clips');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  Future<void> uploadClip(GamerClip clip) async {
    try {
      final doc = clip.id.isNotEmpty ? _clipsRef.doc(clip.id) : _clipsRef.doc();
      final finalClip = clip.id.isEmpty ? clip.copyWith(id: doc.id) : clip;
      await doc.set(finalClip.toMap());
    } catch (_) {}
  }

  Stream<List<GamerClip>> getClipsStream() {
    return _clipsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GamerClip.fromFirestore(d)).toList());
  }

  Future<void> toggleLikeClip({
    required String clipId,
    required String userId,
    required String authorId,
  }) async {
    try {
      final doc = await _clipsRef.doc(clipId).get();
      if (!doc.exists) return;
      final clip = GamerClip.fromFirestore(doc);
      final isLiked = clip.likedBy.contains(userId);

      if (isLiked) {
        await _clipsRef.doc(clipId).update({
          'likedBy': FieldValue.arrayRemove([userId]),
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        await _clipsRef.doc(clipId).update({
          'likedBy': FieldValue.arrayUnion([userId]),
          'likesCount': FieldValue.increment(1),
        });

        if (authorId != userId) {
          await _notificationsRef.add({
            'recipientUid': authorId,
            'senderUid': userId,
            'type': 'like',
            'message': 'liked your gaming clip!',
            'clipId': clipId,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {}
  }

  Future<void> addComment({
    required String clipId,
    required String userId,
    required String username,
    required String text,
  }) async {
    try {
      await _clipsRef.doc(clipId).collection('comments').add({
        'userId': userId,
        'username': username,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _clipsRef.doc(clipId).update({
        'commentsCount': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  Stream<QuerySnapshot> getClipComments(String clipId) {
    return _clipsRef
        .doc(clipId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
