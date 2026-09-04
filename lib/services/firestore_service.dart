import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  final StreamController<List<NewsModel>> _streamController =
      StreamController<List<NewsModel>>.broadcast();

  List<NewsModel> _currentNewsList = [];

  FirestoreService._internal() {
    _initFirestoreListener();
  }

  void _initFirestoreListener() {
    try {
      final db = _db;
      if (db == null) return;
      db
         .collection('news')
         .orderBy('timestamp', descending: true)
         .limit(500)
         .snapshots()
         .listen(
        (snapshot) {
          final firestoreItems =
              snapshot.docs.map((doc) => NewsModel.fromFirestore(doc)).toList();
          _currentNewsList = firestoreItems;
          _streamController.add(List.from(_currentNewsList));
        },
        onError: (err) {
          _streamController.add(List.from(_currentNewsList));
        },
      );
    } catch (_) {}
  }

  List<NewsModel> get currentNews => List.from(_currentNewsList);

  Stream<List<NewsModel>> getNewsStream() async* {
    yield List.from(_currentNewsList);
    yield* _streamController.stream;
  }

  Future<void> refreshNews() async {
    try {
      final db = _db;
      if (db!= null) {
        final snapshot = await db
           .collection('news')
           .orderBy('timestamp', descending: true)
           .limit(500)
           .get(const GetOptions(source: Source.serverAndCache))
           .timeout(const Duration(seconds: 10));

        final firestoreItems =
            snapshot.docs.map((doc) => NewsModel.fromFirestore(doc)).toList();
        _currentNewsList = firestoreItems;
        _streamController.add(List.from(_currentNewsList));
        return;
      }
    } catch (_) {}
    _streamController.add(List.from(_currentNewsList));
  }

  Future<void> incrementView(String id) async {
    final idx = _currentNewsList.indexWhere((item) => item.id == id);
    if (idx!= -1) {
      final old = _currentNewsList[idx];
      _currentNewsList[idx] = old.copyWith(views: old.views + 1);
      _streamController.add(List.from(_currentNewsList));
    }
    try {
      final db = _db;
      if (db!= null &&!id.startsWith('local-')) {
        await db.collection('news').doc(id).update({'views': FieldValue.increment(1)}).timeout(const Duration(seconds: 2));
      }
    } catch (_) {}
  }

  Future<void> updateNewsTranslation(String id, String langCode, String translatedTitle, String translatedDesc) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty || cleanId.startsWith('local-')) return;
    final idx = _currentNewsList.indexWhere((item) => item.id == cleanId);
    if (idx!= -1) {
      final old = _currentNewsList[idx];
      old.titleMap[langCode] = translatedTitle;
      old.descriptionMap[langCode] = translatedDesc;
      _streamController.add(List.from(_currentNewsList));
    }
    try {
      final db = _db;
      if (db!= null) {
        await db.collection('news').doc(cleanId).set({
          'title': {langCode: translatedTitle},
          'description': {langCode: translatedDesc},
          'content': {langCode: translatedDesc},
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  Future<NewsModel?> getNewsById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;
    final inMemory = _currentNewsList.where((item) => item.id == cleanId).toList();
    if (inMemory.isNotEmpty) return inMemory.first;
    try {
      final db = _db;
      if (db!= null) {
        final doc = await db.collection('news').doc(cleanId).get().timeout(const Duration(seconds: 4));
        if (doc.exists && doc.data()!= null) return NewsModel.fromFirestore(doc);
      }
    } catch (_) {}
    return null;
  }

  Map<String, String> _parseTextMap(dynamic val, String fallback) {
    if (val is Map) {
      final res = <String, String>{};
      val.forEach((k, v) { if (v!= null) res[k.toString()] = v.toString(); });
      if (res.containsKey('roman') &&!res.containsKey('ro')) res['ro'] = res['roman']!;
      if (res.containsKey('ro') &&!res.containsKey('roman')) res['roman'] = res['ro']!;
      return res;
    } else if (val is String && val.isNotEmpty) {
      return {'roman': val, 'ro': val, 'en': val, 'hi': val, 'ur': val, 'bn': val, 'ar': val, 'zh': val, 'zh-cn': val};
    }
    return {'roman': fallback, 'ro': fallback, 'en': fallback, 'hi': fallback, 'ur': fallback, 'bn': fallback, 'ar': fallback, 'zh': fallback, 'zh-cn': fallback};
  }

  Future<String> addNews(Map<String, dynamic> data) async {
    final localId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final videoUrl = data['videoUrl'] as String??? '';
    final titleMap = _parseTextMap(data['title'], 'Untitled');
    final descriptionMap = _parseTextMap(data['content']?? data['description'], '');
    final newModel = NewsModel(
      id: localId, titleMap: titleMap, descriptionMap: descriptionMap,
      category: data['category'] as String??? 'Gaming News',
      imageUrl: (data['imageUrl'] as String??? '').isNotEmpty? data['imageUrl'] as String : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
      videoUrl: videoUrl, timeAgo: 'Just now', views: 0,
      isFree: data['isFree'] as bool??? false, isFeatured: data['isFeatured'] as bool??? false,
      sourceUrl: data['sourceUrl'] as String?,
    );
    _currentNewsList.insert(0, newModel);
    _streamController.add(List.from(_currentNewsList));
    String createdId = localId;
    try {
      final db = _db;
      if (db!= null) {
        final docRef = await db.collection('news').add({
          'title': titleMap, 'content': descriptionMap, 'description': descriptionMap,
          'category': newModel.category, 'imageUrl': newModel.imageUrl, 'videoUrl': videoUrl,
          'timestamp': FieldValue.serverTimestamp(), 'isPublished': true, 'views': 0,
          'isFree': newModel.isFree, 'isFeatured': newModel.isFeatured, 'timeAgo': 'Just now',
          if (newModel.sourceUrl!= null) 'sourceUrl': newModel.sourceUrl,
        }).timeout(const Duration(seconds: 4));
        createdId = docRef.id;
      }
    } catch (_) {}
    return createdId;
  }

  Future<void> deleteNews(String id) async {
    _currentNewsList.removeWhere((item) => item.id == id);
    _streamController.add(List.from(_currentNewsList));
    try {
      final db = _db;
      if (db!= null &&!id.startsWith('local-')) {
        await db.collection('news').doc(id).delete().timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  Future<void> updateNews(String id, Map<String, dynamic> data) async {
    final idx = _currentNewsList.indexWhere((item) => item.id == id);
    final titleMap = _parseTextMap(data['title'], 'Untitled');
    final descriptionMap = _parseTextMap(data['content']?? data['description'], '');
    final category = data['category'] as String??? 'Gaming News';
    final imageUrl = (data['imageUrl'] as String??? '').isNotEmpty? data['imageUrl'] as String : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80';
    final videoUrl = data['videoUrl'] as String??? '';
    final isFree = data['isFree'] as bool??? category.toLowerCase().contains('free');
    final isFeatured = data['isFeatured'] as bool??? false;
    if (idx!= -1) {
      final old = _currentNewsList[idx];
      _currentNewsList[idx] = NewsModel(
        id: old.id, titleMap: titleMap, descriptionMap: descriptionMap, category: category,
        imageUrl: imageUrl, videoUrl: videoUrl, timeAgo: old.timeAgo, views: old.views,
        isFree: isFree, isFeatured: isFeatured, sourceUrl: data['sourceUrl'] as String??? old.sourceUrl, timestamp: old.timestamp,
      );
      _streamController.add(List.from(_currentNewsList));
    }
    try {
      final db = _db;
      if (db!= null &&!id.startsWith('local-')) {
        await db.collection('news').doc(id).update({
          'title': titleMap, 'content': descriptionMap, 'description': descriptionMap,
          'category': category, 'imageUrl': imageUrl, 'videoUrl': videoUrl, 'isFree': isFree, 'isFeatured': isFeatured,
          if (data['sourceUrl']!= null) 'sourceUrl': data['sourceUrl'],
        }).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  Future<void> makeFeatured(String newDocId) async {
    for (int i = 0; i < _currentNewsList.length; i++) {
      final item = _currentNewsList[i];
      if (item.id == newDocId) _currentNewsList[i] = item.copyWith(isFeatured: true);
      else if (item.isFeatured == true) _currentNewsList[i] = item.copyWith(isFeatured: false);
    }
    _streamController.add(List.from(_currentNewsList));
    try {
      final db = _db;
      if (db!= null) {
        final batch = db.batch();
        final querySnapshot = await db.collection('news').where('isFeatured', isEqualTo: true).get();
        for (var doc in querySnapshot.docs) { if (doc.id!= newDocId) batch.update(doc.reference, {'isFeatured': false}); }
        batch.update(db.collection('news').doc(newDocId), {'isFeatured': true});
        await batch.commit();
      }
    } catch (e) { debugPrint('Error making news featured: $e'); }
  }
}