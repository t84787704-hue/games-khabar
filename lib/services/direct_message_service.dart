// ===============================================================================
// DIRECT MESSAGE SERVICE — User Resolution, Presence Heartbeat, Search & Chat
// File: lib/services/direct_message_service.dart
// ===============================================================================

import 'dart:async';
import 'dart:io';
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

  /// Reactive unread direct message count notifier observed by the bottom navigation Messages tab.
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  static final RegExp _uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// Window in minutes within which a user's `last_seen` UTC timestamp is considered Online.
  static const int onlineWindowMinutes = 5;

  /// Normalizes any avatar URL, preset string, data URI, or relative Supabase storage path.
  static String normalizeAvatarUrl(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    if (lower == 'null' || lower == 'undefined' || lower == 'none') {
      return '';
    }
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('preset:') ||
        lower.startsWith('data:image')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    if (trimmed.startsWith('/storage/v1/object/public/')) {
      return '${SupabaseService.supabaseUrl}$trimmed';
    }
    if (trimmed.startsWith('storage/v1/object/public/')) {
      return '${SupabaseService.supabaseUrl}/$trimmed';
    }
    var cleanPath = trimmed.replaceFirst(RegExp(r'^/+'), '');
    if (cleanPath.startsWith('avatars/')) {
      cleanPath = cleanPath.substring('avatars/'.length);
    }
    try {
      return SupabaseService.client.storage
          .from(SupabaseService.bucketAvatars)
          .getPublicUrl(cleanPath);
    } catch (_) {
      return trimmed;
    }
  }

  /// Extracts the first valid non-empty avatar URL from a `users` or `profiles` row.
  static String extractAvatarFromMap(Map<String, dynamic>? row) {
    if (row == null) return '';
    const avatarKeys = [
      'avatar_url',
      'avatar',
      'photoUrl',
      'photo_url',
      'user_avatar',
      'profile_pic',
      'profile_image',
      'profile_photo',
      'image_url',
      'picture',
    ];
    for (final key in avatarKeys) {
      final normalized = normalizeAvatarUrl(row[key]?.toString());
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    for (final metaKey in ['user_metadata', 'raw_user_meta_data']) {
      final meta = row[metaKey];
      if (meta is Map) {
        for (final key in avatarKeys) {
          final normalized = normalizeAvatarUrl(meta[key]?.toString());
          if (normalized.isNotEmpty) {
            return normalized;
          }
        }
      }
    }
    return '';
  }

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

    String photo = extractAvatarFromMap(userRow);

    // Fallback or avatar enrichment from `profiles` table
    if (userRow == null || photo.isEmpty) {
      for (final candidate in lookupIds) {
        final isUuid = _uuidRegex.hasMatch(candidate);
        if (isUuid) {
          try {
            final profRow = await _client
                .from('profiles')
                .select()
                .eq('id', candidate)
                .maybeSingle();
            if (profRow != null) {
              userRow ??= profRow;
              if (photo.isEmpty) {
                photo = extractAvatarFromMap(profRow);
              }
            }
          } catch (_) {}
        }
        if (userRow != null && photo.isNotEmpty) break;
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
      'photo': photo,
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
        final extractedPhoto = extractAvatarFromMap(row);
        var normalizedUser = rowId.isNotEmpty && user.uid != rowId
            ? user.copyWith(uid: rowId)
            : user;
        if (extractedPhoto.isNotEmpty && normalizedUser.photoUrl != extractedPhoto) {
          normalizedUser = normalizedUser.copyWith(photoUrl: extractedPhoto);
        }

        final key = canonicalId.toLowerCase();
        final existing = matchedById[key];
        if (existing != null) {
          matchedById[key] = existing.copyWith(
            photoUrl: existing.photoUrl.isNotEmpty
                ? existing.photoUrl
                : normalizedUser.photoUrl,
            displayName: existing.displayName.isNotEmpty
                ? existing.displayName
                : normalizedUser.displayName,
            username: existing.username.isNotEmpty
                ? existing.username
                : normalizedUser.username,
          );
        } else {
          matchedById[key] = normalizedUser;
        }
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

  /// Holds the most recent human-readable error message when sending a direct message fails.
  String? lastSendErrorMessage;

  /// Resolves any user identifier (auth.uid, users.uid, users.id, profiles.id, or username)
  /// to the canonical UUID `id` from the `users` or `profiles` table.
  Future<String> resolveToTableId(String idOrUid) async {
    final clean = idOrUid.trim();
    if (clean.isEmpty) return '';
    if (_resolvedUuidCache.containsKey(clean)) {
      return _resolvedUuidCache[clean]!;
    }

    final isUuid = _uuidRegex.hasMatch(clean);

    try {
      Map<String, dynamic>? row;
      // 1. If clean matches UUID format, check `users` primary key `id` first
      if (isUuid) {
        try {
          row = await _client
              .from('users')
              .select('id, uid')
              .eq('id', clean)
              .maybeSingle();
        } catch (_) {}
      }

      // 2. If not found by `id`, check `users` by `uid` (text column)
      if (row == null) {
        try {
          row = await _client
              .from('users')
              .select('id, uid')
              .eq('uid', clean)
              .maybeSingle();
        } catch (_) {}
      }

      // 3. If not found in `users`, check `profiles` by `id` (or `username` if non-UUID)
      if (row == null) {
        if (isUuid) {
          try {
            final profRow = await _client
                .from('profiles')
                .select()
                .eq('id', clean)
                .maybeSingle();
            if (profRow != null && profRow['id'] != null) {
              row = Map<String, dynamic>.from(profRow);
              // Automatically link/sync this unlinked profile into `public.users`
              unawaited(_syncProfileRowToUsersTable(row));
            }
          } catch (_) {}
        } else {
          try {
            final profRow = await _client
                .from('profiles')
                .select()
                .or('username.ilike.$clean,display_name.ilike.$clean')
                .limit(1)
                .maybeSingle();
            if (profRow != null && profRow['id'] != null) {
              row = Map<String, dynamic>.from(profRow);
              unawaited(_syncProfileRowToUsersTable(row));
            }
          } catch (_) {}
        }
      }

      // 4. Return canonical UUID `id` from table
      if (row != null && row['id'] != null) {
        final tableId = row['id'].toString().trim();
        if (tableId.isNotEmpty) {
          _resolvedUuidCache[clean] = tableId;
          _resolvedUuidCache[tableId] = tableId;
          if (row['uid'] != null && row['uid'].toString().trim().isNotEmpty) {
            _resolvedUuidCache[row['uid'].toString().trim()] = tableId;
          }
          return tableId;
        }
      }
    } catch (e) {
      debugPrint('[DMS] resolveToTableId error: $e');
    }

    // 5. Fallback: if already a valid UUID format, use it; else convert via toUuid
    if (isUuid) {
      final res = clean.toLowerCase();
      _resolvedUuidCache[clean] = res;
      return res;
    }
    final fallback = SupabaseService.toUuid(clean);
    _resolvedUuidCache[clean] = fallback;
    return fallback;
  }

  /// Ensures that a user who exists only in `public.profiles` (or auth) has a corresponding
  /// linked row in `public.users` so foreign-key constraints on `direct_messages` and
  /// `GamerProfileScreen` lookups never fail.
  Future<void> _syncProfileRowToUsersTable(Map<String, dynamic> profileRow) async {
    final rawId = (profileRow['id'] ?? profileRow['uid'] ?? '').toString().trim();
    if (rawId.isEmpty || !_uuidRegex.hasMatch(rawId)) return;

    try {
      final existing = await _client
          .from('users')
          .select('id')
          .eq('id', rawId)
          .maybeSingle();
      if (existing != null) return;

      final rawUsername = (profileRow['username'] ?? '').toString().trim();
      final rawDisplayName = (profileRow['display_name'] ??
              profileRow['displayName'] ??
              rawUsername)
          .toString()
          .trim();
      final shortId = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;
      final cleanUsername = rawUsername.isNotEmpty
          ? rawUsername
          : 'user_$shortId';
      final cleanDisplayName =
          rawDisplayName.isNotEmpty ? rawDisplayName : cleanUsername;
      final rawEmail = (profileRow['email'] ?? '').toString().trim();
      final fallbackEmail = rawEmail.isNotEmpty
          ? rawEmail
          : '${cleanUsername.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '')}_$shortId@gamersid.local';
      final avatarUrl = extractAvatarFromMap(profileRow);

      final payload = <String, dynamic>{
        'id': rawId,
        'uid': rawId,
        'email': fallbackEmail,
        'username': cleanUsername,
        'display_name': cleanDisplayName,
        if (avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
        'favorite_game': (profileRow['favorite_game'] ??
                profileRow['game_name'] ??
                profileRow['game'] ??
                'BGMI')
            .toString(),
        'selected_rank':
            (profileRow['selected_rank'] ?? profileRow['rank'] ?? 'Bronze')
                .toString(),
      };

      await _client.from('users').upsert(payload, onConflict: 'id');
    } catch (e) {
      debugPrint('[DMS] _syncProfileRowToUsersTable note: $e');
    }
  }

  /// Ensures a recipient/sender user ID is present in `public.users` before inserting
  /// a direct message (hydrating from `public.profiles` if the user hasn't completed Gamer ID setup yet).
  Future<String> ensureUserRecordLinked(
    String userId, {
    String? fallbackDisplayName,
    String? fallbackPhotoUrl,
  }) async {
    final resolved = await resolveToTableId(userId);
    final candidateId = resolved.isNotEmpty ? resolved : userId.trim();
    if (candidateId.isEmpty || !_uuidRegex.hasMatch(candidateId)) {
      return candidateId;
    }

    try {
      final userRow = await _client
          .from('users')
          .select('id')
          .eq('id', candidateId)
          .maybeSingle();
      if (userRow != null) {
        return candidateId;
      }

      // Check `profiles` table for this UUID
      Map<String, dynamic>? profRow;
      try {
        profRow = await _client
            .from('profiles')
            .select()
            .eq('id', candidateId)
            .maybeSingle();
      } catch (_) {}

      if (profRow != null) {
        await _syncProfileRowToUsersTable(Map<String, dynamic>.from(profRow));
        return candidateId;
      }

      // If we have a fallback display name (e.g., from a chat header or search result), create a minimal linked row
      if (fallbackDisplayName != null && fallbackDisplayName.trim().isNotEmpty) {
        final shortId =
            candidateId.length >= 8 ? candidateId.substring(0, 8) : candidateId;
        await _syncProfileRowToUsersTable({
          'id': candidateId,
          'uid': candidateId,
          'username': 'user_$shortId',
          'display_name': fallbackDisplayName.trim(),
          if (fallbackPhotoUrl != null && fallbackPhotoUrl.trim().isNotEmpty)
            'avatar_url': fallbackPhotoUrl.trim(),
        });
      }
    } catch (e) {
      debugPrint('[DMS] ensureUserRecordLinked note: $e');
    }
    return candidateId;
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
      if (row == null && isUuid) {
        try {
          final profRow = await _client
              .from('profiles')
              .select('id')
              .eq('id', clean)
              .maybeSingle();
          if (profRow != null && profRow['id'] != null) {
            row = {'id': profRow['id'], 'uid': profRow['id']};
          }
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

  /// Uploads a chat image file to Supabase Storage and returns its public URL.
  Future<String?> uploadChatImage({
    required File file,
    required String senderId,
  }) async {
    try {
      if (!await file.exists()) return null;
      final cleanSender = senderId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      final folder = cleanSender.isNotEmpty ? 'chat_images/$cleanSender' : 'chat_images';

      // 1. Primary upload to `posts` bucket (public media bucket)
      final url = await SupabaseService.uploadFile(
        file: file,
        folder: folder,
        bucket: SupabaseService.bucketPosts,
      );
      if (url != null && url.trim().isNotEmpty) {
        return url.trim();
      }

      // 2. Fallback upload to `avatars` bucket
      final fallbackAvatarUrl = await SupabaseService.uploadFile(
        file: file,
        folder: folder,
        bucket: SupabaseService.bucketAvatars,
      );
      if (fallbackAvatarUrl != null && fallbackAvatarUrl.trim().isNotEmpty) {
        return fallbackAvatarUrl.trim();
      }

      // 3. Fallback upload to `screenshots` bucket
      final fallbackScreenUrl = await SupabaseService.uploadFile(
        file: file,
        folder: folder,
        bucket: SupabaseService.bucketScreenshots,
      );
      if (fallbackScreenUrl != null && fallbackScreenUrl.trim().isNotEmpty) {
        return fallbackScreenUrl.trim();
      }
    } catch (e) {
      debugPrint('[DMS] uploadChatImage error: $e');
    }
    return null;
  }

  /// Converts a raw Supabase / PostgREST exception into a clear, actionable message.
  String _describeSupabaseInsertError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('42501') || lower.contains('row-level security')) {
      return 'Session expired or unauthorized (RLS). Please sign in again.';
    }
    if (lower.contains('23503') || lower.contains('foreign key constraint')) {
      return 'Recipient profile is not linked yet. Please retry.';
    }
    if (lower.contains('22p02') || lower.contains('invalid input syntax for type uuid')) {
      return 'Invalid recipient user ID format.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('clientexception')) {
      return 'Network connection error. Check your internet and tap to retry.';
    }
    if (lower.contains('timeout')) {
      return 'Request timed out. Tap the message to retry.';
    }
    return 'Failed to send message. Tap the message to retry.';
  }

  /// Send a message, persist it to Supabase, and return the persisted ChatMessage (or null on failure).
  /// Supports optional image URL and reply-to message reference.
  Future<ChatMessage?> sendMessageReturningRecord({
    required String senderId,
    required String receiverId,
    required String message,
    String messageType = 'text',
    String? imageUrl,
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
    String? replyToImageUrl,
    String? receiverDisplayName,
    String? receiverPhotoUrl,
    DateTime? clientCreatedAt,
  }) async {
    lastSendErrorMessage = null;
    final cleanImageUrl = (imageUrl ?? '').trim();
    final cleanMessage = message.trim();
    if (senderId.trim().isEmpty ||
        receiverId.trim().isEmpty ||
        (cleanMessage.isEmpty && cleanImageUrl.isEmpty)) {
      lastSendErrorMessage = 'Missing sender or recipient ID.';
      return null;
    }

    try {
      // Prefer authenticated Supabase session user ID for sender_id so RLS `auth.uid() = sender_id` always passes
      final authUserId = _client.auth.currentUser?.id?.trim() ?? '';
      final resolvedSender = await ensureUserRecordLinked(
        authUserId.isNotEmpty ? authUserId : senderId,
      );
      final resolvedReceiver = await ensureUserRecordLinked(
        receiverId,
        fallbackDisplayName: receiverDisplayName,
        fallbackPhotoUrl: receiverPhotoUrl,
      );

      final senderUuid = (authUserId.isNotEmpty && _uuidRegex.hasMatch(authUserId))
          ? authUserId
          : resolvedSender;
      final receiverUuid = resolvedReceiver;

      if (senderUuid.isEmpty ||
          receiverUuid.isEmpty ||
          !_uuidRegex.hasMatch(senderUuid) ||
          !_uuidRegex.hasMatch(receiverUuid)) {
        lastSendErrorMessage = 'Invalid user ID for direct chat.';
        debugPrint('[DMS] Invalid senderUuid ($senderUuid) or receiverUuid ($receiverUuid)');
        return null;
      }

      // Prevent chatting with self
      if (senderUuid.toLowerCase() == receiverUuid.toLowerCase()) {
        lastSendErrorMessage = 'You cannot send a message to yourself.';
        debugPrint('[DMS] Cannot send message to self');
        return null;
      }

      final createdUtc = (clientCreatedAt ?? DateTime.now()).toUtc();
      final nowUtcIso = createdUtc.toIso8601String();
      final effectiveType = cleanImageUrl.isNotEmpty ? 'image' : messageType;
      final plainMessageText =
          cleanMessage.isNotEmpty ? cleanMessage : cleanImageUrl;

      // Encode reply/image metadata into a zero-width suffix on `message` so it persists
      // even if optional columns (`reply_to_id`, `reply_to_text`, `image_url`) aren't in the DB table
      final encodedMessageText = ChatMessage.encodeMessageWithMetadata(
        cleanMessage: plainMessageText,
        imageUrl: cleanImageUrl.isNotEmpty ? cleanImageUrl : null,
        replyToId: replyToId,
        replyToText: replyToText,
        replyToSenderId: replyToSenderId,
        replyToSenderName: replyToSenderName,
        replyToImageUrl: replyToImageUrl,
      );

      final basePayload = <String, dynamic>{
        'sender_id': senderUuid,
        'receiver_id': receiverUuid,
        'message': encodedMessageText,
        'message_type': effectiveType,
        'is_read': false,
        'created_at': nowUtcIso,
      };

      final extendedPayload = <String, dynamic>{
        ...basePayload,
        if (cleanImageUrl.isNotEmpty) 'image_url': cleanImageUrl,
        if (replyToId != null && replyToId.trim().isNotEmpty)
          'reply_to_id': replyToId.trim(),
        if (replyToText != null && replyToText.trim().isNotEmpty)
          'reply_to_text': replyToText.trim(),
        if (replyToSenderId != null && replyToSenderId.trim().isNotEmpty)
          'reply_to_sender_id': replyToSenderId.trim(),
        if (replyToSenderName != null && replyToSenderName.trim().isNotEmpty)
          'reply_to_sender_name': replyToSenderName.trim(),
        if (replyToImageUrl != null && replyToImageUrl.trim().isNotEmpty)
          'reply_to_image_url': replyToImageUrl.trim(),
      };

      Map<String, dynamic>? insertedRow;
      bool inserted = false;

      // 1. Try inserting with extended columns if any optional fields are present
      if (extendedPayload.length > basePayload.length) {
        try {
          final res = await _client
              .from('direct_messages')
              .insert(extendedPayload)
              .select()
              .maybeSingle();
          if (res != null) {
            insertedRow = Map<String, dynamic>.from(res);
          }
          inserted = true;
        } catch (_) {
          // Schema may not have optional columns; fall through
        }
      }

      // 2. If extended failed and we have an image, try with just `image_url`
      if (!inserted && cleanImageUrl.isNotEmpty) {
        final payloadWithImageCol = <String, dynamic>{
          ...basePayload,
          'image_url': cleanImageUrl,
        };
        try {
          final res = await _client
              .from('direct_messages')
              .insert(payloadWithImageCol)
              .select()
              .maybeSingle();
          if (res != null) {
            insertedRow = Map<String, dynamic>.from(res);
          }
          inserted = true;
        } catch (_) {}
      }

      // 3. Standard guaranteed insert using core columns (with embedded metadata in `message`)
      if (!inserted) {
        try {
          final res = await _client
              .from('direct_messages')
              .insert(basePayload)
              .select()
              .maybeSingle();
          if (res != null) {
            insertedRow = Map<String, dynamic>.from(res);
          }
          inserted = true;
        } catch (selectErr) {
          // Fallback if `.select()` is restricted by RLS policy on return
          try {
            await _client.from('direct_messages').insert(basePayload);
            inserted = true;
          } catch (insertErr) {
            // If foreign key constraint failed because receiver row was missing in `users`,
            // force-sync receiver to `users` and retry once
            final errStr = insertErr.toString().toLowerCase();
            if (errStr.contains('23503') || errStr.contains('foreign key')) {
              await _syncProfileRowToUsersTable({
                'id': receiverUuid,
                'uid': receiverUuid,
                'display_name': receiverDisplayName ?? 'Gamer',
                if (receiverPhotoUrl != null) 'avatar_url': receiverPhotoUrl,
              });
              await _client.from('direct_messages').insert(basePayload);
              inserted = true;
            } else {
              rethrow;
            }
          }
        }
      }

      // Immediately update sender's presence timestamp in UTC
      unawaited(updateUserPresence(userId: senderUuid, force: true));

      if (insertedRow != null) {
        var parsed = ChatMessage.fromMap(insertedRow);
        if (cleanImageUrl.isNotEmpty && !parsed.hasImage) {
          parsed = parsed.copyWith(imageUrl: cleanImageUrl);
        }
        if (replyToId != null &&
            (parsed.replyToId == null || parsed.replyToId!.isEmpty)) {
          parsed = parsed.copyWith(
            replyToId: replyToId,
            replyToText: replyToText,
            replyToSenderId: replyToSenderId,
            replyToSenderName: replyToSenderName,
            replyToImageUrl: replyToImageUrl,
          );
        }
        return parsed;
      }
      return ChatMessage(
        id: '',
        senderId: senderUuid,
        receiverId: receiverUuid,
        message: plainMessageText,
        imageUrl: cleanImageUrl.isNotEmpty ? cleanImageUrl : null,
        replyToId: replyToId,
        replyToText: replyToText,
        replyToSenderId: replyToSenderId,
        replyToSenderName: replyToSenderName,
        replyToImageUrl: replyToImageUrl,
        createdAt: createdUtc.toLocal(),
        isRead: false,
      );
    } catch (e) {
      lastSendErrorMessage = _describeSupabaseInsertError(e);
      debugPrint('[DMS] sendMessageReturningRecord error: $e');
      return null;
    }
  }

  /// Toggles or sets a user's emoji reaction on a specific message and persists it to Supabase.
  Future<Map<String, List<String>>?> toggleMessageReaction({
    required ChatMessage message,
    required String emoji,
    required String currentUserId,
  }) async {
    final msgId = message.id.trim();
    final cleanEmoji = emoji.trim();
    if (msgId.isEmpty || msgId.startsWith('temp_') || cleanEmoji.isEmpty) {
      return null;
    }

    try {
      final canonicalUserId = await resolveToTableId(currentUserId);
      final effectiveUid =
          canonicalUserId.isNotEmpty ? canonicalUserId : currentUserId.trim();
      if (effectiveUid.isEmpty) return null;

      final myAliases = await getUserAliases(effectiveUid);
      myAliases.add(effectiveUid);
      myAliases.add(effectiveUid.toLowerCase());

      // Clone current reactions map
      final updatedReactions = <String, List<String>>{};
      message.reactions.forEach((k, v) {
        updatedReactions[k] = List<String>.from(v);
      });

      final existingUsersForEmoji = updatedReactions[cleanEmoji] ?? <String>[];
      final alreadyReactedWithSame = existingUsersForEmoji.any(
        (u) => myAliases.contains(u) || myAliases.contains(u.toLowerCase()),
      );

      // Remove any existing reaction by this user across all emojis (one active reaction per user)
      for (final entry in updatedReactions.entries.toList()) {
        entry.value.removeWhere(
          (u) => myAliases.contains(u) || myAliases.contains(u.toLowerCase()),
        );
        if (entry.value.isEmpty) {
          updatedReactions.remove(entry.key);
        }
      }

      // If the user tapped a different emoji (or hadn't reacted yet), add it
      if (!alreadyReactedWithSame) {
        updatedReactions.putIfAbsent(cleanEmoji, () => []).add(effectiveUid);
      }

      final encodedMessageText = ChatMessage.encodeMessageWithMetadata(
        cleanMessage: message.message.isNotEmpty
            ? message.message
            : message.resolvedImageUrl,
        imageUrl: message.hasImage ? message.resolvedImageUrl : null,
        reactions: updatedReactions,
        replyToId: message.replyToId,
        replyToText: message.replyToText,
        replyToSenderId: message.replyToSenderId,
        replyToSenderName: message.replyToSenderName,
        replyToImageUrl: message.replyToImageUrl,
      );

      bool persisted = false;
      // 1. Try updating both native `reactions` JSONB column and `message`
      try {
        await _client
            .from('direct_messages')
            .update({
              'reactions': updatedReactions,
              'message': encodedMessageText,
            })
            .eq('id', msgId);
        persisted = true;
      } catch (_) {}

      // 2. Fallback: update `message` column with embedded metadata
      if (!persisted) {
        await _client
            .from('direct_messages')
            .update({
              'message': encodedMessageText,
            })
            .eq('id', msgId);
      }

      return updatedReactions;
    } catch (e) {
      debugPrint('[DMS] toggleMessageReaction error: $e');
      return null;
    }
  }

  /// Send a message and update the sender's `last_seen` presence timestamp in UTC.
  Future<bool> sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    String messageType = 'text',
    String? imageUrl,
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
    String? replyToImageUrl,
  }) async {
    final record = await sendMessageReturningRecord(
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      messageType: messageType,
      imageUrl: imageUrl,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSenderId: replyToSenderId,
      replyToSenderName: replyToSenderName,
      replyToImageUrl: replyToImageUrl,
    );
    return record != null;
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

      final validEntries = grouped.entries.where((entry) {
        final otherRawId = entry.key;
        return !myAliases.any((a) => a.toLowerCase() == otherRawId.toLowerCase());
      }).toList();

      final resolvedList = await Future.wait(
        validEntries.map((entry) async {
          final otherRawId = entry.key;
          final msgs = entry.value;

          final lastMsg = msgs.first;
          final parsedLastMsg = ChatMessage.fromMap(lastMsg);
          final lastText = parsedLastMsg.message;
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

          void applyProfileRow(Map<String, dynamic> row) {
            final rowId = (row['id'] ?? '').toString().trim();
            final rowUid = (row['uid'] ?? '').toString().trim();
            if (rowId.isNotEmpty &&
                (canonicalOtherId == otherRawId || !_uuidRegex.hasMatch(canonicalOtherId))) {
              canonicalOtherId = rowId;
            } else if (rowUid.isNotEmpty && canonicalOtherId.isEmpty) {
              canonicalOtherId = rowUid;
            }

            final rowUsername = (row['username'] ?? row['tag'] ?? '').toString().trim();
            if (username.isEmpty &&
                rowUsername.isNotEmpty &&
                rowUsername.toLowerCase() != 'null') {
              username = rowUsername;
            }

            final candidateNames = [
              row['display_name'],
              row['displayName'],
              row['bgmiName'],
              row['full_name'],
              row['name'],
              row['in_game_name'],
              row['inGameName'],
            ];
            for (final candidate in candidateNames) {
              final s = (candidate ?? '').toString().trim();
              if (s.isNotEmpty && s.toLowerCase() != 'null' && name == 'Gamer') {
                name = s;
                break;
              }
            }
            if (name == 'Gamer' && username.isNotEmpty) {
              name = username;
            }

            final rowPhoto = extractAvatarFromMap(row);
            if (photo.isEmpty && rowPhoto.isNotEmpty) {
              photo = rowPhoto;
            }

            if (row['is_verified'] == true ||
                row['isVerified'] == true ||
                row['isBlueTickVerified'] == true) {
              verified = true;
            }

            if (gameId.isEmpty) {
              for (final gKey in ['game_uid', 'gameUid', 'game_id', 'gameId', 'gamer_id', 'bgmiUid']) {
                final gVal = (row[gKey] ?? '').toString().trim();
                if (gVal.isNotEmpty &&
                    gVal.toLowerCase() != 'null' &&
                    gVal.toLowerCase() != 'not set' &&
                    gVal != canonicalOtherId) {
                  gameId = gVal;
                  break;
                }
              }
            }

            final rawGame = (row['primary_game'] ??
                    row['selected_game'] ??
                    row['selectedGame'] ??
                    row['favorite_game'] ??
                    row['favoriteGame'] ??
                    row['game_name'] ??
                    row['game'] ??
                    '')
                .toString()
                .trim();
            if (rawGame.isNotEmpty &&
                rawGame.toLowerCase() != 'null' &&
                gameTag == 'PUBG') {
              gameTag = rawGame.toUpperCase().contains('PUBG') ? 'PUBG' : rawGame;
            }

            if (evaluateOnlineStatus(row, latestActivityUtc: latestPartnerMsgUtc)) {
              isOnline = true;
            }
            final candidateSeen = parseToUtc(row['last_seen'] ?? row['lastSeen']) ??
                parseToUtc(row['updated_at'] ?? row['updatedAt']);
            if (candidateSeen != null &&
                (lastSeenUtc == null || candidateSeen.isAfter(lastSeenUtc!))) {
              lastSeenUtc = candidateSeen;
            }
          }

          try {
            final isUuid = _uuidRegex.hasMatch(otherRawId);
            final candidateIds = <String>{
              otherRawId,
              if (isUuid) otherRawId.toLowerCase(),
              SupabaseService.toUuid(otherRawId),
            };

            // 1. Check `users` table by `id` and `uid` (fetching multiple rows in case duplicate/synced rows exist)
            for (final candidate in candidateIds) {
              if (_uuidRegex.hasMatch(candidate)) {
                try {
                  final rowsById = await _client
                      .from('users')
                      .select()
                      .eq('id', candidate)
                      .limit(5);
                  for (final r in (rowsById as List)) {
                    if (r is Map) applyProfileRow(Map<String, dynamic>.from(r));
                  }
                } catch (_) {}
              }
              try {
                final rowsByUid = await _client
                    .from('users')
                    .select()
                    .eq('uid', candidate)
                    .limit(5);
                for (final r in (rowsByUid as List)) {
                  if (r is Map) applyProfileRow(Map<String, dynamic>.from(r));
                }
              } catch (_) {}
            }

            if (canonicalOtherId.isNotEmpty) {
              candidateIds.add(canonicalOtherId);
            }

            // 2. Check `profiles` table (`public.profiles`) for `avatar_url` and profile fields
            if (photo.isEmpty || name == 'Gamer') {
              for (final candidate in candidateIds) {
                if (_uuidRegex.hasMatch(candidate)) {
                  try {
                    final profRows = await _client
                        .from('profiles')
                        .select()
                        .eq('id', candidate)
                        .limit(5);
                    for (final r in (profRows as List)) {
                      if (r is Map) applyProfileRow(Map<String, dynamic>.from(r));
                    }
                  } catch (_) {}
                }
                if (photo.isNotEmpty && name != 'Gamer') break;
              }
            }

            // 3. If photo is still empty and we know username or display_name, check `users` and `profiles` by username/display_name
            if (photo.isEmpty && username.isNotEmpty) {
              try {
                final byUsernameRows = await _client
                    .from('users')
                    .select()
                    .ilike('username', username)
                    .limit(5);
                for (final r in (byUsernameRows as List)) {
                  if (r is Map) applyProfileRow(Map<String, dynamic>.from(r));
                }
              } catch (_) {}

              if (photo.isEmpty) {
                try {
                  final profByUsername = await _client
                      .from('profiles')
                      .select()
                      .ilike('username', username)
                      .limit(5);
                  for (final r in (profByUsername as List)) {
                    if (r is Map) applyProfileRow(Map<String, dynamic>.from(r));
                  }
                } catch (_) {}
              }
            }

            if (photo.isEmpty && name != 'Gamer') {
              try {
                final byDisplayRows = await _client
                    .from('users')
                    .select()
                    .ilike('display_name', name)
                    .limit(5);
                for (final r in (byDisplayRows as List)) {
                  if (r is Map) {
                    final map = Map<String, dynamic>.from(r);
                    final candidatePhoto = extractAvatarFromMap(map);
                    if (candidatePhoto.isNotEmpty) {
                      photo = candidatePhoto;
                      break;
                    }
                  }
                }
              } catch (_) {}
            }

            // 4. Fallback: check `posts` table (`user_avatar`) if user has posted with an avatar
            if (photo.isEmpty) {
              for (final candidate in candidateIds) {
                if (!_uuidRegex.hasMatch(candidate)) continue;
                try {
                  final postRows = await _client
                      .from('posts')
                      .select('user_avatar, display_name, username')
                      .eq('user_id', candidate)
                      .order('created_at', ascending: false)
                      .limit(5);
                  for (final r in (postRows as List)) {
                    if (r is Map) {
                      final pAvatar = normalizeAvatarUrl(r['user_avatar']?.toString());
                      if (pAvatar.isNotEmpty) {
                        photo = pAvatar;
                        break;
                      }
                    }
                  }
                } catch (_) {}
                if (photo.isNotEmpty) break;
              }
            }

            if (!isOnline && isTimestampRecentlyActive(latestPartnerMsgUtc)) {
              isOnline = true;
            }
            lastSeenUtc ??= latestPartnerMsgUtc;
          } catch (_) {}

          if (myAliases.any((a) => a.toLowerCase() == canonicalOtherId.toLowerCase())) {
            return null;
          }

          final isImageLast = lastType == 'image' ||
              (lastMsg['image_url']?.toString().trim().isNotEmpty ?? false) ||
              ChatMessage.fromMap(lastMsg).hasImage;

          return ChatConversation(
            otherUserId: canonicalOtherId,
            otherUserName: name,
            otherUsername: username,
            otherUserPhoto: photo,
            otherUserGame: gameTag,
            otherUserGameId: gameId,
            lastMessage: isImageLast ? '📷 Photo' : lastText,
            lastMessageType: isImageLast ? 'image' : lastType,
            lastMessageTime: lastTime,
            unreadCount: unread,
            isVerified: verified,
            isOnline: isOnline,
            lastSeen: lastSeenUtc,
          );
        }),
      );

      final Map<String, ChatConversation> deduplicated = {};
      for (final conv in resolvedList) {
        if (conv == null) continue;
        final key = conv.otherUserId.toLowerCase();
        final existing = deduplicated[key];
        if (existing == null) {
          deduplicated[key] = conv;
        } else {
          final isNewer = conv.lastMessageTime.isAfter(existing.lastMessageTime);
          final primary = isNewer ? conv : existing;
          final secondary = isNewer ? existing : conv;
          deduplicated[key] = ChatConversation(
            otherUserId: primary.otherUserId,
            otherUserName: primary.otherUserName != 'Gamer'
                ? primary.otherUserName
                : secondary.otherUserName,
            otherUsername: primary.otherUsername.isNotEmpty
                ? primary.otherUsername
                : secondary.otherUsername,
            otherUserPhoto: primary.otherUserPhoto.isNotEmpty
                ? primary.otherUserPhoto
                : secondary.otherUserPhoto,
            otherUserGame: primary.otherUserGame,
            otherUserGameId: primary.otherUserGameId.isNotEmpty
                ? primary.otherUserGameId
                : secondary.otherUserGameId,
            lastMessage: primary.lastMessage,
            lastMessageType: primary.lastMessageType,
            lastMessageTime: primary.lastMessageTime,
            unreadCount: primary.unreadCount + secondary.unreadCount,
            isVerified: primary.isVerified || secondary.isVerified,
            isOnline: primary.isOnline || secondary.isOnline,
            lastSeen: primary.lastSeen ?? secondary.lastSeen,
          );
        }
      }

      final List<ChatConversation> conversations = deduplicated.values.toList();
      conversations.sort((ChatConversation a, ChatConversation b) {
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });
      final totalUnreadFromList = conversations.fold<int>(
        0,
        (sum, item) => sum + item.unreadCount,
      );
      if (unreadCountNotifier.value != totalUnreadFromList) {
        unreadCountNotifier.value = totalUnreadFromList;
      }
      return conversations;
    } catch (e) {
      debugPrint('[DMS] getConversations error: $e');
      return [];
    }
  }

  /// Refreshes the global `unreadCountNotifier` for the current user.
  Future<int> refreshUnreadCount([String? userId]) async {
    final authUid = _client.auth.currentUser?.id ?? '';
    final gamerUid = GamerAuthService().currentGamer?.uid ?? '';
    final effectiveUid = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : (gamerUid.isNotEmpty ? gamerUid : authUid);
    if (effectiveUid.isEmpty) {
      if (unreadCountNotifier.value != 0) {
        unreadCountNotifier.value = 0;
      }
      return 0;
    }
    final count = await getTotalUnreadCount(effectiveUid);
    if (unreadCountNotifier.value != count) {
      unreadCountNotifier.value = count;
    }
    return count;
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
      await refreshUnreadCount(currentUserId);
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
          .select('id, sender_id')
          .or(filterList)
          .eq('is_read', false);
      int count = 0;
      for (final r in (rows as List)) {
        if (r is Map) {
          final sender = (r['sender_id'] ?? '').toString();
          if (!myAliases.any((a) => a.toLowerCase() == sender.toLowerCase())) {
            count++;
          }
        }
      }
      if (unreadCountNotifier.value != count) {
        unreadCountNotifier.value = count;
      }
      return count;
    } catch (e) {
      debugPrint('[DMS] getTotalUnreadCount error: $e');
      return unreadCountNotifier.value;
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
      await Future.delayed(const Duration(seconds: 4));
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