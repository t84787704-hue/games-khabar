class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final String messageType; // 'text' or 'image'
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.messageType = 'text',
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data) {
    return ChatMessage(
      id: (data['id'] ?? '').toString(),
      senderId: (data['sender_id'] ?? '').toString(),
      receiverId: (data['receiver_id'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      messageType: (data['message_type'] ?? 'text').toString(),
      isRead: data['is_read'] == true,
      createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'message_type': messageType,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Represents a chat conversation entry in the messages list
class ChatConversation {
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhoto;
  final String lastMessage;
  final String lastMessageType;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isVerified;

  ChatConversation({
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto = '',
    required this.lastMessage,
    this.lastMessageType = 'text',
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isVerified = false,
  });
}