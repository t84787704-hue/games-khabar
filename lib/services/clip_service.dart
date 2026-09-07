import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/clip_model.dart';
import 'cloudinary_service.dart';

class ClipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  CollectionReference get _clipsRef => _firestore.collection('gamer_clips');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  /// Uploads a media file (screen recording video or gameplay image) directly to Cloudinary
  /// and returns the HTTPS secure_url. (Zero Firebase Storage usage).
  Future<String> uploadClipMedia({
    required File file,
    required String userId,
    String? customFileName,
    bool isVideo = true,
  }) async {
    try {
      final cleanName = customFileName?.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_') ??
          'clip_${DateTime.now().millisecondsSinceEpoch}';
      final publicId = '${userId}_${DateTime.now().millisecondsSinceEpoch}_$cleanName';

      final secureUrl = await _cloudinaryService.uploadMedia(
        file: file,
        isVideo: isVideo,
        customPublicId: publicId,
      );

      return secureUrl;
    } catch (e) {
      debugPrint('ClipService.uploadClipMedia failed: $e');
      rethrow;
    }
  }

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
