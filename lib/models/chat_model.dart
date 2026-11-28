/// Chat and Direct Message Models for 1-on-1 Gamer Messaging
///
/// NOTE: These models are PURE DATA classes.
/// Time should be injected by the repository/service layer.
/// Fallback time is applied ONLY when parsing legacy/incomplete data.

import 'dart:convert';

class ChatMessage {
  static const String _metaSuffixStart = '\u200B\u2063[[GM_META:';
  static const String _metaSuffixEnd = ']]\u2063\u200B';

  final String id;
  final String senderId;
  final String receiverId;
  final String conversationId;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? imageUrl;
  final String? mediaUrl;

  /// Map of emoji -> list of userIds (or single userId) who reacted with that emoji,
  /// normalized here as `Map<String, List<String>>` (emoji -> list of userIds).
  final Map<String, List<String>> reactions;

  /// Reply metadata when this message is a reply to an earlier message.
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderId;
  final String? replyToSenderName;
  final String? replyToImageUrl;

  const ChatMessage({
    this.id = '',
    this.senderId = '',
    this.receiverId = '',
    this.conversationId = '',
    this.message = '',
    required this.createdAt,
    this.isRead = false,
    this.imageUrl,
    this.mediaUrl,
    this.reactions = const {},
    this.replyToId,
    this.replyToText,
    this.replyToSenderId,
    this.replyToSenderName,
    this.replyToImageUrl,
  });

  String get text => message;
  String get content => message;
  DateTime get timestamp => createdAt;
  DateTime get time => createdAt;

  bool get isReply =>
      (replyToId != null && replyToId!.trim().isNotEmpty) ||
      (replyToText != null && replyToText!.trim().isNotEmpty) ||
      (replyToImageUrl != null && replyToImageUrl!.trim().isNotEmpty);

  bool get hasReactions =>
      reactions.entries.any((entry) => entry.key.trim().isNotEmpty && entry.value.isNotEmpty);

  /// Resolves the image URL for an image message whether stored in `image_url`, `media_url`,
  /// or directly in `message` when `message_type == 'image'`.
  String get resolvedImageUrl {
    final img = (imageUrl ?? '').trim();
    if (img.isNotEmpty && img.toLowerCase() != 'null') return img;
    final media = (mediaUrl ?? '').trim();
    if (media.isNotEmpty && media.toLowerCase() != 'null') return media;
    final msg = message.trim();
    if (_looksLikeImageUrl(msg)) return msg;
    return '';
  }

  bool get hasImage => resolvedImageUrl.isNotEmpty;

