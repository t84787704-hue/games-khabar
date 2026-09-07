import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Cloudinary Configuration and Service for Gaming Clips
/// Handles 100% unsigned direct uploads to Cloudinary (ZERO Firebase Storage, ZERO API Secret).
class CloudinaryService {
  // Cloudinary Configuration - Updated with your console credentials
  static String cloudName = 'fka9mgwu'; // Your Cloudinary cloud name
  static String uploadPreset = 'gamer_clips_preset'; // Your unsigned video upload preset
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
        final err = 'Video size ($mb MB) exceeds 50MB free-tier limit. Please trim or compress video.';
        print('❌ [CLOUDINARY] $err');
        throw Exception(err);
      }

      // 3. API endpoint for video upload
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$activeCloudName/video/upload');

      print('🚀 [CLOUDINARY] POST to: $uri');
      print('📁 [CLOUDINARY] cloud_name: "$activeCloudName", upload_preset: "$activePreset", folder: "$activeFolder"');
      print('📦 [CLOUDINARY] Uploading ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB video...');

      // 4. Create Multipart Request
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = activePreset;
      request.fields['folder'] = activeFolder;

      // Attach file
      final multipartFile = await http.MultipartFile.fromPath('file', file.path);
      request.files.add(multipartFile);

      // 5. Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          print('❌ [CLOUDINARY] Request timed out after 3 minutes');
          throw Exception('Cloudinary upload timed out. Please check your internet connection.');
        },
      );

      final responseBody = await streamedResponse.stream.bytesToString();

      // 6. Handle response and extract secure_url
      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;

        if (secureUrl != null && secureUrl.isNotEmpty) {
          print('✅ [CLOUDINARY] Upload SUCCESS!');
          print('🔗 [CLOUDINARY] secure_url: $secureUrl');
          return secureUrl;
        } else {
          print('❌ [CLOUDINARY] No secure_url found in response: $responseBody');
          throw Exception('Cloudinary upload succeeded but returned no secure_url.');
        }
      } else {
        String errorMessage = 'Cloudinary upload failed (HTTP ${streamedResponse.statusCode})';
        try {
          final Map<String, dynamic> errorData = jsonDecode(responseBody);
          if (errorData.containsKey('error') && errorData['error'] is Map) {
            errorMessage = errorData['error']['message'] ?? errorMessage;
          }
        } catch (_) {
          errorMessage = '$errorMessage: $responseBody';
        }
        print('❌ [CLOUDINARY] Error response: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ [CLOUDINARY] Exception: $e');
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

      final streamedResponse = await request.send().timeout(const Duration(minutes: 2));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
          print('✅ [CLOUDINARY] Image upload SUCCESS: $secureUrl');
          return secureUrl;
        }
        throw Exception('No secure_url returned from Cloudinary.');
      } else {
        print('❌ [CLOUDINARY] Image upload failed: $responseBody');
        throw Exception('Cloudinary image upload failed: $responseBody');
      }
    } catch (e) {
      print('❌ [CLOUDINARY] Exception in uploadMedia: $e');
      rethrow;
    }
  }
}
