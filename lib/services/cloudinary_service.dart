import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Cloudinary Configuration and Service for Gaming Clips
/// Handles 100% unsigned direct uploads to Cloudinary with strict 60-second timeout
/// (ZERO Firebase Storage, ZERO API Secret).
class CloudinaryService {
  // Cloudinary Configuration
  // Put your Cloudinary cloud_name and unsigned upload preset here:
  static String cloudName = 'fka9mgwu'; 
  static String uploadPreset = 'gamer_clips_preset'; // <-- Paste your Cloudinary unsigned preset name here
  static String folder = 'clips';

  // 25GB Free Tier Protection: Max 50MB per clip
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB

  /// Uploads video directly to Cloudinary using unsigned POST MultipartRequest:
  /// Endpoint: POST https://api.cloudinary.com/v1_1/<cloud_name>/video/upload
  /// Fields: upload_preset = unsigned preset, folder = clips
  /// Returns the HTTPS [secure_url] from Cloudinary response.
  static Future<String> uploadVideo(
    File file, {
    String? customCloudName,
    String? customPreset,
    String? customFolder,
  }) async {
    final activeCloudName = customCloudName ?? cloudName;
    final activePreset = customPreset ?? uploadPreset;
    final activeFolder = customFolder ?? folder;

    try {
      // 1. Validate file exists
      if (!await file.exists()) {
        final err = 'Selected video file does not exist on device: ${file.path}';
        print('❌ [CLOUDINARY] $err');
        throw Exception(err);
      }

      // 2. 25GB Free Limit Guard: Check file size
      final fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        final mb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        final err = 'Video size ($mb MB) exceeds 50MB limit. Please trim or compress video.';
        print('❌ [CLOUDINARY] $err');
        throw Exception(err);
      }

      // 3. API endpoint for video upload
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$activeCloudName/video/upload');

      print('🚀 [CLOUDINARY] Starting upload to: $uri');
      print('📁 [CLOUDINARY] Cloud Name: "$activeCloudName", Preset: "$activePreset", Folder: "$activeFolder"');
      print('📦 [CLOUDINARY] Video file size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');

      // 4. Create Multipart Request
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = activePreset;
      request.fields['folder'] = activeFolder;

      // Attach file
      final multipartFile = await http.MultipartFile.fromPath('file', file.path);
      request.files.add(multipartFile);

      // 5. Send request with strict 60-second timeout to prevent UI getting stuck
      print('⏳ [CLOUDINARY] Sending request to Cloudinary (timeout: 60s)...');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('❌ [CLOUDINARY] Connection timed out after 60 seconds!');
          throw Exception('Upload timed out after 60 seconds. Please check your internet connection and retry.');
        },
      );

      // 6. Read response body with 60-second timeout
      final response = await http.Response.fromStream(streamedResponse).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('❌ [CLOUDINARY] Timeout while reading Cloudinary response stream!');
          throw Exception('Timeout reading response from Cloudinary server.');
        },
      );

      final statusCode = response.statusCode;
      final responseBody = response.body;

      // Log exact status code and raw response body
      print('📡 [CLOUDINARY] HTTP Status Code: $statusCode');
      print('📄 [CLOUDINARY] Response Body: $responseBody');

      // 7. Handle response
      if (statusCode >= 200 && statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;

        if (secureUrl != null && secureUrl.isNotEmpty) {
          print('✅ [CLOUDINARY] Upload SUCCESS! URL: $secureUrl');
          return secureUrl;
        } else {
          print('❌ [CLOUDINARY] Missing secure_url in response body.');
          throw Exception('Cloudinary upload succeeded but no secure_url was returned: $responseBody');
        }
      } else {
        // Parse readable error message from Cloudinary JSON
        String errorMessage = 'Cloudinary upload failed with HTTP $statusCode';
        try {
          final Map<String, dynamic> errorData = jsonDecode(responseBody);
          if (errorData.containsKey('error') && errorData['error'] is Map) {
            errorMessage = errorData['error']['message'] ?? errorMessage;
          }
        } catch (_) {
          errorMessage = '$errorMessage: $responseBody';
        }

        print('❌ [CLOUDINARY] Upload ERROR: $errorMessage');

        // Helpful explanation if preset is wrong or signed
        if (errorMessage.toLowerCase().contains('preset') ||
            errorMessage.toLowerCase().contains('unsigned') ||
            statusCode == 400 ||
            statusCode == 401) {
          throw Exception(
            'Cloudinary Preset Error: "$errorMessage". '
            'Please verify that upload preset "$activePreset" is created and set to "Unsigned" in Cloudinary Console -> Settings -> Upload.',
          );
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ [CLOUDINARY] Exception in uploadVideo: $e');
      rethrow;
    }
  }

  /// General media upload for video or image files
  static Future<String> uploadMedia(
    File file, {
    bool isVideo = true,
  }) async {
    if (isVideo) {
      return uploadVideo(file);
    }

    try {
      if (!await file.exists()) {
        throw Exception('Selected image file does not exist on device.');
      }
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse).timeout(const Duration(seconds: 60));

      final statusCode = response.statusCode;
      final responseBody = response.body;
      print('📡 [CLOUDINARY] Image Status: $statusCode, Body: $responseBody');

      if (statusCode >= 200 && statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
          print('✅ [CLOUDINARY] Image upload SUCCESS: $secureUrl');
          return secureUrl;
        }
        throw Exception('No secure_url returned from Cloudinary.');
      } else {
        print('❌ [CLOUDINARY] Image upload failed: $responseBody');
        throw Exception('Cloudinary image upload failed (HTTP $statusCode): $responseBody');
      }
    } catch (e) {
      print('❌ [CLOUDINARY] Exception in uploadMedia: $e');
      rethrow;
    }
  }
}
