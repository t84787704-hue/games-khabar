import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// High-Speed Chunked & Parallel Uploader for Cloudinary Video
/// Supports files up to 1000MB via chunked streaming (8-10MB chunks).
/// Provides TikTok-style real-time percentage progress.
class FastChunkedUploadService {
  static const String cloudName = "fka9mgwu";
  static const String uploadPreset = "gaming_clips_preset";
  static const int defaultChunkSize = 8 * 1024 * 1024; // 8MB chunks

  static bool _isCancelled = false;

  static void cancel() {
    _isCancelled = true;
    debugPrint("🛑 [FAST_UPLOAD] Upload cancelled by user");
  }

  /// Upload video file with TikTok-style fast chunking or direct stream
  static Future<Map<String, dynamic>?> uploadVideo({
    required File file,
    String? caption,
    String? gameTag,
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    _isCancelled = false;
    final int fileSize = await file.length();
    final double fileSizeMB = fileSize / (1024 * 1024);

    debugPrint("🚀 [FAST_UPLOAD] Preparing to upload ${fileSizeMB.toStringAsFixed(1)} MB video");

    // Strategy 1: Direct single multipart upload if under 20MB
    if (fileSize <= 20 * 1024 * 1024) {
      return await _directStreamUpload(
        file: file,
        fileSize: fileSize,
        caption: caption,
        gameTag: gameTag,
        onProgress: onProgress,
        onStatus: onStatus,
      );
    }

    // Strategy 2: Chunked Upload for larger files
    return await _chunkedUpload(
      file: file,
      fileSize: fileSize,
      caption: caption,
      gameTag: gameTag,
      onProgress: onProgress,
      onStatus: onStatus,
    );
  }

  /// Single stream upload with progress tracking for smaller files (< 20MB)
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
      final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/video/upload");
      final request = http.MultipartRequest("POST", uri);

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'gaming_clips';
      request.fields['quality'] = 'auto:eco';
      request.fields['fetch_format'] = 'auto';
      if (gameTag != null) request.fields['tags'] = 'gaming,$gameTag';
      if (caption != null && caption.isNotEmpty) {
        request.fields['context'] = 'caption=${caption.replaceAll("|", " ")}|gameTag=${gameTag ?? ""}';
      }

      int bytesSent = 0;
      final fileStream = file.openRead();

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
        filename: file.path.split(Platform.pathSeparator).last,
      );

      request.files.add(multipartFile);

      final streamedResponse = await request.send();
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

  /// Cloudinary standard chunked upload with Content-Range & X-Unique-Upload-Id
  static Future<Map<String, dynamic>?> _chunkedUpload({
    required File file,
    required int fileSize,
    String? caption,
    String? gameTag,
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    final String uploadId = 'cloud_chunk_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final int chunkSize = defaultChunkSize;
    final int totalChunks = (fileSize / chunkSize).ceil();
    final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/video/upload");

    debugPrint("📦 [CHUNKED_UPLOAD] Uploading $fileSize bytes in $totalChunks chunks (ID: $uploadId)");

    final randomAccessFile = await file.open(mode: FileMode.read);
    Map<String, dynamic>? finalResponseData;

    try {
      for (int i = 0; i < totalChunks; i++) {
        if (_isCancelled) {
          debugPrint("🛑 Chunked upload stopped by cancellation");
          await randomAccessFile.close();
          return null;
        }

        final int startByte = i * chunkSize;
        final int endByte = min(startByte + chunkSize, fileSize);
        final int currentChunkLength = endByte - startByte;

        await randomAccessFile.setPosition(startByte);
        final List<int> chunkBytes = await randomAccessFile.read(currentChunkLength);

        onStatus?.call("🚀 Uploading Part ${i + 1}/$totalChunks (${((startByte / fileSize) * 100).toInt()}%)...");

        final request = http.MultipartRequest("POST", uri);
        request.headers['X-Unique-Upload-Id'] = uploadId;
        request.headers['Content-Range'] = 'bytes $startByte-${endByte - 1}/$fileSize';

        request.fields['upload_preset'] = uploadPreset;
        request.fields['folder'] = 'gaming_clips';
        request.fields['quality'] = 'auto:eco';
        request.fields['fetch_format'] = 'auto';
        if (gameTag != null) request.fields['tags'] = 'gaming,$gameTag';
        if (caption != null && caption.isNotEmpty) {
          request.fields['context'] = 'caption=${caption.replaceAll("|", " ")}|gameTag=${gameTag ?? ""}';
        }

        request.files.add(http.MultipartFile.fromBytes(
          'file',
          chunkBytes,
          filename: 'chunk_${i}_${file.path.split(Platform.pathSeparator).last}',
        ));

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        final double overallProgress = (endByte / fileSize).clamp(0.0, 0.99);
        onProgress?.call(overallProgress);

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body) as Map<String, dynamic>;
          // On the final chunk, Cloudinary returns the full object with secure_url
          if (resData['secure_url'] != null) {
            finalResponseData = resData;
            break;
          }
        } else if (response.statusCode != 200 && response.statusCode != 206) {
          debugPrint("⚠️ Chunk $i failed with status ${response.statusCode}: ${response.body}");
          await randomAccessFile.close();
          return null;
        }
      }

      await randomAccessFile.close();

      if (finalResponseData != null) {
        onProgress?.call(1.0);
        onStatus?.call("✅ Complete!");
        return finalResponseData;
      }
      return null;
    } catch (e) {
      debugPrint("❌ [CHUNKED_UPLOAD] Error: $e");
      try {
        await randomAccessFile.close();
      } catch (_) {}
      return null;
    }
  }
}
