// ===============================================================================
// DIRECT MESSAGE SERVICE — User Resolution, Presence Heartbeat, Search & Chat
// File: lib/services/direct_message_service.dart
// ===============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/gamer_user_model.dart';
import 'gamer_auth_service.dart';
import 'supabase_service.dart';

class DirectMessageService {
  static final DirectMessageService _instance = DirectMessageService._internal();
  factory DirectMessageService() => _instance;
  DirectMessageService._internal();

  final _client = SupabaseService.client;
  static final Map<String, String> _resolvedUuidCache = {};
  DateTime? _lastPresenceUpdateUtc;

  static final RegExp _uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// Window in minutes within which a user's `last_seen` UTC timestamp is considered Online.
  static const int onlineWindowMinutes = 5;

  /// Parses a timestamp from Supabase (with or without timezone suffix) into UTC.
  static DateTime? parseToUtc(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    final hasTz = str.endsWith('Z') ||
        str.endsWith('z') ||
        RegExp(r'[+-]\d{2}(:?\d{2})?$').hasMatch(str);
    final normalized = hasTz ? str : '${str.replaceFirst(' ', 'T')}Z';
    return (DateTime.tryParse(normalized) ?? DateTime.tryParse(str))?.toUtc();
  }

  /// Checks if a UTC timestamp is within the recent activity window (default 5 minutes).
  static bool isTimestampRecentlyActive(
    DateTime? timestampUtc, {
    int windowMinutes = onlineWindowMinutes,
  }) {
    if (timestampUtc == null) return false;
    final nowUtc = DateTime.now().toUtc();
    final diffSeconds = nowUtc.difference(timestampUtc.toUtc()).inSeconds;
    // Allow up to 5 minutes in the past and up to 5 minutes clock skew
    return diffSeconds >= -300 && diffSeconds <= (windowMinutes * 60);
  }

  /// Evaluates whether a user row from `users` / `profiles` represents an Online user,
  /// comparing `last_seen` (and fallback `updated_at` / latest message timestamp) in UTC.
  static bool evaluateOnlineStatus(
    Map<String, dynamic>? row, {
    DateTime? latestActivityUtc,
    int windowMinutes = onlineWindowMinutes,
  }) {
    if (isTimestampRecentlyActive(latestActivityUtc, windowMinutes: windowMinutes)) {
      return true;
    }
    if (row == null) return false;

    final lastSeenUtc = parseToUtc(
      row['last_seen'] ?? row['lastSeen'] ?? row['last_active'] ?? row['lastActive'],
    );
    if (lastSeenUtc != null) {
      return isTimestampRecentlyActive(lastSeenUtc, windowMinutes: windowMinutes);
    }

    final updatedAtUtc = parseToUtc(row['updated_at'] ?? row['updatedAt']);
    if (updatedAtUtc != null &&
        isTimestampRecentlyActive(updatedAtUtc, windowMinutes: windowMinutes)) {
      return true;
    }

    if (row['is_online'] == true || row['isOnline'] == true) {
      return true;
    }

    return false;
  }

