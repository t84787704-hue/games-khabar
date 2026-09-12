import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

class VideoCompressService {
  /// Compresses gaming clips (e.g. PUBG Mobile screen recordings > 25MB, 60fps, 1080p/2K)
  /// down to 720p 30fps (approx 15-20MB) for seamless Cloudinary upload and lag-free playback.
  static Future<File> compressIfNeeded(
    File originalFile, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final int bytes = await originalFile.length();
      final int sizeInMB = bytes ~/ (1024 * 1024);
      print("ORIGINAL SIZE: $sizeInMB MB");

      // Gaming clips are always big, so compress if > 25MB
      if (sizeInMB > 25) {
        print("COMPRESSING GAMING CLIP...");
        
        Subscription? progressSubscription;
        if (onProgress != null) {
          progressSubscription = VideoCompress.compressProgress$.subscribe((progress) {
            onProgress(progress / 100.0);
          });
        }

        try {
          final MediaInfo? info = await VideoCompress.compressVideo(
            originalFile.path,
            quality: VideoQuality.MediumQuality, // 720p, 30fps, ~15-20MB
            deleteOrigin: false,
            includeAudio: true,
          );

          if (info != null && info.file != null) {
            final int newBytes = await info.file!.length();
            final int newSize = newBytes ~/ (1024 * 1024);
            print("COMPRESSED SIZE: $newSize MB PATH: ${info.file!.path}");
            return info.file!;
          }
        } finally {
          progressSubscription?.unsubscribe();
        }
      }
    } catch (e) {
      print("⚠️ VideoCompress error ($e), proceeding with original file");
    }
    return originalFile;
  }
}
