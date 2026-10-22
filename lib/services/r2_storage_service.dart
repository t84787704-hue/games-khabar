import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:minio_new/minio.dart';

class R2StorageService {
  static final R2StorageService _instance = R2StorageService._internal();
  factory R2StorageService() => _instance;
  R2StorageService._internal();

  static const String _accountId = '1cffac649ca0a4c545cf39588d0183d5';
  static const String _accessKey = 'F95ff7a33b51c33530b9e852b621d97d';
  static const String _secretKey = 'c0628471d57c7fb82be1e24b77b44b8e45c3f22e7253cc56945dc8c6f495b194';
  static const String _bucketName = 'gamersid-post';
  static const String _publicBaseUrl = 'https://pub-7a0250f08fb949a49663fef70e707.r2.dev';

  late final Minio _minioClient = Minio(
    endPoint: '$_accountId.r2.cloudflarestorage.com',
    accessKey: _accessKey,
    secretKey: _secretKey,
    useSSL: true,
  );

  /// Image upload karke Cloudflare R2 ka direct public link dega
  Future<String?> uploadImage({
    required File file,
    required String userId,
  }) async {
    try {
      final fileName = 'posts/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await file.readAsBytes();
      final stream = Stream.value(fileBytes);

      await _minioClient.putObject(
        _bucketName,
        fileName,
        stream,
        fileBytes.length,
        metadata: {
          'Content-Type': 'image/jpeg',
        },
      );

      final publicUrl = '$_publicBaseUrl/$fileName';
      return publicUrl;
    } catch (e) {
      debugPrint('[R2 Storage Error]: $e');
      return null;
    }
  }
}
