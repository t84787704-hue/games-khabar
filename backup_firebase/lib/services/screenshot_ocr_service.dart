import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/tournament_room_model.dart';
import '../constants/tournament_game_categories.dart';

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

      // 2. Search for Victory keywords specific to THAT game and universal victory terms
      final gameName = room?.gameName ?? room?.gameType ?? '';
      final gameConfig = getGameConfig(gameName);
      final List<String> gameSpecificKeywords = gameConfig.victoryKeywords;

      bool matchedGameKeyword = false;
      for (final kw in gameSpecificKeywords) {
        if (upperText.contains(kw.toUpperCase())) {
          matchedGameKeyword = true;
          break;
        }
      }

      final bool hasVictoryKeyword = matchedGameKeyword ||
          upperText.contains('VICTORY') ||
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
        final totalJoined = room.joinedPlayers.length;
        final mode = (room.gameMode.isNotEmpty ? room.gameMode : room.roomType).toLowerCase();

        // Determine actual team size for competing sides:
        // In a tournament room, players are split into 2 opposing teams.
        // A team size can NEVER equal or exceed totalJoined!
        int teamSize = 1;
        if (mode.contains('2v2') || mode.contains('duo')) {
          teamSize = 2;
        } else if (mode.contains('1v1') || mode.contains('solo')) {
          teamSize = 1;
        } else if (mode.contains('4v4') || mode.contains('squad')) {
          // If 4 total players played, it's 2v2 (2 on each team). If 8, it's 4v4.
          teamSize = totalJoined >= 8 ? 4 : (totalJoined ~/ 2).clamp(1, 2);
        } else {
          teamSize = (totalJoined ~/ 2).clamp(1, 4);
        }

        // Safety clamp: maximum winners can never exceed half of players (or at least 1, max 4)
        final int maxTeamWinners = totalJoined > 1 ? (totalJoined ~/ 2).clamp(1, teamSize) : 1;

        // Clean text for OCR matching (remove non-alphanumeric noise)
        final cleanUpperOcr = upperText.replaceAll(RegExp(r'[^A-Z0-9]'), '');

        // STEP A: PRIMARY OCR NAME MATCHING
        // Check other joined players' names in the OCR recognized text.
        // Winning players have their names clearly visible on the victory screen!
        for (final pUid in room.joinedPlayers) {
          if (pUid == userId) continue;
          if (winnerUids.length >= maxTeamWinners) break;

          final pName = room.getPlayerName(pUid);
          if (pName.isEmpty || pName.toLowerCase() == 'player') continue;

          final normPName = pName.trim().toUpperCase();
          final cleanPName = normPName.replaceAll(RegExp(r'[^A-Z0-9]'), '');

          bool isMatched = false;
          if (normPName.length >= 2 && upperText.contains(normPName)) {
            isMatched = true;
          } else if (cleanPName.length >= 3 && cleanUpperOcr.contains(cleanPName)) {
            isMatched = true;
          } else {
            // Also check individual words if multi-word name
            final words = normPName.split(RegExp(r'\s+')).where((w) => w.length >= 3);
            for (final word in words) {
              if (upperText.contains(word)) {
                isMatched = true;
                break;
              }
            }
          }

          if (isMatched) {
            winnerUids.add(pUid);
            winnerNames.add(pName);
          }
        }

        // STEP B: SLOT-BASED TEAMMATE FILL (Only if team game and OCR missed teammate due to font/resolution)
        // Strictly only take teammates from submitter's OWN slot group (Team 1 or Team 2), NEVER opponents!
        if (winnerUids.length < maxTeamWinners && maxTeamWinners > 1) {
          final sIdx = room.joinedPlayers.indexOf(userId);
          if (sIdx != -1) {
            final teamIdx = sIdx ~/ maxTeamWinners;
            final start = teamIdx * maxTeamWinners;
            final end = (start + maxTeamWinners).clamp(0, totalJoined);
            for (int i = start; i < end; i++) {
              if (winnerUids.length >= maxTeamWinners) break;
              final pUid = room.joinedPlayers[i];
              if (!winnerUids.contains(pUid)) {
                winnerUids.add(pUid);
                winnerNames.add(room.getPlayerName(pUid));
              }
            }
          }
        }

        // STEP C: HARD INVARIANT SAFEGUARD
        // If competing sides exist, winners can NEVER equal total players in room!
        if (winnerUids.length >= totalJoined && totalJoined > 1) {
          final trimmedUids = winnerUids.take(maxTeamWinners).toList();
          final trimmedNames = winnerNames.take(maxTeamWinners).toList();
          winnerUids.clear();
          winnerUids.addAll(trimmedUids);
          winnerNames.clear();
          winnerNames.addAll(trimmedNames);
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
