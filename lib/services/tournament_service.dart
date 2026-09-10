import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tournament_room_model.dart';
import '../constants/tournament_game_categories.dart';
import 'coin_wallet_service.dart';

class TournamentService extends ChangeNotifier {
  static final TournamentService _instance = TournamentService._internal();
  factory TournamentService() => _instance;

  TournamentService._internal() {
    _loadFromLocal();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CoinWalletService _walletService = CoinWalletService();
  static const String _storageKey = 'cached_tournament_rooms_v3';

  List<TournamentRoom> _rooms = [];
  List<TournamentRoom> get rooms => List.unmodifiable(_rooms);

  CollectionReference get _roomsRef => _firestore.collection('tournament_rooms');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  /// Load cached rooms from local storage
  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        final Map<String, TournamentRoom> map = {};
        for (final item in decoded) {
          final room = TournamentRoom.fromJson(Map<String, dynamic>.from(item));
          map[room.id] = room; // deduplicate
        }
        _rooms = map.values.toList();
      }

      if (_rooms.isEmpty) {
        _rooms = _getDefaultMultiGameRooms();
        await _saveToLocal();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('TournamentService: _loadFromLocal error: $e');
      if (_rooms.isEmpty) {
        _rooms = _getDefaultMultiGameRooms();
      }
      notifyListeners();
    }
  }

  List<TournamentRoom> _getDefaultMultiGameRooms() {
    final now = DateTime.now();
    final List<TournamentRoom> defaultRooms = [];
    int idCounter = 101;

    for (final gameName in kExactGameCategories) {
      final config = getGameConfig(gameName);
      final roomId = 'seed_${gameName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_$idCounter';
      defaultRooms.add(
        TournamentRoom(
          id: roomId,
          hostId: 'admin_bot',
          hostName: 'AI Gaming Bot',
          hostAvatar: '',
          gameType: gameName,
          gameMode: config.defaultMode,
          roomType: config.defaultMode,
          title: '$gameName ${config.defaultMode} Auto #$idCounter',
          map: config.defaultMap,
          platform: config.platform,
          serverRegion: 'Asia / India',
          rules: 'Official Auto Room. Entry is FREE (Watch 1 Ad to Join). 500 Coins Escrow Prize Pool from Admin Wallet.',
          entryFee: 'FREE (Watch 1 Ad to Join)',
          prize: '💰 500 Coins Prize',
          prizePool: '💰 500 Coins',
          prizePoolCoins: 500,
          entryFeeCoins: 0,
          escrowCoins: 500,
          status: 'OPEN',
          roomId: 'AUTO-$idCounter',
          password: '',
          startTime: now.add(Duration(minutes: (idCounter % 50) + 15)),
          maxSlots: config.defaultSlots,
          totalSlots: config.defaultSlots,
          currentSlots: 0,
          joinedPlayers: const [],
          joinedPlayerNames: const {},
          isLive: true,
          isRoomRevealed: true,
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
      );
      idCounter++;
    }

    return defaultRooms;
  }

  /// Save current rooms list to local storage
  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_rooms.map((r) => r.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('TournamentService: _saveToLocal error: $e');
    }
  }

  /// Actually adds room to rooms list, calls notifyListeners(), saves to local storage, and syncs to Firestore
  Future<TournamentRoom> publishRoom(TournamentRoom room) async {
    debugPrint('TournamentService: publishRoom() called for room "${room.title}"');
    final doc = room.id.isNotEmpty ? _roomsRef.doc(room.id) : _roomsRef.doc();
    final publishedRoom = room.copyWith(
      id: room.id.isNotEmpty ? room.id : doc.id,
      createdAt: room.createdAt ?? DateTime.now(),
      isLive: true,
      status: 'OPEN',
    );

    // 1. Actually add room to rooms list (deduplicated by id)
    _rooms.removeWhere((r) => r.id == publishedRoom.id);
    _rooms.insert(0, publishedRoom);

    // 2. Save to local storage
    await _saveToLocal();

    // 3. Call notifyListeners()
    notifyListeners();

    // 4. Sync to Firestore in background
    try {
      await doc.set(publishedRoom.toMap());
    } catch (e) {
      debugPrint('TournamentService: publishRoom Firestore sync notice: $e');
    }

    return publishedRoom;
  }

  /// Alias for backward compatibility
  Future<void> createRoom(TournamentRoom room) async {
    await publishRoom(room);
  }

  /// Fetches rooms from Firestore and local storage, updates rooms list, and notifies listeners
  Future<List<TournamentRoom>> fetchRooms() async {
    try {
      if (_rooms.isEmpty) {
        await _loadFromLocal();
      }

      final snap = await _roomsRef
          .where('isLive', isEqualTo: true)
          .orderBy('startTime', descending: false)
          .get();

      final firestoreRooms = snap.docs.map((d) => TournamentRoom.fromFirestore(d)).toList();

      // Deduplicate by ID
      final Map<String, TournamentRoom> roomMap = {};
      for (final r in _rooms) {
        if (r.isLive) roomMap[r.id] = r;
      }
      for (final r in firestoreRooms) {
        roomMap[r.id] = r;
      }

      _rooms = roomMap.values.toList();
      _rooms.sort((a, b) => b.startTime.compareTo(a.startTime));

      await _saveToLocal();
      notifyListeners();
    } catch (e) {
      debugPrint('TournamentService: fetchRooms error: $e');
      if (_rooms.isEmpty) {
        await _loadFromLocal();
      }
      notifyListeners();
    }
    return _rooms;
  }

  Stream<List<TournamentRoom>> getLiveRoomsStream({String? gameName}) {
    Query query = _roomsRef.where('isLive', isEqualTo: true);

    return query
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snap) {
          final streamRooms = snap.docs.map((d) => TournamentRoom.fromFirestore(d)).toList();
          final Map<String, TournamentRoom> map = {};
          for (final r in _rooms) {
            map[r.id] = r;
          }
          for (final sr in streamRooms) {
            map[sr.id] = sr;
          }
          _rooms = map.values.toList();

          if (gameName != null && gameName.isNotEmpty && gameName != 'All Games') {
            final target = gameName.toLowerCase().trim();
            return _rooms.where((r) {
              final gName = r.gameName.toLowerCase().trim();
              final gType = r.gameType.toLowerCase().trim();
              return gName == target || gType == target;
            }).toList();
          }

          return _rooms;
        });
  }

  Future<bool> joinRoom({
    required String roomId,
    required String hostUid,
    required String playerUid,
    required String playerName,
  }) async {
    try {
      debugPrint('TournamentService: joinRoom() called for room: $roomId by player: $playerUid');
      final index = _rooms.indexWhere((r) => r.id == roomId);
      TournamentRoom? targetRoom;
      if (index != -1) {
        targetRoom = _rooms[index];
      } else {
        final doc = await _roomsRef.doc(roomId).get();
        if (doc.exists) targetRoom = TournamentRoom.fromFirestore(doc);
      }

      if (targetRoom == null) return false;
      if (targetRoom.isFull) return false;
      if (targetRoom.joinedPlayers.contains(playerUid)) return true; // already joined

      // If entry fee > 0, deduct from player's coins to escrow
      if (targetRoom.entryFeeCoins > 0 && playerUid != targetRoom.hostId) {
        final success = await _walletService.holdEntryFeeCoins(
          userId: playerUid,
          entryFeeCoins: targetRoom.entryFeeCoins,
          roomId: targetRoom.id,
          roomTitle: targetRoom.title,
        );
        if (!success) return false; // Not enough coins
      }

      // Update local room
      final updatedPlayers = List<String>.from(targetRoom.joinedPlayers)..add(playerUid);
      final updatedNames = Map<String, String>.from(targetRoom.joinedPlayerNames)..[playerUid] = playerName;
      final updatedRoom = targetRoom.copyWith(
        joinedPlayers: updatedPlayers,
        joinedPlayerNames: updatedNames,
        escrowCoins: targetRoom.escrowCoins + (targetRoom.entryFeeCoins > 0 && playerUid != targetRoom.hostId ? targetRoom.entryFeeCoins : 0),
      );

      if (index != -1) {
        _rooms[index] = updatedRoom;
      } else {
        _rooms.add(updatedRoom);
      }
      await _saveToLocal();
      notifyListeners();

      // Update Firestore
      await _roomsRef.doc(roomId).update({
        'joinedPlayers': FieldValue.arrayUnion([playerUid]),
        'joinedPlayerNames.$playerUid': playerName,
        'escrowCoins': updatedRoom.escrowCoins,
      });

      if (hostUid != playerUid) {
        await _notificationsRef.add({
          'recipientUid': hostUid,
          'senderUid': playerUid,
          'type': 'room_joined',
          'message': 'joined your Custom Tournament ($playerName)!',
          'roomId': roomId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('TournamentService: joinRoom error: $e');
      return false;
    }
  }

  Future<void> leaveRoom(String roomId, String playerUid) async {
    try {
      debugPrint('TournamentService: leaveRoom() for room: $roomId by player: $playerUid');
      final index = _rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        final room = _rooms[index];
        final updatedPlayers = List<String>.from(room.joinedPlayers)..remove(playerUid);
        _rooms[index] = room.copyWith(joinedPlayers: updatedPlayers);
        await _saveToLocal();
        notifyListeners();

        // Refund entry fee if applied
        if (room.entryFeeCoins > 0 && playerUid != room.hostId) {
          await _walletService.refundEntryFeeOnLeave(
            userId: playerUid,
            entryFeeCoins: room.entryFeeCoins,
            roomId: room.id,
            roomTitle: room.title,
          );
        }
      }

      await _roomsRef.doc(roomId).update({
        'joinedPlayers': FieldValue.arrayRemove([playerUid]),
      });
    } catch (e) {
      debugPrint('TournamentService: leaveRoom error: $e');
    }
  }

  /// Participant uploads BGMI Victory screenshot with OCR result
  Future<bool> submitResultScreenshot({
    required String roomId,
    required String playerUid,
    required String playerName,
    required String screenshotUrl,
    required String ocrText,
    required bool isVictory,
    List<String>? detectedWinnerUids,
    List<String>? detectedWinnerNames,
  }) async {
    try {
      final submission = {
        'screenshotUrl': screenshotUrl,
        'submittedAt': DateTime.now().toIso8601String(),
        'ocrText': ocrText,
        'isVictory': isVictory,
        'playerName': playerName,
        if (detectedWinnerUids != null) 'detectedWinnerUids': detectedWinnerUids,
        if (detectedWinnerNames != null) 'detectedWinnerNames': detectedWinnerNames,
      };

      final index = _rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        final subs = Map<String, dynamic>.from(_rooms[index].resultSubmissions);
        subs[playerUid] = submission;
        _rooms[index] = _rooms[index].copyWith(resultSubmissions: subs);
        await _saveToLocal();
        notifyListeners();
      }

      await _roomsRef.doc(roomId).update({
        'resultSubmissions.$playerUid': submission,
      });
      return true;
    } catch (e) {
      debugPrint('TournamentService: submitResultScreenshot error: $e');
      return false;
    }
  }

  /// Host finishes match and selects the winner (or winning team members):
  /// Transfers all escrowCoins directly from escrow to winners (divided equally among team members)
  /// and updates room status to COMPLETED
  Future<bool> finishMatchWithWinner({
    required String roomId,
    String? winnerUid,
    List<String>? winnerUids,
    String? winnerName,
    List<String>? winnerNames,
  }) async {
    try {
      TournamentRoom? room;
      final index = _rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        room = _rooms[index];
      } else {
        try {
          final doc = await _roomsRef.doc(roomId).get();
          if (doc.exists) {
            room = TournamentRoom.fromFirestore(doc);
          }
        } catch (_) {}
      }

      if (room == null) return false;
      final currentRoom = room;
      final hostId = currentRoom.hostId;

      final List<String> allWinnerUids = [];
      if (winnerUids != null && winnerUids.isNotEmpty) {
        allWinnerUids.addAll(winnerUids);
      } else if (winnerUid != null && winnerUid.isNotEmpty) {
        allWinnerUids.add(winnerUid);
      }
      if (allWinnerUids.isEmpty) return false;

      final List<String> allWinnerNames = [];
      if (winnerNames != null && winnerNames.isNotEmpty) {
        allWinnerNames.addAll(winnerNames);
      } else if (winnerName != null && winnerName.isNotEmpty) {
        allWinnerNames.add(winnerName);
      } else {
        allWinnerNames.add('Winner');
      }

      // 1. Calculate total escrow reward
      final totalEntryFees = currentRoom.entryFeeCoins * currentRoom.joinedPlayers.where((p) => p != hostId).length;
      final prizeToAward = currentRoom.prizePoolCoins > 0 ? currentRoom.prizePoolCoins : currentRoom.escrowCoins;

      await _walletService.awardWinnerPrize(
        hostId: hostId,
        winnerIds: allWinnerUids,
        prizePoolCoins: prizeToAward,
        totalEntryFees: totalEntryFees,
        joiners: currentRoom.joinedPlayers,
        entryFeeCoinsPerJoiner: currentRoom.entryFeeCoins,
        roomId: currentRoom.id,
        roomTitle: currentRoom.title,
        winnerNames: allWinnerNames,
      );

      // 2. Penalize any participant who did not submit result (-10 trustScore)
      for (final pUid in currentRoom.joinedPlayers) {
        if (!currentRoom.resultSubmissions.containsKey(pUid) && pUid != hostId) {
          await _walletService.penalizeTrustScore(pUid, 10, 'Did not submit match result');
        }
      }

      final combinedWinnerUid = allWinnerUids.join(',');
      final combinedWinnerName = allWinnerNames.join(', ');

      // 3. Mark room as COMPLETED in memory & Firestore
      final roomIdx = _rooms.indexWhere((r) => r.id == roomId);
      if (roomIdx != -1) {
        _rooms[roomIdx] = _rooms[roomIdx].copyWith(
          status: 'COMPLETED',
          winnerUid: combinedWinnerUid,
          winnerName: combinedWinnerName,
          isLive: false,
        );
        await _saveToLocal();
        notifyListeners();
      }

      try {
        await _roomsRef.doc(roomId).set({
          'status': 'COMPLETED',
          'winnerUid': combinedWinnerUid,
          'winnerName': combinedWinnerName,
          'isLive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('TournamentService Firestore update error: $e');
      }

      return true;
    } catch (e) {
      debugPrint('TournamentService finishMatchWithWinner error: $e');
      return false;
    }
  }

  /// Cancel or Expire Room:
  /// Refunds prizePoolCoins to host, refunds entry fees to joiners, and marks status EXPIRED
  Future<void> cancelOrExpireRoom(String roomId) async {
    try {
      TournamentRoom? room;
      final index = _rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        room = _rooms[index];
      } else {
        try {
          final doc = await _roomsRef.doc(roomId).get();
          if (doc.exists) {
            room = TournamentRoom.fromFirestore(doc);
          }
        } catch (_) {}
      }

      if (room == null) return;

      final prizeToRefund = room.prizePoolCoins > 0 ? room.prizePoolCoins : room.escrowCoins;

      await _walletService.refundRoom(
        hostId: room.hostId,
        prizePoolCoins: prizeToRefund,
        joiners: room.joinedPlayers,
        entryFeeCoins: room.entryFeeCoins,
        roomId: room.id,
        roomTitle: room.title,
      );

      final rIndex = _rooms.indexWhere((r) => r.id == roomId);
      if (rIndex != -1) {
        _rooms[rIndex] = _rooms[rIndex].copyWith(
          status: 'EXPIRED',
          isLive: false,
        );
        await _saveToLocal();
        notifyListeners();
      }

      try {
        await _roomsRef.doc(roomId).set({
          'status': 'EXPIRED',
          'isLive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    } catch (e) {
      debugPrint('TournamentService cancelOrExpireRoom error: $e');
    }
  }

  Future<void> updateRoomCredentials({
    required String roomId,
    required String inGameRoomId,
    required String password,
  }) async {
    try {
      final index = _rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        _rooms[index] = _rooms[index].copyWith(
          roomId: inGameRoomId,
          password: password,
          isRoomRevealed: true,
        );
        await _saveToLocal();
        notifyListeners();
      }

      await _roomsRef.doc(roomId).update({
        'roomId': inGameRoomId,
        'password': password,
        'isRoomRevealed': true,
      });
    } catch (e) {
      debugPrint('TournamentService: updateRoomCredentials error: $e');
    }
  }

  Future<void> closeRoom(String roomId) async {
    try {
      _rooms.removeWhere((r) => r.id == roomId);
      await _saveToLocal();
      notifyListeners();

      await _roomsRef.doc(roomId).update({'isLive': false});
    } catch (e) {
      debugPrint('TournamentService: closeRoom error: $e');
    }
  }
}

