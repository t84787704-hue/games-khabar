import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clip_model.dart';
import 'cloudinary_service.dart';
import 'video_compress_service.dart';

/// Service for managing gaming clips and memes.
/// Uses 100% Cloudinary for video storage (ZERO Firebase Storage dependencies)
/// and Cloud Firestore for saving clip records in collection 'clips'.
class ClipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firestore collections
  CollectionReference get _clipsRef => _firestore.collection('clips');
  CollectionReference get _legacyClipsRef => _firestore.collection('gamer_clips');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  /// Uploads media directly to Cloudinary and returns the HTTPS secure_url.
  /// 100% Cloudinary - NO Firebase Storage!
  Future<String> uploadClipMedia({
    required File file,
    required String userId,
    String? customFileName,
    bool isVideo = true,
  }) async {
    try {
      print('🚀 [CLIP_SERVICE] uploadClipMedia called for user: $userId (isVideo: $isVideo)');
      final secureUrl = await CloudinaryService.uploadFile(file: file, folder: 'gamer_clips');
      if (secureUrl == null) {
        throw Exception('Cloudinary upload returned null');
      }
      print('✅ [CLIP_SERVICE] uploadClipMedia completed: $secureUrl');
      return secureUrl;
    } catch (e) {
      print('❌ [CLIP_SERVICE] uploadClipMedia failed: $e');
      rethrow;
    }
  }

  /// Uploads video clip to Cloudinary and saves {videoUrl, thumbnailUrl, caption, gameTag, duration, etc.} to Firestore collection 'clips'
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
    double trimmedDuration = 0.0,
    double originalDuration = 0.0,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    try {
      print('🚀 [CLIP_SERVICE] Step 0: Checking video compression...');
      final fileToUpload = await VideoCompressService.compressIfNeeded(
        file,
        onProgress: onProgress != null ? (p) => onProgress(p * 0.35) : null,
      );

      print('🚀 [CLIP_SERVICE] Step 1: Uploading video file to Cloudinary with progress...');
      
      final uploadResult = await CloudinaryService.uploadVideoWithProgress(
        file: fileToUpload,
        userId: userId,
        gameTag: gameTag,
        caption: caption,
        onProgress: onProgress != null ? (p) => onProgress(0.35 + (p * 0.6)) : null,
        isCancelled: isCancelled,
      );

      final videoUrl = uploadResult.secureUrl;
      final thumbnailUrl = uploadResult.thumbnailUrl.isNotEmpty 
          ? uploadResult.thumbnailUrl 
          : CloudinaryService.getAutoThumbnailUrl(videoUrl);
      final finalDuration = (uploadResult.duration > 0) ? uploadResult.duration : trimmedDuration;

      print('✅ [CLIP_SERVICE] Cloudinary upload successful! URL: $videoUrl, Thumb: $thumbnailUrl');
      print('💾 [CLIP_SERVICE] Step 2: Saving clip record to Firestore collection "clips"...');
      
      // Prepare document data for collection 'clips'
      final docRef = _clipsRef.doc();
      final clipData = {
        'id': docRef.id,
        'userId': userId,
        'authorId': userId,
        'uploaderId': userId,
        'caption': caption.trim(),
        'title': caption.trim(),
        'videoUrl': videoUrl,
        'mediaUrl': videoUrl,
        'thumbnail': thumbnailUrl,
        'thumbnailUrl': thumbnailUrl,
        'publicId': uploadResult.publicId,
        'username': username,
        'displayName': displayName,
        'userAvatar': userAvatar,
        'gameTag': gameTag,
        'songTitle': songTitle,
        'duration': finalDuration,
        'originalDuration': originalDuration > 0 ? originalDuration : finalDuration,
        'isGamingClip': true,
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'viewsCount': 0,
        'likes': 0,
        'views': 0,
        'likedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 3. Save to Firestore collection 'clips'
      await docRef.set(clipData);
      print('✅ [CLIP_SERVICE] Clip record saved to Firestore collection "clips" (id: ${docRef.id})');

      // Increment user's posts count in Profile ('users' collection)
      await _firestore.collection('users').doc(userId).update({
        'postsCount': FieldValue.increment(1),
      }).catchError((e) {
        print('⚠️ [CLIP_SERVICE] Could not increment postsCount for user $userId: $e');
      });

      // Also mirror to 'gamer_clips' for legacy feed compatibility
      await _legacyClipsRef.doc(docRef.id).set(clipData).catchError((e) {
        print('⚠️ [CLIP_SERVICE] Legacy mirror notice: $e');
      });

      return videoUrl;
    } catch (e) {
      print('❌ [CLIP_SERVICE] uploadClip error: $e');
      rethrow;
    }
  }

  /// Real-time stream of clips from Firestore collection 'clips' ordered by createdAt descending.
  /// Filters out null, corrupted, and oversized entries that cause black screens.
  Stream<List<GamerClip>> getClipsStream() {
    return _clipsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          print('📺 [CLIP_SERVICE] Real-time clips fetched: ${snap.docs.length}');
          final validClips = <GamerClip>[];
          for (final d in snap.docs) {
            final data = d.data() as Map<String, dynamic>?;
            if (data == null) continue;
            final vUrl = data['videoUrl']?.toString() ?? data['mediaUrl']?.toString() ?? '';
            final sizeBytes = (data['sizeBytes'] as num?)?.toInt() ?? 0;
            final sizeMB = (data['sizeMB'] as num?)?.toInt() ?? (sizeBytes ~/ (1024 * 1024));

            // Clean up and skip broken/null/huge docs that cause black screen
            if (vUrl.isEmpty || vUrl == 'null' || sizeMB > 100) {
              print('🧹 [CLIP_SERVICE] Auto-removing black/invalid clip doc: ${d.id}');
              d.reference.delete().catchError((_) {});
              _legacyClipsRef.doc(d.id).delete().catchError((_) {});
              continue;
            }

            try {
              validClips.add(GamerClip.fromFirestore(d));
            } catch (e) {
              print('⚠️ [CLIP_SERVICE] Skipped corrupt clip: $e');
            }
          }
          return validClips;
        });
  }

  /// One-time cleanup for any old black/corrupted clip documents in Firestore
  Future<void> cleanupOldBlackEntries() async {
    try {
      final snap = await _clipsRef.get();
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final vUrl = data['videoUrl']?.toString() ?? data['mediaUrl']?.toString() ?? '';
        final sizeBytes = (data['sizeBytes'] as num?)?.toInt() ?? 0;
        final sizeMB = (data['sizeMB'] as num?)?.toInt() ?? (sizeBytes ~/ (1024 * 1024));
        if (vUrl.isEmpty || vUrl == 'null' || sizeMB > 100) {
          print('🧹 [CLIP_SERVICE] Deleting old black entry: ${doc.id}');
          await doc.reference.delete().catchError((_) {});
          await _legacyClipsRef.doc(doc.id).delete().catchError((_) {});
        }
      }
    } catch (e) {
      print('⚠️ [CLIP_SERVICE] cleanupOldBlackEntries error: $e');
    }
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

  /// Increment clip view count when played in feed
  Future<void> incrementClipViews(String clipId) async {
    try {
      await _clipsRef.doc(clipId).update({
        'viewsCount': FieldValue.increment(1),
      }).catchError((_) {});
      await _legacyClipsRef.doc(clipId).update({
        'viewsCount': FieldValue.increment(1),
      }).catchError((_) {});
    } catch (_) {}
  }

  /// Report non-gaming or inappropriate clip
  Future<void> reportClip({
    required String clipId,
    required String reporterId,
    required String reason,
    required String clipTitle,
  }) async {
    try {
      await _firestore.collection('clip_reports').add({
        'clipId': clipId,
        'reporterId': reporterId,
        'reason': reason,
        'clipTitle': clipTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending_review',
      });
      await _clipsRef.doc(clipId).update({
        'reportsCount': FieldValue.increment(1),
      }).catchError((_) {});
      await _legacyClipsRef.doc(clipId).update({
        'reportsCount': FieldValue.increment(1),
      }).catchError((_) {});
    } catch (e) {
      print('❌ [CLIP_SERVICE] reportClip error: $e');
    }
  }
}
