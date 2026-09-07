import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cloudinary Configuration and Service for Gaming Clips
/// Handles unsigned direct uploads to Cloudinary (no API Secret required on client).
class CloudinaryService {
  // Cloudinary Configuration
  // Note: Only cloudName and uploadPreset (unsigned) are used. NEVER expose API Secret in client code!
  static const String cloudName = 'dkmvqp9xr'; // Replace with your Cloudinary Cloud Name
  static const String uploadPreset = 'gamer_clips_preset'; // Unsigned upload preset enabled in Cloudinary Settings
  static const String folder = 'clips';

  // 25GB Free Tier Protection: Max 50MB per clip to prevent storage quota exhaustion
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB

  /// Uploads a video or image file directly to Cloudinary using unsigned upload.
  /// Returns the HTTPS [secure_url] from Cloudinary response.
  Future<String> uploadMedia({
    required File file,
    bool isVideo = true,
    String? customPublicId,
  }) async {
    try {
      // 1. Validate File Existence
      if (!await file.exists()) {
        throw Exception('Selected media file does not exist on device.');
      }

      // 2. 25GB Free Limit Guard: Check file size
      final fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        final mb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        throw Exception(
          'File size ($mb MB) exceeds the 50MB limit. '
          'Please trim or compress the clip to preserve cloud storage quota.',
        );
      }

      // 3. Determine resource type: 'video', 'image', or 'auto'
      final resourceType = isVideo ? 'video' : 'image';
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

      // 4. Create Multipart Request
      final request = http.MultipartRequest('POST', uri);

      // Add Cloudinary unsigned upload parameters
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;

      if (customPublicId != null && customPublicId.isNotEmpty) {
        request.fields['public_id'] = customPublicId;
      }

      // Attach file
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
      );
      request.files.add(multipartFile);

      debugPrint('Cloudinary: Uploading ${isVideo ? "video" : "image"} (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB) to folder "$folder"...');

      // 5. Send Request
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          throw Exception('Upload timed out. Please check your internet connection and try again.');
        },
      );

      final responseBody = await streamedResponse.stream.bytesToString();

      // 6. Handle Response & Errors
      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final secureUrl = data['secure_url'] as String?;

        if (secureUrl != null && secureUrl.isNotEmpty) {
          debugPrint('Cloudinary: Upload successful! URL: $secureUrl');
          return secureUrl;
        } else {
          throw Exception('Cloudinary upload succeeded but no secure_url was returned in response.');
        }
      } else {
        // Parse error message from Cloudinary JSON
        String errorMessage = 'Cloudinary upload failed with status ${streamedResponse.statusCode}';
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
      debugPrint('CloudinaryService.uploadMedia error: $e');
      rethrow;
    }
  }
}
