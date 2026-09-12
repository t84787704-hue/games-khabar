import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:ffmpeg_kit_flutter/session.dart';
import 'package:ffmpeg_kit_flutter/statistics.dart';
import 'package:path_provider/path_provider.dart';

class VideoCompressService {
  static Session? _currentSession;

  /// Cancel any currently active FFmpeg compression process
  static Future<void> cancel() async {
    try {
      print("🛑 [FFMPEG] Cancelling active FFmpeg session...");
      await FFmpegKit.cancel();
      if (_currentSession != null) {
        try {
          await FFmpegKit.cancel(_currentSession!.getSessionId());
        } catch (_) {}
        _currentSession = null;
      }
    } catch (e) {
      print("⚠️ Error cancelling FFmpeg: $e");
    }
  }

  /// Conforms directly to user request specification
  static Future<File> compressGamingClip(File inputFile, Function(int) onProgress) async {
    return compressIfNeeded(
      inputFile,
      onProgress: (p) => onProgress((p * 100).round()),
    );
  }

  /// Fast, stable compression for gaming clips using FFmpeg (h264, ultrafast, crf 28, 720p 30fps).
  /// Won't get stuck at 51% like video_compress on high bitrate 60FPS recordings.
  static Future<File> compressIfNeeded(
    File originalFile, {
    double totalDurationSec = 30.0,
    double? trimStartSec,
    double? trimEndSec,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    try {
      final int bytes = await originalFile.length();
      final int sizeInMB = bytes ~/ (1024 * 1024);
      print("ORIGINAL SIZE: $sizeInMB MB");

      // Gaming clips are always big, so compress if > 25MB
      if (sizeInMB <= 25) {
        return originalFile;
      }

      print("COMPRESSING GAMING CLIP WITH FFMPEG...");
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Determine duration to process
      double processDuration = totalDurationSec;
      String trimArgs = '';
      if (trimStartSec != null && trimEndSec != null && trimEndSec > trimStartSec) {
        processDuration = trimEndSec - trimStartSec;
        if (sizeInMB > 100 && processDuration > 30.0) {
          processDuration = 30.0;
        }
        trimArgs = '-ss ${trimStartSec.toStringAsFixed(2)} -t ${processDuration.toStringAsFixed(2)} ';
      } else if (sizeInMB > 100 && processDuration > 30.0) {
        processDuration = 30.0;
        trimArgs = '-t 30.00 ';
      }

      // Fast compression: 720p, 30fps, crf 28 - ultrafast preset avoids hang on high bitrate 60fps recordings
      // -vf scale=-2:720 ensures even dimensions (divisible by 2) required by libx264
      final command = '-y $trimArgs-i "${originalFile.path}" -vcodec libx264 -crf 28 -preset ultrafast -vf "scale=-2:720" -r 30 -acodec aac -b:a 128k "$outputPath"';

      final completer = Completer<File>();
      final totalMs = (processDuration > 0 ? processDuration : 30.0) * 1000.0;

      final session = await FFmpegKit.executeAsync(
        command,
        (Session session) async {
          _currentSession = null;
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            final compressedFile = File(outputPath);
            if (await compressedFile.exists() && await compressedFile.length() > 1000) {
              final int newBytes = await compressedFile.length();
              final int newSize = newBytes ~/ (1024 * 1024);
              print("COMPRESSED SIZE: $newSize MB PATH: $outputPath");
              onProgress?.call(1.0);
              if (!completer.isCompleted) completer.complete(compressedFile);
              return;
            }
          } else if (ReturnCode.isCancel(returnCode)) {
            print("🛑 FFmpeg session was cancelled");
          } else {
            final failLogs = await session.getAllLogsAsString();
            print("⚠️ FFmpeg execution notice: $failLogs");
          }

          if (!completer.isCompleted) completer.complete(originalFile);
        },
        (log) {
          final msg = log.getMessage();
          if (msg.contains('Error') || msg.contains('warning')) {
            print(msg);
          }
        },
        (Statistics statistics) {
          if (isCancelled != null && isCancelled()) {
            cancel();
            return;
          }
          final timeMs = statistics.getTime();
          if (timeMs > 0 && totalMs > 0) {
            final progress = (timeMs / totalMs).clamp(0.0, 0.99);
            onProgress?.call(progress);
          }
        },
      );

      _currentSession = session;

      // Timeout safety: if compress takes longer than 90 seconds, fallback gracefully
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          print("⚠️ FFmpeg compression timed out after ${timeout.inSeconds}s, stopping FFmpeg and uploading with Cloudinary transformation q_auto");
          cancel();
          return originalFile;
        },
      );
    } catch (e) {
      print("⚠️ VideoCompressService error ($e), proceeding with original file");
      return originalFile;
    }
  }
}

