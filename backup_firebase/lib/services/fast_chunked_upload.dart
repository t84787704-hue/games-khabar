import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'fast_compress.dart';
import 'supabase_service.dart';

/// High-Speed Parallel Uploader for Gaming Video Clips
/// Primary: Supabase Storage
/// Secondary: Firebase Storage fallback.
class FastChunkedUploadService {
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
    File actualFile = file;
    int fileSize = await actualFile.length();
    double fileSizeMB = fileSize / (1024 * 1024);

    debugPrint("🚀 [FAST_UPLOAD] Preparing to upload ${fileSizeMB.toStringAsFixed(1)} MB video");
    final List<String> errorLogs = [];

    // If video is > 20MB and not already compressed, optimize it before upload
    final bool alreadyCompressed = actualFile.path.contains('compressed_');
    final bool needsOptimization = fileSizeMB > 20.0 && !alreadyCompressed;
    if (needsOptimization) {
      debugPrint("⚡ [FAST_UPLOAD] Video is ${fileSizeMB.toStringAsFixed(1)}MB (>20MB). Optimizing before upload...");
      onStatus?.call("⚡ Optimizing video for upload...");
      actualFile = await FastCompressService.compressGamingVideo(
        actualFile,
        onProgress: (p) => onProgress?.call((p * 0.25).clamp(0.05, 0.25)),
        onStatus: onStatus,
      );
      fileSize = await actualFile.length();
      fileSizeMB = fileSize / (1024 * 1024);
      debugPrint("⚡ [FAST_UPLOAD] New size after optimization: ${fileSizeMB.toStringAsFixed(1)} MB");
    }

    // 1. Primary: Supabase Storage Upload
    onStatus?.call("🚀 Uploading to Supabase Storage...");
    final effectiveProgressCallback = (double p) {
      final effectiveProg = needsOptimization ? (0.25 + (p * 0.73)).clamp(0.25, 0.99) : p;
      onProgress?.call(effectiveProg);
    };
    effectiveProgressCallback(0.3);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoFileName = 'clip_${timestamp}_${Random().nextInt(99999)}.mp4';
      final supabaseUrl = await SupabaseService.uploadFile(
        file: actualFile,
        folder: 'clips',
        bucket: SupabaseService.bucketUploads,
        customFileName: videoFileName,
      );

      if (supabaseUrl != null && supabaseUrl.isNotEmpty) {
        onProgress?.call(1.0);
        onStatus?.call("✅ Upload Complete!");
        return {
          'secure_url': supabaseUrl,
          'url': supabaseUrl,
          'public_id': videoFileName,
          'format': 'mp4',
          'bytes': fileSize,
        };
      }
    } catch (e) {
      debugPrint("⚠️ Supabase video upload notice: $e");
      errorLogs.add("Supabase: $e");
    }

    if (_isCancelled) return null;

    // 2. Secondary: Firebase Storage Fallback
    debugPrint("⚠️ Supabase upload notice. Trying Firebase Storage fallback...");
    final fbResult = await _uploadToFirebaseStorage(
      file: actualFile,
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

    // If all failed, format a clear, user-friendly error
    String failureSummary = errorLogs.isNotEmpty
        ? errorLogs.last
        : "Internet connection error. Please check your network.";

    if (failureSummary.contains("Failed host lookup") ||
        failureSummary.contains("SocketException") ||
        failureSummary.contains("No address associated with hostname") ||
        failureSummary.contains("ClientException") ||
        failureSummary.contains("Network error")) {
      failureSummary = "Internet connection error. Please check your WiFi or mobile data and try again.";
    }

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
}
