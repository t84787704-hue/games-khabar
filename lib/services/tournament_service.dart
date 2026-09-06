import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tournament_room_model.dart';

class TournamentService extends ChangeNotifier {
  static final TournamentService _instance = TournamentService._internal();
  factory TournamentService() => _instance;

  TournamentService._internal() {
    _loadFromLocal();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _storageKey = 'cached_tournament_rooms_v1';

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
        _rooms = decoded
            .map((item) => TournamentRoom.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        print('TournamentService: Loaded ${_rooms.length} rooms from local storage');
        notifyListeners();
      }
    } catch (e) {
      print('TournamentService: _loadFromLocal error: $e');
    }
  }

  /// Save current rooms list to local storage
  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_rooms.map((r) => r.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
      print('TournamentService: Saved ${_rooms.length} rooms to local storage');
    } catch (e) {
      print('TournamentService: _saveToLocal error: $e');
    }
  }

  /// Actually adds room to rooms list, calls notifyListeners(), saves to local storage, and syncs to Firestore
  Future<TournamentRoom> publishRoom(TournamentRoom room) async {
    print('TournamentService: publishRoom() called for room "${room.title}"');
    final doc = room.id.isNotEmpty ? _roomsRef.doc(room.id) : _roomsRef.doc();
    final publishedRoom = room.copyWith(
      id: room.id.isNotEmpty ? room.id : doc.id,
      createdAt: room.createdAt ?? DateTime.now(),
      isLive: true,
    );

    // 1. Actually add room to rooms list (at the top)
    _rooms.removeWhere((r) => r.id == publishedRoom.id);
    _rooms.insert(0, publishedRoom);
    print('TournamentService: publishRoom() - Added room "${publishedRoom.title}" (ID: ${publishedRoom.id}) to rooms list. Total rooms: ${_rooms.length}');

    // 2. Save to local storage
    await _saveToLocal();
    print('TournamentService: publishRoom() - Saved rooms to local storage');

    // 3. Call notifyListeners()
    notifyListeners();
    print('TournamentService: publishRoom() - notifyListeners() called successfully');

    // 4. Sync to Firestore in background
    try {
      await doc.set(publishedRoom.toMap());
      print('TournamentService: publishRoom() - Successfully synced room to Firestore: ${publishedRoom.id}');
    } catch (e) {
      print('TournamentService: publishRoom() - Firestore sync notice (persisted in local): $e');
    }

    return publishedRoom;
  }

  /// Alias for backward compatibility
  Future<void> createRoom(TournamentRoom room) async {
    await publishRoom(room);
  }

  /// Fetches rooms from Firestore and local storage, updates rooms list, and notifies listeners
  Future<List<TournamentRoom>> fetchRooms() async {
    print('TournamentService: fetchRooms() called');
    try {
      if (_rooms.isEmpty) {
        await _loadFromLocal();
      }

      final snap = await _roomsRef
          .where('isLive', isEqualTo: true)
          .orderBy('startTime', descending: false)
          .get();

      final firestoreRooms = snap.docs.map((d) => TournamentRoom.fromFirestore(d)).toList();
      print('TournamentService: fetchRooms() - Fetched ${firestoreRooms.length} rooms from Firestore');

      // Merge firestore rooms with freshly published local rooms
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
      print('TournamentService: fetchRooms() - Finished with ${_rooms.length} total rooms, called notifyListeners()');
    } catch (e) {
      print('TournamentService: fetchRooms() error: $e, using ${_rooms.length} cached rooms');
      if (_rooms.isEmpty) {
        await _loadFromLocal();
      }
      notifyListeners();
    }
    return _rooms;
  }

  Stream<List<TournamentRoom>> getLiveRoomsStream() {
    return _roomsRef
        .where('isLive', isEqualTo: true)
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snap) {
          final streamRooms = snap.docs.map((d) => TournamentRoom.fromFirestore(d)).toList();
          for (final sr in streamRooms) {
            final idx = _rooms.indexWhere((r) => r.id == sr.id);
            if (idx != -1) {
              _rooms[idx] = sr;
            } else {
              _rooms.add(sr);
            }
          }
          return streamRooms;
        });
  }

  Future<bool> joinRoom({
    required String roomId,
    required String hostUid,
    required String playerUid,
    required String playerName,
  }) async {
    try {
      print('TournamentService: joinRoom() called for room: $roomId by player: $playerUid');
      // Update local rooms state immediately
      final index = _rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        final room = _rooms[index];
        if (room.isFull) return false;
        final updatedPlayers = List<String>.from(room.joinedPlayers);
        if (!updatedPlayers.contains(playerUid)) {
          updatedPlayers.add(playerUid);
          _rooms[index] = room.copyWith(joinedPlayers: updatedPlayers);
          await _saveToLocal();
          notifyListeners();
        }
      }

      final doc = await _roomsRef.doc(roomId).get();
      if (!doc.exists) return false;
      final room = TournamentRoom.fromFirestore(doc);
      if (room.isFull) return false;

      await _roomsRef.doc(roomId).update({
        'joinedPlayers': FieldValue.arrayUnion([playerUid]),
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
      print('TournamentService: joinRoom error: $e');
      return false;
    }
  }

  Future<void> leaveRoom(String roomId, String playerUid) async {
    try {
      print('TournamentService: leaveRoom() called for room: $roomId by player: $playerUid');
      final index = _rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        final room = _rooms[index];
        final updatedPlayers = List<String>.from(room.joinedPlayers);
        updatedPlayers.remove(playerUid);
        _rooms[index] = room.copyWith(joinedPlayers: updatedPlayers);
        await _saveToLocal();
        notifyListeners();
      }

      await _roomsRef.doc(roomId).update({
        'joinedPlayers': FieldValue.arrayRemove([playerUid]),
      });
    } catch (e) {
      print('TournamentService: leaveRoom error: $e');
    }
  }

  Future<void> updateRoomCredentials({
    required String roomId,
    required String inGameRoomId,
    required String password,
  }) async {
    try {
      print('TournamentService: updateRoomCredentials() for room: $roomId');
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
      print('TournamentService: updateRoomCredentials error: $e');
    }
  }

  Future<void> closeRoom(String roomId) async {
    try {
      print('TournamentService: closeRoom() for room: $roomId');
      _rooms.removeWhere((r) => r.id == roomId);
      await _saveToLocal();
      notifyListeners();

      await _roomsRef.doc(roomId).update({'isLive': false});
    } catch (e) {
      print('TournamentService: closeRoom error: $e');
    }
  }
}
