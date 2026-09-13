import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';

/// Service class to handle video operations with proper resource cleanup
class VideoService {
  static final VideoService _instance = VideoService._internal();

  factory VideoService() {
    return _instance;
  }

  VideoService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Safely pause and dispose a single video controller pair
  Future<void> pauseAndDisposeController({
    required VideoPlayerController? videoController,
    required ChewieController? chewieController,
  }) async {
    try {
      // Pause video if it's playing
      if (videoController != null && videoController.value.isPlaying) {
        await videoController.pause();
      }

      // Dispose Chewie controller first
      if (chewieController != null) {
        await chewieController.dispose();
      }

      // Dispose Video Player controller
      if (videoController != null) {
        await videoController.dispose();
      }
    } catch (e) {
      debugPrint('Error disposing controllers: $e');
    }
  }

  /// Dispose controller at specific index from lists
  Future<void> disposeControllerAtIndex({
    required List<VideoPlayerController>? videoControllers,
    required List<ChewieController>? chewieControllers,
    required int index,
  }) async {
    try {
      if (chewieControllers != null &&
          index >= 0 &&
          index < chewieControllers.length) {
        await chewieControllers[index].dispose();
        chewieControllers.removeAt(index);
      }

      if (videoControllers != null &&
          index >= 0 &&
          index < videoControllers.length) {
        await videoControllers[index].dispose();
        videoControllers.removeAt(index);
      }
    } catch (e) {
      debugPrint('Error disposing controller at index $index: $e');
    }
  }

  /// Delete video from Firestore and Firebase Storage with proper cleanup
  Future<bool> deleteVideo({
    required String videoDocId,
    required String videoStoragePath,
    required VideoPlayerController? videoController,
    required ChewieController? chewieController,
    required String collectionPath,
  }) async {
    try {
      // Step 1: Pause and dispose controllers BEFORE deleting from Firebase
      await pauseAndDisposeController(
        videoController: videoController,
        chewieController: chewieController,
      );

      // Step 2: Delete from Firestore
      await _firestore.collection(collectionPath).doc(videoDocId).delete();

      // Step 3: Delete from Firebase Storage
      try {
        await _storage.ref(videoStoragePath).delete();
      } catch (e) {
        debugPrint('Warning: Could not delete storage file: $e');
        // Don't throw - Firestore deletion is more critical
      }

      debugPrint('Video deleted successfully: $videoDocId');
      return true;
    } catch (e) {
      debugPrint('Error deleting video: $e');
      rethrow;
    }
  }

  /// Delete video from list at specific index
  Future<bool> deleteVideoAtIndex({
    required int index,
    required String videoDocId,
    required String videoStoragePath,
    required List<VideoPlayerController>? videoControllers,
    required List<ChewieController>? chewieControllers,
    required String collectionPath,
  }) async {
    try {
      // Step 1: Dispose controller at this index
      await disposeControllerAtIndex(
        videoControllers: videoControllers,
        chewieControllers: chewieControllers,
        index: index,
      );

      // Step 2: Delete from Firestore
      await _firestore.collection(collectionPath).doc(videoDocId).delete();

      // Step 3: Delete from Firebase Storage
      try {
        await _storage.ref(videoStoragePath).delete();
      } catch (e) {
        debugPrint('Warning: Could not delete storage file: $e');
      }

      debugPrint('Video at index $index deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting video at index $index: $e');
      rethrow;
    }
  }
}
