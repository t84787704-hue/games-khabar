import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class WinProofValidationResult {
  final bool isVerified;
  final int score; // 4 for verified (4/4), 0 for rejected (0/4)
  final String status; // 'verified', 'mismatch', 'doubt'
  final String? detectedScreenshotName;
  final String accountIdName;
  final String message;
  final String fullOcrText;
  final bool isNameMatched;
  final bool hasVictoryKeyword;

  const WinProofValidationResult({
    required this.isVerified,
    required this.score,
    required this.status,
    this.detectedScreenshotName,
    required this.accountIdName,
    required this.message,
    required this.fullOcrText,
    required this.isNameMatched,
    required this.hasVictoryKeyword,
  });

  bool get isDoubt => !isVerified;
}

class WinProofValidator {
  static const Set<String> _gameStopwords = {
    'winner', 'chicken', 'dinner', 'victory', 'defeat', 'rank', '#1', '1/100',
    '#1/100', '1/64', '1/50', 'team', 'kills', 'kill', 'damage', 'points',
    'coins', 'battlegrounds', 'pubg', 'bgmi', 'mobile', 'free fire', 'booyah',
    'game', 'match', 'total', 'rating', 'tier', 'rp', 'score', 'mvp',
    'continue', 'share', 'exit', 'back', 'details', 'stats', 'eliminations',
    'eliminated', 'assists', 'revives', 'heals', 'accuracy', 'headshots',
    'first', 'place', 'classic', 'toggled', 'level', 'season', 'survival',
    'time', 'zone', 'playzone', 'result', 'results', 'app', 'ai', 'check',
    'screenshot', 'clear', 'win', 'won', 'play', 'player', 'loading', 'ping',
    'ms', 'fps', 'hd', 'uhd', 'smooth', 'extreme', 'balanced', 'auto',
    'report', 'like', 'spectate', 'lobby', 'settings', 'clan', 'squad',
    'duo', 'solo', 'erangel', 'livik', 'miramar', 'sanhok', 'vikendi',
    'karakin', 'nusa', 'tdm', 'room', 'custom', 'id', 'pass', 'password',
    'slot', 'slots', 'all', 'alive', 'killed', 'finish', 'finishes', 'finishs',
    'reward', 'host', 'bot', 'coins', 'g-coins', 'gcoins', 'rank#1', '1', '100'
  };

  /// Clean candidate name by stripping common prefixes and punctuation
  static String _cleanCandidateName(String text) {
    String cleaned = text.trim();
    final prefixes = ['ign:', 'player:', 'name:', 'user:', 'id:', 'team:'];
    for (final prefix in prefixes) {
      if (cleaned.toLowerCase().startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
      }
    }
    cleaned = cleaned
        .replaceAll(RegExp(r'^[#@\(\[\{<]+'), '')
        .replaceAll(RegExp(r'[\)\]\}>]+$'), '')
        .trim();
    return cleaned;
  }

  /// Check if candidate name is a standard game stopword
  static bool _isStopword(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return true;
    if (_gameStopwords.contains(lower)) return true;
    if (lower.startsWith('kd') || lower.startsWith('k/d')) return true;
    if (lower.startsWith('lv.') || lower.startsWith('exp')) return true;
    return false;
  }

