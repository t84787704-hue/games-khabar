import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'fast_compress.dart';

/// High-Speed Chunked & Parallel Uploader for Gaming Video Clips
/// Primary: Multi-region Cloudinary HTTP streaming
/// Secondary: Firebase Storage fallback.
class FastChunkedUploadService {
  static const String cloudName = "fka9mgwu";
  static const String uploadPreset = "clips_preset";
  static const int defaultChunkSize = 6 * 1024 * 1024; // 6MB chunks for Cloudinary chunked upload (must be >= 5MB)

  /// Multi-regional Cloudinary endpoints:
  /// api-ap: Asia-Pacific (fastest & lowest latency for Pakistan/Asia users)
  /// api: Global / US
  /// api-eu: Europe
  static const List<String> cloudinaryHosts = [
    'api-ap.cloudinary.com',
    'api.cloudinary.com',
    'api-eu.cloudinary.com',
  ];

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

    Map<String, dynamic>? uploadResult;

    // 1. Direct Cloudinary High-Speed Stream (only for files <= 25MB)
    // Larger files must NEVER use single-part direct upload to avoid HTTP 413 Payload Too Large
    if (fileSize <= 25 * 1024 * 1024) {
      uploadResult = await _directStreamUpload(
        file: actualFile,
        fileSize: fileSize,
        caption: caption,
        gameTag: gameTag,
        onProgress: (p) {
          final effectiveProg = needsOptimization ? (0.25 + (p * 0.73)).clamp(0.25, 0.99) : p;
          onProgress?.call(effectiveProg);
        },
        onStatus: onStatus,
        onErrorLog: (err) => errorLogs.add(err),
      );
    }

    if (uploadResult != null) {
      return uploadResult;
    }

    // 2. Chunked Cloudinary Upload (handles files of any size split into safe 6MB parts)
    debugPrint("📦 Attempting Cloudinary chunked upload for ${fileSizeMB.toStringAsFixed(1)}MB video...");
    uploadResult = await _chunkedCloudinaryUpload(
      file: actualFile,
      fileSize: fileSize,
      caption: caption,
      gameTag: gameTag,
      onProgress: (p) {
        final effectiveProg = needsOptimization ? (0.25 + (p * 0.73)).clamp(0.25, 0.99) : p;
        onProgress?.call(effectiveProg);
      },
      onStatus: onStatus,
      onErrorLog: (err) => errorLogs.add(err),
    );

    if (uploadResult != null) {
      return uploadResult;
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
    );

    if (fbResult != null) {
      return fbResult;
    }

    // If all failed, format a clear, user-friendly error
    String failureSummary = errorLogs.isNotEmpty
        ? errorLogs.last
        : "Internet connection error. Please check your network.";

    for (final err in errorLogs) {
      if (err.contains("413") ||
          err.contains("File size too large") ||
          err.contains("104857600") ||
          err.contains("Request Entity Too Large")) {
        failureSummary = "Video file is too large (max 100MB). Please select a clip under 3 minutes.";
        break;
      }
    }

