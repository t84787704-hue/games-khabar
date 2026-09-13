import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Ultra-Fast Video Compression Service
/// Safely optimizes video files before upload while never blocking or failing the upload.
class FastCompressService {
  static bool _isCancelled = false;

  static void cancel() {
    _isCancelled = true;
    try {
      FFmpegKit.cancel();
    } catch (_) {}
    debugPrint("🛑 [FAST_COMPRESS] Compression cancelled");
  }

  /// Compress gaming video:
  /// - If < 35MB: skips compression to save battery and time.
  /// - If > 35MB: fast 720p scaling with strict safety timeout.
  /// - Never throws: always safely falls back to [inputFile].
  static Future<File> compressGamingVideo(
    File inputFile, {
    int totalDurationSeconds = 180,
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    _isCancelled = false;
    try {
      final int originalBytes = await inputFile.length();
      final double originalMB = originalBytes / (1024 * 1024);
      debugPrint("🎬 [FAST_COMPRESS] Input file size: ${originalMB.toStringAsFixed(1)} MB");

      // Skip compression for files under 20MB that are already small enough for high-speed upload.
      if (originalMB <= 20.0) {
        debugPrint("⚡ [FAST_COMPRESS] Video is already compact (${originalMB.toStringAsFixed(1)}MB <= 20MB). Uploading directly.");
        onProgress?.call(1.0);
        return inputFile;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/compressed_fast_$timestamp.mp4';
      final inputPath = inputFile.path;

      onStatus?.call("⚡ Optimizing video for upload...");
      onProgress?.call(0.1);

      // Clean, robust argument list with universal aspect-ratio preserving 720p scale
      // and LGPL-compliant mpeg4 encoder with AAC audio.
      final arguments = [
        '-y',
        '-i', inputPath,
        '-vf', "scale='if(gt(a,1),-2,720)':'if(gt(a,1),720,-2)'",
        '-r', '24',
        '-c:v', 'mpeg4',
        '-b:v', '850k',
        '-maxrate', '1200k',
        '-bufsize', '2000k',
        '-pix_fmt', 'yuv420p',
        '-movflags', '+faststart',
        '-c:a', 'aac',
        '-b:a', '64k',
        '-t', '180',
        outputPath,
      ];

      debugPrint("🚀 [FAST_COMPRESS] Running FFmpeg with args: $arguments");
      final bool success = await _runFFmpegCommandWithArgs(
        arguments,
        outputPath,
        totalDurationSeconds,
        onProgress,
      );

      final outputFile = File(outputPath);
      if (success && await outputFile.exists()) {
        final int length = await outputFile.length();
        if (length > 1000) {
          final double newMB = length / (1024 * 1024);
          debugPrint("✅ [FAST_COMPRESS] Success: ${originalMB.toStringAsFixed(1)}MB -> ${newMB.toStringAsFixed(1)}MB");
          onProgress?.call(1.0);
          return outputFile;
        }
      }
    } catch (e) {
      debugPrint("⚠️ [FAST_COMPRESS] Notice: $e. Using original file.");
    }

    debugPrint("⚡ [FAST_COMPRESS] Proceeding with original video file.");
    return inputFile;
  }

  static Future<bool> _runFFmpegCommandWithArgs(
    List<String> args,
    String outputPath,
    int totalDurationSeconds,
    Function(double progress)? onProgress,
  ) async {
    final double targetDurationMs = (totalDurationSeconds > 0 ? totalDurationSeconds : 60) * 1000.0;
    final completer = Completer<bool>();

    try {
      final session = await FFmpegKit.executeWithArgumentsAsync(
        args,
        (session) async {
          final returnCode = await session.getReturnCode();
          final isSuccess = ReturnCode.isSuccess(returnCode);
          debugPrint("🎬 [FAST_COMPRESS] FFmpeg completed. ReturnCode: $returnCode, Success: $isSuccess");
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
            final progress = (timeMs / targetDurationMs).clamp(0.1, 0.95);
            onProgress?.call(progress);
          }
        },
      );

      // 90-second safety timeout so it never hangs
      return await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          debugPrint("⚠️ [FAST_COMPRESS] Timed out after 90s, cancelling");
          try {
            FFmpegKit.cancel(session.getSessionId());
          } catch (_) {}
          return false;
        },
      );
    } catch (e) {
      debugPrint("⚠️ [FAST_COMPRESS] FFmpegKit error: $e");
      return false;
    }
  }
}
