import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;
  final double duration;
  final int width;
  final int height;
  final String thumbnailUrl;

  CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    required this.duration,
    required this.width,
    required this.height,
    required this.thumbnailUrl,
  });
}

class CloudinaryService {
  // Cloudinary credentials & presets
  static const String cloudName = "fka9mgwu";
  static const String gamingClipsPreset = "clips_preset";
  static const String fallbackPreset = "gaming_clips_preset";

  /// Generates an auto video thumbnail from Cloudinary URL
  static String getAutoThumbnailUrl(String secureUrl) {
    if (secureUrl.isEmpty) return '';
    try {
      if (secureUrl.contains('/video/upload/')) {
        return secureUrl
            .replaceAll('/video/upload/', '/video/upload/so_1,w_400,h_700,c_fill/')
            .replaceAll(RegExp(r'\.(mp4|mov|mkv|webm)(\?.*)?$', caseSensitive: false), '.jpg');
      }
    } catch (_) {}
    return secureUrl;
  }

  /// Uploads video to Cloudinary with real-time progress stream & optional cancellation
  static Future<CloudinaryUploadResult> uploadVideoWithProgress({
    required File file,
    required String userId,
    String? gameTag,
    String? caption,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = http.Client();
    try {
      // Try gaming_clips_preset first, fall back to clips_preset if needed
      return await _performVideoUpload(
        client: client,
        file: file,
        preset: gamingClipsPreset,
        userId: userId,
        gameTag: gameTag,
        caption: caption,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    } catch (e) {
      debugPrint('⚠️ [CLOUDINARY] Primary preset failed ($e), retrying with fallback preset...');
      return await _performVideoUpload(
        client: client,
        file: file,
        preset: fallbackPreset,
        userId: userId,
        gameTag: gameTag,
        caption: caption,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    } finally {
      client.close();
    }
  }

  static Future<CloudinaryUploadResult> _performVideoUpload({
    required http.Client client,
    required File file,
    required String preset,
    required String userId,
    String? gameTag,
    String? caption,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/video/upload");
    final fileSize = await file.length();

    debugPrint('🚀 [CLOUDINARY] Uploading video (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB) to $uri with preset $preset');

    final request = http.MultipartRequest("POST", uri);
    request.fields['upload_preset'] = preset;
    request.fields['folder'] = 'gaming_clips/$userId';
    request.fields['tags'] = 'gaming,${gameTag ?? "bgmi"},$userId';
    if (caption != null && caption.isNotEmpty) {
      request.fields['context'] = 'caption=${caption.replaceAll("|", " ")}|gameTag=${gameTag ?? ""}';
    }

    // Wrap file stream to report real progress
    int bytesSent = 0;
    final fileStream = file.openRead();
    final progressStream = fileStream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          if (isCancelled != null && isCancelled()) {
            sink.addError(Exception('Upload cancelled by user'));
            return;
          }
          bytesSent += data.length;
          sink.add(data);
          if (onProgress != null && fileSize > 0) {
            final progress = (bytesSent / fileSize).clamp(0.0, 0.98);
            onProgress(progress);
          }
        },
      ),
    );

    final filename = file.path.split('/').last;
    final multipartFile = http.MultipartFile(
      'file',
      progressStream,
      fileSize,
      filename: filename.isNotEmpty ? filename : 'clip.mp4',
    );
    request.files.add(multipartFile);

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    print("CLOUDINARY STATUS: ${response.statusCode}");
    debugPrint("CLOUDINARY STATUS: ${response.statusCode}");

    if (isCancelled != null && isCancelled()) {
      throw Exception('Upload cancelled by user');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = data['secure_url']?.toString() ?? '';
      final publicId = data['public_id']?.toString() ?? '';
      final duration = (data['duration'] as num?)?.toDouble() ?? 0.0;
      final width = (data['width'] as num?)?.toInt() ?? 720;
      final height = (data['height'] as num?)?.toInt() ?? 1280;

      if (secureUrl.isEmpty) {
        throw Exception('Cloudinary upload returned empty secure_url: ${response.body}');
      }

      onProgress?.call(1.0);

      final thumb = getAutoThumbnailUrl(secureUrl);
      debugPrint('✅ [CLOUDINARY] Upload success! URL: $secureUrl, duration: $duration s, thumb: $thumb');

      return CloudinaryUploadResult(
        secureUrl: secureUrl,
        publicId: publicId,
        duration: duration,
        width: width,
        height: height,
        thumbnailUrl: thumb,
      );
    } else {
      debugPrint('❌ [CLOUDINARY] Upload failed with status ${response.statusCode}: ${response.body}');
      throw Exception('Cloudinary upload error (${response.statusCode}): ${response.body}');
    }
  }

  /// Legacy helper for quick upload
  static Future<String?> uploadFile({required File file, required String folder}) async {
    try {
      final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");
      var request = http.MultipartRequest("POST", uri);
      request.fields['upload_preset'] = fallbackPreset;
      request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      var response = await request.send();
      var resBody = await http.Response.fromStream(response);
      var data = jsonDecode(resBody.body);
      if (data['secure_url'] != null) {
        return data['secure_url'];
      } else {
        debugPrint("Upload failed: ${resBody.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error: $e");
      return null;
    }
  }

  // Compatibility helpers
  static Future<String> uploadVideo(File file) async {
    final res = await uploadVideoWithProgress(file: file, userId: 'legacy');
    return res.secureUrl;
  }

  static Future<String> uploadMedia(File file, {bool isVideo = true}) async {
    final url = await uploadFile(file: file, folder: isVideo ? 'gamer_clips' : 'match_proofs');
    if (url == null) throw Exception('Media upload failed');
    return url;
  }
}
