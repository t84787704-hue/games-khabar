import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'fast_compress.dart';
import 'fast_chunked_upload.dart';
import 'gamer_social_service.dart';

class UploadTaskState {
  final String taskId;
  final String title;
  final double progress; // 0.0 to 1.0
  final String statusText;
  final bool isCompleted;
  final bool hasError;
  final String? errorMessage;
  final String? mediaUrl;

  UploadTaskState({
    required this.taskId,
    required this.title,
    this.progress = 0.0,
    this.statusText = 'Preparing...',
    this.isCompleted = false,
    this.hasError = false,
    this.errorMessage,
    this.mediaUrl,
  });

  UploadTaskState copyWith({
    double? progress,
    String? statusText,
    bool? isCompleted,
    bool? hasError,
    String? errorMessage,
    String? mediaUrl,
  }) {
    return UploadTaskState(
      taskId: taskId,
      title: title,
      progress: progress ?? this.progress,
      statusText: statusText ?? this.statusText,
      isCompleted: isCompleted ?? this.isCompleted,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      mediaUrl: mediaUrl ?? this.mediaUrl,
    );
  }
}

/// TikTok-style Background Video Upload Manager
/// Allows instant closing of screen while compression & chunked upload continue in background.
class BackgroundUploadManager {
  static final BackgroundUploadManager _instance = BackgroundUploadManager._internal();
  factory BackgroundUploadManager() => _instance;
  BackgroundUploadManager._internal();

  final ValueNotifier<UploadTaskState?> activeTask = ValueNotifier<UploadTaskState?>(null);

  /// Start background video processing & upload
  Future<void> startVideoUpload({
    required File videoFile,
    required String text,
    required String gameTag,
    required String userId,
    required String username,
    required String displayName,
    required String userPhoto,
    int estimatedDurationSeconds = 60,
  }) async {
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    activeTask.value = UploadTaskState(
      taskId: taskId,
      title: text.isNotEmpty ? text : 'Gaming Video',
      progress: 0.05,
      statusText: '⚡ Hardware Compressing... 5%',
    );

    // Run async in background without blocking caller
    unawaited(() async {
      try {
        final originalBytes = await videoFile.length();
        final double originalMB = originalBytes / (1024 * 1024);

        // Step 1: Fast Hardware GPU Compression (5-10 sec for 1000MB)
        File fileToUpload = videoFile;
        if (originalMB > 15.0) {
          fileToUpload = await FastCompressService.compressGamingVideo(
            videoFile,
            totalDurationSeconds: estimatedDurationSeconds,
            onProgress: (p) {
              final combinedProg = (p * 0.45).clamp(0.05, 0.45);
              final pct = (combinedProg * 100).toInt();
              activeTask.value = activeTask.value?.copyWith(
                progress: combinedProg,
                statusText: '⚡ Compressing... $pct%',
              );
            },
            onStatus: (status) {
              activeTask.value = activeTask.value?.copyWith(statusText: status);
            },
          );
        }

        // Step 2: Parallel Chunked Upload to Cloudinary (8-12 sec)
        activeTask.value = activeTask.value?.copyWith(
          progress: 0.48,
          statusText: '🚀 Fast Uploading... 48%',
        );

        final uploadResult = await FastChunkedUploadService.uploadVideo(
          file: fileToUpload,
          caption: text,
          gameTag: gameTag,
          onProgress: (p) {
            final combinedProg = (0.45 + (p * 0.50)).clamp(0.48, 0.95);
            final pct = (combinedProg * 100).toInt();
            activeTask.value = activeTask.value?.copyWith(
              progress: combinedProg,
              statusText: '🚀 Uploading... $pct%',
            );
          },
          onStatus: (status) {
            activeTask.value = activeTask.value?.copyWith(statusText: status);
          },
        );

        if (uploadResult == null || uploadResult['secure_url'] == null) {
          throw Exception("Cloud upload failed or was interrupted");
        }

        final String videoUrl = uploadResult['secure_url'].toString();

        // Step 3: Save to Firestore
        activeTask.value = activeTask.value?.copyWith(
          progress: 0.97,
          statusText: 'Posting to Feed... ⚡',
        );

        await GamerSocialService().createPost(
          userId: userId,
          username: username,
          displayName: displayName,
          userPhoto: userPhoto,
          text: text,
          gameTag: gameTag,
          mediaUrl: videoUrl,
        );

        // Success state
        activeTask.value = activeTask.value?.copyWith(
          progress: 1.0,
          statusText: '🎉 Video Clip Published!',
          isCompleted: true,
          mediaUrl: videoUrl,
        );

        // Auto dismiss after 3.5 seconds
        await Future.delayed(const Duration(milliseconds: 3500));
        if (activeTask.value?.taskId == taskId) {
          activeTask.value = null;
        }
      } catch (e) {
        debugPrint("❌ [BACKGROUND_UPLOAD] Error: $e");
        activeTask.value = activeTask.value?.copyWith(
          hasError: true,
          errorMessage: e.toString(),
          statusText: '⚠️ Upload failed. Tap to dismiss.',
        );
      }
    }());
  }

  void dismissTask() {
    activeTask.value = null;
  }
}
