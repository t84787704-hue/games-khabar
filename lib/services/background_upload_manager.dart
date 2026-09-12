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
  UploadTaskState({required this.taskId, required this.title, this.progress = 0.0, this.statusText = 'Preparing...', this.isCompleted = false, this.hasError = false, this.errorMessage, this.mediaUrl});
  UploadTaskState copyWith({double? progress, String? statusText, bool? isCompleted, bool? hasError, String? errorMessage, String? mediaUrl}) {
    return UploadTaskState(taskId: taskId, title: title, progress: progress ?? this.progress, statusText: statusText ?? this.statusText, isCompleted: isCompleted ?? this.isCompleted, hasError: hasError ?? this.hasError, errorMessage: errorMessage ?? this.errorMessage, mediaUrl: mediaUrl ?? this.mediaUrl);
  }
}

class BackgroundUploadManager {
  static final BackgroundUploadManager _instance = BackgroundUploadManager._internal();
  factory BackgroundUploadManager() => _instance;
  BackgroundUploadManager._internal();
  
  static const String _cloudName = 'fka9mgwu';
  static const String _uploadPreset = 'clips_preset';
  
  final ValueNotifier<UploadTaskState?> activeTask = ValueNotifier<UploadTaskState?>(null);

  Future<void> startVideoUpload({required File videoFile, required String text, required String gameTag, required String userId, required String username, required String displayName, required String userPhoto, int estimatedDurationSeconds = 180}) async {
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final fileSize = await videoFile.length();
      final sizeMB = fileSize / (1024 * 1024);
      
      if (sizeMB > 100) {
        activeTask.value = UploadTaskState(taskId: taskId, title: text, progress: 0, statusText: '❌ File too big ${sizeMB.toStringAsFixed(1)}MB > 100MB', hasError: true, errorMessage: 'File too large for free plan');
        return;
      }

      activeTask.value = UploadTaskState(taskId: taskId, title: text.isNotEmpty ? text : 'Gaming Video', progress: 0.1, statusText: '🚀 Uploading ${sizeMB.toStringAsFixed(1)}MB... 10%');
      
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/video/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['public_id'] = 'gaming_${DateTime.now().millisecondsSinceEpoch}';
      request.files.add(await http.MultipartFile.fromPath('file', videoFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonRes = json.decode(response.body);
        final String finalUrl = jsonRes['secure_url'];
        activeTask.value = activeTask.value?.copyWith(progress: 0.9, statusText: 'Posting to Feed... ⚡');
        await GamerSocialService().createPost(userId: userId, username: username, displayName: displayName, userPhoto: userPhoto, text: text, gameTag: gameTag, mediaUrl: finalUrl);
        activeTask.value = activeTask.value?.copyWith(progress: 1.0, statusText: '🎉 Video Clip Published!', isCompleted: true, mediaUrl: finalUrl);
        await Future.delayed(const Duration(seconds: 4));
        activeTask.value = null;
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      final msg = e.toString();
      final shortMsg = msg.length > 120 ? msg.substring(0, 120) : msg;
      activeTask.value = UploadTaskState(taskId: taskId, title: text, statusText: '❌ $shortMsg', hasError: true, errorMessage: msg);
      debugPrint('UPLOAD ERROR FULL: $msg');
    }
  }
  void dismissTask() { activeTask.value = null; }
}