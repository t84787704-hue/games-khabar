import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/news_model.dart';
import '../screens/news_detail_screen.dart';
import 'firestore_service.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  // FCM automatically handles notification display in system tray when app is in background/killed
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  FirebaseMessaging? get _fcm {
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

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

  /// Initialize Push Notifications on App Launch
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Request Notification Permissions (Android 13+ & iOS)
    await requestPermissions();

    // 2. Setup Local Notifications (for Foreground notification display)
    await _setupLocalNotifications();

    // 3. Subscribe all users to topic 'all_news'
    await subscribeToAllNewsTopic();

    // 4. Foreground Message Handler
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });
    } catch (_) {}

    // 5. Background Notification Tap Handler (App running in background)
    try {
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessageTap(message.data);
      });
    } catch (_) {}

    // 6. Terminated State Notification Tap Handler (App launched from notification)
    _checkInitialMessage();

    // 7. Listen for newly added Firestore docs in real-time and notify "New: {gameName}"
    _listenForNewNewsDocuments();
  }

  /// Real-time Firestore listener: when a new doc is added, trigger notification "New: {gameName}"
  void _listenForNewNewsDocuments() {
    bool isFirstSnapshot = true;
    try {
      FirebaseFirestore.instance
          .collection('news')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots()
          .listen((snapshot) {
        if (isFirstSnapshot) {
          isFirstSnapshot = false;
          return; // Skip initial batch on launch
        }

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              final gameName = (data['gameName'] as String?)?.trim().isNotEmpty == true
                  ? (data['gameName'] as String).trim()
                  : ((data['category'] as String?)?.trim().isNotEmpty == true
                      ? (data['category'] as String).trim()
                      : 'Gaming News');
              final title = data['title'] ?? 'Check out the latest gaming update!';
              final newsId = change.doc.id;
              final imageUrl = data['imageUrl'] as String?;
              final category = data['category'] as String? ?? 'Gaming';

              _showLocalNotification(
                title: 'New: $gameName',
                body: title,
                newsId: newsId,
                imageUrl: imageUrl,
                category: category,
              );
            }
          }
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
  Future<void> requestPermissions() async {
    try {
      final fcm = _fcm;
      if (fcm != null) {
        await fcm.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
      }

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
  Future<void> subscribeToAllNewsTopic() async {
    try {
      final fcm = _fcm;
      if (fcm != null) {
        await fcm.subscribeToTopic(topicName);
      }
    } catch (_) {}
  }

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
  Future<void> _checkInitialMessage() async {
    try {
      final initialMessage = await _fcm?.getInitialMessage();
      if (initialMessage != null) {
        // Slight delay to allow navigation stack / widget tree to be fully ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleMessageTap(initialMessage.data);
        });
      }
    } catch (_) {}
  }

  /// Show Foreground Heads-Up Banner Notification with Sound & Vibration
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'Games Khabar 🎮';
    final body = notification?.body ?? data['body'] ?? data['description'] ?? 'Check out the latest gaming update!';

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

    NewsModel? news = await FirestoreService().getNewsById(newsId);

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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(news: news!),
      ),
    );
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

    // 2. Save Notification Record in Firestore 'notifications' collection
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': notifTitle,
        'body': notifBody,
        'topic': topicName,
        'newsId': newsId,
        'category': category,
        'imageUrl': imageUrl ?? '',
        'timestamp': FieldValue.serverTimestamp(),
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
}