  static bool _looksLikeImageUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
    if (lower.contains('/storage/v1/object/public/') ||
        lower.contains('/chat_images/') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        RegExp(r'\.(jpg|jpeg|png|webp|gif)(\?.*)?$', caseSensitive: false)
            .hasMatch(lower)) {
      return true;
    }
    return false;
  }

  /// Strips any embedded metadata suffix from a raw database message string and returns
  /// `{ 'cleanMessage': String, 'meta': Map<String, dynamic>? }`.
  static Map<String, dynamic> decodeEmbeddedMetadata(String rawMessage) {
    final startIdx = rawMessage.indexOf(_metaSuffixStart);
    if (startIdx == -1) {
      return {'cleanMessage': rawMessage, 'meta': null};
    }
    final endIdx = rawMessage.indexOf(_metaSuffixEnd, startIdx);
    if (endIdx == -1) {
      return {'cleanMessage': rawMessage, 'meta': null};
    }
    final cleanText = rawMessage.substring(0, startIdx);
    final b64Payload = rawMessage.substring(
      startIdx + _metaSuffixStart.length,
      endIdx,
    );
    try {
      final jsonStr = utf8.decode(base64Decode(b64Payload));
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return {
          'cleanMessage': cleanText,
          'meta': Map<String, dynamic>.from(decoded),
        };
      }
    } catch (_) {}
    return {'cleanMessage': cleanText, 'meta': null};
  }

  /// Encodes reply/reaction/image metadata into a compact suffix appended to `cleanMessage`
  /// so databases without dedicated `reactions` or `reply_to_*` columns still persist them.
  static String encodeMessageWithMetadata({
    required String cleanMessage,
    String? imageUrl,
    Map<String, List<String>>? reactions,
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
    String? replyToImageUrl,
  }) {
    final meta = <String, dynamic>{};
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      meta['img'] = imageUrl.trim();
    }
    if (replyToId != null && replyToId.trim().isNotEmpty) {
      meta['r_id'] = replyToId.trim();
    }
    if (replyToText != null && replyToText.trim().isNotEmpty) {
      meta['r_txt'] = replyToText.trim();
    }
    if (replyToSenderId != null && replyToSenderId.trim().isNotEmpty) {
      meta['r_sid'] = replyToSenderId.trim();
    }
    if (replyToSenderName != null && replyToSenderName.trim().isNotEmpty) {
      meta['r_sname'] = replyToSenderName.trim();
    }
    if (replyToImageUrl != null && replyToImageUrl.trim().isNotEmpty) {
      meta['r_img'] = replyToImageUrl.trim();
    }
    if (reactions != null && reactions.isNotEmpty) {
      final cleanReactions = <String, List<String>>{};
      reactions.forEach((emoji, users) {
        if (emoji.trim().isNotEmpty && users.isNotEmpty) {
          cleanReactions[emoji.trim()] = users;
        }
      });
      if (cleanReactions.isNotEmpty) {
        meta['rx'] = cleanReactions;
      }
    }

    if (meta.isEmpty) return cleanMessage;
    try {
      final b64 = base64Encode(utf8.encode(jsonEncode(meta)));
      return '$cleanMessage$_metaSuffixStart$b64$_metaSuffixEnd';
    } catch (_) {
      return cleanMessage;
    }
  }

  static Map<String, List<String>> parseReactionsMap(dynamic raw) {
    final result = <String, List<String>>{};
    if (raw == null) return result;
    dynamic parsed = raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        parsed = jsonDecode(raw);
      } catch (_) {
        return result;
      }
    }
    if (parsed is Map) {
      parsed.forEach((key, value) {
        final k = key.toString().trim();
        if (k.isEmpty) return;
        if (value is List) {
          // Format: { "👍": ["userId1", "userId2"] }
          final users = value
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList();
          if (users.isNotEmpty) {
            result[k] = users;
          }
        } else if (value is String && value.trim().isNotEmpty) {
          // Format: { "userId1": "👍" } or { "👍": "userId1" }
          final v = value.trim();
          // Check if key looks like an emoji (short length <= 8 and non-ASCII) vs userId
          final isKeyEmoji = k.runes.length <= 4 && k.codeUnits.any((c) => c > 127);
          if (isKeyEmoji) {
            result.putIfAbsent(k, () => []).add(v);
          } else {
            result.putIfAbsent(v, () => []).add(k);
          }
        }
      });
    }
    return result;
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final rawField = map['message']?.toString() ??
        map['text']?.toString() ??
        map['content']?.toString() ??
        '';
    final decodedPayload = decodeEmbeddedMetadata(rawField);
    final String rawMsg = decodedPayload['cleanMessage'] as String;
    final Map<String, dynamic>? embeddedMeta =
        decodedPayload['meta'] as Map<String, dynamic>?;

    final msgType = (map['message_type'] ?? map['messageType'] ?? 'text')
        .toString()
        .trim()
        .toLowerCase();

    String? imgUrl = map['image_url']?.toString() ??
        map['imageUrl']?.toString() ??
        embeddedMeta?['img']?.toString();
    String? medUrl = map['media_url']?.toString() ?? map['mediaUrl']?.toString();

    if ((imgUrl == null || imgUrl.trim().isEmpty || imgUrl == 'null') &&
        (medUrl == null || medUrl.trim().isEmpty || medUrl == 'null')) {
      if ((msgType == 'image' &&
              (rawMsg.trim().startsWith('http://') ||
                  rawMsg.trim().startsWith('https://'))) ||
          _looksLikeImageUrl(rawMsg)) {
        imgUrl = rawMsg.trim();
      }
    }

    // Parse reactions from native `reactions` column or embedded metadata
    Map<String, List<String>> parsedReactions = parseReactionsMap(map['reactions']);
    if (parsedReactions.isEmpty && embeddedMeta != null && embeddedMeta['rx'] != null) {
      parsedReactions = parseReactionsMap(embeddedMeta['rx']);
    }

    // Parse reply reference from native columns or embedded metadata
    final String? replyId = (map['reply_to_id'] ??
            map['replyToId'] ??
            map['reply_to_message_id'] ??
            embeddedMeta?['r_id'])
        ?.toString();
    final String? replyText = (map['reply_to_text'] ??
            map['replyToText'] ??
            map['reply_to_message'] ??
            embeddedMeta?['r_txt'])
        ?.toString();
    final String? replySenderId = (map['reply_to_sender_id'] ??
            map['replyToSenderId'] ??
            embeddedMeta?['r_sid'])
        ?.toString();
    final String? replySenderName = (map['reply_to_sender_name'] ??
            map['replyToSenderName'] ??
            embeddedMeta?['r_sname'])
        ?.toString();
    final String? replyImage = (map['reply_to_image_url'] ??
            map['replyToImageUrl'] ??
            embeddedMeta?['r_img'])
        ?.toString();

    return ChatMessage(
      id: map['id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ??
          map['senderId']?.toString() ??
          '',
      receiverId: map['receiver_id']?.toString() ??
          map['receiverId']?.toString() ??
          '',
      conversationId: map['conversation_id']?.toString() ??
          map['conversationId']?.toString() ??
          '',
      message: rawMsg,
      createdAt: _parseDate(
        map['created_at'] ?? map['createdAt'] ?? map['timestamp'],
      ),
      isRead: map['is_read'] == true || map['isRead'] == true,
      imageUrl: (imgUrl != null && imgUrl != 'null' && imgUrl.trim().isNotEmpty)
          ? imgUrl.trim()
          : null,
      mediaUrl: (medUrl != null && medUrl != 'null' && medUrl.trim().isNotEmpty)
          ? medUrl.trim()
          : null,
      reactions: parsedReactions,
      replyToId: (replyId != null && replyId != 'null' && replyId.trim().isNotEmpty)
          ? replyId.trim()
          : null,
      replyToText:
          (replyText != null && replyText != 'null' && replyText.trim().isNotEmpty)
              ? replyText.trim()
              : null,
      replyToSenderId: (replySenderId != null &&
              replySenderId != 'null' &&
              replySenderId.trim().isNotEmpty)
          ? replySenderId.trim()
          : null,
      replyToSenderName: (replySenderName != null &&
              replySenderName != 'null' &&
              replySenderName.trim().isNotEmpty)
          ? replySenderName.trim()
          : null,
      replyToImageUrl: (replyImage != null &&
              replyImage != 'null' &&
              replyImage.trim().isNotEmpty)
          ? replyImage.trim()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'sender_id': senderId,
      'senderId': senderId,
      'receiver_id': receiverId,
      'receiverId': receiverId,
      if (conversationId.isNotEmpty) 'conversation_id': conversationId,
      'message': message,
      'text': message,
      'created_at': createdAt.toUtc().toIso8601String(),
      'timestamp': createdAt.toUtc().toIso8601String(),
      'is_read': isRead,
      'isRead': isRead,
      if (imageUrl != null) 'image_url': imageUrl,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (reactions.isNotEmpty) 'reactions': reactions,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyToText != null) 'reply_to_text': replyToText,
      if (replyToSenderId != null) 'reply_to_sender_id': replyToSenderId,
      if (replyToSenderName != null) 'reply_to_sender_name': replyToSenderName,
      if (replyToImageUrl != null) 'reply_to_image_url': replyToImageUrl,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? conversationId,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    String? imageUrl,
    String? mediaUrl,
    Map<String, List<String>>? reactions,
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
    String? replyToImageUrl,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      conversationId: conversationId ?? this.conversationId,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      reactions: reactions ?? this.reactions,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyToImageUrl: replyToImageUrl ?? this.replyToImageUrl,
    );
  }
}