  /// Resolve the uploader's real ID name:
  /// 1. Slot allocation name (e.g. "1083") from room slots
  /// 2. Firestore users collection -> bgmiName / inGameName / username / displayName
  /// 3. Fallback to currentUserName
  static Future<String> resolveAccountIdName({
    required String userId,
    required String fallbackName,
    List<Map<String, dynamic>>? joinedUsers,
    Map<String, dynamic>? joinedPlayerNames,
    String? roomId,
  }) async {
    // 1. From joinedUsers slots in memory
    if (joinedUsers != null && joinedUsers.isNotEmpty) {
      for (final u in joinedUsers) {
        if (u['id'] == userId) {
          final slotName = u['name']?.toString().trim();
          if (slotName != null &&
              slotName.isNotEmpty &&
              slotName != 'Player' &&
              slotName != 'Gamer') {
            return slotName;
          }
        }
      }
    }

    // From joinedPlayerNames in memory
    if (joinedPlayerNames != null && joinedPlayerNames.containsKey(userId)) {
      final pName = joinedPlayerNames[userId]?.toString().trim();
      if (pName != null &&
          pName.isNotEmpty &&
          pName != 'Player' &&
          pName != 'Gamer') {
        return pName;
      }
    }

    // Check room document in Firestore if roomId provided
    if (roomId != null && roomId.isNotEmpty) {
      try {
        final roomSnap = await FirebaseFirestore.instance.collection('rooms').doc(roomId).get();
        if (roomSnap.exists) {
          final rData = roomSnap.data() as Map<String, dynamic>? ?? {};
          final rUsers = rData['joinedUsers'] as List?;
          if (rUsers != null) {
            for (final item in rUsers) {
              if (item is Map && item['id'] == userId) {
                final sName = item['name']?.toString().trim();
                if (sName != null &&
                    sName.isNotEmpty &&
                    sName != 'Player' &&
                    sName != 'Gamer') {
                  return sName;
                }
              }
            }
          }
          final pNames = rData['joinedPlayerNames'] as Map?;
          if (pNames != null && pNames[userId] != null) {
            final sName = pNames[userId].toString().trim();
            if (sName.isNotEmpty && sName != 'Player' && sName != 'Gamer') {
              return sName;
            }
          }
        }
      } catch (e) {
        debugPrint('WinProofValidator: Error fetching room slot: $e');
      }
    }

    // 2. Check users collection -> bgmiName / inGameName / username
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final uData = userDoc.data() as Map<String, dynamic>? ?? {};
        final bgmiName = uData['bgmiName']?.toString().trim();
        if (bgmiName != null && bgmiName.isNotEmpty) return bgmiName;

        final inGameName = uData['inGameName']?.toString().trim();
        if (inGameName != null && inGameName.isNotEmpty) return inGameName;

        final username = uData['username']?.toString().trim();
        if (username != null && username.isNotEmpty) return username;

        final displayName = uData['displayName']?.toString().trim();
        if (displayName != null &&
            displayName.isNotEmpty &&
            displayName != 'Player' &&
            displayName != 'Gamer') {
          return displayName;
        }
      }
    } catch (e) {
      debugPrint('WinProofValidator: Error fetching user doc: $e');
    }

    // 3. Fallback
    final cleanFallback = fallbackName.trim();
    return cleanFallback.isNotEmpty ? cleanFallback : 'Player';
  }

  /// Run OCR using Google ML Kit on win proof screenshot and validate name match against account ID name.
  static Future<WinProofValidationResult> validate({
    required File imageFile,
    required String userId,
    required String accountIdName,
    required String roomId,
  }) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await recognizer.processImage(inputImage);
      await recognizer.close();

      final String fullText = recognizedText.text;
      final String lowerFullText = fullText.toLowerCase();

      // 1. Victory keyword detection
      final bool hasVictoryKeyword = lowerFullText.contains('winner winner') ||
          lowerFullText.contains('chicken dinner') ||
          lowerFullText.contains('rank #1') ||
          lowerFullText.contains('rank 1') ||
          lowerFullText.contains('team victory') ||
          lowerFullText.contains('victory') ||
          lowerFullText.contains('booyah') ||
          lowerFullText.contains('#1/') ||
          lowerFullText.contains('#1 ') ||
          lowerFullText.contains('champion') ||
          lowerFullText.contains('you win') ||
          (lowerFullText.contains('winner') && lowerFullText.contains('team'));

      final bool hasDefeatKeyword = (lowerFullText.contains('defeat') ||
              lowerFullText.contains('better luck next time')) &&
          !lowerFullText.contains('victory') &&
          !lowerFullText.contains('chicken dinner') &&
          !lowerFullText.contains('booyah');

      final bool isVictory = hasVictoryKeyword && !hasDefeatKeyword;

      // 2. Extract candidate player names from OCR blocks, lines, and elements
      final List<String> candidateNames = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final rawLine = line.text.trim();
          final cleanLine = _cleanCandidateName(rawLine);
          if (cleanLine.length >= 2 && cleanLine.length <= 25 && !_isStopword(cleanLine)) {
            candidateNames.add(cleanLine);
          }
          for (final elem in line.elements) {
            final rawElem = elem.text.trim();
            final cleanElem = _cleanCandidateName(rawElem);
            if (cleanElem.length >= 2 && cleanElem.length <= 25 && !_isStopword(cleanElem)) {
              candidateNames.add(cleanElem);
            }
          }
        }
      }

      final String targetAccountName = accountIdName.trim();
      final String lowerAccountName = targetAccountName.toLowerCase();

      // 3. Name comparison: case-insensitive exact check
      bool isNameMatched = false;
      String? matchedCandidate;

      // Check candidate names
      for (final candidate in candidateNames) {
        if (candidate.toLowerCase() == lowerAccountName) {
          isNameMatched = true;
          matchedCandidate = candidate;
          break;
        }
      }

      // Check full text for token/word boundary match
      if (!isNameMatched && lowerAccountName.isNotEmpty) {
        final escaped = RegExp.escape(lowerAccountName);
        final wordRegex = RegExp(r'(^|[^\w])' + escaped + r'([^\w]|$)', caseSensitive: false);
        if (wordRegex.hasMatch(lowerFullText)) {
          isNameMatched = true;
          matchedCandidate = targetAccountName;
        }
      }

      // Determine the detected name on screenshot
      String detectedScreenshotName;
      if (isNameMatched) {
        detectedScreenshotName = matchedCandidate ?? targetAccountName;
      } else {
        // Pick the first non-stopword candidate found on the screenshot
        if (candidateNames.isNotEmpty) {
          detectedScreenshotName = candidateNames.firstWhere(
            (c) => !RegExp(r'^\d+$').hasMatch(c),
            orElse: () => candidateNames.first,
          );
        } else {
          // Fallback: extract first word from OCR that is not a game keyword
          final words = fullText.split(RegExp(r'\s+'));
          detectedScreenshotName = words.firstWhere(
            (w) => w.length >= 2 && !_isStopword(w),
            orElse: () => 'Unknown',
          );
        }
      }

      // 4. Comparison logic & Decision
      final String sName = detectedScreenshotName.toLowerCase().trim();
      final String aName = lowerAccountName;

      if (!isNameMatched || sName != aName) {
        // REJECT - Name Mismatch
        final String rejectMsg =
            "❌ App AI Check: REJECTED - Name Mismatch. Screenshot has '$detectedScreenshotName' but your ID is '$targetAccountName'";

        return WinProofValidationResult(
          isVerified: false,
          score: 0,
          status: 'mismatch',
          detectedScreenshotName: detectedScreenshotName,
          accountIdName: targetAccountName,
          message: rejectMsg,
          fullOcrText: fullText,
          isNameMatched: false,
          hasVictoryKeyword: isVictory,
        );
      }

      // If name matched, verify victory keyword
      if (!isVictory) {
        const String doubtMsg =
            '🤖 App AI Check: ❌ App Doubt: Not a clear winner screenshot. Reward BLOCKED by App.';
        return WinProofValidationResult(
          isVerified: false,
          score: 0,
          status: 'doubt',
          detectedScreenshotName: detectedScreenshotName,
          accountIdName: targetAccountName,
          message: doubtMsg,
          fullOcrText: fullText,
          isNameMatched: true,
          hasVictoryKeyword: false,
        );
      }

      // APPROVE - Name Matched and Victory Verified
      const String approveMsg =
          '🤖 App AI Check: ✅ Verified - Name Matched (Score 4/4). Awaiting Host Approval.';

      return WinProofValidationResult(
        isVerified: true,
        score: 4,
        status: 'verified',
        detectedScreenshotName: detectedScreenshotName,
        accountIdName: targetAccountName,
        message: approveMsg,
        fullOcrText: fullText,
        isNameMatched: true,
        hasVictoryKeyword: true,
      );
    } catch (e) {
      try {
        await recognizer.close();
      } catch (_) {}
      debugPrint('WinProofValidator error: $e');

      final String errMsg = '❌ App AI Check: Error reading screenshot: $e';
      return WinProofValidationResult(
        isVerified: false,
        score: 0,
        status: 'doubt',
        detectedScreenshotName: 'Unknown',
        accountIdName: accountIdName,
        message: errMsg,
        fullOcrText: '',
        isNameMatched: false,
        hasVictoryKeyword: false,
      );
    }
  }
}
