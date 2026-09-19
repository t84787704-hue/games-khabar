import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';

/// Manages video controller lifecycle and cleanup
class VideoControllerManager {
  static final VideoControllerManager _instance = VideoControllerManager._internal();

  factory VideoControllerManager() {
    return _instance;
  }

  VideoControllerManager._internal();

  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, ChewieController?> _chewieControllers = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Register a video controller pair
  void registerController(
    String videoId, {
    required VideoPlayerController videoController,
    required ChewieController? chewieController,
  }) {
    _videoControllers[videoId] = videoController;
    _chewieControllers[videoId] = chewieController;
    debugPrint('✅ Registered controller for video: $videoId');
  }

  /// Unregister a video controller pair
  void unregisterController(String videoId) {
    _videoControllers.remove(videoId);
    _chewieControllers.remove(videoId);
    debugPrint('❌ Unregistered controller for video: $videoId');
  }

  /// Pause video without disposing
  Future<void> pauseVideo(String videoId) async {
    try {
      final controller = _videoControllers[videoId];
      if (controller != null && controller.value.isPlaying) {
        await controller.pause();
        debugPrint('⏸️ Paused video: $videoId');
      }
    } catch (e) {
      debugPrint('⚠️ Error pausing video $videoId: $e');
    }
  }

  /// Dispose controllers properly
  Future<void> _disposeControllers(String videoId) async {
    try {
      // Pause Chewie controller first
      final chewieController = _chewieControllers[videoId];
      if (chewieController != null) {
        try {
          await chewieController.dispose();
          debugPrint('✅ Disposed Chewie controller for: $videoId');
        } catch (e) {
          debugPrint('⚠️ Error disposing Chewie: $e');
        }
      }

      // Then dispose Video Player controller
      final videoController = _videoControllers[videoId];
      if (videoController != null) {
        try {
          await videoController.dispose();
          debugPrint('✅ Disposed VideoPlayer controller for: $videoId');
        } catch (e) {
          debugPrint('⚠️ Error disposing VideoPlayer: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _disposeControllers: $e');
    }
  }

  /// Delete video from Firestore and Firebase Storage
  Future<bool> deleteVideo({
    required String videoId,
    required String videoStoragePath,
    required String collectionPath,
  }) async {
    try {
      debugPrint('🔄 Starting delete process for video: $videoId');

      // Step 1: Pause video immediately (stop audio)
      await pauseVideo(videoId);

      // Step 2: Dispose controllers
      await _disposeControllers(videoId);

      // Step 3: Remove from local cache
      unregisterController(videoId);

      // Step 4: Delete from Firestore
      await _firestore.collection(collectionPath).doc(videoId).delete();
      debugPrint('✅ Deleted from Firestore: $videoId');

      // Step 5: Delete from Firebase Storage
      try {
        await _storage.ref(videoStoragePath).delete();
        debugPrint('✅ Deleted from Storage: $videoStoragePath');
      } catch (e) {
        debugPrint('⚠️ Storage file not found or already deleted: $e');
        // Don't fail if storage delete fails - Firestore deletion is more critical
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error deleting video: $e');
      rethrow;
    }
  }

  /// Dispose all controllers (call on app exit or screen exit)
  Future<void> disposeAll() async {
    debugPrint('🛑 Disposing all video controllers...');
    final videoIds = _videoControllers.keys.toList();
    for (final videoId in videoIds) {
      await _disposeControllers(videoId);
      unregisterController(videoId);
    }
    debugPrint('✅ All controllers disposed');
  }

  /// Get controller by video ID
  VideoPlayerController? getVideoController(String videoId) {
    return _videoControllers[videoId];
  }

  /// Get Chewie controller by video ID
  ChewieController? getChewieController(String videoId) {
    return _chewieControllers[videoId];
  }
}
