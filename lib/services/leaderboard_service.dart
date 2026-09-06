import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gamer_user_model.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _gamersRef => _firestore.collection('gamers');

  Stream<List<GamerUser>> getTopPlayersByLikes({int limit = 15}) {
    return _gamersRef
        .orderBy('likesReceived', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GamerUser.fromFirestore(d)).toList());
  }

  Stream<List<GamerUser>> getTopPlayersByPosts({int limit = 15}) {
    return _gamersRef
        .orderBy('postsCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GamerUser.fromFirestore(d)).toList());
  }

  Stream<List<GamerUser>> getTopPlayersByFollowers({int limit = 15}) {
    return _gamersRef
        .orderBy('followersCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GamerUser.fromFirestore(d)).toList());
  }

  Stream<List<GamerUser>> getTopKdKings({int limit = 15}) {
    return _gamersRef
        .orderBy('kdRatio', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GamerUser.fromFirestore(d)).toList());
  }
}
