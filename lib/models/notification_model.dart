import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';

class InAppNotification {
  final String id;
  final String userId;
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final bool isSeen;
  final String priority;
  final DateTime createdAt;
  final DateTime? readAt;

  const InAppNotification({
    required this.id,
    required this.userId,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    this.isSeen = false,
    this.priority = 'normal',
    required this.createdAt,
    this.readAt,
  });

  factory InAppNotification.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      try {
        if ((val as dynamic).toDate != null) return (val as dynamic).toDate();
      } catch (_) {}
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      try {
        if ((val as dynamic).toDate != null) return (val as dynamic).toDate();
      } catch (_) {}
      return null;
    }

    Map<String, dynamic>? parseData(dynamic val) {
      if (val == null) return null;
      if (val is Map<String, dynamic>) return val;
      if (val is Map) return Map<String, dynamic>.from(val);
      return null;
    }

    final id = map['id']?.toString() ?? docId ?? '';
    final userId = (map['user_id'] ?? map['userId'] ?? map['recipientUid'] ?? map['recipient_uid'])?.toString() ?? '';
    final senderId = (map['sender_id'] ?? map['senderId'] ?? map['senderUid'])?.toString();
    final senderName = (map['sender_name'] ?? map['senderName'])?.toString();
    final senderAvatar = (map['sender_avatar'] ?? map['senderAvatar'] ?? map['senderPhoto'])?.toString();
    final type = map['type']?.toString() ?? 'system';
    final title = map['title']?.toString() ?? 'Notification';
    final body = (map['body'] ?? map['message'] ?? '')?.toString() ?? '';
    final data = parseData(map['data'] ?? map['payload']);
    final isRead = map['is_read'] == true || map['isRead'] == true || map['read'] == true;
    final isSeen = map['is_seen'] == true || map['isSeen'] == true;
    final priority = map['priority']?.toString() ?? 'normal';
    final createdAt = parseDate(map['created_at'] ?? map['createdAt'] ?? map['timestamp']);
    final readAt = parseNullableDate(map['read_at'] ?? map['readAt']);

    return InAppNotification(
      id: id,
      userId: userId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      type: type,
      title: title,
      body: body,
      data: data,
      isRead: isRead,
      isSeen: isSeen,
      priority: priority,
      createdAt: createdAt,
      readAt: readAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'is_read': isRead,
      'is_seen': isSeen,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
    };
  }

  InAppNotification copyWith({
    String? id,
    String? userId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    bool? isSeen,
    String? priority,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return InAppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      isSeen: isSeen ?? this.isSeen,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(createdAt);
  }

  IconData get iconData {
    switch (type) {
      case 'follow':
        return Icons.person_add_rounded;
      case 'post_like':
      case 'like':
        return Icons.favorite_rounded;
      case 'post_comment':
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'admin_announcement':
      case 'announcement':
        return Icons.campaign_rounded;
      case 'proof_uploaded':
        return Icons.file_upload_rounded;
      case 'proof_accepted':
      case 'match_verified':
        return Icons.verified_rounded;
      case 'proof_rejected':
        return Icons.cancel_rounded;
      case 'challenge_received':
      case 'challenge':
        return Icons.sports_kabaddi_rounded;
      case 'challenge_accepted':
        return Icons.flash_on_rounded;
      case 'challenge_rejected':
        return Icons.close_rounded;
      case 'team_join_request':
        return Icons.group_add_rounded;
      case 'team_join_approved':
        return Icons.groups_rounded;
      case 'match_result':
        return Icons.emoji_events_rounded;
      case 'coin_reward':
      case 'daily_bonus':
      case 'ad_reward':
      case 'referral':
        return Icons.monetization_on_rounded;
      case 'store_purchase':
        return Icons.shopping_bag_rounded;
      case 'perk_expiry':
        return Icons.alarm_rounded;
      case 'tournament_update':
      case 'room_update':
        return Icons.sports_esports_rounded;
      case 'system':
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get iconColor {
    switch (type) {
      case 'follow':
        return GamerTheme.accentBlue;
      case 'post_like':
      case 'like':
        return GamerTheme.redAccent;
      case 'post_comment':
      case 'comment':
        return GamerTheme.accentOrange;
      case 'admin_announcement':
      case 'announcement':
        return const Color(0xFFFFD700); // Gold
      case 'proof_uploaded':
        return const Color(0xFF00E5FF); // Cyan
      case 'proof_accepted':
      case 'match_verified':
        return GamerTheme.neonGreen;
      case 'proof_rejected':
        return const Color(0xFFFF4655);
      case 'challenge_received':
      case 'challenge':
        return const Color(0xFFFF2D55); // Crimson
      case 'challenge_accepted':
        return GamerTheme.neonGreen;
      case 'challenge_rejected':
        return GamerTheme.textMuted;
      case 'team_join_request':
        return GamerTheme.accentBlue;
      case 'team_join_approved':
        return GamerTheme.neonGreen;
      case 'match_result':
        return const Color(0xFFFFD700);
      case 'coin_reward':
      case 'daily_bonus':
      case 'ad_reward':
      case 'referral':
        return const Color(0xFFFFD700);
      case 'store_purchase':
        return const Color(0xFF00E5FF);
      case 'perk_expiry':
        return GamerTheme.accentOrange;
      case 'tournament_update':
      case 'room_update':
        return GamerTheme.neonGreen;
      case 'system':
      default:
        return GamerTheme.accentBlue;
    }
  }

  String get categoryTag {
    switch (type) {
      case 'follow':
        return 'Follow';
      case 'post_like':
      case 'like':
        return 'Like';
      case 'post_comment':
      case 'comment':
        return 'Comment';
      case 'admin_announcement':
      case 'announcement':
        return 'Announcement';
      case 'proof_uploaded':
        return 'Proof';
      case 'proof_accepted':
      case 'match_verified':
        return 'Match Win';
      case 'proof_rejected':
        return 'Proof Rejected';
      case 'challenge_received':
      case 'challenge':
        return '1v1 Challenge';
      case 'challenge_accepted':
        return 'Challenge Accepted';
      case 'challenge_rejected':
        return 'Challenge Declined';
      case 'team_join_request':
        return 'Team Request';
      case 'team_join_approved':
        return 'Team Approved';
      case 'match_result':
        return 'Match Result';
      case 'coin_reward':
      case 'daily_bonus':
      case 'ad_reward':
      case 'referral':
        return 'Coins';
      case 'store_purchase':
        return 'Store';
      case 'perk_expiry':
        return 'Reminder';
      case 'tournament_update':
      case 'room_update':
        return 'Room';
      case 'system':
      default:
        return 'System';
    }
  }
}
