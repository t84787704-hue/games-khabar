import 'dart:async';
import 'dart:io';
import 'supabase_service.dart';

/// Legacy CloudinaryService - Deprecated & Replaced with Supabase Storage.
/// All uploads are routed directly to Supabase Storage.
class CloudinaryService {
  /// Upload image/file directly to Supabase Storage.
  static Future<String?> uploadFile({required File file, required String folder}) async {
    return await SupabaseService.uploadFile(
      file: file,
      folder: folder,
      bucket: SupabaseService.bucketUploads,
    );
  }
}
