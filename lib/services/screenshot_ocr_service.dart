import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/tournament_room_model.dart';

class OcrResult {
  final bool isVictory;
  final String recognizedText;
  final String? detectedWinner;
  final List<String> detectedWinnerUids;
  final List<String> detectedWinnerNames;
  final List<String> detectedOcrUids;
  final String imageUrl;
  final String localPath;

  const OcrResult({
    required this.isVictory,
    required this.recognizedText,
    this.detectedWinner,
    this.detectedWinnerUids = const [],
    this.detectedWinnerNames = const [],
    this.detectedOcrUids = const [],
    required this.imageUrl,
    required this.localPath,
  });
}

class ScreenshotOcrService {
  static final ScreenshotOcrService _instance = ScreenshotOcrService._internal();
  factory ScreenshotOcrService() => _instance;
  ScreenshotOcrService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Pick game screenshot from gallery, run Google ML Kit OCR, and auto-detect winning team
  Future<OcrResult?> processResultScreenshot({
    required String roomId,
    required String userId,
    String? userName,
    TournamentRoom? room,
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

      // 2. Search for Victory keywords across BGMI, PUBG, Free Fire, COD, etc.
      final bool hasVictoryKeyword = upperText.contains('VICTORY') ||
          upperText.contains('WINNER') ||
          upperText.contains('WON') ||
          upperText.contains('#1/') ||
          upperText.contains('#1 ') ||
          upperText.contains('CHICKEN DINNER') ||
          upperText.contains('FIRST PLACE') ||
          upperText.contains('BOOYAH') ||
          upperText.contains('CHAMPION') ||
          upperText.contains('BLUE TEAM WINS') ||
          upperText.contains('RED TEAM WINS') ||
          upperText.contains('YOU WIN') ||
          upperText.contains('#1');

      final bool hasDefeatKeyword = (upperText.contains('DEFEAT') ||
              upperText.contains('BETTER LUCK NEXT TIME')) &&
          !upperText.contains('VICTORY') &&
          !upperText.contains('CHICKEN DINNER') &&
          !upperText.contains('BOOYAH');

      final bool hasVictory = hasVictoryKeyword && !hasDefeatKeyword;

      // 3. Extract any numerical game UIDs from screenshot (e.g. 6 to 12 digits)
      final uidRegex = RegExp(r'\b[0-9]{6,12}\b');
      final detectedOcrUids = uidRegex.allMatches(fullText).map((m) => m.group(0)!).toSet().toList();

      // 4. Auto-suggest single winner from candidate names found in OCR text
      String? matchedWinner;
      for (final name in candidateNames) {
        if (name.isNotEmpty && upperText.contains(name.toUpperCase())) {
          matchedWinner = name;
          break;
        }
      }

      // 5. Intelligent Winning Team Detection
      final List<String> winnerUids = [];
      final List<String> winnerNames = [];

      final submitterName = (userName != null && userName.isNotEmpty) ? userName : 'Player';
      winnerUids.add(userId);
      winnerNames.add(submitterName);

      if (room != null && room.joinedPlayers.isNotEmpty) {
        final mode = (room.gameMode.isNotEmpty ? room.gameMode : room.roomType).toLowerCase();
        int teamSize = 1;
        if (mode.contains('4v4') || mode.contains('squad')) {
          teamSize = 4;
        } else if (mode.contains('2v2') || mode.contains('duo')) {
          teamSize = 2;
        } else if (mode.contains('1v1') || mode.contains('solo')) {
          teamSize = 1;
        } else if (room.maxSlots >= 8) {
          teamSize = 4;
        } else if (room.maxSlots == 4) {
          teamSize = 2;
        }

        // A) If teamSize > 1, find submitter's teammates based on room slot grouping
        if (teamSize > 1) {
          final sIdx = room.joinedPlayers.indexOf(userId);
          if (sIdx != -1) {
            final teamIdx = sIdx ~/ teamSize;
            final start = teamIdx * teamSize;
            final end = (start + teamSize).clamp(0, room.joinedPlayers.length);
            for (int i = start; i < end; i++) {
              final pUid = room.joinedPlayers[i];
              if (!winnerUids.contains(pUid)) {
                winnerUids.add(pUid);
                final pName = pUid == room.hostId ? room.hostName : 'Player';
                winnerNames.add(pName);
              }
            }
          }
        }

        // B) Check if other joined players' names appear in the OCR text
        for (final pUid in room.joinedPlayers) {
          if (winnerUids.contains(pUid)) continue;
          final sub = room.resultSubmissions[pUid] as Map<String, dynamic>?;
          final pName = (pUid == room.hostId ? room.hostName : sub?['playerName'])?.toString();
          if (pName != null && pName.isNotEmpty && upperText.contains(pName.toUpperCase())) {
            winnerUids.add(pUid);
            winnerNames.add(pName);
          }
        }
      }

      // 6. Upload to Firebase Storage
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
        detectedWinner: matchedWinner ?? submitterName,
        detectedWinnerUids: winnerUids,
        detectedWinnerNames: winnerNames,
        detectedOcrUids: detectedOcrUids,
        imageUrl: downloadUrl.isNotEmpty ? downloadUrl : pickedFile.path,
        localPath: pickedFile.path,
      );
    } catch (e) {
      debugPrint('ScreenshotOcrService: Error processing screenshot: $e');
      return null;
    }
  }
}
