import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_model.dart';

// =========================================================================
// RECOMMENDED FIRESTORE SECURITY RULES FOR GAMES KHABAR:
//
// Paste these in Firebase Console > Firestore Database > Rules:
//
// rules_version = '2';
// service cloud.firestore {
//   match /databases/{database}/documents {
//     match /news/{newsId} {
//       // 1. Anyone (public) can read gaming news
//       allow read: if true;
//
//       // 2. Only authenticated Admin can create or delete
//       allow create, delete: if request.auth != null;
//
//       // 3. Admin can update full document, OR public can increment view counter
//       allow update: if request.auth != null
//                     || request.resource.data.diff(resource.data).affectedKeys().hasOnly(['views']);
//     }
//   }
// }
// =========================================================================

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

  // In-memory master list (starts empty, populated strictly from Firestore)
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
    } catch (_) {
      // Ignore initial Firestore listener setup failure
    }
  }

  List<NewsModel> get currentNews => List.from(_currentNewsList);

  // Reactive stream of all news sorted by newest
  Stream<List<NewsModel>> getNewsStream() async* {
    yield List.from(_currentNewsList);
    yield* _streamController.stream;
  }

  // Force refresh news from Firestore (pull-to-refresh)
  Future<void> refreshNews() async {
    try {
      final db = _db;
      if (db != null) {
        final snapshot = await db
            .collection('news')
            .orderBy('timestamp', descending: true)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 4));

        final firestoreItems =
            snapshot.docs.map((doc) => NewsModel.fromFirestore(doc)).toList();

        _currentNewsList = firestoreItems;
        _streamController.add(List.from(_currentNewsList));
        return;
      }
    } catch (_) {}
    // Re-emit existing list on error or timeout
    _streamController.add(List.from(_currentNewsList));
  }

  // Increment views
  Future<void> incrementView(String id) async {
    final idx = _currentNewsList.indexWhere((item) => item.id == id);
    if (idx != -1) {
      final old = _currentNewsList[idx];
      _currentNewsList[idx] = old.copyWith(views: old.views + 1);
      _streamController.add(List.from(_currentNewsList));
    }

    try {
      final db = _db;
      if (db != null && !id.startsWith('local-')) {
        await db
            .collection('news')
            .doc(id)
            .update({'views': FieldValue.increment(1)})
            .timeout(const Duration(seconds: 2));
      }
    } catch (_) {}
  }

  // Update localized title & description translations in memory & Firestore
  Future<void> updateNewsTranslation(
    String id,
    String langCode,
    String translatedTitle,
    String translatedDesc,
  ) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty || cleanId.startsWith('local-')) return;

    final idx = _currentNewsList.indexWhere((item) => item.id == cleanId);
    if (idx != -1) {
      final old = _currentNewsList[idx];
      old.titleMap[langCode] = translatedTitle;
      old.descriptionMap[langCode] = translatedDesc;
      _streamController.add(List.from(_currentNewsList));
    }

    try {
      final db = _db;
      if (db != null) {
        await db.collection('news').doc(cleanId).set({
          'title': {langCode: translatedTitle},
          'description': {langCode: translatedDesc},
          'content': {langCode: translatedDesc},
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  // Get single news article by ID (checks memory first, then Firestore)
  Future<NewsModel?> getNewsById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;

    final inMemory = _currentNewsList.where((item) => item.id == cleanId).toList();
    if (inMemory.isNotEmpty) {
      return inMemory.first;
    }

    try {
      final db = _db;
      if (db != null) {
        final doc = await db.collection('news').doc(cleanId).get().timeout(const Duration(seconds: 4));
        if (doc.exists && doc.data() != null) {
          return NewsModel.fromFirestore(doc);
        }
      }
    } catch (_) {}
    return null;
  }

  Map<String, String> _parseTextMap(dynamic val, String fallback) {
    if (val is Map) {
      final res = <String, String>{};
      val.forEach((k, v) {
        if (v != null) res[k.toString()] = v.toString();
      });
      if (res.containsKey('roman') && !res.containsKey('ro')) {
        res['ro'] = res['roman']!;
      }
      if (res.containsKey('ro') && !res.containsKey('roman')) {
        res['roman'] = res['ro']!;
      }
      return res;
    } else if (val is String && val.isNotEmpty) {
      return {
        'roman': val,
        'ro': val,
        'en': val,
        'hi': val,
        'ur': val,
        'bn': val,
        'ar': val,
        'zh': val,
        'zh-cn': val,
      };
    }
    return {
      'roman': fallback,
      'ro': fallback,
      'en': fallback,
      'hi': fallback,
      'ur': fallback,
      'bn': fallback,
      'ar': fallback,
      'zh': fallback,
      'zh-cn': fallback,
    };
  }

  // Add new article - instant UI update + background Firestore sync (returns created newsId)
  Future<String> addNews(Map<String, dynamic> data) async {
    final localId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final videoUrl = data['videoUrl'] as String? ?? '';
    final titleMap = _parseTextMap(data['title'], 'Untitled');
    final descriptionMap = _parseTextMap(data['content'] ?? data['description'], '');

    final newModel = NewsModel(
      id: localId,
      titleMap: titleMap,
      descriptionMap: descriptionMap,
      category: data['category'] as String? ?? 'Gaming News',
      imageUrl: (data['imageUrl'] as String? ?? '').isNotEmpty
          ? data['imageUrl'] as String
          : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
      videoUrl: videoUrl,
      timeAgo: 'Just now',
      views: 0,
      isFree: data['isFree'] as bool? ?? false,
      isFeatured: data['isFeatured'] as bool? ?? false,
      sourceUrl: data['sourceUrl'] as String?,
      timestamp: Timestamp.now(),
    );

    // Insert at index 0 immediately so user sees it instantly
    _currentNewsList.insert(0, newModel);
    _streamController.add(List.from(_currentNewsList));

    String createdId = localId;

    // Try to sync with Firestore in background with 4-second timeout
    try {
      final db = _db;
      if (db != null) {
        final docRef = await db.collection('news').add({
          'title': titleMap,
          'content': descriptionMap,
          'description': descriptionMap,
          'category': newModel.category,
          'imageUrl': newModel.imageUrl,
          'videoUrl': videoUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'isPublished': true,
          'views': 0,
          'isFree': newModel.isFree,
          'isFeatured': newModel.isFeatured,
          'timeAgo': 'Just now',
          if (newModel.sourceUrl != null) 'sourceUrl': newModel.sourceUrl,
        }).timeout(const Duration(seconds: 4));
        createdId = docRef.id;
      }
    } catch (_) {
      // If Firestore write times out or fails (e.g. offline/permission), local store already has it
    }

    return createdId;
  }

  // Delete article
  Future<void> deleteNews(String id) async {
    _currentNewsList.removeWhere((item) => item.id == id);
    _streamController.add(List.from(_currentNewsList));

    try {
      final db = _db;
      if (db != null && !id.startsWith('local-')) {
        await db
            .collection('news')
            .doc(id)
            .delete()
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  // Update existing article - instant UI update + background Firestore sync
  Future<void> updateNews(String id, Map<String, dynamic> data) async {
    final idx = _currentNewsList.indexWhere((item) => item.id == id);
    final titleMap = _parseTextMap(data['title'], 'Untitled');
    final descriptionMap = _parseTextMap(data['content'] ?? data['description'], '');
    final category = data['category'] as String? ?? 'Gaming News';
    final imageUrl = (data['imageUrl'] as String? ?? '').isNotEmpty
        ? data['imageUrl'] as String
        : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80';
    final videoUrl = data['videoUrl'] as String? ?? '';
    final isFree = data['isFree'] as bool? ?? category.toLowerCase().contains('free');
    final isFeatured = data['isFeatured'] as bool? ?? false;

    if (idx != -1) {
      final old = _currentNewsList[idx];
      _currentNewsList[idx] = NewsModel(
        id: old.id,
        titleMap: titleMap,
        descriptionMap: descriptionMap,
        category: category,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        timeAgo: old.timeAgo,
        views: old.views,
        isFree: isFree,
        isFeatured: isFeatured,
        sourceUrl: data['sourceUrl'] as String? ?? old.sourceUrl,
        timestamp: old.timestamp,
      );
      _streamController.add(List.from(_currentNewsList));
    }

    try {
      final db = _db;
      if (db != null && !id.startsWith('local-')) {
        final updateData = <String, dynamic>{
          'title': titleMap,
          'content': descriptionMap,
          'description': descriptionMap,
          'category': category,
          'imageUrl': imageUrl,
          'videoUrl': videoUrl,
          'isFree': isFree,
          'isFeatured': isFeatured,
          if (data['sourceUrl'] != null) 'sourceUrl': data['sourceUrl'],
        };
        await db.collection('news').doc(id).update(updateData).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  // Set an article as featured and demote previous featured articles without deleting them
  Future<void> makeFeatured(String newDocId) async {
    // 1. Update in-memory state for immediate UI reactivity
    for (int i = 0; i < _currentNewsList.length; i++) {
      final item = _currentNewsList[i];
      if (item.id == newDocId) {
        _currentNewsList[i] = item.copyWith(isFeatured: true);
      } else if (item.isFeatured == true) {
        _currentNewsList[i] = item.copyWith(isFeatured: false);
      }
    }
    _streamController.add(List.from(_currentNewsList));

    // 2. Perform atomic batch update on Firestore
    try {
      final db = _db;
      if (db != null) {
        final batch = db.batch();

        // Find all currently featured documents
        final querySnapshot = await db
            .collection('news')
            .where('isFeatured', isEqualTo: true)
            .get();

        for (var doc in querySnapshot.docs) {
          if (doc.id != newDocId) {
            // Demote old featured document to regular news (do NOT delete)
            batch.update(doc.reference, {'isFeatured': false});
          }
        }

        // Promote new document to featured
        final newDocRef = db.collection('news').doc(newDocId);
        batch.update(newDocRef, {'isFeatured': true});

        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error making news featured: $e');
    }
  }
}
