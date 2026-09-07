import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clip_model.dart';
import 'cloudinary_service.dart';

/// Service managing Gaming Clips using 100% Cloudinary for video hosting and Firestore for metadata.
/// ZERO Firebase Storage dependencies.
class ClipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Firestore collections
  CollectionReference get _clipsRef => _firestore.collection('clips');
  CollectionReference get _legacyClipsRef => _firestore.collection('gamer_clips');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  /// Uploads media file to Cloudinary and returns the HTTPS secure_url
  Future<String> uploadClipMedia({
    required File file,
    required String userId,
    String? customFileName,
    bool isVideo = true,
  }) async {
    try {
      print('🚀 [CLIP_SERVICE] Starting media upload for user $userId (isVideo: $isVideo)...');
      final secureUrl = await _cloudinaryService.uploadMedia(
        file: file,
        isVideo: isVideo,
      );
      print('✅ [CLIP_SERVICE] Media upload finished! Secure URL: $secureUrl');
      return secureUrl;
    } catch (e) {
      print('❌ [CLIP_SERVICE] uploadClipMedia failed: $e');
      rethrow;
    }
  }

  /// Full video clip upload pipeline:
  /// 1. Uploads video directly to Cloudinary (POST https://api.cloudinary.com/v1_1/<cloudName>/video/upload)
  /// 2. Returns secure_url
  /// 3. Saves document to Firestore collection 'clips' with {videoUrl, userId, createdAt, caption}
  Future<String> uploadClip({
    required File file,
    required String userId,
    required String caption,
    String username = 'gamer',
    String displayName = 'Gamer',
    String userAvatar = '',
    String gameTag = 'BGMI',
    String songTitle = 'Original Audio',
    bool isVideo = true,
  }) async {
    try {
      print('🚀 [CLIP_SERVICE] Step 1: Uploading video to Cloudinary...');
      
      // 1. Upload to Cloudinary unsigned endpoint
      final secureUrl = await _cloudinaryService.uploadVideo(file: file);
      print('✅ [CLIP_SERVICE] Step 1 Complete: Cloudinary secure_url obtained: $secureUrl');

      print('💾 [CLIP_SERVICE] Step 2: Saving to Firestore collection "clips"...');
      
      // 2. Prepare document data for collection 'clips'
      final docRef = _clipsRef.doc();
      final clipData = {
        'id': docRef.id,
        'userId': userId,
        'caption': caption.trim(),
        'title': caption.trim(),
        'videoUrl': secureUrl,
        'mediaUrl': secureUrl,
        'thumbnail': '',
        'username': username,
        'displayName': displayName,
        'userAvatar': userAvatar,
        'gameTag': gameTag,
        'songTitle': songTitle,
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'likedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 3. Save to Firestore collection 'clips'
      await docRef.set(clipData);
      print('✅ [CLIP_SERVICE] Document saved to Firestore "clips" with ID: ${docRef.id}');

      // Also mirror to 'gamer_clips' for legacy UI sync
      await _legacyClipsRef.doc(docRef.id).set(clipData).catchError((e) {
        print('⚠️ [CLIP_SERVICE] Notice mirroring to gamer_clips: $e');
      });

      return secureUrl;
    } catch (e) {
      print('❌ [CLIP_SERVICE] uploadClip failed: $e');
      rethrow;
    }
  }

  /// Saves a pre-constructed GamerClip model to Firestore collection 'clips'
  Future<void> saveClipModel(GamerClip clip) async {
    try {
      final docId = clip.id.isNotEmpty ? clip.id : _clipsRef.doc().id;
      final finalClip = clip.id.isEmpty ? clip.copyWith(id: docId) : clip;
      final mapData = finalClip.toMap();

      print('💾 [CLIP_SERVICE] Saving GamerClip ${finalClip.id} to collection "clips"...');
      await _clipsRef.doc(docId).set(mapData);
      await _legacyClipsRef.doc(docId).set(mapData).catchError((_) {});
      print('✅ [CLIP_SERVICE] GamerClip saved successfully!');
    } catch (e) {
      print('❌ [CLIP_SERVICE] saveClipModel error: $e');
      rethrow;
    }
  }

  /// Real-time stream of gaming clips from Firestore collection 'clips' ordered by createdAt descending
  Stream<List<GamerClip>> getClipsStream() {
    return _clipsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          print('📺 [CLIP_SERVICE] Loaded ${snap.docs.length} clips from Firestore "clips" collection');
          return snap.docs.map((d) => GamerClip.fromFirestore(d)).toList();
        });
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
    } catch (e) {
      print('❌ [CLIP_SERVICE] toggleLikeClip error: $e');
    }
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
    } catch (e) {
      print('❌ [CLIP_SERVICE] addComment error: $e');
    }
  }

  Stream<QuerySnapshot> getClipComments(String clipId) {
    return _clipsRef
        .doc(clipId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