  /// Updates the current user's activity timestamp (`last_seen`, `updated_at`, `is_online`)
  /// in UTC across `users` (and `profiles` if present).
  Future<void> updateUserPresence({
    String? userId,
    bool force = false,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    if (!force &&
        _lastPresenceUpdateUtc != null &&
        nowUtc.difference(_lastPresenceUpdateUtc!).inSeconds < 20) {
      return;
    }

    final authUid = _client.auth.currentUser?.id ?? '';
    final gamerUid = GamerAuthService().currentGamer?.uid ?? '';
    final rawUid = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : (gamerUid.isNotEmpty ? gamerUid : authUid);
    if (rawUid.isEmpty) return;

    _lastPresenceUpdateUtc = nowUtc;
    final nowIso = nowUtc.toIso8601String();

    try {
      final canonicalId = await resolveToTableId(rawUid);
      final targetId = canonicalId.isNotEmpty ? canonicalId : rawUid;
      final isUuid = _uuidRegex.hasMatch(targetId);

      Future<bool> tryUpdateTable(String table, Map<String, dynamic> payload) async {
        try {
          if (isUuid) {
            await _client.from(table).update(payload).eq('id', targetId);
            return true;
          } else {
            await _client.from(table).update(payload).eq('uid', targetId);
            return true;
          }
        } catch (_) {
          if (authUid.isNotEmpty && _uuidRegex.hasMatch(authUid)) {
            try {
              await _client.from(table).update(payload).eq('id', authUid);
              return true;
            } catch (_) {}
          }
          try {
            await _client.from(table).update(payload).eq('uid', rawUid);
            return true;
          } catch (_) {}
          return false;
        }
      }

      // 1. Try updating users table with last_seen, is_online, updated_at
      bool updatedUsers = await tryUpdateTable('users', {
        'last_seen': nowIso,
        'is_online': true,
        'updated_at': nowIso,
      });

      if (!updatedUsers) {
        updatedUsers = await tryUpdateTable('users', {
          'last_seen': nowIso,
          'updated_at': nowIso,
        });
      }

      if (!updatedUsers) {
        await tryUpdateTable('users', {
          'updated_at': nowIso,
        });
      }

      // 2. Best-effort update on profiles table if it exists in the Supabase schema
      try {
        await tryUpdateTable('profiles', {
          'last_seen': nowIso,
          'is_online': true,
          'updated_at': nowIso,
        });
      } catch (_) {}
    } catch (e) {
      debugPrint('[DMS] updateUserPresence note: $e');
    }
  }

  /// Fetches the latest presence status (`isOnline`, `game`, `lastSeen`) for a chat partner.
  Future<Map<String, dynamic>> fetchUserPresenceStatus(
    String otherUserId, {
    DateTime? latestMessageUtc,
  }) async {
    final clean = otherUserId.trim();
    if (clean.isEmpty) {
      return {'isOnline': false, 'game': '', 'lastSeen': null};
    }

    Map<String, dynamic>? userRow;
    final canonicalId = await resolveToTableId(clean);
    final lookupIds = <String>{
      if (canonicalId.isNotEmpty) canonicalId,
      clean,
    };

    for (final candidate in lookupIds) {
      final isUuid = _uuidRegex.hasMatch(candidate);
      if (isUuid && userRow == null) {
        try {
          userRow = await _client
              .from('users')
              .select()
              .eq('id', candidate)
              .maybeSingle();
        } catch (_) {}
      }
      if (userRow == null) {
        try {
          userRow = await _client
              .from('users')
              .select()
              .eq('uid', candidate)
              .maybeSingle();
        } catch (_) {}
      }
      if (userRow != null) break;
    }

    // Fallback to profiles table if not found in users
    if (userRow == null) {
      for (final candidate in lookupIds) {
        final isUuid = _uuidRegex.hasMatch(candidate);
        if (isUuid) {
          try {
            userRow = await _client
                .from('profiles')
                .select()
                .eq('id', candidate)
                .maybeSingle();
          } catch (_) {}
        }
        if (userRow != null) break;
      }
    }

    DateTime? recentPartnerActivityUtc = latestMessageUtc;

    // Also check latest message sent by this user in direct_messages
    if (recentPartnerActivityUtc == null) {
      try {
        final queryId = canonicalId.isNotEmpty && _uuidRegex.hasMatch(canonicalId)
            ? canonicalId
            : (_uuidRegex.hasMatch(clean) ? clean : '');
        if (queryId.isNotEmpty) {
          final lastMsgRow = await _client
              .from('direct_messages')
              .select('created_at')
              .eq('sender_id', queryId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (lastMsgRow != null) {
            recentPartnerActivityUtc = parseToUtc(lastMsgRow['created_at']);
          }
        }
      } catch (_) {}
    }

    final isOnline = evaluateOnlineStatus(
      userRow,
      latestActivityUtc: recentPartnerActivityUtc,
    );

    String game = '';
    if (userRow != null) {
      game = (userRow['primary_game'] ??
              userRow['selected_game'] ??
              userRow['selectedGame'] ??
              userRow['favorite_game'] ??
              userRow['favoriteGame'] ??
              userRow['game_name'] ??
              userRow['game'] ??
              '')
          .toString()
          .trim();
    }

    final lastSeenUtc = userRow != null
        ? (parseToUtc(userRow['last_seen'] ?? userRow['lastSeen']) ??
            parseToUtc(userRow['updated_at'] ?? userRow['updatedAt']) ??
            recentPartnerActivityUtc)
        : recentPartnerActivityUtc;

    return {
      'isOnline': isOnline,
      'game': game,
      'lastSeen': lastSeenUtc,
    };
  }

  /// Searches registered app users (`users` and `profiles`) by display name, username,
  /// game ID, or user ID (`id` / `uid`) so they can be messaged directly from Direct Messages.
  Future<List<GamerUser>> searchRegisteredUsers(
    String query, {
    String? currentUserId,
  }) async {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) return [];

    final cleanQuery = rawQuery.startsWith('@')
        ? rawQuery.substring(1).trim().toLowerCase()
        : rawQuery.toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final myAuthUid = _client.auth.currentUser?.id ?? '';
    final myGamerUid = GamerAuthService().currentGamer?.uid ?? '';
    final effectiveMyUid = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId
        : (myGamerUid.isNotEmpty ? myGamerUid : myAuthUid);
    final myAliases = await getUserAliases(effectiveMyUid);
    if (myAuthUid.isNotEmpty) {
      myAliases.add(myAuthUid);
      myAliases.add(myAuthUid.toLowerCase());
    }
    if (myGamerUid.isNotEmpty) {
      myAliases.add(myGamerUid);
      myAliases.add(myGamerUid.toLowerCase());
    }

    final Map<String, GamerUser> matchedById = {};
    final isUuidQuery = _uuidRegex.hasMatch(cleanQuery);

    void collectRows(List<dynamic> rows) {
      for (final raw in rows) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final rowId = (row['id'] ?? '').toString().trim();
        final rowUid = (row['uid'] ?? '').toString().trim();
        final canonicalId = rowId.isNotEmpty ? rowId : rowUid;
        if (canonicalId.isEmpty) continue;

        // Exclude current logged-in user
        if (myAliases.any((a) =>
            a.toLowerCase() == canonicalId.toLowerCase() ||
            (rowId.isNotEmpty && a.toLowerCase() == rowId.toLowerCase()) ||
            (rowUid.isNotEmpty && a.toLowerCase() == rowUid.toLowerCase()))) {
          continue;
        }

        final user = GamerUser.fromMap(row, canonicalId);
        // Ensure uid is set to canonical table id when available so DM routing works cleanly
        final normalizedUser = rowId.isNotEmpty && user.uid != rowId
            ? user.copyWith(uid: rowId)
            : user;
        matchedById[canonicalId.toLowerCase()] = normalizedUser;
      }
    }

    // 1. Primary server-side search on `users` table
    try {
      final orParts = <String>[
        'username.ilike.%$cleanQuery%',
        'display_name.ilike.%$cleanQuery%',
        'uid.ilike.%$cleanQuery%',
        'game_id.ilike.%$cleanQuery%',
        if (isUuidQuery) 'id.eq.$cleanQuery',
      ];
      final rows = await _client
          .from('users')
          .select()
          .or(orParts.join(','))
          .limit(25);
      collectRows(rows as List);
    } catch (_) {
      // Fallback if uid or game_id is not a text column in a custom schema
      try {
        final orParts = <String>[
          'username.ilike.%$cleanQuery%',
          'display_name.ilike.%$cleanQuery%',
          if (isUuidQuery) 'id.eq.$cleanQuery',
        ];
        final rows = await _client
            .from('users')
            .select()
            .or(orParts.join(','))
            .limit(25);
        collectRows(rows as List);
      } catch (_) {}
    }

    // 2. Fallback / additional search for partial UUID `id` or custom columns on `users`
    if (matchedById.length < 10) {
      try {
        final recentUsers = await _client
            .from('users')
            .select()
            .order('created_at', ascending: false)
            .limit(100);
        final filtered = (recentUsers as List).where((raw) {
          if (raw is! Map) return false;
          final idStr = (raw['id'] ?? '').toString().toLowerCase();
          final uidStr = (raw['uid'] ?? '').toString().toLowerCase();
          final uname = (raw['username'] ?? '').toString().toLowerCase();
          final dname = (raw['display_name'] ?? raw['displayName'] ?? '').toString().toLowerCase();
          final gid = (raw['game_id'] ?? raw['gameId'] ?? '').toString().toLowerCase();
          return dname.contains(cleanQuery) ||
              uname.contains(cleanQuery) ||
              idStr.contains(cleanQuery) ||
              uidStr.contains(cleanQuery) ||
              gid.contains(cleanQuery);
        }).toList();
        collectRows(filtered);
      } catch (_) {}
    }

    // 3. Best-effort check on `profiles` table if present
    try {
      final orParts = <String>[
        'username.ilike.%$cleanQuery%',
        'display_name.ilike.%$cleanQuery%',
        if (isUuidQuery) 'id.eq.$cleanQuery',
      ];
      final profileRows = await _client
          .from('profiles')
          .select()
          .or(orParts.join(','))
          .limit(20);
      collectRows(profileRows as List);
    } catch (_) {}

    return matchedById.values.toList();
  }

