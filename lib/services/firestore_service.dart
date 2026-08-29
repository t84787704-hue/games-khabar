import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StreamController<List<NewsModel>> _streamController =
      StreamController<List<NewsModel>>.broadcast();

  // In-memory master list seeded with the fallback gaming news
  List<NewsModel> _currentNewsList = [
    NewsModel(
      id: 'dummy-1',
      title: 'BGMI 3.2 Update: New Map, Mecha Fusion Mode & Futuristic Weapons',
      description:
          'Battlegrounds Mobile India (BGMI) rolls out the massive 3.2 update featuring robotic suits, new weapon attachments, enhanced 90/120 FPS performance, and exciting Royale Pass rewards.',
      category: 'BGMI',
      imageUrl:
          'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '15m ago',
      views: 1240,
    ),
    NewsModel(
      id: 'dummy-2',
      title: 'Free Fire MAX World Series Tournament 2024 Announced with \$2M Prize Pool',
      description:
          'Garena unveils official roadmap and qualifying tournament slots for Free Fire World Series with regional qualifiers and exclusive in-game character bundles.',
      category: 'Free Fire',
      imageUrl:
          'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '1h ago',
      views: 980,
    ),
    NewsModel(
      id: 'dummy-3',
      title: 'PUBG Mobile 3.4 Vampire Blood Moon Mode & Flying Steed Details',
      description:
          'The upcoming PUBG Mobile 3.4 version brings gothic vampire powers, transformed werewolf mechanics, and magical mounts across Erangel and Livik.',
      category: 'PUBG',
      imageUrl:
          'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '3h ago',
      views: 750,
    ),
    NewsModel(
      id: 'dummy-4',
      title: 'Call of Duty Warzone Mobile Season 4: Rebirth Island & Ranked Play',
      description:
          'Activision drops Season 4 with significant optimization passes for mid-range chipsets, Rebirth Island Resurgence mode, and shared Battle Pass progression.',
      category: 'COD',
      imageUrl:
          'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '5h ago',
      views: 620,
    ),
    NewsModel(
      id: 'dummy-5',
      title: 'Valorant Mobile Closed Beta Regional Rollout Dates Confirmed',
      description:
          'Riot Games starts regional technical testing for Valorant Mobile with intuitive touch controls, gyro aiming support, and customized mobile maps.',
      category: 'Valorant',
      imageUrl:
          'https://images.unsplash.com/photo-1612287233207-6f81c9535032?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '8h ago',
      views: 1430,
    ),
    NewsModel(
      id: 'dummy-6',
      title: 'GTA 6 Official Release Window & Vice City Map Size Comparisons',
      description:
          'Rockstar Games re-confirms Autumn 2025 release window for Grand Theft Auto VI, highlighting next-gen AI simulations and expanded Leonida state map.',
      category: 'Gaming News',
      imageUrl:
          'https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '12h ago',
      views: 2890,
    ),
  ];

  FirestoreService._internal() {
    _initFirestoreListener();
  }

  void _initFirestoreListener() {
    try {
      _db
          .collection('news')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final firestoreItems =
                snapshot.docs.map((doc) => NewsModel.fromFirestore(doc)).toList();

            // Merge newly added local items if not yet in snapshot
            final Map<String, NewsModel> map = {};
            for (var item in firestoreItems) {
              map[item.id] = item;
            }
            for (var local in _currentNewsList) {
              if (!map.containsKey(local.id)) {
                map[local.id] = local;
              }
            }

            _currentNewsList = map.values.toList();
            _streamController.add(List.from(_currentNewsList));
          }
        },
        onError: (err) {
          // Firestore connection failed or offline, stream continues with in-memory store
          _streamController.add(List.from(_currentNewsList));
        },
      );
    } catch (_) {
      // Ignore initial Firestore listener setup failure
    }
  }

  // Reactive stream of all news sorted by newest
  Stream<List<NewsModel>> getNewsStream() async* {
    yield List.from(_currentNewsList);
    yield* _streamController.stream;
  }

  // Increment views
  Future<void> incrementView(String id) async {
    final idx = _currentNewsList.indexWhere((item) => item.id == id);
    if (idx != -1) {
      final old = _currentNewsList[idx];
      _currentNewsList[idx] = NewsModel(
        id: old.id,
        title: old.title,
        description: old.description,
        category: old.category,
        imageUrl: old.imageUrl,
        timeAgo: old.timeAgo,
        views: old.views + 1,
        isFree: old.isFree,
        sourceUrl: old.sourceUrl,
        timestamp: old.timestamp,
      );
      _streamController.add(List.from(_currentNewsList));
    }

    try {
      if (!id.startsWith('dummy-') && !id.startsWith('local-')) {
        await _db
            .collection('news')
            .doc(id)
            .update({'views': FieldValue.increment(1)})
            .timeout(const Duration(seconds: 2));
      }
    } catch (_) {}
  }

  // Add new article - instant UI update + background Firestore sync
  Future<void> addNews(Map<String, dynamic> data) async {
    final localId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final videoUrl = data['videoUrl'] as String?;
    final newModel = NewsModel(
      id: localId,
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'Gaming News',
      imageUrl: (data['imageUrl'] as String? ?? '').isNotEmpty
          ? data['imageUrl'] as String
          : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
      videoUrl: videoUrl,
      timeAgo: 'Just now',
      views: 0,
      isFree: data['isFree'] as bool? ?? false,
      sourceUrl: data['sourceUrl'] as String?,
      timestamp: Timestamp.now(),
    );

    // Insert at index 0 immediately so user sees it instantly
    _currentNewsList.insert(0, newModel);
    _streamController.add(List.from(_currentNewsList));

    // Try to sync with Firestore in background with 3-second timeout
    try {
      await _db.collection('news').add({
        'title': newModel.title,
        'description': newModel.description,
        'category': newModel.category,
        'imageUrl': newModel.imageUrl,
        if (newModel.videoUrl != null && newModel.videoUrl!.isNotEmpty)
          'videoUrl': newModel.videoUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isPublished': true,
        'views': 0,
        'isFree': newModel.isFree,
        'timeAgo': 'Just now',
        if (newModel.sourceUrl != null) 'sourceUrl': newModel.sourceUrl,
      }).timeout(const Duration(seconds: 3));
    } catch (_) {
      // If Firestore write times out or fails (e.g. offline/permission), local store already has it
    }
  }

  // Delete article
  Future<void> deleteNews(String id) async {
    _currentNewsList.removeWhere((item) => item.id == id);
    _streamController.add(List.from(_currentNewsList));

    try {
      if (!id.startsWith('dummy-') && !id.startsWith('local-')) {
        await _db
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
    final title = data['title'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';
    final category = data['category'] as String? ?? 'Gaming News';
    final imageUrl = (data['imageUrl'] as String? ?? '').isNotEmpty
        ? data['imageUrl'] as String
        : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80';
    final videoUrl = data['videoUrl'] as String?;
    final isFree = data['isFree'] as bool? ?? category.toLowerCase().contains('free');

    if (idx != -1) {
      final old = _currentNewsList[idx];
      _currentNewsList[idx] = NewsModel(
        id: old.id,
        title: title,
        description: description,
        category: category,
        imageUrl: imageUrl,
        videoUrl: videoUrl ?? old.videoUrl,
        timeAgo: old.timeAgo,
        views: old.views,
        isFree: isFree,
        sourceUrl: data['sourceUrl'] as String? ?? old.sourceUrl,
        timestamp: old.timestamp,
      );
      _streamController.add(List.from(_currentNewsList));
    }

    try {
      if (!id.startsWith('dummy-') && !id.startsWith('local-')) {
        final updateData = <String, dynamic>{
          'title': title,
          'description': description,
          'category': category,
          'imageUrl': imageUrl,
          'isFree': isFree,
          if (data['sourceUrl'] != null) 'sourceUrl': data['sourceUrl'],
        };
        if (data.containsKey('videoUrl')) {
          updateData['videoUrl'] = data['videoUrl'];
        }
        await _db.collection('news').doc(id).update(updateData).timeout(const Duration(seconds: 3));
      }
    } catch (_) {
      // Local state already updated
    }
  }
}
