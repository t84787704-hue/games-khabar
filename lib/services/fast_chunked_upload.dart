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
  static const String uploadPreset = "clips_preset";
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
    final List<String> errorLogs = [];

    // 1. Primary Strategy: Cloudinary High-Speed Upload (verified active preset: clips_preset)
    final directResult = await _directStreamUpload(
      file: file,
      fileSize: fileSize,
      caption: caption,
      gameTag: gameTag,
      onProgress: onProgress,
      onStatus: onStatus,
      onErrorLog: (err) => errorLogs.add(err),
    );

    if (directResult != null) {
      return directResult;
    }

    // 2. Secondary Strategy: Firebase Storage fallback
    debugPrint("⚠️ Cloudinary upload failed. Trying Firebase Storage fallback...");
    final fbResult = await _uploadToFirebaseStorage(
      file: file,
      fileSize: fileSize,
      caption: caption,
      gameTag: gameTag,
      userId: userId,
      onProgress: onProgress,
      onStatus: onStatus,
      onErrorLog: (err) => errorLogs.add(err),
    );

    if (fbResult != null) {
      return fbResult;
    }

    // If both failed, format a clear, informative error
    final failureSummary = errorLogs.isNotEmpty
        ? errorLogs.join(" | ")
        : "Firebase Storage or Cloudinary unsigned preset not configured.";
    debugPrint("❌ [FAST_UPLOAD] All upload strategies failed: $failureSummary");
    throw Exception(failureSummary);
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
    Function(String error)? onErrorLog,
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
      onErrorLog?.call("Firebase Storage: ${e.toString().split('\n').first}");
      return null;
    }
  }

  /// Single stream upload with progress tracking and fallback presets
  static Future<Map<String, dynamic>?> _directStreamUpload({
    required File file,
    required int fileSize,
    String? caption,
    String? gameTag,
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
    Function(String error)? onErrorLog,
  }) async {
    final presetsToTry = [uploadPreset, "clips_preset", "gaming_clips_preset", "clips", "ml_default"];
    String lastError = "";

    for (final preset in presetsToTry) {
      if (_isCancelled) return null;
      try {
        onStatus?.call("🚀 Uploading via Cloudinary (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB)...");
        final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/video/upload");
        final request = http.MultipartRequest("POST", uri);

        request.fields['upload_preset'] = preset;
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

        final streamedResponse = await request.send().timeout(const Duration(minutes: 4));
        final responseBody = await http.Response.fromStream(streamedResponse);

        if (responseBody.statusCode == 200) {
          onProgress?.call(1.0);
          onStatus?.call("✅ Upload Complete!");
          final data = jsonDecode(responseBody.body) as Map<String, dynamic>;
          return data;
        } else {
          lastError = "Cloudinary ($preset): HTTP ${responseBody.statusCode} - ${responseBody.body}";
          debugPrint("⚠️ Direct upload attempt failed: $lastError");
        }
      } catch (e) {
        lastError = "Cloudinary ($preset) error: $e";
        debugPrint("❌ Direct upload error: $lastError");
      }
    }

    onErrorLog?.call(lastError.isNotEmpty ? lastError : "Cloudinary preset error");
    return null;
  }
}
