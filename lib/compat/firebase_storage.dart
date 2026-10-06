import 'dart:io';
import '../services/supabase_service.dart';

/// Compatibility layer for FirebaseStorage backed 100% by Supabase Storage
class FirebaseStorage {
  static final FirebaseStorage instance = FirebaseStorage._();
  FirebaseStorage._();

  Reference ref([String? path]) => Reference(path ?? '');
}

class Reference {
  final String path;
  Reference(this.path);

  Reference child(String segment) {
    final cleanPath = path.isEmpty ? segment : '$path/$segment';
    return Reference(cleanPath);
  }

  UploadTask putFile(File file, [SettableMetadata? metadata]) {
    final future = _upload(file, metadata);
    return UploadTask(this, future);
  }

  Future<String> _upload(File file, SettableMetadata? metadata) async {
    String bucket = SupabaseService.bucketUploads;
    if (path.contains('avatar') || path.contains('profile')) {
      bucket = SupabaseService.bucketAvatars;
    } else if (path.contains('cover')) {
      bucket = SupabaseService.bucketCovers;
    } else if (path.contains('rank') || path.contains('screenshot') || path.contains('proof')) {
      bucket = SupabaseService.bucketScreenshots;
    } else if (path.contains('team') || path.contains('logo')) {
      bucket = SupabaseService.bucketTeamLogos;
    }

    final url = await SupabaseService.uploadFile(
      file: file,
      bucket: bucket,
      folder: path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : null,
      customFileName: path.split('/').last,
    );
    return url ?? '';
  }

  Future<String> getDownloadURL() async {
    // If path is already a full URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    String bucket = SupabaseService.bucketUploads;
    if (path.contains('avatar')) bucket = SupabaseService.bucketAvatars;
    if (path.contains('cover')) bucket = SupabaseService.bucketCovers;
    if (path.contains('screenshot') || path.contains('rank')) bucket = SupabaseService.bucketScreenshots;
    if (path.contains('team')) bucket = SupabaseService.bucketTeamLogos;
    return '${SupabaseService.supabaseUrl}/storage/v1/object/public/$bucket/$path';
  }
}

class SettableMetadata {
  final String? contentType;
  SettableMetadata({this.contentType});
}

class TaskSnapshot {
  final Reference ref;
  TaskSnapshot(this.ref);
}

class UploadTask {
  final Reference ref;
  final Future<String> _uploadFuture;

  UploadTask(this.ref, this._uploadFuture);

  Future<TaskSnapshot> get onComplete async {
    await _uploadFuture;
    return TaskSnapshot(ref);
  }

  Future<T> then<T>(Future<T> Function(TaskSnapshot) onValue) async {
    await _uploadFuture;
    return onValue(TaskSnapshot(ref));
  }
}
