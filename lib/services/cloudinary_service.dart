import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // Cloudinary credentials & presets
  static const String cloudName = "fka9mgwu";
  static const String uploadPreset = "clips_preset";

  /// Upload image/file to Cloudinary for avatars, banners, and match proofs
  static Future<String?> uploadFile({required File file, required String folder}) async {
    final presets = [uploadPreset, "gaming_clips_preset", "clips"];
    for (final preset in presets) {
      try {
        final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");
        final request = http.MultipartRequest("POST", uri);
        request.fields['upload_preset'] = preset;
        request.fields['folder'] = folder;
        request.files.add(await http.MultipartFile.fromPath('file', file.path));

        final response = await request.send().timeout(const Duration(minutes: 2));
        final resBody = await http.Response.fromStream(response);
        final data = jsonDecode(resBody.body) as Map<String, dynamic>;

        if (data['secure_url'] != null) {
          return data['secure_url'].toString();
        } else {
          debugPrint("Cloudinary ($preset) upload failed: ${resBody.body}");
        }
      } catch (e) {
        debugPrint("Cloudinary ($preset) upload error: $e");
      }
    }
    return null;
  }
}
