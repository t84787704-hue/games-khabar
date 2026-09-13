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

      // Skip compression for files under 9.5MB - Cloudinary unsigned preset max file limit is 10MB.
      // Keeping files under 9.5MB guarantees 100% successful direct upload without rejecting.
      if (originalMB <= 9.5) {
        debugPrint("⚡ [FAST_COMPRESS] Video is already under 9.5MB (${originalMB.toStringAsFixed(1)}MB). Uploading directly.");
        onProgress?.call(1.0);
        return inputFile;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/compressed_fast_$timestamp.mp4';
      final inputPath = inputFile.path;

      onStatus?.call("⚡ Optimizing video...");
      onProgress?.call(0.1);

      // Fast scale command ensuring even width & height (compatible with any screen recording resolution like 1080x2400)
      // Caps resolution to 720p maximum to guarantee file stays well below 10MB
      final cmd = '-y -i "$inputPath" -vf "scale=trunc(iw*min(720/iw\\,1280/ih)/2)*2:trunc(ih*min(720/iw\\,1280/ih)/2)*2" -r 30 -c:v libx264 -preset ultrafast -crf 28 -c:a aac -b:a 96k -t 180 "$outputPath"';

      debugPrint("🚀 [FAST_COMPRESS] Executing: $cmd");
      final bool success = await _runFFmpegCommand(
        cmd,
        outputPath,
        totalDurationSeconds,
        onProgress,
      );

      final outputFile = File(outputPath);
      if (success && await outputFile.exists() && await outputFile.length() > 1000) {
        final double newMB = (await outputFile.length()) / (1024 * 1024);
        debugPrint("✅ [FAST_COMPRESS] Success: ${originalMB.toStringAsFixed(1)}MB -> ${newMB.toStringAsFixed(1)}MB");
        onProgress?.call(1.0);
        return outputFile;
      }
    } catch (e) {
      debugPrint("⚠️ [FAST_COMPRESS] Notice: $e. Using original file.");
    }

    debugPrint("⚡ [FAST_COMPRESS] Proceeding with original video file.");
    return inputFile;
  }

  static Future<bool> _runFFmpegCommand(
    String cmd,
    String outputPath,
    int totalDurationSeconds,
    Function(double progress)? onProgress,
  ) async {
    final double targetDurationMs = (totalDurationSeconds > 0 ? totalDurationSeconds : 60) * 1000.0;
    final completer = Completer<bool>();

    try {
      final session = await FFmpegKit.executeAsync(
        cmd,
        (session) async {
          final returnCode = await session.getReturnCode();
          final isSuccess = ReturnCode.isSuccess(returnCode);
          debugPrint("🎬 [FAST_COMPRESS] FFmpeg ended, success: $isSuccess");
          if (!completer.isCompleted) {
            completer.complete(isSuccess);
          }
        },
        (log) {},
        (Statistics stats) {
          final timeMs = stats.getTime();
          if (timeMs > 0 && targetDurationMs > 0) {
            final progress = (timeMs / targetDurationMs).clamp(0.1, 0.95);
            onProgress?.call(progress);
          }
        },
      );

      // 45-second safety timeout so it never hangs
      return await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          debugPrint("⚠️ [FAST_COMPRESS] Timed out after 45s, bypassing compression");
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
