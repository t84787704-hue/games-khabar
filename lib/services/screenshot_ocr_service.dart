import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_storage/firebase_storage.dart';

class OcrResult {
  final bool isVictory;
  final String recognizedText;
  final String? detectedWinner;
  final String imageUrl;
  final String localPath;

  const OcrResult({
    required this.isVictory,
    required this.recognizedText,
    this.detectedWinner,
    required this.imageUrl,
    required this.localPath,
  });
}

class ScreenshotOcrService {
  static final ScreenshotOcrService _instance = ScreenshotOcrService._internal();
  factory ScreenshotOcrService() => _instance;
  ScreenshotOcrService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Pick BGMI screenshot from gallery, run Google ML Kit OCR, and verify victory
  Future<OcrResult?> processResultScreenshot({
    required String roomId,
    required String userId,
    required List<String> candidateNames,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final File file = File(pickedFile.path);

      // 1. Run Google ML Kit Text Recognition
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFile(file);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final fullText = recognizedText.text;
      final upperText = fullText.toUpperCase();

      // 2. Search for BGMI Victory keywords
      final bool hasVictory = upperText.contains('VICTORY') ||
          upperText.contains('WINNER') ||
          upperText.contains('WON') ||
          upperText.contains('#1/') ||
          upperText.contains('#1 ') ||
          upperText.contains('CHICKEN DINNER') ||
          upperText.contains('FIRST PLACE');

      // 3. Auto-suggest winner from candidate names found in OCR text
      String? matchedWinner;
      for (final name in candidateNames) {
        if (name.isNotEmpty && upperText.contains(name.toUpperCase())) {
          matchedWinner = name;
          break;
        }
      }

      // 4. Upload to Firebase Storage
      String downloadUrl = '';
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('results')
            .child('${roomId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = await storageRef.putFile(file);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      } catch (storageError) {
        debugPrint('ScreenshotOcrService: Storage upload notice: $storageError. Using local path.');
        downloadUrl = pickedFile.path;
      }

      return OcrResult(
        isVictory: hasVictory,
        recognizedText: fullText,
        detectedWinner: matchedWinner,
        imageUrl: downloadUrl.isNotEmpty ? downloadUrl : pickedFile.path,
        localPath: pickedFile.path,
      );
    } catch (e) {
      debugPrint('ScreenshotOcrService: Error processing screenshot: $e');
      return null;
    }
  }
}
