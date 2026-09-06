import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  final String cloudName = "fka9mgwu";
  final String uploadPreset = "clips_preset";

  Future<String?> uploadVideo(File videoFile) async {
    var url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/video/upload");
    
    var request = http.MultipartRequest("POST", url);
    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = 'clip';
    
    request.files.add(await http.MultipartFile.fromPath('file', videoFile.path));

    var response = await request.send();
    var res = await response.stream.bytesToString();
    var jsonMap = json.decode(res);

    if (response.statusCode == 200) {
      return jsonMap['secure_url'];
    } else {
      print("Cloudinary Error: $res");
      return null;
    }
  }
}