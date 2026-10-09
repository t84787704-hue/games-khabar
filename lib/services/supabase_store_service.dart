import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../models/news_model.dart';

class SupabaseStoreService {
  static final SupabaseStoreService _instance = SupabaseStoreService._internal();
  factory SupabaseStoreService() => _instance;

  final StreamController<List<NewsModel>> _streamController =
      StreamController<List<NewsModel>>.broadcast();

  // In-memory master list (populated strictly from Supabase)
  List<NewsModel> _currentNewsList = [];

  SupabaseStoreService._internal() {
    _initSupabaseListener();
  }

  void _initSupabaseListener() {
    try {
      refreshNews();
      SupabaseService.client
          .from('news')
          .stream(primaryKey: ['id'])
          .order('timestamp', ascending: false)
          .limit(500)
          .listen(
        (data) {
          final items = data.map((row) => NewsModel.fromMap(row)).toList();
          if (items.isNotEmpty) {
            _currentNewsList = items;
            _streamController.add(List.from(_currentNewsList));
          }
        },
        onError: (err) {
          _streamController.add(List.from(_currentNewsList));
        },
      );
    } catch (_) {
      // Ignore initial listener setup failure
    }
  }

  List<NewsModel> get currentNews => List.from(_currentNewsList);

  // Reactive stream of all news sorted by newest
  Stream<List<NewsModel>> getNewsStream() async* {
    yield List.from(_currentNewsList);
    yield* _streamController.stream;
  }

  // Force refresh news from Supabase (pull-to-refresh)
  Future<void> refreshNews() async {
    try {
      final rows = await SupabaseService.client
          .from('news')
          .select()
          .order('timestamp', ascending: false)
          .limit(500)
          .timeout(const Duration(seconds: 10));

      final items = (rows as List).map((row) => NewsModel.fromMap(row)).toList();
      _currentNewsList = items;
      _streamController.add(List.from(_currentNewsList));
      return;
    } catch (_) {}
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
      if (!id.startsWith('local-')) {
        final row = await SupabaseService.client.from('news').select('views').eq('id', id).maybeSingle();
        final currentViews = (row?['views'] as num?)?.toInt() ?? 0;
        await SupabaseService.client
            .from('news')
            .update({'views': currentViews + 1})
            .eq('id', id)
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  // Update localized title & description translations in memory & Supabase
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
      await SupabaseService.client.from('news').update({
        'title': {langCode: translatedTitle},
        'description': {langCode: translatedDesc},
        'content': {langCode: translatedDesc},
      }).eq('id', cleanId).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  // Get single news article by ID (checks memory first, then Supabase)
  Future<NewsModel?> getNewsById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;

    final inMemory = _currentNewsList.where((item) => item.id == cleanId).toList();
    if (inMemory.isNotEmpty) {
      return inMemory.first;
    }

    try {
      final row = await SupabaseService.client.from('news').select().eq('id', cleanId).maybeSingle().timeout(const Duration(seconds: 4));
      if (row != null) {
        return NewsModel.fromMap(row);
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

  // Add new article - instant UI update + background Supabase sync (returns created newsId)
  Future<String> addNews(Map<String, dynamic> data) async {
    final localId = 'news-${DateTime.now().millisecondsSinceEpoch}';
    final videoUrl = (data['videoUrl'] ?? '') as String;
    final titleMap = _parseTextMap(data['title'], 'Untitled');
    final descriptionMap = _parseTextMap(data['content'] ?? data['description'], '');
    final category = (data['category'] ?? 'Gaming News') as String;
    final rawImageUrl = (data['imageUrl'] ?? '') as String;
    final imageUrl = rawImageUrl.isNotEmpty
        ? rawImageUrl
        : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80';
    final isFree = (data['isFree'] ?? false) as bool;
    final isFeatured = (data['isFeatured'] ?? false) as bool;
    final sourceUrl = data['sourceUrl'] != null ? data['sourceUrl'] as String : null;

    final newModel = NewsModel(
      id: localId,
      titleMap: titleMap,
      descriptionMap: descriptionMap,
      category: category,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      timeAgo: 'Just now',
      views: 0,
      isFree: isFree,
      isFeatured: isFeatured,
      sourceUrl: sourceUrl,
    );

    // Insert at index 0 immediately so user sees it instantly
    _currentNewsList.insert(0, newModel);
    _streamController.add(List.from(_currentNewsList));

    String createdId = localId;

    try {
      final nowIso = DateTime.now().toIso8601String();
      await SupabaseService.client.from('news').upsert({
        'id': localId,
        'title': titleMap,
        'content': descriptionMap,
        'description': descriptionMap,
        'category': newModel.category,
        'imageUrl': newModel.imageUrl,
        'videoUrl': videoUrl,
        'timestamp': nowIso,
        'created_at': nowIso,
        'isPublished': true,
        'views': 0,
        'isFree': newModel.isFree,
        'isFeatured': newModel.isFeatured,
        'timeAgo': 'Just now',
        if (newModel.sourceUrl != null) 'sourceUrl': newModel.sourceUrl,
      }).timeout(const Duration(seconds: 4));
    } catch (_) {}

    return createdId;
  }

  // Delete article
  Future<void> deleteNews(String id) async {
    _currentNewsList.removeWhere((item) => item.id == id);
    _streamController.add(List.from(_currentNewsList));

    try {
      if (!id.startsWith('local-')) {
        await SupabaseService.client
            .from('news')
            .delete()
            .eq('id', id)
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  // Update existing article - instant UI update + background Supabase sync
  Future<void> updateNews(String id, Map<String, dynamic> data) async {
    final idx = _currentNewsList.indexWhere((item) => item.id == id);
    final titleMap = _parseTextMap(data['title'], 'Untitled');
    final descriptionMap = _parseTextMap(data['content'] ?? data['description'], '');
    final category = (data['category'] ?? 'Gaming News') as String;
    final rawImageUrl = (data['imageUrl'] ?? '') as String;
    final imageUrl = rawImageUrl.isNotEmpty
        ? rawImageUrl
        : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80';
    final videoUrl = (data['videoUrl'] ?? '') as String;
    final isFree = data['isFree'] != null
        ? (data['isFree'] as bool)
        : category.toLowerCase().contains('free');
    final isFeatured = (data['isFeatured'] ?? false) as bool;

    if (idx != -1) {
      final old = _currentNewsList[idx];
      final sourceUrl = data['sourceUrl'] != null ? data['sourceUrl'] as String : old.sourceUrl;
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
        sourceUrl: sourceUrl,
        timestamp: old.timestamp,
      );
      _streamController.add(List.from(_currentNewsList));
    }

    try {
      if (!id.startsWith('local-')) {
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
        await SupabaseService.client.from('news').update(updateData).eq('id', id).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  // Set an article as featured and demote previous featured articles without deleting them
  Future<void> makeFeatured(String newDocId) async {
    for (int i = 0; i < _currentNewsList.length; i++) {
      final item = _currentNewsList[i];
      if (item.id == newDocId) {
        _currentNewsList[i] = item.copyWith(isFeatured: true);
      } else if (item.isFeatured == true) {
        _currentNewsList[i] = item.copyWith(isFeatured: false);
      }
    }
    _streamController.add(List.from(_currentNewsList));

    try {
      await SupabaseService.client.from('news').update({'isFeatured': false}).eq('isFeatured', true);
      await SupabaseService.client.from('news').update({'isFeatured': true}).eq('id', newDocId);
    } catch (e) {
      debugPrint('Error making news featured: $e');
    }
  }
}
