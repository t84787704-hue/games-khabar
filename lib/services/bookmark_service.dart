import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_model.dart';

class BookmarkService {
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  static const String _prefsKey = 'bookmarked_gaming_news_v1';

  // ValueNotifiers for reactive UI updates across the entire app
  static final ValueNotifier<Set<String>> bookmarkedIdsNotifier = ValueNotifier<Set<String>>({});
  static final ValueNotifier<List<NewsModel>> bookmarksListNotifier = ValueNotifier<List<NewsModel>>([]);

  bool _isLoaded = false;

  /// Initialize and load saved bookmarks into memory on app launch
  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStringList = prefs.getStringList(_prefsKey) ?? [];
      
      final List<NewsModel> loaded = [];
      final Set<String> ids = {};

      for (final itemStr in jsonStringList) {
        try {
          final map = jsonDecode(itemStr) as Map<String, dynamic>;
          final model = NewsModel.fromJson(map);
          loaded.add(model);
          ids.add(model.id);
        } catch (_) {}
      }

      bookmarksListNotifier.value = loaded;
      bookmarkedIdsNotifier.value = ids;
      _isLoaded = true;
    } catch (_) {}
  }

  /// Check if article is bookmarked (instant synchronous lookup)
  bool isBookmarked(String newsId) {
    return bookmarkedIdsNotifier.value.contains(newsId);
  }

  /// Get list of all saved bookmarks
  Future<List<NewsModel>> getBookmarks() async {
    if (!_isLoaded) {
      await init();
    }
    return bookmarksListNotifier.value;
  }

  /// Toggle bookmark status for a news article
  /// Returns `true` if article was saved, `false` if removed
  Future<bool> toggleBookmark(NewsModel news) async {
    if (!_isLoaded) {
      await init();
    }

    final currentIds = Set<String>.from(bookmarkedIdsNotifier.value);
    final currentList = List<NewsModel>.from(bookmarksListNotifier.value);

    bool isNowBookmarked = false;

    if (currentIds.contains(news.id)) {
      // Remove bookmark
      currentIds.remove(news.id);
      currentList.removeWhere((item) => item.id == news.id);
      isNowBookmarked = false;
    } else {
      // Add bookmark to top of list
      currentIds.add(news.id);
      currentList.insert(0, news);
      isNowBookmarked = true;
    }

    // Update notifiers immediately
    bookmarkedIdsNotifier.value = currentIds;
    bookmarksListNotifier.value = currentList;

    // Persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStringList = currentList.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_prefsKey, jsonStringList);
    } catch (_) {}

    return isNowBookmarked;
  }

  /// Remove bookmark by ID
  Future<void> removeBookmark(String newsId) async {
    if (!_isLoaded) {
      await init();
    }

    final currentIds = Set<String>.from(bookmarkedIdsNotifier.value);
    final currentList = List<NewsModel>.from(bookmarksListNotifier.value);

    if (currentIds.contains(newsId)) {
      currentIds.remove(newsId);
      currentList.removeWhere((item) => item.id == newsId);

      bookmarkedIdsNotifier.value = currentIds;
      bookmarksListNotifier.value = currentList;

      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonStringList = currentList.map((item) => jsonEncode(item.toJson())).toList();
        await prefs.setStringList(_prefsKey, jsonStringList);
      } catch (_) {}
    }
  }

  /// Clear all bookmarks
  Future<void> clearAllBookmarks() async {
    bookmarkedIdsNotifier.value = {};
    bookmarksListNotifier.value = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }
}
