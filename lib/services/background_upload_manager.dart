import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'gamer_social_service.dart';

class UploadTaskState {
  final String taskId;
  final String title;
  final double progress;
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

/// FIXED - NO DOTENV - DIRECT UPLOAD - No Compression
class BackgroundUploadManager {
  static final BackgroundUploadManager _instance = BackgroundUploadManager._internal();
  factory BackgroundUploadManager() => _instance;
  BackgroundUploadManager._internal();

  // YAHAN APNA CLOUDINARY NAME DALO
  static const String _cloudName = 'YOUR_CLOUD_NAME_HERE';
  static const String _uploadPreset = 'tiktok_3min_direct';

  final ValueNotifier<UploadTaskState?> activeTask = ValueNotifier<UploadTaskState?>(null);

  Future<void> startVideoUpload({
    required File videoFile,
    required String text,
    required String gameTag,
    required String userId,
    required String username,
    required String displayName,
    required String userPhoto,
    int estimatedDurationSeconds = 180,
  }) async {
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    activeTask.value = UploadTaskState(
      taskId: taskId,
      title: text.isNotEmpty ? text : 'Gaming Video',
      progress: 0.05,
      statusText: '🚀 Direct Uploading... 5%',
    );

    unawaited(() async {
      try {
        final fileSize = await videoFile.length();
        const int chunkSize = 10 * 1024 * 1024;
        final totalChunks = (fileSize / chunkSize).ceil();
        final String uniqueUploadId = 'gaming_${DateTime.now().millisecondsSinceEpoch}';
        String? finalSecureUrl;

        for (int i = 0; i < totalChunks; i++) {
          final int start = i * chunkSize;
          final int end = (start + chunkSize > fileSize) ? fileSize : start + chunkSize;
          final bytes = await file.openRead(start, end).expand((e) => e).toList();
          final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/video/upload');
          final request = http.MultipartRequest('POST', uri);
          request.headers['X-Unique-Upload-Id'] = uniqueUploadId;
          request.headers['Content-Range'] = 'bytes $start-${end - 1}/$fileSize';
          request.fields['upload_preset'] = _uploadPreset;
          request.fields['public_id'] = uniqueUploadId;
          request.fields['eager'] = 'w_720,h_1280,c_limit,q_auto,f_auto';
          request.fields['eager_async'] = 'true';
          request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'chunk_$i.mp4'));
          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);
          if (response.statusCode == 200 || response.statusCode == 201) {
            final jsonRes = json.decode(response.body);
            if (jsonRes['secure_url'] != null) finalSecureUrl = jsonRes['secure_url'];
            final prog = ((i + 1) / totalChunks).clamp(0.0, 1.0);
            final pct = (prog * 100).toInt();
            activeTask.value = activeTask.value?.copyWith(progress: prog, statusText: '🚀 Uploading... $pct%');
          } else { throw Exception('Upload failed: ${response.body}'); }
        }

        if (finalSecureUrl == null) throw Exception("Cloud upload failed");
        activeTask.value = activeTask.value?.copyWith(progress: 0.95, statusText: 'Posting to Feed... ⚡');
        await GamerSocialService().createPost(userId: userId, username: username, displayName: displayName, userPhoto: userPhoto, text: text, gameTag: gameTag, mediaUrl: finalSecureUrl);
        activeTask.value = activeTask.value?.copyWith(progress: 1.0, statusText: '🎉 Video Clip Published!', isCompleted: true, mediaUrl: finalSecureUrl);
        await Future.delayed(const Duration(milliseconds: 3500));
        if (activeTask.value?.taskId == taskId) activeTask.value = null;
      } catch (e) {
        activeTask.value = activeTask.value?.copyWith(hasError: true, errorMessage: e.toString(), statusText: '⚠️ Upload failed. Tap to dismiss.');
      }
    }());
  }
  void dismissTask() { activeTask.value = null; }
}