import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = "fka9mgwu";
  static const String uploadPreset = "clips_preset";

  static Future<String?> uploadFile({required File file, required String folder}) async {
    try {
      final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");
      var request = http.MultipartRequest("POST", uri);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      var response = await request.send();
      var resBody = await http.Response.fromStream(response);
      var data = jsonDecode(resBody.body);
      if (data['secure_url'] != null) {
        return data['secure_url'];
      } else {
        print("Upload failed: ${resBody.body}");
        return null;
      }
    } catch (e) {
      print("Error: $e");
      return null;
    }
  }

  // Compatibility helpers for video and media
  static Future<String> uploadVideo(File file) async {
    final url = await uploadFile(file: file, folder: 'gamer_clips');
    if (url == null) throw Exception('Video upload failed');
    return url;
  }

  static Future<String> uploadMedia(File file, {bool isVideo = true}) async {
    final url = await uploadFile(file: file, folder: isVideo ? 'gamer_clips' : 'match_proofs');
    if (url == null) throw Exception('Media upload failed');
    return url;
  }
}
