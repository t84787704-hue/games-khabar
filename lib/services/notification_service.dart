import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../models/news_model.dart';
import 'supabase_store_service.dart';
import 'supabase_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String topicName = 'all_news';
  static const String channelId = 'games_khabar_news_channel';
  static const String channelName = 'Games Khabar News';
  static const String channelDescription = 'Instant gaming news, updates, and free game alerts';

  final AndroidNotificationChannel _androidChannel = const AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFF00FF88),
  );

  bool _isInitialized = false;

  /// Initialize Push & Local Notifications on App Launch
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Request Notification Permissions (Android 13+ & iOS)
    await requestPermissions();

    // 2. Setup Local Notifications (for Foreground notification display)
    await _setupLocalNotifications();

    // 3. Listen for newly added news docs in real-time and notify "New: {gameName}"
    _listenForNewNewsDocuments();

    // 4. Listen for squad request / acceptance notifications for current user
    _listenForSquadNotifications();
  }

  /// Saves FCM device token to Supabase users table (stub)
  /// Saves FCM device token to Supabase users table (stub)
  Future<void> saveUserFcmToken([String? explicitUid]) async {}

  /// Real-time listener for current user's squad notifications (e.g. requests, accepts)
  void _listenForSquadNotifications() {
    bool isFirstSnapshot = true;
    try {
      SupabaseService.client.auth.onAuthStateChange.listen((data) {
        final user = data.session?.user;
        if (user == null) return;
        saveUserFcmToken(user.id);

        try {
          SupabaseService.client
              .from('notifications')
              .stream(primaryKey: ['id'])
              .eq('recipientUid', user.id)
              .order('created_at', ascending: false)
              .limit(10)
              .listen((rows) {
            if (isFirstSnapshot) {
              isFirstSnapshot = false;
              return;
            }

            for (final map in rows) {
              final type = map['type'] as String? ?? '';
              if (type.startsWith('squad_')) {
                final title = map['title'] as String? ?? 'Squad Update 🎮';
                final message = map['message'] as String? ?? map['body'] as String? ?? 'New update in your squad!';
                final postId = map['postId'] as String? ?? map['post_id'] as String? ?? '';
                showSquadNotification(
                  title: title,
                  body: message,
                  postId: postId,
                  recipientUid: user.id,
                );
              }
            }
          }, onError: (_) {});
        } catch (_) {}
      });
    } catch (_) {}
  }

  /// Show heads-up banner notification for squad events
  Future<void> showSquadNotification({
    required String title,
    required String body,
    required String postId,
    required String recipientUid,
  }) async {
    try {
      final currentUid = SupabaseService.client.auth.currentUser?.id;
      // Trigger local notification if device matches recipient or in development
      if (currentUid != null && currentUid != recipientUid) {
        // Different user on this client - only show if on same physical test device
        return;
      }

      final payloadData = {
        'postId': postId,
        'title': title,
        'body': body,
        'type': 'squad_event',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      };

      final androidDetails = AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF00FF88),
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Games Khabar • Squads',
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(payloadData),
      );
    } catch (_) {}
  }

  /// Real-time news listener
  void _listenForNewNewsDocuments() {
    bool isFirstSnapshot = true;
    try {
      SupabaseService.client
          .from('posts')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(10)
          .listen((rows) {
        if (isFirstSnapshot) {
          isFirstSnapshot = false;
          return; // Skip initial batch on launch
        }

        for (final data in rows) {
          final gameName = (data['gameName'] ?? data['game_name'] as String?)?.trim().isNotEmpty == true
              ? (data['gameName'] ?? data['game_name'] as String).trim()
              : ((data['category'] as String?)?.trim().isNotEmpty == true
                  ? (data['category'] as String).trim()
                  : 'Gaming News');
          final title = data['title']?.toString() ?? 'Check out the latest gaming update!';
          final newsId = data['id']?.toString() ?? '';
          final imageUrl = data['imageUrl'] ?? data['image_url'] as String?;
          final category = data['category'] as String? ?? 'Gaming';

          _showLocalNotification(
            title: 'New: $gameName',
            body: title,
            newsId: newsId,
            imageUrl: imageUrl,
            category: category,
          );
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  /// Show direct local notification for new article
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String newsId,
    String? imageUrl,
    String? category,
  }) async {
    final payloadData = {
      'newsId': newsId,
      'title': title,
      'body': body,
      'category': category ?? 'Gaming News',
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
    };

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF00FF88),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: category ?? 'Games Khabar',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _localNotifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(payloadData),
    );
  }

  /// Request permissions for iOS and Android 13+ (POST_NOTIFICATIONS)
  /// Request permissions for iOS and Android 13+ (POST_NOTIFICATIONS)
  Future<void> requestPermissions() async {
    try {
      // Setup Android notification channel
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_androidChannel);
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (_) {}
  }

  /// Subscribe to topic 'all_news'
  Future<void> subscribeToAllNewsTopic() async {}

  /// Configure flutter_local_notifications plugin
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            _handleMessageTap(data);
          } catch (_) {
            _navigateToNewsDetail(response.payload!);
          }
        }
      },
    );
  }

  /// Check if app was opened from a terminated notification
  Future<void> _checkInitialMessage() async {}

  /// Show Foreground Heads-Up Banner Notification with Sound & Vibration
  Future<void> _showForegroundNotification({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) async {
    final effectiveTitle = title ?? data['title'] ?? 'Games Khabar 🎮';
    final effectiveBody = body ?? data['body'] ?? data['description'] ?? 'Check out the latest gaming update!';

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF00FF88),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: data['category'] ?? 'Gaming News',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _localNotifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(data),
    );
  }

  /// Handle Notification Click & Route to NewsDetailScreen
  void _handleMessageTap(Map<String, dynamic> data) {
    final newsId = data['newsId'] ?? data['id'];
    if (newsId != null && newsId.toString().isNotEmpty) {
      _navigateToNewsDetail(
        newsId.toString(),
        fallbackTitle: data['title'],
        fallbackCategory: data['category'],
        fallbackDesc: data['description'] ?? data['body'],
        fallbackImage: data['imageUrl'],
      );
    }
  }

  /// Fetch article and navigate to NewsDetailScreen
  Future<void> _navigateToNewsDetail(
    String newsId, {
    String? fallbackTitle,
    String? fallbackCategory,
    String? fallbackDesc,
    String? fallbackImage,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    NewsModel? news = await SupabaseStoreService().getNewsById(newsId);

    // If offline or news not yet synced to snapshot, create a fallback model so UI opens instantly
    news ??= NewsModel(
      id: newsId,
      title: fallbackTitle ?? 'Latest Gaming News',
      description: fallbackDesc ?? 'Read the full story on Games Khabar app.',
      category: fallbackCategory ?? 'Gaming News',
      imageUrl: fallbackImage ??
          'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
      timeAgo: 'Just now',
      views: 1,
    );

    // Notification handled; detail screen removed in favor of Super Feed
    debugPrint('Notification tapped for news: $newsId');
  }

  /// Admin Action: Send Push Notification to Topic 'all_news' when new news is published
  Future<void> sendNewsNotification({
    required String newsId,
    required String title,
    required String description,
    required String category,
    String? gameName,
    String? imageUrl,
  }) async {
    // 1. Prepare clean Notification Title & Body: "New: {gameName}"
    final effectiveGame = (gameName != null && gameName.trim().isNotEmpty)
        ? gameName.trim()
        : category;
    final notifTitle = 'New: $effectiveGame';
    final notifBody = title;

    final payloadData = {
      'newsId': newsId,
      'category': category,
      'gameName': effectiveGame,
      'title': title,
      'description': description,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
    };

    // 2. Save Notification Record in Supabase 'notifications' table
    try {
      await SupabaseService.client.from('notifications').insert({
        'title': notifTitle,
        'body': notifBody,
        'topic': topicName,
        'newsId': newsId,
        'category': category,
        'imageUrl': imageUrl ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'sent',
      }).timeout(const Duration(seconds: 4));
    } catch (_) {}

    // 3. Show local notification confirmation on device
    try {
      final androidDetails = AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF00FF88),
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notifTitle,
        notifBody,
        NotificationDetails(android: androidDetails),
        payload: jsonEncode(payloadData),
      );
    } catch (_) {}
  }

  /// Create and store an in-app notification in Supabase
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final notifMap = {
        'recipientUid': userId,
        'userId': userId,
        'user_id': userId,
        'title': title,
        'body': body,
        'message': body,
        'type': type,
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'timestamp': DateTime.now().toIso8601String(),
        if (additionalData != null) ...additionalData,
      };

      try {
        await SupabaseService.client.from('notifications').insert(notifMap);
      } catch (_) {}

      // Sync notification to Supabase notifications table via helper
      try {
        await SupabaseService.sendNotification({
          'userId': userId,
          'title': title,
          'body': body,
          'type': type,
          if (additionalData != null) 'data': additionalData,
        });
      } catch (e) {
        debugPrint('Error syncing notification to Supabase: $e');
      }
    } catch (e) {
      debugPrint('Error creating in-app notification: $e');
    }
  }
}
