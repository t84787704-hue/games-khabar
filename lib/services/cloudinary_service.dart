import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // Cloudinary credentials & presets
  static const String cloudName = "fka9mgwu";
  static const String uploadPreset = "gaming_clips_preset";

  /// Upload image/file to Cloudinary for avatars, banners, and match proofs
  static Future<String?> uploadFile({required File file, required String folder}) async {
    try {
      final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");
      final request = http.MultipartRequest("POST", uri);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final resBody = await http.Response.fromStream(response);
      final data = jsonDecode(resBody.body) as Map<String, dynamic>;

      if (data['secure_url'] != null) {
        return data['secure_url'].toString();
      } else {
        debugPrint("Cloudinary upload failed: ${resBody.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Cloudinary upload error: $e");
      return null;
    }
  }
}
