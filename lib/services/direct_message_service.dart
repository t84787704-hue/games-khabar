import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import 'supabase_service.dart';

class DirectMessageService {
  static final DirectMessageService _instance = DirectMessageService._internal();
  factory DirectMessageService() => _instance;
  DirectMessageService._internal();

  final _client = SupabaseService.client;
  static final Map<String, String> _resolvedUuidCache = {};

  /// Resolves any user identifier (auth.uid or users.uid or users.id)
  /// to the canonical UUID `id` from the `users` table.
  Future<String> resolveToTableId(String idOrUid) async {
    final clean = idOrUid.trim();
    if (clean.isEmpty) return '';
    if (_resolvedUuidCache.containsKey(clean)) {
      return _resolvedUuidCache[clean]!;
    }
    try {
      final row = await _client
          .from('users')
          .select('id, uid')
          .or('id.eq.$clean,uid.eq.$clean')
          .maybeSingle();
      if (row != null && row['id'] != null) {
        final tableId = row['id'].toString();
        _resolvedUuidCache[clean] = tableId;
        if (row['uid'] != null) {
          _resolvedUuidCache[row['uid'].toString()] = tableId;
        }
        return tableId;
      }
    } catch (e) {
      debugPrint('[DMS] resolveToTableId error: $e');
    }
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(clean)) {
      final res = clean.toLowerCase();
      _resolvedUuidCache[clean] = res;
      return res;
    }
    final fallback = SupabaseService.toUuid(clean);
    _resolvedUuidCache[clean] = fallback;
    return fallback;
  }

  /// Collects all valid identifier representations for a user (canonical UUID, auth uid, toUuid).
  Future<Set<String>> getUserAliases(String idOrUid) async {
    final clean = idOrUid.trim();
    if (clean.isEmpty) return {};
    final aliases = <String>{clean, clean.toLowerCase()};
    final uuidFallback = SupabaseService.toUuid(clean);
    if (uuidFallback.isNotEmpty) {
      aliases.add(uuidFallback);
      aliases.add(uuidFallback.toLowerCase());
    }
    try {
      final row = await _client
          .from('users')
          .select('id, uid')
          .or('id.eq.$clean,uid.eq.$clean')
          .maybeSingle();
      if (row != null) {
        if (row['id'] != null) {
          final idStr = row['id'].toString();
          aliases.add(idStr);
          aliases.add(idStr.toLowerCase());
          _resolvedUuidCache[clean] = idStr;
        }
        if (row['uid'] != null) {
          final uidStr = row['uid'].toString();
          aliases.add(uidStr);
          aliases.add(uidStr.toLowerCase());
          final uidUuid = SupabaseService.toUuid(uidStr);
          aliases.add(uidUuid);
          aliases.add(uidUuid.toLowerCase());
        }
      }
    } catch (_) {}
    return aliases;
  }

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
      final senderUuid = await resolveToTableId(senderId);
      final receiverUuid = await resolveToTableId(receiverId);

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
    final aliases1 = await getUserAliases(userId1);
    final aliases2 = await getUserAliases(userId2);

    final pairs = <String>[];
    for (final a1 in aliases1) {
      for (final a2 in aliases2) {
        pairs.add('and(sender_id.eq.$a1,receiver_id.eq.$a2)');
        pairs.add('and(sender_id.eq.$a2,receiver_id.eq.$a1)');
      }
    }
    final orCondition = pairs.isNotEmpty ? pairs.join(',') : '';

    while (true) {
      try {
        if (orCondition.isNotEmpty) {
          final rows = await _client
              .from('direct_messages')
              .select()
              .or(orCondition)
              .order('created_at', ascending: true);

          final messages = (rows as List)
              .map((r) => ChatMessage.fromMap(Map<String, dynamic>.from(r)))
              .toList();
          yield messages;
        } else {
          yield [];
        }
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
      final myAliases = await getUserAliases(userId);

      final filterList = <String>[];
      for (final a in myAliases) {
        filterList.add('sender_id.eq.$a');
        filterList.add('receiver_id.eq.$a');
      }
      final orFilter = filterList.join(',');

      final rows = await _client
          .from('direct_messages')
          .select()
          .or(orFilter)
          .order('created_at', ascending: false)
          .limit(500);

      if (rows.isEmpty) return [];

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final row in rows) {
        final sender = (row['sender_id'] ?? '').toString();
        final receiver = (row['receiver_id'] ?? '').toString();

        final bool isSenderMe =
            myAliases.any((a) => a.toLowerCase() == sender.toLowerCase());
        final otherId = isSenderMe ? receiver : sender;
        if (otherId.isEmpty) continue;

        // Skip self messages
        if (myAliases.any((a) => a.toLowerCase() == otherId.toLowerCase())) {
          continue;
        }

        grouped
            .putIfAbsent(otherId, () => [])
            .add(Map<String, dynamic>.from(row));
      }

      final List<ChatConversation> conversations = [];

      for (final entry in grouped.entries) {
        final otherRawId = entry.key;
        final msgs = entry.value;

        final lastMsg = msgs.first;
        final lastText = (lastMsg['message'] ?? '').toString();
        final lastType = (lastMsg['message_type'] ?? 'text').toString();
        final lastTime = DateTime.tryParse(
                (lastMsg['created_at'] ?? '').toString()) ??
            DateTime.now();

        int unread = 0;
        for (final m in msgs) {
          final s = (m['sender_id'] ?? '').toString();
          final isRead = m['is_read'] == true;
          if (!myAliases.any((a) => a.toLowerCase() == s.toLowerCase()) && !isRead) {
            unread++;
          }
        }

        String name = 'Gamer';
        String photo = '';
        bool verified = false;
        String canonicalOtherId = otherRawId;
        try {
          final userRow = await _client
              .from('users')
              .select('id, uid, username, display_name, avatar_url, is_verified')
              .or('id.eq.$otherRawId,uid.eq.$otherRawId')
              .maybeSingle();
          if (userRow != null) {
            name = (userRow['display_name'] ??
                    userRow['username'] ??
                    'Gamer')
                .toString();
            photo = (userRow['avatar_url'] ?? '').toString();
            verified = userRow['is_verified'] == true;
            canonicalOtherId =
                (userRow['id'] ?? userRow['uid'] ?? otherRawId).toString();
          }
        } catch (_) {}

        // Double check not adding myself
        if (myAliases.any((a) => a.toLowerCase() == canonicalOtherId.toLowerCase())) {
          continue;
        }

        conversations.add(ChatConversation(
          otherUserId: canonicalOtherId,
          otherUserName: name,
          otherUserPhoto: photo,
          lastMessage: lastType == 'image' ? '📷 Photo' : lastText,
          lastMessageType: lastType,
          lastMessageTime: lastTime,
          unreadCount: unread,
          isVerified: verified,
        ));
      }

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
      final myAliases = await getUserAliases(currentUserId);
      final otherAliases = await getUserAliases(otherUserId);

      for (final myId in myAliases) {
        for (final otherId in otherAliases) {
          try {
            await _client
                .from('direct_messages')
                .update({'is_read': true})
                .eq('sender_id', otherId)
                .eq('receiver_id', myId)
                .eq('is_read', false);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[DMS] markAsRead error: $e');
    }
  }

  /// Get total unread message count for current user
  Future<int> getTotalUnreadCount(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final myAliases = await getUserAliases(userId);
      final filterList = myAliases.map((a) => 'receiver_id.eq.$a').join(',');

      final rows = await _client
          .from('direct_messages')
          .select('id')
          .or(filterList)
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