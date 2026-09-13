import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'fast_chunked_upload.dart';

/// VideoUploadService - Option B Flow: Compress First, Upload After
/// 1. User selects video (e.g. 500-600MB, 2 min)
/// 2. Immediately compress: 720p HD, bitrate 1500k, 30fps, include audio
/// 3. Target size: under 90MB for a 2-min clip
/// 4. If still > 100MB, re-compress with 1000k bitrate
/// 5. No early 100MB error check; only check AFTER compression
/// 6. Upload cleanly to Cloudinary
class VideoUploadService {
  static final VideoUploadService _instance = VideoUploadService._internal();
  factory VideoUploadService() => _instance;
  VideoUploadService._internal();

  static bool _isCancelled = false;

  static void cancel() {
    _isCancelled = true;
    try {
      FFmpegKit.cancel();
    } catch (_) {}
    FastChunkedUploadService.cancel();
    debugPrint("🛑 [VIDEO_UPLOAD_SERVICE] Cancelled");
  }

  /// Option B: Compress video before upload
  /// Passes:
  /// - Pass 1: 720p HD, 1500k bitrate, 30fps, aac audio
  /// - If still > 100MB: Pass 2 with 1000k bitrate
  static Future<File> compressVideoOptionB({
    required File inputFile,
    int estimatedDurationSeconds = 120,
    Function(double progress)? onProgress,
    Function(String statusText)? onStatus,
  }) async {
    _isCancelled = false;
    final int originalBytes = await inputFile.length();
    final double originalMB = originalBytes / (1024 * 1024);

    debugPrint("🎬 [COMPRESS_FIRST] Original size: ${originalMB.toStringAsFixed(1)} MB");

    // If file is already compact (under 20MB), skip compression to save user time
    if (originalMB <= 20.0) {
      onProgress?.call(1.0);
      onStatus?.call("Ready for Upload (${originalMB.toStringAsFixed(0)}MB • Original)");
      return inputFile;
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // --- PASS 1: 720p HD @ 1500k Bitrate, 30 FPS ---
    final pass1Output = '${tempDir.path}/compressed_720p_$timestamp.mp4';
    onStatus?.call("⚡ Optimizing... 0% - Compressing from ${originalMB.toInt()}MB to ~80MB");
    onProgress?.call(0.05);

    final pass1Args = [
      '-y',
      '-i', inputFile.path,
      '-vf', "scale='if(gt(a,1),-2,720)':'if(gt(a,1),720,-2)'",
      '-r', '30',
      '-c:v', 'mpeg4',
      '-b:v', '1500k',
      '-maxrate', '1800k',
      '-bufsize', '3000k',
      '-pix_fmt', 'yuv420p',
      '-movflags', '+faststart',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-t', '180', // max 3 min
      pass1Output,
    ];

    debugPrint("🚀 [COMPRESS_FIRST] Starting Pass 1 (1500k bitrate)...");
    final pass1Success = await _executeFFmpeg(
      pass1Args,
      pass1Output,
      estimatedDurationSeconds: estimatedDurationSeconds,
      onProgress: (p) {
        final pct = (p * 100).toInt();
        onProgress?.call(p);
        onStatus?.call("⚡ Optimizing... $pct% - Compressing from ${originalMB.toInt()}MB to ~80MB");
      },
    );

    File candidateFile = File(pass1Output);
    if (pass1Success && await candidateFile.exists()) {
      int candidateBytes = await candidateFile.length();
      double candidateMB = candidateBytes / (1024 * 1024);
      debugPrint("✅ [COMPRESS_FIRST] Pass 1 complete: ${candidateMB.toStringAsFixed(1)} MB");

      // Check if under 100MB
      if (candidateMB <= 100.0 && candidateBytes > 5000) {
        onProgress?.call(1.0);
        onStatus?.call("Ready for Upload (Compressed: ${candidateMB.toStringAsFixed(0)}MB • 720p HD)");
        return candidateFile;
      }

      // If still > 100MB, run Pass 2 with lower bitrate (1000k)
      if (candidateMB > 100.0) {
        debugPrint("⚠️ [COMPRESS_FIRST] File still > 100MB (${candidateMB.toStringAsFixed(1)}MB). Running Pass 2 with 1000k bitrate...");
        final pass2Output = '${tempDir.path}/compressed_pass2_$timestamp.mp4';
        onStatus?.call("⚡ Optimizing... Extra pass for high quality under 90MB");

        final pass2Args = [
          '-y',
          '-i', inputFile.path,
          '-vf', "scale='if(gt(a,1),-2,720)':'if(gt(a,1),720,-2)'",
          '-r', '30',
          '-c:v', 'mpeg4',
          '-b:v', '1000k',
          '-maxrate', '1200k',
          '-bufsize', '2000k',
          '-pix_fmt', 'yuv420p',
          '-movflags', '+faststart',
          '-c:a', 'aac',
          '-b:a', '96k',
          '-t', '180',
          pass2Output,
        ];

        final pass2Success = await _executeFFmpeg(
          pass2Args,
          pass2Output,
          estimatedDurationSeconds: estimatedDurationSeconds,
          onProgress: (p) {
            final pct = (p * 100).toInt();
            onProgress?.call(p);
            onStatus?.call("⚡ Optimizing... $pct% - Compressing from ${originalMB.toInt()}MB to ~80MB");
          },
        );

        final pass2File = File(pass2Output);
        if (pass2Success && await pass2File.exists()) {
          final p2Bytes = await pass2File.length();
          final p2MB = p2Bytes / (1024 * 1024);
          debugPrint("✅ [COMPRESS_FIRST] Pass 2 complete: ${p2MB.toStringAsFixed(1)} MB");
          if (p2MB <= 100.0 && p2Bytes > 5000) {
            onProgress?.call(1.0);
            onStatus?.call("Ready for Upload (Compressed: ${p2MB.toStringAsFixed(0)}MB • 720p HD)");
            return pass2File;
          }
          candidateFile = pass2File;
          candidateMB = p2MB;
        }
      }

      // Check after compression attempt
      if (candidateMB > 100.0) {
        throw Exception("Video file is too large (max 100MB after compression). Please select a clip under 3 minutes.");
      }

      onProgress?.call(1.0);
      onStatus?.call("Ready for Upload (Compressed: ${candidateMB.toStringAsFixed(0)}MB • 720p HD)");
      return candidateFile;
    }

    // If FFmpeg encountered an issue on this device:
    debugPrint("⚠️ [COMPRESS_FIRST] Compression was not completed. Checking original file size.");
    if (originalMB > 100.0) {
      throw Exception("Video file is too large (max 100MB). Optimization could not reduce file size below 100MB.");
    }

    return inputFile;
  }

  static Future<bool> _executeFFmpeg(
    List<String> args,
    String outputPath, {
    required int estimatedDurationSeconds,
    Function(double progress)? onProgress,
  }) async {
    final double targetDurationMs = (estimatedDurationSeconds > 0 ? estimatedDurationSeconds : 120) * 1000.0;
    final completer = Completer<bool>();

    try {
      final session = await FFmpegKit.executeWithArgumentsAsync(
        args,
        (session) async {
          final returnCode = await session.getReturnCode();
          final isSuccess = ReturnCode.isSuccess(returnCode);
          debugPrint("🎬 [FFMPEG] Session finished. ReturnCode: $returnCode, Success: $isSuccess");
          if (!completer.isCompleted) {
            completer.complete(isSuccess);
          }
        },
        (log) {
          final msg = log.getMessage();
          if (msg.contains("Error") || msg.contains("error") || msg.contains("failed")) {
            debugPrint("⚠️ [FFMPEG_LOG] $msg");
          }
        },
        (Statistics stats) {
          final timeMs = stats.getTime();
          if (timeMs > 0 && targetDurationMs > 0) {
            final progress = (timeMs / targetDurationMs).clamp(0.05, 0.98);
            onProgress?.call(progress);
          }
        },
      );

      return await completer.future.timeout(
        const Duration(minutes: 4),
        onTimeout: () {
          debugPrint("⚠️ [FFMPEG] Compression timed out after 4 minutes");
          try {
            FFmpegKit.cancel(session.getSessionId());
          } catch (_) {}
          return false;
        },
      );
    } catch (e) {
      debugPrint("⚠️ [FFMPEG] Execution error: $e");
      return false;
    }
  }

  /// Upload compressed video to Cloudinary with fallback
  static Future<Map<String, dynamic>?> uploadVideo({
    required File file,
    String? caption,
    String? gameTag,
    String? userId,
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    return await FastChunkedUploadService.uploadVideo(
      file: file,
      caption: caption,
      gameTag: gameTag,
      userId: userId,
      onProgress: onProgress,
      onStatus: onStatus,
    );
  }
}
