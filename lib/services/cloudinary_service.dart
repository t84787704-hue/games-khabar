import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cloudinary Configuration and Service for Gaming Clips
/// Handles 100% unsigned direct uploads to Cloudinary (No Firebase Storage, No API Secret needed).
class CloudinaryService {
  // Cloudinary Configuration variables
  String cloudName = 'dkmvqp9xr'; // Replace with your Cloudinary cloud name
  String uploadPreset = 'gamer_clips_preset'; // Replace with your unsigned upload preset
  String folder = 'clips';

  // 25GB Free Tier Protection: 50MB max per clip
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB

  CloudinaryService({
    String? cloudName,
    String? uploadPreset,
    String? folder,
  }) {
    if (cloudName != null) this.cloudName = cloudName;
    if (uploadPreset != null) this.uploadPreset = uploadPreset;
    if (folder != null) this.folder = folder;
  }

  /// Uploads video directly to Cloudinary using unsigned upload via http.MultipartRequest.
  /// Endpoint: https://api.cloudinary.com/v1_1/{cloudName}/video/upload
  /// Returns the HTTPS [secure_url] from Cloudinary response.
  Future<String> uploadVideo({
    required File file,
    String? userId,
  }) async {
    try {
      // 1. Validate file exists
      if (!await file.exists()) {
        throw Exception('Selected video file does not exist on device.');
      }

      // 2. 25GB Free Limit Guard: Check file size
      final fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        final mb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        throw Exception(
          'Video size ($mb MB) exceeds the 50MB limit. '
          'Please compress or trim your video to preserve Cloudinary free quota.',
        );
      }

      // 3. API endpoint for unsigned video upload
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');

      // 4. Create Multipart Request
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;

      if (userId != null && userId.isNotEmpty) {
        request.fields['public_id'] = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Attach file
      final multipartFile = await http.MultipartFile.fromPath('file', file.path);
      request.files.add(multipartFile);

      debugPrint('Cloudinary: Uploading video (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB) to $uri...');

      // 5. Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          throw Exception('Cloudinary upload timed out. Please check your internet connection.');
        },
      );

      final responseBody = await streamedResponse.stream.bytesToString();

      // 6. Handle response and return secure_url
      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;

        if (secureUrl != null && secureUrl.isNotEmpty) {
          debugPrint('Cloudinary: Upload success! secure_url: $secureUrl');
          return secureUrl;
        } else {
          throw Exception('Cloudinary upload succeeded but no secure_url was returned in response.');
        }
      } else {
        String errorMessage = 'Cloudinary upload failed (Status ${streamedResponse.statusCode})';
        try {
          final Map<String, dynamic> errorData = jsonDecode(responseBody);
          if (errorData.containsKey('error') && errorData['error'] is Map) {
            errorMessage = errorData['error']['message'] ?? errorMessage;
          }
        } catch (_) {
          errorMessage = '$errorMessage: $responseBody';
        }
        debugPrint('Cloudinary upload error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('CloudinaryService.uploadVideo error: $e');
      rethrow;
    }
  }

  /// General media upload for video or image files
  Future<String> uploadMedia({
    required File file,
    bool isVideo = true,
    String? customPublicId,
  }) async {
    if (isVideo) {
      return uploadVideo(file: file, userId: customPublicId);
    }

    try {
      if (!await file.exists()) {
        throw Exception('Selected image file does not exist on device.');
      }

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;
      if (customPublicId != null && customPublicId.isNotEmpty) {
        request.fields['public_id'] = customPublicId;
      }

      final multipartFile = await http.MultipartFile.fromPath('file', file.path);
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(const Duration(minutes: 2));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
          return secureUrl;
        }
        throw Exception('Cloudinary upload succeeded but no secure_url was returned.');
      } else {
        throw Exception('Cloudinary image upload failed: $responseBody');
      }
    } catch (e) {
      debugPrint('CloudinaryService.uploadMedia error: $e');
      rethrow;
    }
  }
}
