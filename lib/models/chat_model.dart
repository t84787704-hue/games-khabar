/// Chat and Direct Message Models for 1-on-1 Gamer Messaging
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

  ChatMessage({
    this.id = '',
    this.senderId = '',
    this.receiverId = '',
    this.conversationId = '',
    this.message = '',
    DateTime? createdAt,
    this.isRead = false,
    this.imageUrl,
    this.mediaUrl,
  }) : createdAt = createdAt ?? DateTime.now();

  // Alias getters to support various naming conventions across screens
  String get text => message;
  String get content => message;
  DateTime get timestamp => createdAt;
  DateTime get time => createdAt;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      try {
        return (val as dynamic).toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

    return ChatMessage(
      id: map['id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? map['senderId']?.toString() ?? '',
      receiverId: map['receiver_id']?.toString() ?? map['receiverId']?.toString() ?? '',
      conversationId: map['conversation_id']?.toString() ?? map['conversationId']?.toString() ?? '',
      message: map['message']?.toString() ?? map['text']?.toString() ?? map['content']?.toString() ?? '',
      createdAt: parseDate(map['created_at'] ?? map['createdAt'] ?? map['timestamp']),
      isRead: map['is_read'] == true || map['isRead'] == true,
      imageUrl: map['image_url']?.toString() ?? map['imageUrl']?.toString(),
      mediaUrl: map['media_url']?.toString() ?? map['mediaUrl']?.toString(),
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
      'created_at': createdAt.toIso8601String(),
      'timestamp': createdAt.toIso8601String(),
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

class ChatConversation implements Comparable<ChatConversation> {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;
  final String lastMessage;
  final String lastMessageType;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isVerified;

  ChatConversation({
    this.id = '',
    this.otherUserId = '',
    this.otherUserName = '',
    String otherUserAvatar = '',
    String? otherUserPhoto,
    this.lastMessage = '',
    this.lastMessageType = 'text',
    DateTime? lastMessageAt,
    DateTime? lastMessageTime,
    this.unreadCount = 0,
    this.isVerified = false,
  })  : otherUserAvatar = (otherUserPhoto != null && otherUserPhoto.isNotEmpty)
            ? otherUserPhoto
            : otherUserAvatar,
        lastMessageAt = lastMessageTime ?? lastMessageAt ?? DateTime.now();

  // Alias getters to support various naming conventions across screens
  String get conversationId => id;
  String get peerId => otherUserId;
  String get userId => otherUserId;
  String get peerName => otherUserName;
  String get username => otherUserName;
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
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      try {
        return (val as dynamic).toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

    return ChatConversation(
      id: map['id']?.toString() ?? map['conversation_id']?.toString() ?? '',
      otherUserId: map['other_user_id']?.toString() ?? map['otherUserId']?.toString() ?? map['peer_id']?.toString() ?? '',
      otherUserName: map['other_user_name']?.toString() ?? map['otherUserName']?.toString() ?? map['username']?.toString() ?? '',
      otherUserAvatar: map['other_user_avatar']?.toString() ?? map['otherUserAvatar']?.toString() ?? map['avatar_url']?.toString() ?? '',
      lastMessage: map['last_message']?.toString() ?? map['lastMessage']?.toString() ?? '',
      lastMessageAt: parseDate(map['last_message_at'] ?? map['lastMessageAt'] ?? map['updated_at'] ?? map['timestamp']),
      unreadCount: (map['unread_count'] is num)
          ? (map['unread_count'] as num).toInt()
          : (map['unreadCount'] is num)
              ? (map['unreadCount'] as num).toInt()
              : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'other_user_id': otherUserId,
      'otherUserId': otherUserId,
      'other_user_name': otherUserName,
      'otherUserName': otherUserName,
      'other_user_avatar': otherUserAvatar,
      'otherUserAvatar': otherUserAvatar,
      'last_message': lastMessage,
      'lastMessage': lastMessage,
      'last_message_at': lastMessageAt.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'unread_count': unreadCount,
      'unreadCount': unreadCount,
    };
  }

  @override
  int compareTo(ChatConversation other) {
    return other.lastMessageAt.compareTo(lastMessageAt);
  }
}
