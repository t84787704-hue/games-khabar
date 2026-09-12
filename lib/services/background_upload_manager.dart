import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackgroundUploadManager {
  static final BackgroundUploadManager _instance = BackgroundUploadManager._internal();
  factory BackgroundUploadManager() => _instance;
  BackgroundUploadManager._internal();

  bool _isUploading = false;
  double _progress = 0.0;
  bool get isUploading => _isUploading;
  double get progress => _progress;

  final StreamController<Map<String, dynamic>> _uploadStatusController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get uploadStatusStream => _uploadStatusController.stream;

  Future<void> startVideoUpload({
    required File videoFile,
    required String text,
    required String gameTag,
    required String userId,
    required String username,
    required String displayName,
    String? userPhoto,
    int estimatedDurationSeconds = 180,
  }) async {
    if (_isUploading) return;
    _isUploading = true; _progress = 0.0;
    try {
      _uploadStatusController.add({'status': 'uploading', 'progress': 0, 'message': 'Uploading directly to Cloudinary... 0%'});
      final videoUrl = await _uploadLargeVideoDirect(videoFile);
      if (videoUrl == null) throw Exception('Upload failed');
      await FirebaseFirestore.instance.collection('videos').add({
        'videoUrl': videoUrl, 'caption': text, 'gameTag': gameTag, 'userId': userId,
        'username': username, 'displayName': displayName, 'userPhotoUrl': userPhoto ?? '',
        'createdAt': FieldValue.serverTimestamp(), 'duration': estimatedDurationSeconds,
        'fileSizeMB': (await videoFile.length()) / (1024 * 1024), 'likes': 0, 'views': 0, 'isPublished': true,
      });
      _progress = 100;
      _uploadStatusController.add({'status': 'completed', 'progress': 100, 'message': 'Video published!', 'url': videoUrl});
    } catch (e) {
      debugPrint('❌ Direct upload error: $e');
      _uploadStatusController.add({'status': 'error', 'progress': _progress, 'message': 'Upload failed: $e'});
    } finally { _isUploading = false; }
  }

  Future<String?> _uploadLargeVideoDirect(File file) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'YOUR_CLOUD_NAME';
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'tiktok_3min_direct';
    final fileSize = await file.length();
    const int chunkSize = 10 * 1024 * 1024;
    final totalChunks = (fileSize / chunkSize).ceil();
    final String uniqueUploadId = 'gaming_${DateTime.now().millisecondsSinceEpoch}';
    String? finalSecureUrl;
    for (int i = 0; i < totalChunks; i++) {
      final int start = i * chunkSize;
      final int end = (start + chunkSize > fileSize) ? fileSize : start + chunkSize;
      final bytes = await file.openRead(start, end).expand((e) => e).toList();
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');
      final request = http.MultipartRequest('POST', uri);
      request.headers['X-Unique-Upload-Id'] = uniqueUploadId;
      request.headers['Content-Range'] = 'bytes $start-${end - 1}/$fileSize';
      request.fields['upload_preset'] = uploadPreset;
      request.fields['public_id'] = uniqueUploadId;
      request.fields['eager'] = 'w_720,h_1280,c_limit,q_auto,f_auto';
      request.fields['eager_async'] = 'true';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'chunk_$i.mp4'));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonRes = json.decode(response.body);
        if (jsonRes['secure_url'] != null) finalSecureUrl = jsonRes['secure_url'];
        _progress = ((i + 1) / totalChunks) * 100;
        _uploadStatusController.add({'status': 'uploading', 'progress': _progress.toInt(), 'message': 'Uploading directly... ${_progress.toInt()}%'});
      } else { throw Exception('Chunk upload failed: ${response.body}'); }
    }
    return finalSecureUrl;
  }
  void dispose() { _uploadStatusController.close(); }
}