// ============================================================================

class ChatConversation implements Comparable<ChatConversation> {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String otherUsername;
  final String otherUserAvatar;
  final String otherUserGame;
  final String otherUserGameId;
  final String lastMessage;
  final String lastMessageType;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isVerified;
  final bool isOnline;
  final DateTime? lastSeen;

  ChatConversation({
    this.id = '',
    this.otherUserId = '',
    this.otherUserName = '',
    this.otherUsername = '',
    String otherUserAvatar = '',
    String? otherUserPhoto,
    this.otherUserGame = '',
    this.otherUserGameId = '',
    this.lastMessage = '',
    this.lastMessageType = 'text',
    DateTime? lastMessageAt,
    DateTime? lastMessageTime,
    this.unreadCount = 0,
    this.isVerified = false,
    this.isOnline = false,
    this.lastSeen,
  })  : otherUserAvatar =
            (otherUserPhoto != null && otherUserPhoto.isNotEmpty)
                ? otherUserPhoto
                : otherUserAvatar,
        lastMessageAt = lastMessageTime ?? lastMessageAt ?? DateTime.now();

  String get conversationId => id;
  String get peerId => otherUserId;
  String get userId => otherUserId;
  String get peerName => otherUserName;
  String get username => otherUsername.isNotEmpty ? otherUsername : otherUserName;
  String get displayName => otherUserName;
  String get name => otherUserName;
  String get peerAvatar => otherUserAvatar;
  String get avatarUrl => otherUserAvatar;
  String get photoUrl => otherUserAvatar;
  String get otherUserPhoto => otherUserAvatar;
  DateTime get timestamp => lastMessageAt;
  DateTime get updatedAt => lastMessageAt;
  DateTime get createdAt => lastMessageAt;
  DateTime get lastMessageTime => lastMessageAt;

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    return ChatConversation(
      id: map['id']?.toString() ??
          map['conversation_id']?.toString() ??
          '',
      otherUserId: map['other_user_id']?.toString() ??
          map['otherUserId']?.toString() ??
          map['peer_id']?.toString() ??
          '',
      otherUserName: map['other_user_name']?.toString() ??
          map['otherUserName']?.toString() ??
          map['display_name']?.toString() ??
          map['username']?.toString() ??
          '',
      otherUsername: map['other_username']?.toString() ??
          map['username']?.toString() ??
          '',
      otherUserAvatar: map['other_user_avatar']?.toString() ??
          map['otherUserAvatar']?.toString() ??
          map['avatar_url']?.toString() ??
          '',
      otherUserGame: map['other_user_game']?.toString() ??
          map['game']?.toString() ??
          '',
      otherUserGameId: map['other_user_game_id']?.toString() ??
          map['game_id']?.toString() ??
          '',
      lastMessage: map['last_message']?.toString() ??
          map['lastMessage']?.toString() ??
          '',
      lastMessageAt: _parseDate(
        map['last_message_at'] ??
            map['lastMessageAt'] ??
            map['updated_at'] ??
            map['timestamp'],
      ),
      unreadCount: (map['unread_count'] is num)
          ? (map['unread_count'] as num).toInt()
          : (map['unreadCount'] is num)
              ? (map['unreadCount'] as num).toInt()
              : 0,
      isOnline: map['is_online'] == true || map['isOnline'] == true,
      lastSeen: map['last_seen'] != null ? _parseDate(map['last_seen']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'other_user_id': otherUserId,
      'otherUserId': otherUserId,
      'other_user_name': otherUserName,
      'otherUserName': otherUserName,
      'other_username': otherUsername,
      'other_user_avatar': otherUserAvatar,
      'otherUserAvatar': otherUserAvatar,
      'other_user_game': otherUserGame,
      'other_user_game_id': otherUserGameId,
      'last_message': lastMessage,
      'lastMessage': lastMessage,
      'last_message_at': lastMessageAt.toUtc().toIso8601String(),
      'lastMessageAt': lastMessageAt.toUtc().toIso8601String(),
      'unread_count': unreadCount,
      'unreadCount': unreadCount,
      'is_online': isOnline,
      if (lastSeen != null) 'last_seen': lastSeen!.toUtc().toIso8601String(),
    };
  }

  @override
  int compareTo(ChatConversation other) {
    return other.lastMessageAt.compareTo(lastMessageAt);
  }
}

// ============================================================================
// PRIVATE HELPERS
// ============================================================================

DateTime _parseDate(dynamic val) {
  if (val == null) return DateTime.now();
  if (val is DateTime) return val.toLocal();
  if (val is String) {
    final str = val.trim();
    if (str.isEmpty) return DateTime.now();
    final hasTz = str.endsWith('Z') ||
        str.endsWith('z') ||
        RegExp(r'[+-]\d{2}(:?\d{2})?$').hasMatch(str);
    final normalized = hasTz ? str : '${str.replaceFirst(' ', 'T')}Z';
    return (DateTime.tryParse(normalized) ?? DateTime.tryParse(str) ?? DateTime.now()).toLocal();
  }
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val).toLocal();
  try {
    final result = (val as dynamic).toDate();
    if (result is DateTime) return result.toLocal();
    return DateTime.now();
  } catch (_) {
    return DateTime.now();
  }
}