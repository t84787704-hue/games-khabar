import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_model.dart';
import '../models/notification_model.dart';
import 'supabase_store_service.dart';
import 'supabase_service.dart';
import 'gamer_auth_service.dart';
import '../screens/news_detail_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/coin_wallet_screen.dart';

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
  static const String channelId = 'gamers_id_loud_alerts_v3';
  static const String channelName = 'Gamers ID Alerts';
  static const String channelDescription = 'Instant match challenges, tournaments, squad alerts, chats and rewards';

  /// Fixed notification ID for general gaming news alerts so updates replace
  /// a single notification rather than stacking duplicate alerts.
  static const int _kGamingNewsNotificationId = 90420;
  static const String _kGamingNewsAlertsPrefKey = 'gaming_news_alerts';
  static const String _kLastGamingNewsAlertMsKey = 'last_gaming_news_alert_ms_v2';
  static const String _kSeenGamingNewsIdsKey = 'seen_gaming_news_alert_ids_v2';
  static const Duration _kGamingNewsCooldown = Duration(hours: 6);

  final AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
    enableLights: true,
    ledColor: const Color(0xFF00FF88),
  );

  bool _isInitialized = false;

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  StreamSubscription? _realtimeNotifSub;
  StreamSubscription? _newsDocsSub;
  Timer? _backgroundPollingTimer;
  String? _subscribedUserId;
  final Set<String> _seenNotificationIds = {};
  final Set<String> _seenNewsDocumentIds = {};
  DateTime? _lastGamingNewsAlertTime;
  bool _isProcessingNewsAlert = false;

  String _trOr(String key, String fallback, {List<String>? args}) {
    try {
      final translated = args != null ? key.tr(args: args) : key.tr();
      if (translated.isEmpty || translated == key || translated.startsWith('notif_')) {
        return fallback;
      }
      return translated;
    } catch (_) {
      return fallback;
    }
  }

  Future<bool> isGamingNewsAlertsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kGamingNewsAlertsPrefKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setGamingNewsAlertsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kGamingNewsAlertsPrefKey, enabled);
      if (!enabled) {
        await _localNotifications.cancel(_kGamingNewsNotificationId);
      }
    } catch (_) {}
  }

  Future<void> _loadGamingNewsAlertState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(_kSeenGamingNewsIdsKey) ?? const <String>[];
      _seenNewsDocumentIds.addAll(savedIds);
      final lastMs = prefs.getInt(_kLastGamingNewsAlertMsKey);
      if (lastMs != null && lastMs > 0) {
        _lastGamingNewsAlertTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
      }
      final enabled = prefs.getBool(_kGamingNewsAlertsPrefKey) ?? true;
      if (!enabled) {
        await _localNotifications.cancel(_kGamingNewsNotificationId);
      }
    } catch (_) {}
  }

  Future<void> _persistSeenNewsIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _seenNewsDocumentIds.toList();
      final trimmed = list.length > 200 ? list.sublist(list.length - 200) : list;
      await prefs.setStringList(_kSeenGamingNewsIdsKey, trimmed);
    } catch (_) {}
  }

  bool _isGenericOrFallbackNewsText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return true;
    final lower = clean.toLowerCase();
    return clean.startsWith('notif_') ||
        lower.contains('notif_new_news_fallback_title') ||
        lower.contains('notif_gaming_fallback') ||
        lower.contains('notif_gaming_news_fallback') ||
        lower.contains('check out the latest gaming updates and news') ||
        lower == 'gaming news' ||
        lower == 'new gaming alert' ||
        lower.contains('weekly #1 team') ||
        clean.contains('ہفتہ وار #1 ٹیم');
  }

  Future<bool> _canFireGamingNewsAlert({bool ignoreCooldown = false}) async {
    if (!await isGamingNewsAlertsEnabled()) {
      return false;
    }
    if (ignoreCooldown) return true;

    final now = DateTime.now();
    if (_lastGamingNewsAlertTime != null &&
        now.difference(_lastGamingNewsAlertTime!) < _kGamingNewsCooldown) {
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_kLastGamingNewsAlertMsKey);
      if (lastMs != null && lastMs > 0) {
        final savedTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
        _lastGamingNewsAlertTime = savedTime;
        if (now.difference(savedTime) < _kGamingNewsCooldown) {
          return false;
        }
      }
    } catch (_) {}
    return true;
  }

  Future<void> _recordGamingNewsAlertFired() async {
    final now = DateTime.now();
    _lastGamingNewsAlertTime = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastGamingNewsAlertMsKey, now.millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _setupLocalNotifications();
    await _loadGamingNewsAlertState();
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
          _subscribedUserId = null;
          _realtimeNotifSub?.cancel();
          _realtimeNotifSub = null;
          _backgroundPollingTimer?.cancel();
          _backgroundPollingTimer = null;
          _seenNotificationIds.clear();
          return;
        }
        _subscribeToUserNotifications(user.id);
      });

      // Also listen to GamerAuthService's user notifier
      GamerAuthService().authUserNotifier.addListener(() {
        final gamerUser = GamerAuthService().authUserNotifier.value;
        if (gamerUser != null) {
          _subscribeToUserNotifications(gamerUser.id);
        }
      });
    } catch (_) {}
  }

  /// Explicit subscription helper accessible from anywhere
  void subscribeToUser(String userId) {
    if (userId.isEmpty) return;
    _subscribeToUserNotifications(userId);
  }

  /// Show quick high-priority banner and ring/vibrate
  Future<void> showBannerNotification({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    final notif = InAppNotification(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      userId: SupabaseService.client.auth.currentUser?.id ?? '',
      type: type ?? 'general',
      title: title,
      body: body,
      isRead: false,
      createdAt: DateTime.now(),
      data: data,
    );
    await showInAppLocalNotification(notif);
  }

  void _subscribeToUserNotifications(String userId) {
    if (userId.isEmpty) return;
    refreshUnreadCount(userId);

    // Avoid tearing down and resetting isFirst when already subscribed to the same user
    if (_subscribedUserId == userId && _realtimeNotifSub != null) {
      return;
    }
    _subscribedUserId = userId;

    _realtimeNotifSub?.cancel();
    _backgroundPollingTimer?.cancel();
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
          // Record all pre-existing notification IDs on initial open/resume without firing burst banners
          for (final r in userRows) {
            final id = r['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              _seenNotificationIds.add(id);
            }
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

    // Fallback periodic poll every 20 seconds to guarantee delivery even if realtime socket drops
    _backgroundPollingTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        final userUuid = SupabaseService.toUuid(userId);
        dynamic rows;
        try {
          rows = await SupabaseService.client
              .from('notifications')
              .select()
              .or('user_id.eq.$userUuid,user_id.eq.$userId,recipientUid.eq.$userId')
              .eq('is_read', false)
              .order('created_at', ascending: false)
              .limit(10);
        } catch (_) {}

        if (rows is List) {
          unreadCountNotifier.value = rows.length;
          final now = DateTime.now();
          for (final r in rows) {
            final id = r['id']?.toString() ?? '';
            if (id.isNotEmpty && !_seenNotificationIds.contains(id)) {
              _seenNotificationIds.add(id);
              final createdAtStr = r['created_at']?.toString() ?? '';
              bool shouldAlert = false;
              if (createdAtStr.isNotEmpty) {
                try {
                  final dt = DateTime.parse(createdAtStr);
                  if (now.difference(dt).inMinutes <= 5) {
                    shouldAlert = true;
                  }
                } catch (_) {}
              }
              if (shouldAlert) {
                final notif = InAppNotification.fromMap(r);
                showInAppLocalNotification(notif);
              }
            }
          }
        }
      } catch (_) {}
    });
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
      final isNewsNotif = notif.type.toLowerCase() == 'news' ||
          (notif.data != null && notif.data!.containsKey('newsId'));

      // Never show generic fallback news reminders
      if (_isGenericOrFallbackNewsText(notif.body)) {
        return;
      }

      if (isNewsNotif) {
        if (!await _canFireGamingNewsAlert()) {
          return;
        }
        await _recordGamingNewsAlertFired();
      }

      // 1. Trigger physical device haptic vibration
      try {
        HapticFeedback.vibrate();
        Future.delayed(const Duration(milliseconds: 250), () {
          HapticFeedback.heavyImpact();
        });
      } catch (_) {}

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
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF00FF88),
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        ticker: notif.title,
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

      final notifId = isNewsNotif
          ? _kGamingNewsNotificationId
          : DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _localNotifications.show(
        notifId,
        notif.title,
        notif.body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(payloadData),
      );

      // 2. In-app floating popup banner if app is currently in foreground
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E293B),
            elevation: 8,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
            ),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Color(0xFF00FF88),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notif.body,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
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

  Future<void> sendSquadJoinNotification({
    required String targetUserId,
    required String squadMemberId,
    required String squadMemberName,
    String? squadMemberAvatar,
  }) async {
    await sendNotification(
      userId: targetUserId,
      senderId: squadMemberId,
      senderName: squadMemberName,
      senderAvatar: squadMemberAvatar,
      type: 'follow',
      title: 'notif_new_follower_title'.tr(),
      body: 'notif_new_follower_body'.tr(args: [squadMemberName]),
      data: {'follower_id': squadMemberId},
    );
  }

  Future<void> sendFollowNotification({
    required String targetUserId,
    required String followerId,
    required String followerName,
    String? followerAvatar,
  }) =>
      sendSquadJoinNotification(
        targetUserId: targetUserId,
        squadMemberId: followerId,
        squadMemberName: followerName,
        squadMemberAvatar: followerAvatar,
      );

  Future<void> sendLikeNotification({
    required String targetUserId,
    required String likerId,
    required String likerName,
    required String postId,
    String? postTitle,
    String? likerAvatar,
  }) async {
    final titleSuffix = (postTitle != null && postTitle.isNotEmpty) ? ' "$postTitle"' : '';
    await sendNotification(
      userId: targetUserId,
      senderId: likerId,
      senderName: likerName,
      senderAvatar: likerAvatar,
      type: 'post_like',
      title: 'notif_post_like_title'.tr(),
      body: 'notif_post_like_body'.tr(args: [likerName, titleSuffix]),
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
      title: 'notif_comment_title'.tr(),
      body: 'notif_comment_body'.tr(args: [commenterName, preview]),
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
      title = 'notif_proof_accepted_title'.tr();
      body = 'notif_proof_accepted_body'.tr(args: [roomTitle]);
    } else if (status == 'rejected') {
      type = 'proof_rejected';
      title = 'notif_proof_rejected_title'.tr();
      final reasonPart = (reason != null && reason.isNotEmpty) ? ': $reason' : '.';
      body = 'notif_proof_rejected_body'.tr(args: [roomTitle, reasonPart]);
    } else {
      type = 'proof_uploaded';
      title = 'notif_proof_uploaded_title'.tr();
      body = 'notif_proof_uploaded_body'.tr(args: [roomTitle]);
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
      title = 'notif_challenge_accepted_title'.tr();
      body = 'notif_challenge_accepted_body'.tr(args: [challengerName]);
    } else if (status == 'rejected') {
      type = 'challenge_rejected';
      title = 'notif_challenge_rejected_title'.tr();
      body = 'notif_challenge_rejected_body'.tr(args: [challengerName]);
    } else {
      type = 'challenge_received';
      title = _trOr('notif_challenge_received_title', 'New Match Challenge');
      body = _trOr(
        'notif_challenge_received_body',
        '$challengerName challenged you in ${gameName ?? 'Gaming'}',
        args: [challengerName, gameName ?? _trOr('notif_gaming_fallback', 'Gaming')],
      );
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
      title: isApproval ? 'notif_team_approved_title'.tr() : 'notif_team_join_title'.tr(),
      body: isApproval
          ? 'notif_team_approved_body'.tr(args: [teamName])
          : 'notif_team_join_body'.tr(args: [senderName ?? 'notif_gamer'.tr(), teamName]),
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
      title: 'notif_coins_earned_title'.tr(args: [amount.toString()]),
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
      title: 'notif_store_purchase_title'.tr(),
      body: 'notif_store_purchase_body'.tr(args: [itemName, costCoins.toString(), category]),
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
      title: 'notif_perk_expiry_title'.tr(),
      body: 'notif_perk_expiry_body'.tr(args: [perkName, daysRemaining.toString()]),
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
      title: 'notif_tournament_update_title'.tr(args: [roomTitle]),
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

  StreamSubscription? _squadNotifSub;
  final Set<String> _seenSquadNotifIds = {};

  void _listenForSquadNotifications() {
    try {
      SupabaseService.client.auth.onAuthStateChange.listen((data) {
        final user = data.session?.user;
        if (user == null) {
          _squadNotifSub?.cancel();
          _squadNotifSub = null;
          _seenSquadNotifIds.clear();
          return;
        }
        saveUserFcmToken(user.id);

        _squadNotifSub?.cancel();
        bool isFirstSnapshot = true;
        try {
          _squadNotifSub = SupabaseService.client
              .from('notifications')
              .stream(primaryKey: ['id'])
              .eq('recipientUid', user.id)
              .order('created_at', ascending: false)
              .limit(10)
              .listen((rows) {
            if (isFirstSnapshot) {
              isFirstSnapshot = false;
              for (final map in rows) {
                final id = map['id']?.toString() ?? '';
                if (id.isNotEmpty) {
                  _seenSquadNotifIds.add(id);
                }
              }
              return;
            }

            for (final map in rows) {
              final id = map['id']?.toString() ?? '';
              if (id.isNotEmpty && !_seenSquadNotifIds.add(id)) {
                continue;
              }
              final type = map['type'] as String? ?? '';
              if (type.startsWith('squad_')) {
                final title = map['title'] as String? ?? 'notif_squad_update_title'.tr();
                final message = map['message'] as String? ?? map['body'] as String? ?? 'notif_squad_update_body'.tr();
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
    _newsDocsSub?.cancel();
    bool isFirstSnapshot = true;
    try {
      _newsDocsSub = SupabaseService.client
          .from('posts')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(10)
          .listen((rows) async {
        // On initial snapshot (app launch / stream connect), mark all existing post IDs as seen
        // and never fire notifications for pre-existing articles.
        if (isFirstSnapshot) {
          isFirstSnapshot = false;
          bool addedAny = false;
          for (final data in rows) {
            final id = data['id']?.toString().trim() ?? '';
            if (id.isNotEmpty && _seenNewsDocumentIds.add(id)) {
              addedAny = true;
            }
          }
          if (addedAny) {
            await _persistSeenNewsIds();
          }
          return;
        }

        // Collect only genuinely unseen post IDs from this snapshot and immediately mark them seen
        final List<Map<String, dynamic>> unseenRows = [];
        bool addedAny = false;
        for (final data in rows) {
          final id = data['id']?.toString().trim() ?? '';
          if (id.isEmpty) continue;
          if (_seenNewsDocumentIds.add(id)) {
            addedAny = true;
            unseenRows.add(data);
          }
        }
        if (addedAny) {
          await _persistSeenNewsIds();
        }

        if (unseenRows.isEmpty || _isProcessingNewsAlert) {
          return;
        }

        if (!await _canFireGamingNewsAlert()) {
          return;
        }

        final now = DateTime.now();
        Map<String, dynamic>? candidateArticle;

        for (final data in unseenRows) {
          // Only trigger news notifications for genuine news articles, never for team rewards, reposts, or generic fallbacks
          final postType = (data['type'] ?? '').toString().toLowerCase();
          final isRepost = data['is_repost'] == true || data['repost_of_id'] != null;
          final rawTitle = (data['title'] ?? '').toString().trim();

          if (isRepost ||
              rawTitle.isEmpty ||
              postType == 'weekly_team_reward' ||
              _isGenericOrFallbackNewsText(rawTitle)) {
            continue;
          }

          // Require a recent created_at timestamp so old articles loaded on reconnect never trigger alerts
          final createdAtRaw = (data['created_at'] ?? data['createdAt'] ?? data['timestamp'])?.toString() ?? '';
          if (createdAtRaw.isNotEmpty) {
            final createdAt = DateTime.tryParse(createdAtRaw);
            if (createdAt != null && now.difference(createdAt.toLocal()).inMinutes.abs() > 20) {
              continue;
            }
          }

          candidateArticle = data;
          break; // At most ONE news alert per batch/cooldown window
        }

        if (candidateArticle == null) {
          return;
        }

        final rawTitle = (candidateArticle['title'] ?? '').toString().trim();
        final rawGame = (candidateArticle['gameName'] ?? candidateArticle['game_name'])?.toString().trim() ?? '';
        final rawCat = (candidateArticle['category'])?.toString().trim() ?? '';
        final gameName = (rawGame.isNotEmpty && !_isGenericOrFallbackNewsText(rawGame))
            ? rawGame
            : ((rawCat.isNotEmpty && !_isGenericOrFallbackNewsText(rawCat))
                ? rawCat
                : 'Gaming');
        final newsId = candidateArticle['id']?.toString().trim() ?? '';
        final imageUrl = (candidateArticle['imageUrl'] ?? candidateArticle['image_url'])?.toString();
        final category = (rawCat.isNotEmpty && !_isGenericOrFallbackNewsText(rawCat))
            ? rawCat
            : gameName;

        _isProcessingNewsAlert = true;
        try {
          await _showLocalNotification(
            title: _trOr('notif_new_news_title', '$gameName News', args: [gameName]),
            body: rawTitle,
            newsId: newsId,
            imageUrl: imageUrl,
            category: category,
          );
        } finally {
          _isProcessingNewsAlert = false;
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
    if (_isGenericOrFallbackNewsText(body)) {
      return;
    }
    if (!await _canFireGamingNewsAlert()) {
      return;
    }
    await _recordGamingNewsAlertFired();

    final cleanCat = (category != null &&
            category.trim().isNotEmpty &&
            !_isGenericOrFallbackNewsText(category))
        ? category.trim()
        : 'Gaming News';
    final payloadData = {
      'type': 'news',
      'newsId': newsId,
      'title': title,
      'body': body,
      'category': cleanCat,
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
      onlyAlertOnce: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: cleanCat,
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

    // Always reuse the single fixed notification ID so new alerts replace rather than stack
    await _localNotifications.show(
      _kGamingNewsNotificationId,
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
    final context = navigatorKey.currentContext;
    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    final titleStr = (data['title'] ?? '').toString();

    // Never route team rewards, coin rewards, or non-news notifications into NewsDetailScreen
    final isRewardOrTeamNotif = type == 'weekly_team_reward' ||
        type == 'coin_reward' ||
        type == 'store_purchase' ||
        type == 'perk_expiry' ||
        titleStr.contains('Weekly #1 Team') ||
        titleStr.contains('ہفتہ وار #1 ٹیم');

    if (isRewardOrTeamNotif) {
      if (context != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CoinWalletScreen()),
        );
      }
      return;
    }

    // Only open NewsDetailScreen if it is explicitly a news notification with a newsId
    final explicitNewsId = data['newsId']?.toString().trim() ?? '';
    final isNewsNotification = (type == 'news' || data.containsKey('newsId')) &&
        explicitNewsId.isNotEmpty;

    if (isNewsNotification) {
      _navigateToNewsDetail(
        explicitNewsId,
        fallbackTitle: data['title']?.toString(),
        fallbackCategory: data['category']?.toString(),
        fallbackDesc: (data['description'] ?? data['body'])?.toString(),
        fallbackImage: data['imageUrl']?.toString(),
      );
      return;
    }

    // For all other in-app notifications (team, squad, challenges, likes, comments, etc.), open NotificationsScreen
    if (context != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
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
    if (news == null) {
      // Do not fabricate a fake news article if it isn't a real news item
      final cleanTitle = (fallbackTitle ?? '').trim();
      final cleanDesc = (fallbackDesc ?? '').trim();
      if (cleanTitle.isEmpty ||
          cleanTitle.contains('Weekly #1 Team') ||
          cleanTitle.contains('ہفتہ وار #1 ٹیم') ||
          cleanTitle.startsWith('notif_')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        return;
      }
      final cleanCat = (fallbackCategory != null &&
              fallbackCategory.trim().isNotEmpty &&
              !fallbackCategory.startsWith('notif_'))
          ? fallbackCategory.trim()
          : 'Gaming News';

      news = NewsModel(
        id: newsId,
        title: cleanTitle,
        description: cleanDesc.startsWith('notif_') ? '' : cleanDesc,
        category: cleanCat,
        imageUrl: fallbackImage ??
            'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
        timeAgo: _trOr('notif_just_now', 'Just now'),
        views: 1,
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(
          newsModel: news,
        ),
      ),
    );
  }

  Future<void> sendNewsNotification({
    required String newsId,
    required String title,
    required String description,
    required String category,
    String? gameName,
    String? imageUrl,
  }) async {
    final cleanTitle = title.trim();
    if (_isGenericOrFallbackNewsText(cleanTitle)) {
      return;
    }

    if (newsId.trim().isNotEmpty) {
      _seenNewsDocumentIds.add(newsId.trim());
      await _persistSeenNewsIds();
    }

    final effectiveGame = (gameName != null &&
            gameName.trim().isNotEmpty &&
            !_isGenericOrFallbackNewsText(gameName))
        ? gameName.trim()
        : ((category.trim().isNotEmpty && !_isGenericOrFallbackNewsText(category))
            ? category.trim()
            : 'Gaming');
    final notifTitle = _trOr('notif_new_news_title', '$effectiveGame News', args: [effectiveGame]);
    final notifBody = cleanTitle;

    final payloadData = {
      'type': 'news',
      'newsId': newsId,
      'category': category,
      'gameName': effectiveGame,
      'title': cleanTitle,
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

    if (!await isGamingNewsAlertsEnabled()) {
      return;
    }
    await _recordGamingNewsAlertFired();

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
        onlyAlertOnce: true,
      );

      await _localNotifications.show(
        _kGamingNewsNotificationId,
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