import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament_room_model.dart';

class TournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _roomsRef => _firestore.collection('tournament_rooms');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  Future<void> createRoom(TournamentRoom room) async {
    try {
      final doc = room.id.isNotEmpty ? _roomsRef.doc(room.id) : _roomsRef.doc();
      final finalRoom = room.id.isEmpty ? room.copyWith(id: doc.id) : room;
      await doc.set(finalRoom.toMap());
    } catch (_) {}
  }

  Stream<List<TournamentRoom>> getLiveRoomsStream() {
    return _roomsRef
        .where('isLive', isEqualTo: true)
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TournamentRoom.fromFirestore(d)).toList());
  }

  Future<bool> joinRoom({
    required String roomId,
    required String hostUid,
    required String playerUid,
    required String playerName,
  }) async {
    try {
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
    } catch (_) {
      return false;
    }
  }

  Future<void> leaveRoom(String roomId, String playerUid) async {
    try {
      await _roomsRef.doc(roomId).update({
        'joinedPlayers': FieldValue.arrayRemove([playerUid]),
      });
    } catch (_) {}
  }

  Future<void> updateRoomCredentials({
    required String roomId,
    required String inGameRoomId,
    required String password,
  }) async {
    try {
      await _roomsRef.doc(roomId).update({
        'roomId': inGameRoomId,
        'password': password,
        'isRoomRevealed': true,
      });
    } catch (_) {}
  }

  Future<void> closeRoom(String roomId) async {
    try {
      await _roomsRef.doc(roomId).update({'isLive': false});
    } catch (_) {}
  }
}
