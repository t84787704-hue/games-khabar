import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/news_model.dart';
import '../models/notification_model.dart';
import 'supabase_store_service.dart';
import 'supabase_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal() {
    final curUser = SupabaseService.client.auth.currentUser;
    if (curUser != null) {
      refreshUnreadCount(curUser.id);
    }
  }

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String topicName = 'all_news';
  static const String channelId = 'games_khabar_alerts_v2';
  static const String channelName = 'Games Khabar Notifications';
  static const String channelDescription = 'Instant gaming alerts, match updates, and in-app alerts';

  final AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
    enableLights: true,
    ledColor: const Color(0xFF00FF88),
  );

  bool _isInitialized = false;

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  StreamSubscription? _realtimeNotifSub;
  final Set<String> _seenNotificationIds = {};

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _setupLocalNotifications();
    await requestPermissions();

    final curUser = SupabaseService.client.auth.currentUser;
    if (curUser != null) {
      await refreshUnreadCount(curUser.id);
    }

    _listenForNewNewsDocuments();
    _listenForUserInAppNotifications();
    _listenForSquadNotifications();
  }

  /// Real-time stream of notifications for user
  Stream<List<InAppNotification>> notificationsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    try {
      final userUuid = SupabaseService.toUuid(userId).toLowerCase();
      final rawUid = userId.toLowerCase();

      return SupabaseService.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .map((rows) {
        final filtered = rows.where((r) {
          final target = (r['user_id'] ?? r['userId'] ?? r['recipientUid'] ?? '').toString().toLowerCase();
          return target == userUuid || target == rawUid;
        });

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

  /// Real-time unread notifications count using Supabase stream
  Stream<int> getUnreadCountStream([String? userId]) {
    final uid = (userId != null && userId.isNotEmpty)
        ? userId
        : (SupabaseService.client.auth.currentUser?.id ?? '');
    if (uid.isEmpty) return Stream.value(0);

    try {
      final userUuid = SupabaseService.toUuid(uid).toLowerCase();
      final rawUid = uid.toLowerCase();

      return SupabaseService.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .map((rows) {
        final unread = rows.where((r) {
          final target = (r['user_id'] ?? r['userId'] ?? r['recipientUid'] ?? '').toString().toLowerCase();
          final matchesUser = target == userUuid || target == rawUid;
          final isRead = r['is_read'] == true || r['isRead'] == true || r['read'] == true;
          return matchesUser && !isRead;
        }).length;

        unreadCountNotifier.value = unread;
        return unread;
      });
    } catch (_) {
      return Stream.value(0);
    }
  }

  Stream<int> unreadCountStream(String userId) => getUnreadCountStream(userId);

  void _listenForUserInAppNotifications() {
    try {
      final initialUser = SupabaseService.client.auth.currentUser;
      if (initialUser != null) {
        _subscribeToUserNotifications(initialUser.id);
      }

      SupabaseService.client.auth.onAuthStateChange.listen((data) {
        final user = data.session?.user;
        if (user == null) {
          unreadCountNotifier.value = 0;
          _realtimeNotifSub?.cancel();
          _seenNotificationIds.clear();
          return;
        }
        _subscribeToUserNotifications(user.id);
      });
    } catch (_) {}
  }

  void _subscribeToUserNotifications(String userId) {
    refreshUnreadCount(userId);
    _realtimeNotifSub?.cancel();
    bool isFirst = true;

    try {
      _realtimeNotifSub = SupabaseService.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .listen((rows) {
        final userUuid = SupabaseService.toUuid(userId).toLowerCase();
        final rawUid = userId.toLowerCase();

        final userRows = rows.where((r) {
          final target = (r['user_id'] ?? r['userId'] ?? r['recipientUid'] ?? '').toString().toLowerCase();
          return target == userUuid || target == rawUid;
        }).toList();

        final unread = userRows.where((r) =>
            r['is_read'] != true && r['isRead'] != true && r['read'] != true).length;
        unreadCountNotifier.value = unread;

        if (isFirst) {
          isFirst = false;
          for (final r in userRows) {
            final id = r['id']?.toString() ?? '';
            if (id.isNotEmpty) _seenNotificationIds.add(id);
          }
          return;
        }

        for (final r in userRows) {
          final id = r['id']?.toString() ?? '';
          if (id.isNotEmpty && !_seenNotificationIds.contains(id)) {
            _seenNotificationIds.add(id);
            final notif = InAppNotification.fromMap(r);
            if (!notif.isRead) {
              showInAppLocalNotification(notif);
            }
          }
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  /// Fresh exact unread count directly from database
  Future<int> refreshUnreadCount([String? userId]) async {
    final uid = (userId != null && userId.isNotEmpty)
        ? userId
        : (SupabaseService.client.auth.currentUser?.id ?? '');
    if (uid.isEmpty) {
      unreadCountNotifier.value = 0;
      return 0;
    }

    try {
      final userUuid = SupabaseService.toUuid(uid);
      dynamic res;
      try {
        res = await SupabaseService.client
            .from('notifications')
            .select('id')
            .eq('user_id', userUuid)
            .eq('is_read', false);
      } catch (_) {
        res = await SupabaseService.client
            .from('notifications')
            .select('id')
            .eq('user_id', uid)
            .eq('is_read', false);
      }

      if (res is List) {
        unreadCountNotifier.value = res.length;
        return res.length;
      }
      return unreadCountNotifier.value;
    } catch (e) {
      debugPrint('[NotificationService] refreshUnreadCount error: $e');
      return unreadCountNotifier.value;
    }
  }

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
        vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
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

      final notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _localNotifications.show(
        notifId,
        notif.title,
        notif.body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(payloadData),
      );
    } catch (e) {
      debugPrint('showInAppLocalNotification error: $e');
    }
  }

  /// Mark single notification as read & decrement count immediately
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      try {
        await SupabaseService.client.from('notifications').update({
          'is_read': true,
        }).eq('id', notificationId);
      } catch (e) {
        try {
          await SupabaseService.client.from('notifications').update({
            'is_read': true,
          }).eq('id', SupabaseService.toUuid(notificationId));
        } catch (_) {}
      }

      if (unreadCountNotifier.value > 0) {
        unreadCountNotifier.value--;
      }

      await refreshUnreadCount();
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  /// Mark all notifications as read for user
  Future<void> markAllAsRead([String? userId]) async {
    final uid = (userId != null && userId.isNotEmpty)
        ? userId
        : (SupabaseService.client.auth.currentUser?.id ?? '');
    if (uid.isEmpty) return;
    try {
      final userUuid = SupabaseService.toUuid(uid);
      try {
        await SupabaseService.client.from('notifications').update({
          'is_read': true,
        }).eq('user_id', userUuid);
      } catch (_) {
        try {
          await SupabaseService.client.from('notifications').update({
            'is_read': true,
          }).eq('user_id', uid);
        } catch (_) {}
      }

      unreadCountNotifier.value = 0;
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      await SupabaseService.client.from('notifications').delete().eq('id', notificationId);
      await refreshUnreadCount();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> clearAll(String userId) async {
    if (userId.isEmpty) return;
    try {
      try {
        await SupabaseService.client
            .from('notifications')
            .delete()
            .eq('user_id', userId);
      } catch (_) {}

      final userUuid = SupabaseService.toUuid(userId);
      if (userUuid.toLowerCase() != userId.toLowerCase()) {
        try {
          await SupabaseService.client
              .from('notifications')
              .delete()
              .eq('user_id', userUuid);
        } catch (_) {}
      }

      unreadCountNotifier.value = 0;
      _seenNotificationIds.clear();
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  Future<void> clearAllNotifications(String userId) async {
    await clearAll(userId);
  }

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

  Future<void> sendProofNotification({
    required String targetUserId,
    required String status,
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

  Future<void> sendChallengeNotification({
    required String targetUserId,
    required String challengerId,
    required String challengerName,
    required String challengeId,
    String? gameName,
    String? status,
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

  Future<void> sendTeamNotification({
    required String targetUserId,
    required String teamId,
    required String teamName,
    required String type,
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

  Future<void> saveUserFcmToken([String? explicitUid]) async {}

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

      final notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _localNotifications.show(
        notifId,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(payloadData),
      );
    } catch (_) {}
  }

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

    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _localNotifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(payloadData),
    );
  }

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

  Future<void> subscribeToAllNewsTopic() async {}

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

    try {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_androidChannel);
      }
    } catch (_) {}
  }

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
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF00FF88),
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        notifTitle,
        notifBody,
        NotificationDetails(android: androidDetails),
        payload: jsonEncode(payloadData),
      );
    } catch (_) {}
  }

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
