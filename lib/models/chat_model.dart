/// Chat and Direct Message Models for 1-on-1 Gamer Messaging
///
/// NOTE: These models are PURE DATA classes.
/// Time should be injected by the repository/service layer.
/// Fallback time is applied ONLY when parsing legacy/incomplete data.

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String conversationId;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? imageUrl;
  final String? mediaUrl;

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
  });

  String get text => message;
  String get content => message;
  DateTime get timestamp => createdAt;
  DateTime get time => createdAt;

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

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final rawMsg = map['message']?.toString() ??
        map['text']?.toString() ??
        map['content']?.toString() ??
        '';
    final msgType =
        (map['message_type'] ?? map['messageType'] ?? 'text').toString().trim().toLowerCase();
    String? imgUrl = map['image_url']?.toString() ?? map['imageUrl']?.toString();
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
      imageUrl: imgUrl,
      mediaUrl: medUrl,
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