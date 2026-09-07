import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Cloudinary Configuration and Service for Gaming Clips
/// Handles 100% unsigned direct uploads to Cloudinary (ZERO Firebase Storage, ZERO API Secret).
class CloudinaryService {
  // Cloudinary Configuration - Set your Cloud Name and Unsigned Preset here
  static String cloudName = 'dkmvqp9xr'; // Replace with your Cloudinary Cloud Name
  static String uploadPreset = 'gamer_clips_preset'; // Replace with your unsigned preset (must allow video)
  static String folder = 'clips';

  // 25GB Free Tier Protection: Max 50MB per clip
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB

  CloudinaryService({
    String? customCloudName,
    String? customUploadPreset,
    String? customFolder,
  }) {
    if (customCloudName != null && customCloudName.isNotEmpty) {
      cloudName = customCloudName;
    }
    if (customUploadPreset != null && customUploadPreset.isNotEmpty) {
      uploadPreset = customUploadPreset;
    }
    if (customFolder != null && customFolder.isNotEmpty) {
      folder = customFolder;
    }
  }

  /// Uploads video directly to Cloudinary via unsigned POST MultipartRequest:
  /// Endpoint: https://api.cloudinary.com/v1_1/<cloudName>/video/upload
  /// Returns the HTTPS [secure_url] from Cloudinary response.
  Future<String> uploadVideo({
    required File file,
    String? customFileName,
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
          'Video size ($mb MB) exceeds the 50MB free-tier limit. '
          'Please compress or trim your clip.',
        );
      }

      // 3. API endpoint for video upload
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');

      print('🚀 [CLOUDINARY] Uploading video to: $uri');
      print('📁 [CLOUDINARY] Cloud Name: "$cloudName", Preset: "$uploadPreset", Folder: "$folder"');
      print('📦 [CLOUDINARY] File size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');

      // 4. Create Multipart Request
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;

      // Attach video file
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
      );
      request.files.add(multipartFile);

      // 5. Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          throw Exception('Cloudinary upload timed out. Please check your internet connection and try again.');
        },
      );

      final responseBody = await streamedResponse.stream.bytesToString();

      // 6. Handle response and extract secure_url
      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;

        if (secureUrl != null && secureUrl.isNotEmpty) {
          print('✅ [CLOUDINARY] Video upload SUCCESS!');
          print('🔗 [CLOUDINARY] Secure URL: $secureUrl');
          return secureUrl;
        } else {
          print('❌ [CLOUDINARY] Upload response missing secure_url: $responseBody');
          throw Exception('Cloudinary upload succeeded but no secure_url was returned.');
        }
      } else {
        String errorMessage = 'Cloudinary upload failed with HTTP ${streamedResponse.statusCode}';
        try {
          final Map<String, dynamic> errorData = jsonDecode(responseBody);
          if (errorData.containsKey('error') && errorData['error'] is Map) {
            errorMessage = errorData['error']['message'] ?? errorMessage;
          }
        } catch (_) {
          errorMessage = '$errorMessage: $responseBody';
        }
        print('❌ [CLOUDINARY] Upload FAILED: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ [CLOUDINARY] Exception in uploadVideo: $e');
      rethrow;
    }
  }

  /// Uploads media (video or image) to Cloudinary
  Future<String> uploadMedia({
    required File file,
    bool isVideo = true,
  }) async {
    if (isVideo) {
      return uploadVideo(file: file);
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
        throw Exception('No secure_url returned from Cloudinary');
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
