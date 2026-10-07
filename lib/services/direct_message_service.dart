import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import 'supabase_service.dart';

class DirectMessageService {
  static final DirectMessageService _instance = DirectMessageService._internal();
  factory DirectMessageService() => _instance;
  DirectMessageService._internal();

  final _client = SupabaseService.client;

  /// Send a message
  Future<bool> sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    String messageType = 'text',
  }) async {
    if (senderId.isEmpty || receiverId.isEmpty || message.trim().isEmpty) {
      return false;
    }
    try {
      final senderUuid = SupabaseService.toUuid(senderId);
      final receiverUuid = SupabaseService.toUuid(receiverId);

      await _client.from('direct_messages').insert({
        'sender_id': senderUuid,
        'receiver_id': receiverUuid,
        'message': message.trim(),
        'message_type': messageType,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('[DMS] sendMessage error: $e');
      return false;
    }
  }

  /// Stream messages between two users (real-time)
  Stream<List<ChatMessage>> getMessagesStream({
    required String userId1,
    required String userId2,
  }) async* {
    if (userId1.isEmpty || userId2.isEmpty) {
      yield [];
      return;
    }
    final u1 = SupabaseService.toUuid(userId1);
    final u2 = SupabaseService.toUuid(userId2);

    while (true) {
      try {
        final rows = await _client
            .from('direct_messages')
            .select()
            .or('and(sender_id.eq.$u1,receiver_id.eq.$u2),and(sender_id.eq.$u2,receiver_id.eq.$u1)')
            .order('created_at', ascending: true);

        final messages = (rows as List)
            .map((r) => ChatMessage.fromMap(Map<String, dynamic>.from(r)))
            .toList();
        yield messages;
      } catch (e) {
        debugPrint('[DMS] getMessagesStream error: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Get all conversations for a user (recent chats)
  Future<List<ChatConversation>> getConversations(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final uuid = SupabaseService.toUuid(userId);

      final rows = await _client
          .from('direct_messages')
          .select()
          .or('sender_id.eq.$uuid,receiver_id.eq.$uuid')
          .order('created_at', ascending: false)
          .limit(500);

      if (rows.isEmpty) return [];

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final row in rows) {
        final sender = (row['sender_id'] ?? '').toString();
        final receiver = (row['receiver_id'] ?? '').toString();
        final otherId = sender == uuid ? receiver : sender;
        if (otherId.isEmpty) continue;
        grouped
            .putIfAbsent(otherId, () => [])
            .add(Map<String, dynamic>.from(row));
      }

      final List<ChatConversation> conversations = [];

      for (final entry in grouped.entries) {
        final otherUuid = entry.key;
        final msgs = entry.value;

        final lastMsg = msgs.first;
        final lastText = (lastMsg['message'] ?? '').toString();
        final lastType = (lastMsg['message_type'] ?? 'text').toString();
        final lastTime = DateTime.tryParse(
                (lastMsg['created_at'] ?? '').toString()) ??
            DateTime.now();

        int unread = 0;
        for (final m in msgs) {
          final sender = (m['sender_id'] ?? '').toString();
          final isRead = m['is_read'] == true;
          if (sender == otherUuid && !isRead) unread++;
        }

        String name = 'Gamer';
        String photo = '';
        bool verified = false;
        try {
          final userRow = await _client
              .from('users')
              .select('username, display_name, avatar_url, is_verified')
              .eq('id', otherUuid)
              .maybeSingle();
          if (userRow != null) {
            name = (userRow['display_name'] ??
                    userRow['username'] ??
                    'Gamer')
                .toString();
            photo = (userRow['avatar_url'] ?? '').toString();
            verified = userRow['is_verified'] == true;
          }
        } catch (_) {}

        conversations.add(ChatConversation(
          otherUserId: otherUuid,
          otherUserName: name,
          otherUserPhoto: photo,
          lastMessage: lastType == 'image' ? '📷 Photo' : lastText,
          lastMessageType: lastType,
          lastMessageTime: lastTime,
          unreadCount: unread,
          isVerified: verified,
        ));
      }

      // FIX: Explicit type annotation to avoid 'Object' inference error
      conversations.sort((ChatConversation a, ChatConversation b) {
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });
      return conversations;
    } catch (e) {
      debugPrint('[DMS] getConversations error: $e');
      return [];
    }
  }

  /// Mark all messages from a specific user as read
  Future<void> markAsRead({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (currentUserId.isEmpty || otherUserId.isEmpty) return;
    try {
      final currentUuid = SupabaseService.toUuid(currentUserId);
      final otherUuid = SupabaseService.toUuid(otherUserId);

      await _client
          .from('direct_messages')
          .update({'is_read': true})
          .eq('sender_id', otherUuid)
          .eq('receiver_id', currentUuid)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[DMS] markAsRead error: $e');
    }
  }

  /// Get total unread message count for current user
  Future<int> getTotalUnreadCount(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final uuid = SupabaseService.toUuid(userId);
      final rows = await _client
          .from('direct_messages')
          .select('id')
          .eq('receiver_id', uuid)
          .eq('is_read', false);
      return (rows as List).length;
    } catch (e) {
      debugPrint('[DMS] getTotalUnreadCount error: $e');
      return 0;
    }
  }

  /// Stream total unread count (for badge)
  Stream<int> getUnreadCountStream(String userId) async* {
    if (userId.isEmpty) {
      yield 0;
      return;
    }
    while (true) {
      yield await getTotalUnreadCount(userId);
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  /// Delete a message (only sender can delete)
  Future<void> deleteMessage(String messageId) async {
    if (messageId.isEmpty) return;
    try {
      await _client.from('direct_messages').delete().eq('id', messageId);
    } catch (e) {
      debugPrint('[DMS] deleteMessage error: $e');
    }
  }
}