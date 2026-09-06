import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge_model.dart';

class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _challengesRef => _firestore.collection('challenges');
  CollectionReference get _notificationsRef => _firestore.collection('notifications');

  Future<void> sendChallenge(GamerChallenge challenge) async {
    try {
      final docRef = challenge.id.isNotEmpty ? _challengesRef.doc(challenge.id) : _challengesRef.doc();
      final finalChallenge = challenge.id.isEmpty ? challenge.copyWith(id: docRef.id) : challenge;
      await docRef.set(finalChallenge.toMap());

      // Send in-app notification to challenged user
      await _notificationsRef.add({
        'recipientUid': challenge.challengedId,
        'senderUid': challenge.challengerId,
        'type': 'challenge',
        'message': 'challenged you to a 1v1 Battle (${challenge.mode}, ${challenge.weaponRule})!',
        'challengeId': finalChallenge.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Fallback
    }
  }

  Future<void> acceptChallenge(String challengeId, {String? challengerUid, String? responderName}) async {
    try {
      await _challengesRef.doc(challengeId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (challengerUid != null && challengerUid.isNotEmpty) {
        await _notificationsRef.add({
          'recipientUid': challengerUid,
          'type': 'challenge_accepted',
          'message': '${responderName ?? "Opponent"} accepted your 1v1 challenge! Room is ON.',
          'challengeId': challengeId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> declineChallenge(String challengeId) async {
    try {
      await _challengesRef.doc(challengeId).update({
        'status': 'declined',
      });
    } catch (_) {}
  }

  Future<void> setWinner(String challengeId, String winnerId) async {
    try {
      await _challengesRef.doc(challengeId).update({
        'status': 'completed',
        'winnerId': winnerId,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Stream<List<GamerChallenge>> getUserChallengesStream(String userId) {
    return _challengesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => GamerChallenge.fromFirestore(d))
          .where((c) => c.challengerId == userId || c.challengedId == userId)
          .toList();
    });
  }

  Stream<List<GamerChallenge>> getPendingIncomingChallenges(String userId) {
    return _challengesRef
        .where('challengedId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => GamerChallenge.fromFirestore(d)).toList());
  }
}
