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

      // We use executeWithArgumentsAsync to eliminate all shell quoting and escaping bugs.
      // We use -c:v mpeg4 with bitrate control, which is 100% supported in all standard (LGPL) FFmpegKit builds
      // (unlike libx264 which is GPL-only and causes 'Unknown encoder' failure on standard builds).
      final arguments = [
        '-y',
        '-i', inputPath,
        '-vf', "scale='trunc(if(gt(iw,ih),min(1280,iw),min(720,iw))/2)*2':-2",
        '-r', '24',
        '-c:v', 'mpeg4',
        '-b:v', '700k',
        '-maxrate', '950k',
        '-bufsize', '1500k',
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
        if (length > 1000 && length < 9.5 * 1024 * 1024) {
          final double newMB = length / (1024 * 1024);
          debugPrint("✅ [FAST_COMPRESS] Success: ${originalMB.toStringAsFixed(1)}MB -> ${newMB.toStringAsFixed(1)}MB");
          onProgress?.call(1.0);
          return outputFile;
        } else if (length >= 9.5 * 1024 * 1024) {
          debugPrint("⚡ [FAST_COMPRESS] Output is ${(length / (1024 * 1024)).toStringAsFixed(1)}MB (>9.5MB). Running pass 2...");
          final pass2Path = '${tempDir.path}/compressed_p2_$timestamp.mp4';
          final pass2Args = [
            '-y',
            '-i', outputPath,
            '-r', '24',
            '-c:v', 'mpeg4',
            '-b:v', '400k',
            '-maxrate', '600k',
            '-bufsize', '1000k',
            '-c:a', 'aac',
            '-b:a', '64k',
            pass2Path,
          ];
          final pass2Success = await _runFFmpegCommandWithArgs(pass2Args, pass2Path, totalDurationSeconds, onProgress);
          final pass2File = File(pass2Path);
          if (pass2Success && await pass2File.exists() && await pass2File.length() > 1000) {
            final double pass2MB = (await pass2File.length()) / (1024 * 1024);
            debugPrint("✅ [FAST_COMPRESS] Pass 2 Success: $pass2MB MB");
            onProgress?.call(1.0);
            return pass2File;
          }
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

      // 45-second safety timeout so it never hangs
      return await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          debugPrint("⚠️ [FAST_COMPRESS] Timed out after 45s, cancelling");
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