  /// Resolves any user identifier (auth.uid or users.uid or users.id)
  /// to the canonical UUID `id` from the `users` table.
  Future<String> resolveToTableId(String idOrUid) async {
    final clean = idOrUid.trim();
    if (clean.isEmpty) return '';
    if (_resolvedUuidCache.containsKey(clean)) {
      return _resolvedUuidCache[clean]!;
    }

    final isUuid = _uuidRegex.hasMatch(clean);

    try {
      Map<String, dynamic>? row;
      // 1. If clean matches UUID format, check table primary key `id` first
      if (isUuid) {
        try {
          row = await _client
              .from('users')
              .select('id, uid')
              .eq('id', clean)
              .maybeSingle();
        } catch (_) {}
      }

      // 2. If not found by `id`, check by `uid` (text column)
      if (row == null) {
        try {
          row = await _client
              .from('users')
              .select('id, uid')
              .eq('uid', clean)
              .maybeSingle();
        } catch (_) {}
      }

      // 3. Return canonical UUID `id` from table
      if (row != null && row['id'] != null) {
        final tableId = row['id'].toString();
        _resolvedUuidCache[clean] = tableId;
        _resolvedUuidCache[tableId] = tableId;
        if (row['uid'] != null) {
          _resolvedUuidCache[row['uid'].toString()] = tableId;
        }
        return tableId;
      }
    } catch (e) {
      debugPrint('[DMS] resolveToTableId error: $e');
    }

    // 4. Fallback: if already a valid UUID format, use it; else convert via toUuid
    if (isUuid) {
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
    final isUuid = _uuidRegex.hasMatch(clean);

    final uuidFallback = SupabaseService.toUuid(clean);
    if (uuidFallback.isNotEmpty) {
      aliases.add(uuidFallback);
      aliases.add(uuidFallback.toLowerCase());
    }

    try {
      Map<String, dynamic>? row;
      if (isUuid) {
        try {
          row = await _client
              .from('users')
              .select('id, uid')
              .eq('id', clean)
              .maybeSingle();
        } catch (_) {}
      }
      if (row == null) {
        try {
          row = await _client
              .from('users')
              .select('id, uid')
              .eq('uid', clean)
              .maybeSingle();
        } catch (_) {}
      }

      if (row != null) {
        if (row['id'] != null) {
          final idStr = row['id'].toString();
          aliases.add(idStr);
          aliases.add(idStr.toLowerCase());
          _resolvedUuidCache[clean] = idStr;
          _resolvedUuidCache[idStr] = idStr;
        }
        if (row['uid'] != null) {
          final uidStr = row['uid'].toString();
          aliases.add(uidStr);
          aliases.add(uidStr.toLowerCase());
          final uidUuid = SupabaseService.toUuid(uidStr);
          aliases.add(uidUuid);
          aliases.add(uidUuid.toLowerCase());
          if (row['id'] != null) {
            _resolvedUuidCache[uidStr] = row['id'].toString();
          }
        }
      }
    } catch (_) {}

    // Also include current auth user id if it corresponds to this user
    try {
      final currentAuthId = _client.auth.currentUser?.id;
      if (currentAuthId != null && currentAuthId.isNotEmpty) {
        if (aliases.contains(currentAuthId) ||
            aliases.contains(currentAuthId.toLowerCase()) ||
            clean == currentAuthId) {
          aliases.add(currentAuthId);
          aliases.add(currentAuthId.toLowerCase());
        }
      }
    } catch (_) {}

    return aliases;
  }

  /// Send a message and update the sender's `last_seen` presence timestamp in UTC.
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

      if (senderUuid.isEmpty || receiverUuid.isEmpty) {
        debugPrint('[DMS] senderUuid or receiverUuid is empty');
        return false;
      }

      // Prevent chatting with self
      if (senderUuid.toLowerCase() == receiverUuid.toLowerCase()) {
        debugPrint('[DMS] Cannot send message to self');
        return false;
      }

      final nowUtcIso = DateTime.now().toUtc().toIso8601String();

      await _client.from('direct_messages').insert({
        'sender_id': senderUuid,
        'receiver_id': receiverUuid,
        'message': message.trim(),
        'message_type': messageType,
        'is_read': false,
        'created_at': nowUtcIso,
      });

      // Immediately update sender's presence timestamp in UTC
      unawaited(updateUserPresence(userId: senderUuid, force: true));
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
  }) =>
      _getMessagesStreamInternal(userId1: userId1, userId2: userId2)
          .asBroadcastStream();

  Stream<List<ChatMessage>> _getMessagesStreamInternal({
    required String userId1,
    required String userId2,
  }) async* {
    if (userId1.isEmpty || userId2.isEmpty) {
      yield [];
      return;
    }
    final u1 = await resolveToTableId(userId1);
    final u2 = await resolveToTableId(userId2);

    final aliases1 = await getUserAliases(userId1);
    final aliases2 = await getUserAliases(userId2);

    final uuids1 = aliases1.where((a) => _uuidRegex.hasMatch(a)).toSet();
    final uuids2 = aliases2.where((a) => _uuidRegex.hasMatch(a)).toSet();
    if (u1.isNotEmpty && _uuidRegex.hasMatch(u1)) uuids1.add(u1);
    if (u2.isNotEmpty && _uuidRegex.hasMatch(u2)) uuids2.add(u2);

    final pairs = <String>[];
    for (final a1 in uuids1) {
      for (final a2 in uuids2) {
        final p1 = 'and(sender_id.eq.$a1,receiver_id.eq.$a2)';
        final p2 = 'and(sender_id.eq.$a2,receiver_id.eq.$a1)';
        if (!pairs.contains(p1)) pairs.add(p1);
        if (!pairs.contains(p2)) pairs.add(p2);
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
      unawaited(updateUserPresence(userId: userId));

      final myAliases = await getUserAliases(userId);
      final myCanonicalId = await resolveToTableId(userId);
      if (myCanonicalId.isNotEmpty) {
        myAliases.add(myCanonicalId);
        myAliases.add(myCanonicalId.toLowerCase());
      }
      final currentAuthId = _client.auth.currentUser?.id;
      if (currentAuthId != null && currentAuthId.isNotEmpty) {
        myAliases.add(currentAuthId);
        myAliases.add(currentAuthId.toLowerCase());
      }

      // Only query with valid UUIDs in SQL to prevent PostgreSQL invalid syntax errors
      final queryUuids = myAliases.where((a) => _uuidRegex.hasMatch(a)).toSet();
      if (myCanonicalId.isNotEmpty && _uuidRegex.hasMatch(myCanonicalId)) {
        queryUuids.add(myCanonicalId);
      }
      if (queryUuids.isEmpty) {
        queryUuids.add(SupabaseService.toUuid(userId));
      }

      final filterList = <String>[];
      for (final a in queryUuids) {
        filterList.add('sender_id.eq.$a');
        filterList.add('receiver_id.eq.$a');
      }
      final orFilter = filterList.join(',');

      final rows = await _client
          .from('direct_messages')
          .select()
          .or(orFilter)
          .order('created_at', ascending: false)
          .limit(300);

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

        // Ensure otherRawId is not current user
        if (myAliases.any((a) => a.toLowerCase() == otherRawId.toLowerCase())) {
          continue;
        }

        final lastMsg = msgs.first;
        final lastText = (lastMsg['message'] ?? '').toString();
        final lastType = (lastMsg['message_type'] ?? 'text').toString();
        final lastTimeUtc = parseToUtc(lastMsg['created_at']);
        final lastTime = (lastTimeUtc ?? DateTime.now().toUtc()).toLocal();

        int unread = 0;
        DateTime? latestPartnerMsgUtc;
        for (final m in msgs) {
          final s = (m['sender_id'] ?? '').toString();
          final isFromPartner =
              !myAliases.any((a) => a.toLowerCase() == s.toLowerCase());
          if (isFromPartner) {
            latestPartnerMsgUtc ??= parseToUtc(m['created_at']);
            final isRead = m['is_read'] == true;
            if (!isRead) {
              unread++;
            }
          }
        }

        String name = 'Gamer';
        String username = '';
        String photo = '';
        String gameTag = 'PUBG';
        String gameId = '';
        bool verified = false;
        bool isOnline = false;
        DateTime? lastSeenUtc;
        String canonicalOtherId = otherRawId;

        // Safe profile lookup without crashing on non-UUID
        try {
          Map<String, dynamic>? userRow;
          final isUuid = _uuidRegex.hasMatch(otherRawId);
          if (isUuid) {
            try {
              userRow = await _client
                  .from('users')
                  .select()
                  .eq('id', otherRawId)
                  .maybeSingle();
            } catch (_) {}
          }
          if (userRow == null) {
            try {
              userRow = await _client
                  .from('users')
                  .select()
                  .eq('uid', otherRawId)
                  .maybeSingle();
            } catch (_) {}
          }

          if (userRow != null) {
            username = (userRow['username'] ?? '').toString().trim();
            final rawDisplayName =
                (userRow['display_name'] ?? userRow['displayName'] ?? '').toString().trim();
            name = rawDisplayName.isNotEmpty
                ? rawDisplayName
                : (username.isNotEmpty ? username : 'Gamer');
            photo = (userRow['avatar_url'] ?? userRow['photoUrl'] ?? '').toString();
            verified = userRow['is_verified'] == true;
            canonicalOtherId =
                (userRow['id'] ?? userRow['uid'] ?? otherRawId).toString();
            gameId = (userRow['game_id'] ?? userRow['gameId'] ?? '').toString().trim();

            final rawGame = (userRow['primary_game'] ??
                    userRow['selected_game'] ??
                    userRow['favorite_game'] ??
                    userRow['game_name'] ??
                    userRow['game'] ??
                    '')
                .toString()
                .trim();
            if (rawGame.isNotEmpty) {
              gameTag = rawGame.toUpperCase().contains('PUBG') ? 'PUBG' : rawGame;
            }

            isOnline = evaluateOnlineStatus(
              userRow,
              latestActivityUtc: latestPartnerMsgUtc,
            );
            lastSeenUtc = parseToUtc(userRow['last_seen'] ?? userRow['lastSeen']) ??
                parseToUtc(userRow['updated_at'] ?? userRow['updatedAt']) ??
                latestPartnerMsgUtc;
          } else {
            isOnline = isTimestampRecentlyActive(latestPartnerMsgUtc);
            lastSeenUtc = latestPartnerMsgUtc;
          }
        } catch (_) {}

        // Double check not adding myself
        if (myAliases.any((a) => a.toLowerCase() == canonicalOtherId.toLowerCase())) {
          continue;
        }

        conversations.add(ChatConversation(
          otherUserId: canonicalOtherId,
          otherUserName: name,
          otherUsername: username,
          otherUserPhoto: photo,
          otherUserGame: gameTag,
          otherUserGameId: gameId,
          lastMessage: lastType == 'image' ? '📷 Photo' : lastText,
          lastMessageType: lastType,
          lastMessageTime: lastTime,
          unreadCount: unread,
          isVerified: verified,
          isOnline: isOnline,
          lastSeen: lastSeenUtc,
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
      unawaited(updateUserPresence(userId: currentUserId));

      final myAliases = await getUserAliases(currentUserId);
      final otherAliases = await getUserAliases(otherUserId);
      final myUuids = myAliases.where((a) => _uuidRegex.hasMatch(a)).toSet();
      final otherUuids = otherAliases.where((a) => _uuidRegex.hasMatch(a)).toSet();

      final myCanonical = await resolveToTableId(currentUserId);
      final otherCanonical = await resolveToTableId(otherUserId);
      if (myCanonical.isNotEmpty && _uuidRegex.hasMatch(myCanonical)) myUuids.add(myCanonical);
      if (otherCanonical.isNotEmpty && _uuidRegex.hasMatch(otherCanonical)) otherUuids.add(otherCanonical);

      for (final myId in myUuids) {
        for (final otherId in otherUuids) {
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
      final myCanonical = await resolveToTableId(userId);
      final myUuids = myAliases.where((a) => _uuidRegex.hasMatch(a)).toSet();
      if (myCanonical.isNotEmpty && _uuidRegex.hasMatch(myCanonical)) {
        myUuids.add(myCanonical);
      }
      if (myUuids.isEmpty) {
        myUuids.add(SupabaseService.toUuid(userId));
      }
      final filterList = myUuids.map((a) => 'receiver_id.eq.$a').join(',');

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
  Stream<int> getUnreadCountStream(String userId) =>
      _getUnreadCountStreamInternal(userId).asBroadcastStream();

  Stream<int> _getUnreadCountStreamInternal(String userId) async* {
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