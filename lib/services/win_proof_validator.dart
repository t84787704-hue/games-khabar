import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
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
    'reward', 'host', 'bot', 'g-coins', 'gcoins', 'rank#1', '1', '100'
  };

  /// Explicit words, UI elements, network tokens, and status bar values to reject
  static const List<String> _explicitIgnoreList = [
    '22:37', '5g', '4g', 'lte', '78', '78%', '100%', 'erangel', 'classic', 'tpp', 'fpp',
    'share', 'lobby', 'replay', 'rp +20', 'rp+', 'rating', 'winner', 'chicken',
    'dinner', 'team rank', 'map:', 'mode:', 'finishes', 'survival', 'kills',
    'damage', 'online', 'rank #1', 'rank 1', 'team victory', 'victory', 'coins',
    'mvp', 'total', 'health', 'assists', 'revives', 'heals', 'details', 'stats'
  ];

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
        .replaceAll('👑', '')
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

  /// Validate candidate player name:
  /// - 3 to 16 chars, letters (and numbers), not time.
  /// - Reject time patterns like 22:37, contains ":", numbers only, status bar icons.
  static bool _isValidPlayerName(String text, String targetAccountName) {
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();

    // If exactly matching target account name, accept
    if (targetAccountName.isNotEmpty && lower == targetAccountName.toLowerCase().trim()) {
      return true;
    }

    // Length check: 3-16 chars as requested
    if (trimmed.length < 3 || trimmed.length > 16) return false;

    // Must not contain ":" (e.g. 22:37, map:, mode:, k/d:)
    if (trimmed.contains(':')) return false;

    // Ignore list check
    for (final ignored in _explicitIgnoreList) {
      if (lower == ignored || lower == ignored.replaceAll(' ', '')) {
        return false;
      }
    }

    // Regex: time pattern ^\d{1,2}:\d{2}$
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(trimmed)) return false;

    // Regex: numbers only ^\d+$
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return false;

    // Regex: percentage / battery, e.g. 78%
    if (RegExp(r'^\d{1,3}%$').hasMatch(trimmed)) return false;

    // Regex: network signal, e.g. 5G, 4G
    if (RegExp(r'^\d{1,2}[gG]$').hasMatch(trimmed)) return false;

    // Regex: general time format like 22.37 or 10:45 am
    if (RegExp(r'^\d{1,2}[.:]\d{2}(\s*(am|pm))?$', caseSensitive: false).hasMatch(trimmed)) {
      return false;
    }

    // Game stopwords
    if (_isStopword(trimmed)) return false;

    // Must be valid letters/numbers with common gamer tag punctuation, containing at least one letter
    if (!RegExp(r'^[a-zA-Z0-9_\-. ]+$').hasMatch(trimmed)) return false;
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) return false;

    return true;
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

      // 2. Decode image height to crop out top 15% (status bar) and bottom 20% (buttons)
      int imgHeight = 0;
      try {
        final bytes = await imageFile.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frameInfo = await codec.getNextFrame();
        imgHeight = frameInfo.image.height;
      } catch (e) {
        debugPrint('WinProofValidator: Codec read height failed: $e');
      }

      // Fallback: estimate height from max text coordinate
      if (imgHeight == 0) {
        double maxBottom = 0;
        for (final block in recognizedText.blocks) {
          if (block.boundingBox.bottom > maxBottom) {
            maxBottom = block.boundingBox.bottom;
          }
        }
        if (maxBottom > 0) {
          imgHeight = maxBottom.toInt();
        }
      }

      // Crop coordinates:
      // - Ignore top 15% of image (status bar with 22:37, 5G, 78% battery)
      // - Ignore bottom 20% (SHARE, LOBBY, REPLAY buttons)
      // - Only scan middle 65% where player name actually is
      final double topCutoff = imgHeight > 0 ? (imgHeight * 0.15) : 0.0;
      final double bottomCutoff = imgHeight > 0 ? (imgHeight * 0.80) : double.infinity;

      bool isInMiddle65(Rect rect) {
        if (imgHeight <= 0) return true;
        // Ignore status bar (top 15%)
        if (rect.top < topCutoff) return false;
        // Ignore bottom buttons (bottom 20%)
        if (rect.bottom > bottomCutoff) return false;
        return true;
      }

      final String targetAccountName = accountIdName.trim();
      final String lowerAccountName = targetAccountName.toLowerCase();

      // 3. Find player name correctly:
      // (a) Look for text that is just above "ONLINE" tag (that's the player name, e.g. Dtive)
      String? detectedOnlineName;

      for (final block in recognizedText.blocks) {
        for (int lIdx = 0; lIdx < block.lines.length; lIdx++) {
          final line = block.lines[lIdx];
          final lineText = line.text.trim();
          final lineLower = lineText.toLowerCase();

          if (lineLower.contains('online')) {
            // Check if player name is before ONLINE on the same line (e.g. "Dtive ONLINE")
            final parts = lineText.split(RegExp(r'online', caseSensitive: false));
            if (parts.isNotEmpty) {
              final prefix = _cleanCandidateName(parts.first);
              if (_isValidPlayerName(prefix, targetAccountName)) {
                detectedOnlineName = prefix;
                break;
              }
            }

            // Check line just above ONLINE in the same block
            if (lIdx > 0) {
              final prevLine = block.lines[lIdx - 1];
              final cleanPrev = _cleanCandidateName(prevLine.text);
              if (_isValidPlayerName(cleanPrev, targetAccountName)) {
                detectedOnlineName = cleanPrev;
                break;
              }
            }

            // Check closest line vertically above ONLINE across all blocks
            final onlineTop = line.boundingBox.top;
            final onlineLeft = line.boundingBox.left;
            final onlineRight = line.boundingBox.right;

            TextLine? closestAboveLine;
            double closestDistance = double.infinity;

            for (final otherBlock in recognizedText.blocks) {
              for (final otherLine in otherBlock.lines) {
                if (otherLine == line) continue;
                if (!isInMiddle65(otherLine.boundingBox)) continue;

                final otherBottom = otherLine.boundingBox.bottom;
                final distance = onlineTop - otherBottom;
                if (distance >= -15 && distance <= 160) {
                  final bool horizAligned = (otherLine.boundingBox.left <= onlineRight + 120) &&
                      (otherLine.boundingBox.right >= onlineLeft - 120);
                  if (horizAligned && distance < closestDistance) {
                    final clean = _cleanCandidateName(otherLine.text);
                    if (_isValidPlayerName(clean, targetAccountName)) {
                      closestDistance = distance;
                      closestAboveLine = otherLine;
                    }
                  }
                }
              }
            }

            if (closestAboveLine != null) {
              detectedOnlineName = _cleanCandidateName(closestAboveLine.text);
              break;
            }
          }
        }
        if (detectedOnlineName != null) break;
      }

      // (b) Look for text next to crown icon 👑 or Rank #1 / MVP
      String? detectedCrownName;
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          if (!isInMiddle65(line.boundingBox)) continue;
          final t = line.text;
          if (t.contains('👑') || t.contains('#1') || t.toLowerCase().contains('mvp')) {
            final stripped = t
                .replaceAll('👑', '')
                .replaceAll('#1', '')
                .replaceAll(RegExp(r'mvp', caseSensitive: false), '');
            final clean = _cleanCandidateName(stripped);
            if (_isValidPlayerName(clean, targetAccountName)) {
              detectedCrownName = clean;
              break;
            }
          }
        }
        if (detectedCrownName != null) break;
      }

      // (c) Collect all valid candidates in the middle 65% area
      final List<String> middleCandidates = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          // Strictly ignore status bar (top 15%) and buttons (bottom 20%)
          if (!isInMiddle65(line.boundingBox)) continue;

          final cleanLine = _cleanCandidateName(line.text);
          if (_isValidPlayerName(cleanLine, targetAccountName)) {
            if (!middleCandidates.contains(cleanLine)) {
              middleCandidates.add(cleanLine);
            }
          }

          for (final elem in line.elements) {
            final cleanElem = _cleanCandidateName(elem.text);
            if (_isValidPlayerName(cleanElem, targetAccountName)) {
              if (!middleCandidates.contains(cleanElem)) {
                middleCandidates.add(cleanElem);
              }
            }
          }
        }
      }

      // 4. Name comparison: check if uploader's account name matches
      bool isNameMatched = false;
      String? matchedCandidate;

      // Check online tag name
      if (detectedOnlineName != null &&
          detectedOnlineName.toLowerCase().trim() == lowerAccountName) {
        isNameMatched = true;
        matchedCandidate = detectedOnlineName;
      }

      // Check crown name
      if (!isNameMatched &&
          detectedCrownName != null &&
          detectedCrownName.toLowerCase().trim() == lowerAccountName) {
        isNameMatched = true;
        matchedCandidate = detectedCrownName;
      }

      // Check middle candidates
      if (!isNameMatched) {
        for (final candidate in middleCandidates) {
          if (candidate.toLowerCase().trim() == lowerAccountName) {
            isNameMatched = true;
            matchedCandidate = candidate;
            break;
          }
        }
      }

      // Check middle 65% text for token/word boundary match
      if (!isNameMatched && lowerAccountName.isNotEmpty) {
        final escaped = RegExp.escape(lowerAccountName);
        final wordRegex = RegExp(r'(^|[^\w])' + escaped + r'([^\w]|$)', caseSensitive: false);

        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            if (isInMiddle65(line.boundingBox)) {
              if (wordRegex.hasMatch(line.text.toLowerCase())) {
                isNameMatched = true;
                matchedCandidate = targetAccountName;
                break;
              }
            }
          }
          if (isNameMatched) break;
        }
      }

      // 5. Determine detected screenshot name
      String detectedScreenshotName;
      if (isNameMatched) {
        detectedScreenshotName = matchedCandidate ?? targetAccountName;
      } else if (detectedOnlineName != null && detectedOnlineName.isNotEmpty) {
        detectedScreenshotName = detectedOnlineName;
      } else if (detectedCrownName != null && detectedCrownName.isNotEmpty) {
        detectedScreenshotName = detectedCrownName;
      } else if (middleCandidates.isNotEmpty) {
        detectedScreenshotName = middleCandidates.first;
      } else {
        // Fallback: search for first valid name in middle area
        detectedScreenshotName = 'Unknown';
      }

      // 6. Final Decision & Rejection/Approval formatting
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
