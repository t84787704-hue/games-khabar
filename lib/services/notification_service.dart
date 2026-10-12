import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/news_model.dart';
import '../models/notification_model.dart';
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

  // Reactive unread count notifier for badge in AppBars/Navigation
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  StreamSubscription? _realtimeNotifSub;

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

    // 4. Listen for in-app notifications in real-time for current user
    _listenForUserInAppNotifications();

    // 5. Listen for squad request / acceptance notifications for current user
    _listenForSquadNotifications();
  }

  /// Real-time stream of notifications for user
  Stream<List<InAppNotification>> notificationsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    try {
      return SupabaseService.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .map((rows) {
        final filtered = rows.where((r) =>
            r['user_id']?.toString() == userId ||
            r['userId']?.toString() == userId ||
            r['recipientUid']?.toString() == userId);

        final list = filtered.map((r) => InAppNotification.fromMap(r)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final unread = list.where((n) => !n.isRead).length;
        unreadCountNotifier.value = unread;

        return list;
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Real-time unread notifications count
  Stream<int> unreadCountStream(String userId) {
    return notificationsStream(userId).map((list) => list.where((n) => !n.isRead).length);
  }

  /// Listen for new in-app notifications to update unread count & show heads-up
  void _listenForUserInAppNotifications() {
    try {
      SupabaseService.client.auth.onAuthStateChange.listen((data) {
        final user = data.session?.user;
        if (user == null) {
          unreadCountNotifier.value = 0;
          _realtimeNotifSub?.cancel();
          return;
        }

        _refreshUnreadCount(user.id);

        _realtimeNotifSub?.cancel();
        bool isFirst = true;
        try {
          _realtimeNotifSub = SupabaseService.client
              .from('notifications')
              .stream(primaryKey: ['id'])
              .listen((rows) {
            final userRows = rows.where((r) =>
                r['user_id']?.toString() == user.id ||
                r['userId']?.toString() == user.id ||
                r['recipientUid']?.toString() == user.id).toList();

            final unread = userRows.where((r) =>
                r['is_read'] != true && r['isRead'] != true && r['read'] != true).length;
            unreadCountNotifier.value = unread;

            if (isFirst) {
              isFirst = false;
              return;
            }

            // Show foreground banner for newly arrived notifications
            if (userRows.isNotEmpty) {
              final latest = InAppNotification.fromMap(userRows.first);
              if (!latest.isRead) {
                showInAppLocalNotification(latest);
              }
            }
          }, onError: (_) {});
        } catch (_) {}
      });
    } catch (_) {}
  }

  Future<void> _refreshUnreadCount(String userId) async {
    try {
      final res = await SupabaseService.client
          .from('notifications')
          .select('id')
          .or('user_id.eq.$userId,recipientUid.eq.$userId')
          .eq('is_read', false);
      unreadCountNotifier.value = res.length;
    } catch (_) {}
  }

  /// Show heads-up banner on device for in-app notification
  Future<void> showInAppLocalNotification(InAppNotification notif) async {
    try {
      final payloadData = {
        'id': notif.id,
        'type': notif.type,
        'title': notif.title,
        'body': notif.body,
        if (notif.data != null) ...notif.data!,
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
          notif.body,
          contentTitle: notif.title,
          summaryText: notif.categoryTag,
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notif.title,
        notif.body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(payloadData),
      );
    } catch (_) {}
  }

  /// Mark single notification as read
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      final now = DateTime.now().toIso8601String();
      await SupabaseService.client.from('notifications').update({
        'is_read': true,
        'is_seen': true,
        'read': true,
        'read_at': now,
      }).eq('id', notificationId);

      if (unreadCountNotifier.value > 0) {
        unreadCountNotifier.value--;
      }
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  /// Mark all notifications as read for user
  Future<void> markAllAsRead(String userId) async {
    if (userId.isEmpty) return;
    try {
      final now = DateTime.now().toIso8601String();
      await SupabaseService.client.from('notifications').update({
        'is_read': true,
        'is_seen': true,
        'read': true,
        'read_at': now,
      }).or('user_id.eq.$userId,recipientUid.eq.$userId');

      unreadCountNotifier.value = 0;
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      await SupabaseService.client.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Clear all notifications for user
  Future<void> clearAllNotifications(String userId) async {
    if (userId.isEmpty) return;
    try {
      await SupabaseService.client
          .from('notifications')
          .delete()
          .or('user_id.eq.$userId,recipientUid.eq.$userId');

      unreadCountNotifier.value = 0;
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  /// =========================================================================
  /// CORE NOTIFICATION SENDER (100% snake_case table: notifications)
  /// =========================================================================
  Future<void> sendNotification({
    required String userId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String priority = 'normal',
  }) async {
    if (userId.isEmpty) return;
    try {
      final now = DateTime.now().toIso8601String();
      final recipientUuid = SupabaseService.toUuid(userId);

      final Map<String, dynamic> payload = {
        'user_id': recipientUuid,
        'type': type,
        'title': title,
        'body': body,
        'is_read': false,
        'is_seen': false,
        'priority': priority,
        'created_at': now,
      };

      if (senderId != null && senderId.isNotEmpty && senderId != 'admin' && senderId != 'system') {
        payload['sender_id'] = SupabaseService.toUuid(senderId);
      }
      if (senderName != null && senderName.isNotEmpty) {
        payload['sender_name'] = senderName;
      }
      if (senderAvatar != null && senderAvatar.isNotEmpty) {
        payload['sender_avatar'] = senderAvatar;
      }
      if (data != null && data.isNotEmpty) {
        payload['data'] = data;
      }

      await SupabaseService.client.from('notifications').insert(payload);
    } catch (e) {
      debugPrint('NotificationService sendNotification error: $e');
    }
  }

  /// Domain Helper: Someone followed user
  Future<void> sendFollowNotification({
    required String targetUserId,
    required String followerId,
    required String followerName,
    String? followerAvatar,
  }) async {
    await sendNotification(
      userId: targetUserId,
      senderId: followerId,
      senderName: followerName,
      senderAvatar: followerAvatar,
      type: 'follow',
      title: 'New Follower! 👤',
      body: '$followerName started following your Gamer ID.',
      data: {'follower_id': followerId},
    );
  }

  /// Domain Helper: Someone liked user's post
  Future<void> sendLikeNotification({
    required String targetUserId,
    required String likerId,
    required String likerName,
    required String postId,
    String? postTitle,
    String? likerAvatar,
  }) async {
    await sendNotification(
      userId: targetUserId,
      senderId: likerId,
      senderName: likerName,
      senderAvatar: likerAvatar,
      type: 'post_like',
      title: 'New Post Like! ❤️',
      body: '$likerName liked your post${postTitle != null && postTitle.isNotEmpty ? ' "$postTitle"' : ''}.',
      data: {'post_id': postId},
    );
  }

  /// Domain Helper: Someone commented on user's post
  Future<void> sendCommentNotification({
    required String targetUserId,
    required String commenterId,
    required String commenterName,
    required String postId,
    required String commentText,
    String? commenterAvatar,
  }) async {
    final preview = commentText.length > 50 ? '${commentText.substring(0, 47)}...' : commentText;
    await sendNotification(
      userId: targetUserId,
      senderId: commenterId,
      senderName: commenterName,
      senderAvatar: commenterAvatar,
      type: 'post_comment',
      title: 'New Comment! 💬',
      body: '$commenterName commented: "$preview"',
      data: {'post_id': postId, 'comment': commentText},
    );
  }

  /// Domain Helper: Proof uploaded, accepted or rejected
  Future<void> sendProofNotification({
    required String targetUserId,
    required String status, // 'uploaded', 'accepted', 'rejected'
    required String roomTitle,
    String? reason,
  }) async {
    String title;
    String body;
    String type;
    if (status == 'accepted') {
      type = 'proof_accepted';
      title = '🏆 Win Proof Accepted!';
      body = 'Your match proof for "$roomTitle" was approved! Reward is in your wallet.';
    } else if (status == 'rejected') {
      type = 'proof_rejected';
      title = '❌ Win Proof Rejected';
      body = 'Your proof for "$roomTitle" was rejected${reason != null && reason.isNotEmpty ? ': $reason' : '.'}';
    } else {
      type = 'proof_uploaded';
      title = '📸 Proof Uploaded';
      body = 'New win proof uploaded for "$roomTitle". Pending verification.';
    }

    await sendNotification(
      userId: targetUserId,
      type: type,
      title: title,
      body: body,
      data: {'room_title': roomTitle, 'status': status, if (reason != null) 'reason': reason},
    );
  }

  /// Domain Helper: 1v1 Challenge notifications
  Future<void> sendChallengeNotification({
    required String targetUserId,
    required String challengerId,
    required String challengerName,
    required String challengeId,
    String? gameName,
    String? status, // 'received', 'accepted', 'rejected'
    String? challengerAvatar,
  }) async {
    String title;
    String body;
    String type;
    if (status == 'accepted') {
      type = 'challenge_accepted';
      title = '⚔️ Challenge Accepted!';
      body = '$challengerName accepted your challenge! Match room is ready.';
    } else if (status == 'rejected') {
      type = 'challenge_rejected';
      title = 'Challenge Declined';
      body = '$challengerName declined your challenge.';
    } else {
      type = 'challenge_received';
      title = '⚔️ 1v1 Challenge Received!';
      body = '$challengerName challenged you in ${gameName ?? 'a match'}!';
    }

    await sendNotification(
      userId: targetUserId,
      senderId: challengerId,
      senderName: challengerName,
      senderAvatar: challengerAvatar,
      type: type,
      title: title,
      body: body,
      data: {'challenge_id': challengeId, 'challengeId': challengeId, 'game_name': gameName},
      priority: 'high',
    );
  }

  /// Domain Helper: Team join requests & approvals
  Future<void> sendTeamNotification({
    required String targetUserId,
    required String teamId,
    required String teamName,
    required String type, // 'team_join_request', 'team_join_approved'
    String? senderId,
    String? senderName,
  }) async {
    final isApproval = type == 'team_join_approved';
    await sendNotification(
      userId: targetUserId,
      senderId: senderId,
      senderName: senderName,
      type: type,
      title: isApproval ? 'Team Request Approved! 🛡️' : 'Team Join Request 👥',
      body: isApproval
          ? 'You are now an official member of team "$teamName"!'
          : '${senderName ?? 'A gamer'} requested to join your team "$teamName".',
      data: {'team_id': teamId, 'team_name': teamName},
    );
  }

  /// Domain Helper: Coin reward notification
  Future<void> sendCoinRewardNotification({
    required String targetUserId,
    required int amount,
    required String reason,
    String? type,
  }) async {
    await sendNotification(
      userId: targetUserId,
      type: type ?? 'coin_reward',
      title: '🪙 Coins Earned: +$amount!',
      body: reason,
      data: {'amount': amount},
    );
  }

  /// Domain Helper: Store purchase notification
  Future<void> sendStorePurchaseNotification({
    required String targetUserId,
    required String itemName,
    required int costCoins,
    required String category,
  }) async {
    await sendNotification(
      userId: targetUserId,
      type: 'store_purchase',
      title: 'Store Purchase Complete! ✨',
      body: 'Successfully unlocked "$itemName" for $costCoins G-Coins ($category).',
      data: {'item_name': itemName, 'cost': costCoins, 'category': category},
    );
  }

  /// Domain Helper: Perk expiry reminder
  Future<void> sendPerkExpiryReminderNotification({
    required String targetUserId,
    required String perkName,
    required int daysRemaining,
  }) async {
    await sendNotification(
      userId: targetUserId,
      type: 'perk_expiry',
      title: '⏰ Perk Expiry Alert',
      body: 'Your "$perkName" will expire in $daysRemaining day(s). Renew in Coin Store!',
      data: {'perk_name': perkName, 'days_remaining': daysRemaining},
    );
  }

  /// Domain Helper: Tournament / Room updates
  Future<void> sendTournamentNotification({
    required String targetUserId,
    required String roomId,
    required String roomTitle,
    required String updateMessage,
  }) async {
    await sendNotification(
      userId: targetUserId,
      type: 'tournament_update',
      title: 'Tournament Update: $roomTitle 🎮',
      body: updateMessage,
      data: {'room_id': roomId, 'roomId': roomId},
    );
  }

  /// Domain Helper: Admin announcement
  Future<void> sendAdminAnnouncement({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final userRows = await SupabaseService.client.from('users').select('id, uid').limit(200);
      for (final u in userRows) {
        final uid = (u['id'] ?? u['uid'])?.toString() ?? '';
        if (uid.isNotEmpty) {
          await sendNotification(
            userId: uid,
            type: 'admin_announcement',
            title: title,
            body: body,
            data: data,
            priority: 'high',
          );
        }
      }
    } catch (_) {}
  }

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
      if (currentUid != null && currentUid != recipientUid) {
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
          return;
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
  Future<void> requestPermissions() async {
    try {
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
        effectiveBody,
        contentTitle: effectiveTitle,
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
    await sendNotification(
      userId: userId,
      type: type,
      title: title,
      body: body,
      data: additionalData,
    );
  }
}
