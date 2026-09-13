import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'fast_compress.dart';

/// High-Speed Chunked & Parallel Uploader for Gaming Video Clips
/// Primary: Firebase Storage native resumable upload with live byte-level progress.
/// Secondary: Cloudinary HTTP streaming fallback.
class FastChunkedUploadService {
  static const String cloudName = "fka9mgwu";
  static const String uploadPreset = "clips_preset";
  static const int defaultChunkSize = 6 * 1024 * 1024; // 6MB chunks for Cloudinary chunked upload (must be >= 5MB)

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

    final bool wasOptimized = fileSizeMB > 9.5;
    // If video is > 9.5MB (e.g. mobile game screen recordings), optimize it to fit within Cloudinary's 10MB limit
    if (wasOptimized) {
      debugPrint("⚡ [FAST_UPLOAD] Video is ${fileSizeMB.toStringAsFixed(1)}MB (>9.5MB). Optimizing before upload...");
      onStatus?.call("⚡ Optimizing video for upload...");
      actualFile = await FastCompressService.compressGamingVideo(
        actualFile,
        onProgress: (p) => onProgress?.call((p * 0.20).clamp(0.05, 0.20)),
        onStatus: onStatus,
      );
      fileSize = await actualFile.length();
      fileSizeMB = fileSize / (1024 * 1024);
      debugPrint("⚡ [FAST_UPLOAD] New size after optimization: ${fileSizeMB.toStringAsFixed(1)} MB");
    }

    // Direct Cloudinary High-Speed Upload
    Map<String, dynamic>? directResult = await _directStreamUpload(
      file: actualFile,
      fileSize: fileSize,
      caption: caption,
      gameTag: gameTag,
      onProgress: (p) {
        // If it was optimized, scale upload progress from 20% to 98%
        final effectiveProg = wasOptimized ? (0.20 + (p * 0.78)).clamp(0.20, 0.99) : p;
        onProgress?.call(effectiveProg);
      },
      onStatus: onStatus,
      onErrorLog: (err) => errorLogs.add(err),
    );

    if (directResult != null) {
      return directResult;
    }

    // 2. Fallback: If still > 10MB or direct failed, attempt chunked upload
    if (fileSize > 10 * 1024 * 1024) {
      debugPrint("📦 File is ${fileSizeMB.toStringAsFixed(1)}MB. Trying Cloudinary chunked upload...");
      directResult = await _chunkedCloudinaryUpload(
        file: actualFile,
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
    }

    // 3. Fallback to Firebase Storage
    debugPrint("⚠️ Cloudinary upload failed. Trying Firebase Storage fallback...");
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

    // If all failed, format a clear, informative error
    final failureSummary = errorLogs.isNotEmpty
        ? errorLogs.join(" | ")
        : "Upload failed. Please check network connection.";
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

  /// Cloudinary Chunked Upload for large gameplay recordings (>10MB).
  /// Sends the video in 6MB chunks with Content-Range headers.
  /// Extremely robust against connection drops or HTTP request size limits.
  static Future<Map<String, dynamic>?> _chunkedCloudinaryUpload({
    required File file,
    required int fileSize,
    String? caption,
    String? gameTag,
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
    Function(String error)? onErrorLog,
  }) async {
    final chunkSize = defaultChunkSize; // 6MB
    final uniqueId = 'upload_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/video/upload");
    final originalFileName = file.path.split(Platform.pathSeparator).last;
    final cleanFileName = originalFileName.isNotEmpty ? originalFileName : 'screen_recording.mp4';

    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      int start = 0;
      int chunkIndex = 0;
      final totalChunks = (fileSize / chunkSize).ceil();
      Map<String, dynamic>? lastResponseData;

      while (start < fileSize) {
        if (_isCancelled) {
          await raf.close();
          return null;
        }

        final end = min(start + chunkSize, fileSize);
        final currentChunkLength = end - start;

        await raf.setPosition(start);
        final chunkBytes = await raf.read(currentChunkLength);

        final chunkProg = (start / fileSize).clamp(0.0, 0.99);
        final pct = (chunkProg * 100).toInt();
        onProgress?.call(chunkProg);
        onStatus?.call("🚀 Uploading Part ${chunkIndex + 1}/$totalChunks ($pct%)...");

        final request = http.MultipartRequest("POST", url);
        request.headers['X-Unique-Upload-Id'] = uniqueId;
        request.headers['Content-Range'] = 'bytes $start-${end - 1}/$fileSize';

        request.fields['upload_preset'] = uploadPreset;
        request.fields['folder'] = 'gaming_clips';
        if (gameTag != null && gameTag.isNotEmpty) {
          request.fields['tags'] = 'gaming,$gameTag';
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            chunkBytes,
            filename: cleanFileName,
          ),
        );

        final streamed = await request.send().timeout(const Duration(minutes: 3));
        final resp = await http.Response.fromStream(streamed);

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          lastResponseData = data;
          debugPrint("✅ [CHUNKED_UPLOAD] Part ${chunkIndex + 1}/$totalChunks uploaded successfully");
        } else {
          final err = "Cloudinary Chunk $chunkIndex failed: HTTP ${resp.statusCode} - ${resp.body}";
          debugPrint("⚠️ [CHUNKED_UPLOAD] $err");
          onErrorLog?.call(err);
          await raf.close();
          return null;
        }

        start = end;
        chunkIndex++;
      }

      await raf.close();

      if (lastResponseData != null && lastResponseData['secure_url'] != null) {
        onProgress?.call(1.0);
        onStatus?.call("✅ Upload Complete!");
        return lastResponseData;
      }
    } catch (e) {
      try {
        await raf?.close();
      } catch (_) {}
      debugPrint("⚠️ [CHUNKED_UPLOAD] Error: $e");
      onErrorLog?.call("Chunked upload: $e");
    }

    return null;
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
    final presetsToTry = [uploadPreset];
    String lastError = "";

    for (final preset in presetsToTry) {
      if (_isCancelled) return null;
      try {
        onStatus?.call("🚀 Uploading (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB)...");
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
          String cleanMsg;
          try {
            final json = jsonDecode(responseBody.body);
            cleanMsg = json['error']?['message'] ?? responseBody.body;
          } catch (_) {
            cleanMsg = "HTTP ${responseBody.statusCode}";
          }
          lastError = "Cloudinary: $cleanMsg";
          debugPrint("⚠️ Direct upload attempt failed: $lastError");
        }
      } catch (e) {
        lastError = "Upload network error: $e";
        debugPrint("❌ Direct upload error: $lastError");
      }
    }

    onErrorLog?.call(lastError.isNotEmpty ? lastError : "Cloudinary upload failed");
    return null;
  }
}
