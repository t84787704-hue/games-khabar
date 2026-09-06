import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/clip_model.dart';

class ClipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _clipsRef => _firestore.collection('gamer_clips');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  /// Uploads a media file (screen recording video or gameplay image) to Firebase Storage
  /// and returns the download URL.
  Future<String> uploadClipMedia({
    required File file,
    required String userId,
    String? customFileName,
    bool isVideo = false,
  }) async {
    try {
      final cleanName = customFileName?.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_') ??
          'clip_${DateTime.now().millisecondsSinceEpoch}';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      final storageRef = _storage.ref().child('gamer_clips').child(userId).child(fileName);

      final lowerPath = file.path.toLowerCase();
      String contentType = 'video/mp4';
      if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      } else if (lowerPath.endsWith('.png')) {
        contentType = 'image/png';
      } else if (lowerPath.endsWith('.webp')) {
        contentType = 'image/webp';
      } else if (lowerPath.endsWith('.mov')) {
        contentType = 'video/quicktime';
      } else if (lowerPath.endsWith('.webm')) {
        contentType = 'video/webm';
      } else if (isVideo) {
        contentType = 'video/mp4';
      }

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': userId,
          'timestamp': DateTime.now().toIso8601String(),
          'isVideo': isVideo.toString(),
        },
      );

      final uploadTask = await storageRef.putFile(file, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
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
