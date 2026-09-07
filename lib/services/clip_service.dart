import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/clip_model.dart';
import 'cloudinary_service.dart';

/// Service managing Gaming Clips using 100% Cloudinary for media and Firestore for metadata.
/// ZERO Firebase Storage dependencies.
class ClipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Firestore collections
  CollectionReference get _clipsRef => _firestore.collection('clips');
  CollectionReference get _legacyClipsRef => _firestore.collection('gamer_clips');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  /// Uploads media directly to Cloudinary and returns the HTTPS secure_url.
  /// 100% Cloudinary unsigned video upload - NO Firebase Storage!
  Future<String> uploadClipMedia({
    required File file,
    required String userId,
    String? customFileName,
    bool isVideo = true,
  }) async {
    try {
      final secureUrl = await _cloudinaryService.uploadMedia(
        file: file,
        isVideo: isVideo,
        customPublicId: '${userId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      return secureUrl;
    } catch (e) {
      debugPrint('ClipService.uploadClipMedia error: $e');
      rethrow;
    }
  }

  /// Uploads video clip file to Cloudinary and saves document with secure_url to Firestore collection "clips"
  Future<String> uploadClipVideoFile({
    required File file,
    required String userId,
    required String username,
    required String displayName,
    required String userAvatar,
    required String title,
    required String gameTag,
    String? songTitle,
  }) async {
    try {
      // 1. Upload video to Cloudinary via unsigned MultipartRequest
      final secureUrl = await _cloudinaryService.uploadVideo(
        file: file,
        userId: userId,
      );

      // 2. Save clip with secure_url into Firestore collection "clips"
      final docRef = _clipsRef.doc();
      final clip = GamerClip(
        id: docRef.id,
        userId: userId,
        username: username,
        displayName: displayName,
        userAvatar: userAvatar,
        title: title.trim(),
        mediaUrl: secureUrl,
        thumbnail: '',
        gameTag: gameTag,
        songTitle: songTitle ?? 'Original Audio - $displayName',
        createdAt: DateTime.now(),
      );

      final map = clip.toMap();
      await docRef.set(map);
      // Also mirror to legacy collection
      await _legacyClipsRef.doc(docRef.id).set(map);

      return secureUrl;
    } catch (e) {
      debugPrint('ClipService.uploadClipVideoFile error: $e');
      rethrow;
    }
  }

  /// Saves a GamerClip document to Firestore collection "clips" (and "gamer_clips")
  Future<void> uploadClip(GamerClip clip) async {
    try {
      final docId = clip.id.isNotEmpty ? clip.id : _clipsRef.doc().id;
      final finalClip = clip.id.isEmpty ? clip.copyWith(id: docId) : clip;
      final mapData = finalClip.toMap();

      // Save to Firestore collection "clips"
      await _clipsRef.doc(docId).set(mapData);
      // Mirror to "gamer_clips"
      await _legacyClipsRef.doc(docId).set(mapData);
    } catch (e) {
      debugPrint('ClipService.uploadClip error: $e');
      rethrow;
    }
  }

  /// Real-time stream of gaming clips
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

      final updateData = isLiked
          ? {
              'likedBy': FieldValue.arrayRemove([userId]),
              'likesCount': FieldValue.increment(-1),
            }
          : {
              'likedBy': FieldValue.arrayUnion([userId]),
              'likesCount': FieldValue.increment(1),
            };

      await _clipsRef.doc(clipId).update(updateData);
      await _legacyClipsRef.doc(clipId).update(updateData).catchError((_) {});

      if (!isLiked && authorId != userId) {
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
    } catch (_) {}
  }

  Future<void> addComment({
    required String clipId,
    required String userId,
    required String username,
    required String text,
  }) async {
    try {
      final commentData = {
        'userId': userId,
        'username': username,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _clipsRef.doc(clipId).collection('comments').add(commentData);
      await _clipsRef.doc(clipId).update({'commentsCount': FieldValue.increment(1)});

      await _legacyClipsRef.doc(clipId).collection('comments').add(commentData).catchError((_) {});
      await _legacyClipsRef.doc(clipId).update({'commentsCount': FieldValue.increment(1)}).catchError((_) {});
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