    if (failureSummary.contains("Failed host lookup") ||
        failureSummary.contains("SocketException") ||
        failureSummary.contains("No address associated with hostname") ||
        failureSummary.contains("ClientException") ||
        failureSummary.contains("Network error")) {
      failureSummary = "Internet connection error. Please check your WiFi or mobile data and try again.";
    } else if (failureSummary.contains("413")) {
      failureSummary = "Video file is too large. Please select a clip under 3 minutes.";
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
    final originalFileName = file.path.split(Platform.pathSeparator).last;
    final cleanFileName = originalFileName.isNotEmpty ? originalFileName : 'screen_recording.mp4';

    RandomAccessFile? raf;
    http.Client? client;
    try {
      client = http.Client();
      raf = await file.open(mode: FileMode.read);
      int start = 0;
      int chunkIndex = 0;
      final totalChunks = (fileSize / chunkSize).ceil();
      Map<String, dynamic>? lastResponseData;
      // Use Asia-Pacific as primary for Pakistan/Asia
      final host = cloudinaryHosts.first;
      final url = Uri.parse("https://$host/v1_1/$cloudName/video/upload");

      while (start < fileSize) {
        if (_isCancelled) {
          await raf.close();
          client.close();
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
        request.fields['folder'] = 'gamer_videos';
        request.fields['resource_type'] = 'video';
        if (gameTag != null && gameTag.isNotEmpty) {
          request.fields['tags'] = 'gaming,$gameTag';
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            chunkBytes,
            filename: cleanFileName,
            contentType: MediaType('video', 'mp4'),
          ),
        );

        final streamed = await client.send(request).timeout(const Duration(minutes: 3));
        final resp = await http.Response.fromStream(streamed);

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          lastResponseData = data;
          debugPrint("✅ [CHUNKED_UPLOAD] Part ${chunkIndex + 1}/$totalChunks uploaded successfully");
        } else {
          String err = "Cloudinary Chunk $chunkIndex failed: HTTP ${resp.statusCode}";
          try {
            final json = jsonDecode(resp.body);
            if (json['error']?['message'] != null) {
              err = json['error']['message'];
            }
          } catch (_) {}
          debugPrint("⚠️ [CHUNKED_UPLOAD] $err");
          onErrorLog?.call(err);
          await raf.close();
          client.close();
          return null;
        }

        start = end;
        chunkIndex++;
      }

      await raf.close();
      client.close();

      if (lastResponseData != null && lastResponseData['secure_url'] != null) {
        onProgress?.call(1.0);
        onStatus?.call("✅ Upload Complete!");
        return lastResponseData;
      }
    } catch (e) {
      try {
        await raf?.close();
      } catch (_) {}
      client?.close();
      debugPrint("⚠️ [CHUNKED_UPLOAD] Error: $e");
      onErrorLog?.call("Chunked upload: $e");
    }

    return null;
  }

  /// Single stream upload with progress tracking and multi-regional fallback
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

      for (final host in cloudinaryHosts) {
        if (_isCancelled) return null;

        http.Client? client;
        try {
          onStatus?.call("🚀 Uploading (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB)...");
          final uri = Uri.parse("https://$host/v1_1/$cloudName/video/upload");
          final request = http.MultipartRequest("POST", uri);

          request.fields['upload_preset'] = preset;
          request.fields['folder'] = 'gamer_videos';
          request.fields['resource_type'] = 'video';
          if (gameTag != null && gameTag.isNotEmpty) {
            request.fields['tags'] = 'gaming,$gameTag';
          }

          int bytesSent = 0;
          final fileStream = file.openRead();
          final cleanUploadFilename = 'clip_${DateTime.now().millisecondsSinceEpoch}.mp4';

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
            filename: cleanUploadFilename,
            contentType: MediaType('video', 'mp4'),
          );

          request.files.add(multipartFile);

          client = http.Client();
          final streamedResponse = await client.send(request).timeout(const Duration(minutes: 4));
          final responseBody = await http.Response.fromStream(streamedResponse);

          if (responseBody.statusCode == 200) {
            onProgress?.call(1.0);
            onStatus?.call("✅ Upload Complete!");
            final data = jsonDecode(responseBody.body) as Map<String, dynamic>;
            client.close();
            return data;
          } else {
            String cleanMsg;
            try {
              final json = jsonDecode(responseBody.body);
              cleanMsg = json['error']?['message'] ?? "Upload failed (${responseBody.statusCode})";
            } catch (_) {
              if (responseBody.statusCode == 413) {
                cleanMsg = "Video file exceeds direct upload size limit (413)";
              } else {
                cleanMsg = "Upload error (${responseBody.statusCode})";
              }
            }
            lastError = cleanMsg;
            debugPrint("⚠️ Direct upload attempt failed on $host: $lastError");
            if (responseBody.statusCode == 400 && cleanMsg.contains("File size too large")) {
              onErrorLog?.call(lastError);
              client.close();
              return null;
            }
          }
        } catch (e) {
          lastError = "Network error: $e";
          debugPrint("❌ Direct upload error on $host: $lastError");
        } finally {
          client?.close();
        }

        // Brief delay before trying next host
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    onErrorLog?.call(lastError.isNotEmpty ? lastError : "Cloudinary upload failed");
    return null;
  }
}
