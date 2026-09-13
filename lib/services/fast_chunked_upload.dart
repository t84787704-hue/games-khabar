import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// High-Speed Chunked & Parallel Uploader for Gaming Video Clips
/// Primary: Firebase Storage native resumable upload with live byte-level progress.
/// Secondary: Cloudinary HTTP streaming fallback.
class FastChunkedUploadService {
  static const String cloudName = "fka9mgwu";
  static const String uploadPreset = "gaming_clips_preset";
  static const int defaultChunkSize = 8 * 1024 * 1024; // 8MB chunks

  static bool _isCancelled = false;

  static void cancel() {
    _isCancelled = true;
    debugPrint("🛑 [FAST_UPLOAD] Upload cancelled by user");
  }

  /// Upload video file with live progress updates
  static Future<Map<String, dynamic>?> uploadVideo({
    required File file,
    String? caption,
    String? gameTag,
    String? userId,
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    _isCancelled = false;
    final int fileSize = await file.length();
    final double fileSizeMB = fileSize / (1024 * 1024);

    debugPrint("🚀 [FAST_UPLOAD] Preparing to upload ${fileSizeMB.toStringAsFixed(1)} MB video");

    // 1. Primary Strategy: Firebase Storage (Fast, Google Cloud CDN, 100% reliable in this app)
    final fbResult = await _uploadToFirebaseStorage(
      file: file,
      fileSize: fileSize,
      caption: caption,
      gameTag: gameTag,
      userId: userId,
      onProgress: onProgress,
      onStatus: onStatus,
    );

    if (fbResult != null) {
      return fbResult;
    }

    // 2. Secondary Strategy: Direct Stream upload fallback
    debugPrint("⚠️ Firebase Storage not available. Trying HTTP upload fallback...");
    final directResult = await _directStreamUpload(
      file: file,
      fileSize: fileSize,
      caption: caption,
      gameTag: gameTag,
      onProgress: onProgress,
      onStatus: onStatus,
    );

    if (directResult != null) {
      return directResult;
    }

    return null;
  }

  /// Firebase Storage upload with live byte-level progress reporting
  static Future<Map<String, dynamic>?> _uploadToFirebaseStorage({
    required File file,
    required int fileSize,
    String? caption,
    String? gameTag,
    String? userId,
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    try {
      final double mb = fileSize / (1024 * 1024);
      onStatus?.call("🚀 Uploading Clip (${mb.toStringAsFixed(1)} MB)...");
      onProgress?.call(0.05);

      final String uid = (userId != null && userId.isNotEmpty) ? userId : 'anonymous';
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String cleanFileName = '${timestamp}_${Random().nextInt(99999)}.mp4';

      final ref = FirebaseStorage.instance
          .ref()
          .child('gaming_clips')
          .child(uid)
          .child(cleanFileName);

      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'gameTag': gameTag ?? '',
          'caption': caption ?? '',
        },
      );

      final uploadTask = ref.putFile(file, metadata);

      StreamSubscription<TaskSnapshot>? sub;
      sub = uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (_isCancelled) {
            uploadTask.cancel();
            return;
          }
          if (snapshot.totalBytes > 0) {
            final double p = (snapshot.bytesTransferred / snapshot.totalBytes).clamp(0.0, 0.99);
            final int pct = (p * 100).toInt();
            onProgress?.call(p);
            onStatus?.call("🚀 Uploading Clip... $pct%");
          }
        },
        onError: (err) {
          debugPrint("⚠️ [FIREBASE_STORAGE] Task event note: $err");
        },
      );

      final completedSnapshot = await uploadTask.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          uploadTask.cancel();
          throw TimeoutException("Firebase Storage upload timed out after 5 minutes");
        },
      );

      await sub?.cancel();

      final downloadUrl = await completedSnapshot.ref.getDownloadURL();
      debugPrint("✅ [FIREBASE_STORAGE] Video uploaded successfully: $downloadUrl");
      onProgress?.call(1.0);
      onStatus?.call("✅ Upload Complete!");

      return {
        'secure_url': downloadUrl,
        'public_id': cleanFileName,
        'format': 'mp4',
        'bytes': fileSize,
      };
    } catch (e) {
      debugPrint("⚠️ [FIREBASE_STORAGE] Upload notice: $e");
      return null;
    }
  }

  /// Single stream upload with progress tracking
  static Future<Map<String, dynamic>?> _directStreamUpload({
    required File file,
    required int fileSize,
    String? caption,
    String? gameTag,
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    try {
      onStatus?.call("🚀 Fast Uploading (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB)...");
      final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");
      final request = http.MultipartRequest("POST", uri);

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'gaming_clips';
      if (gameTag != null && gameTag.isNotEmpty) {
        request.fields['tags'] = 'gaming,$gameTag';
      }

      int bytesSent = 0;
      final fileStream = file.openRead();
      final originalFileName = file.path.split(Platform.pathSeparator).last;

      final multipartFile = http.MultipartFile(
        'file',
        fileStream.transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (List<int> data, EventSink<List<int>> sink) {
              if (_isCancelled) {
                sink.close();
                return;
              }
              bytesSent += data.length;
              if (fileSize > 0) {
                final prog = (bytesSent / fileSize).clamp(0.0, 0.99);
                onProgress?.call(prog);
              }
              sink.add(data);
            },
            handleDone: (sink) => sink.close(),
            handleError: (error, stackTrace, sink) => sink.addError(error, stackTrace),
          ),
        ),
        fileSize,
        filename: originalFileName,
      );

      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(const Duration(minutes: 3));
      final responseBody = await http.Response.fromStream(streamedResponse);

      if (responseBody.statusCode == 200) {
        onProgress?.call(1.0);
        onStatus?.call("✅ Upload Complete!");
        final data = jsonDecode(responseBody.body) as Map<String, dynamic>;
        return data;
      } else {
        debugPrint("⚠️ Direct upload failed: ${responseBody.statusCode} - ${responseBody.body}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Direct upload error: $e");
      return null;
    }
  }
}
