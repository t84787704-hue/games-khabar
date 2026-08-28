import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of all news sorted by timestamp descending
  Stream<List<NewsModel>> getNewsStream() {
    return _db
        .collection('news')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NewsModel.fromFirestore(doc)).toList());
  }

  // Stream of Free Games sorted by timestamp descending
  Stream<List<NewsModel>> getFreeGamesStream() {
    return _db
        .collection('news')
        .where('isFree', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NewsModel.fromFirestore(doc)).toList());
  }

  // Increment view counter atomically in Firestore
  Future<void> incrementView(String id) {
    return _db.collection('news').doc(id).update({
      'views': FieldValue.increment(1),
    });
  }

  // Add new article from Admin
  Future<void> addNews(Map<String, dynamic> data) {
    return _db.collection('news').add({
      ...data,
      'timestamp': FieldValue.serverTimestamp(),
      'views': 0,
    });
  }
}
