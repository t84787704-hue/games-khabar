import 'dart:io';

class VideoCompressService {
  static Future<void> cancel() async {}

  static Future<File> compressIfNeeded(
    File originalFile, {
    double totalDurationSec = 30.0,
    double? trimStartSec,
    double? trimEndSec,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    return originalFile;
  }
}


