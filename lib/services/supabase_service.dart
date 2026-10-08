import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://dxdkitnroypbblazblja.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_gL8ImGd6TS-gdPOr92leHQ_Cwjiw25Y';

  static final SupabaseClient _fallbackClient = SupabaseClient(supabaseUrl, supabaseAnonKey);

  static SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return _fallbackClient;
    }
  }
  static SupabaseClient get _supabase => client;

  static String toUuid(String id) {
    final clean = id.trim();
    if (clean.isEmpty) return '00000000-0000-0000-0000-000000000000';
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(clean)) return clean.toLowerCase();
    final bytes = md5.convert(utf8.encode(clean)).bytes;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static Future<void> init() async {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    } catch (e) {
      debugPrint('Supabase initialize warning: $e');
    }
  }

  static const String bucketAvatars = 'avatars';
  static const String bucketCovers = 'covers';
  static const String bucketPosts = 'posts';
  static const String bucketTeamLogos = 'team-logos';
  static const String bucketScreenshots = 'screenshots';
  static const String bucketUploads = 'posts';
  static const String bucketMatchProofs = 'screenshots';

  static final Map<String, String> _headers = {
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer $supabaseAnonKey',
  };

  // STORAGE
  static Future<String?> uploadFile({
    required File file,
    String? folder,
    String bucket = bucketUploads,
    String? customFileName,
  }) async {
    try {
      if (!await file.exists()) return null;
      final fileBytes = await file.readAsBytes();
      final extension = file.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = customFileName ?? 'file_${timestamp}_${fileBytes.length}.$extension';
      final path = folder != null && folder.isNotEmpty ? '$folder/$fileName' : fileName;
      final uploadUri = Uri.parse('$supabaseUrl/storage/v1/object/$bucket/$path');
      final response = await http.post(
        uploadUri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': mimeType,
          'x-upsert': 'true',
        },
        body: fileBytes,
      ).timeout(const Duration(seconds: 45));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final publicUrl = '$supabaseUrl/storage/v1/object/public/$bucket/$path';
        return publicUrl;
      } else {
        if (bucket != bucketUploads) {
          final fallbackUri = Uri.parse('$supabaseUrl/storage/v1/object/$bucketUploads/$path');
          final fallbackResp = await http.post(
            fallbackUri,
            headers: {
              'apikey': supabaseAnonKey,
              'Authorization': 'Bearer $supabaseAnonKey',
              'Content-Type': mimeType,
              'x-upsert': 'true',
            },
            body: fileBytes,
          );
          if (fallbackResp.statusCode == 200 || fallbackResp.statusCode == 201) {
            final publicUrl = '$supabaseUrl/storage/v1/object/public/$bucketUploads/$path';
            return publicUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('upload error: $e');
    }
    return null;
  }

  static String _getMimeType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'image/jpeg';
    }
  }

  // AUTH
  static Future<Map<String, dynamic>?> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? userMetadata,
  }) async {
    try {
      final uri = Uri.parse('$supabaseUrl/auth/v1/signup');
      final body = {
        'email': email.trim(),
        'password': password,
        if (userMetadata != null) 'data': userMetadata,
      };
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _saveAuthToken(data);
        return data;
      } else {
        return {'error': data['error_description'] ?? data['msg'] ?? 'Sign up failed'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password');
      final body = {'email': email.trim(), 'password': password};
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await _saveAuthToken(data);
        return data;
      } else {
        return {'error': data['error_description'] ?? data['msg'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('supabase_access_token');
    if (token != null) {
      try {
        final uri = Uri.parse('$supabaseUrl/auth/v1/logout');
        await http.post(uri, headers: {..._headers, 'Authorization': 'Bearer $token'});
      } catch (e) {}
    }
    await prefs.remove('supabase_access_token');
    await prefs.remove('supabase_user_id');
  }

  static Future<void> _saveAuthToken(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['access_token'] != null) {
      await prefs.setString('supabase_access_token', data['access_token'].toString());
    }
    if (data['user'] != null && data['user']['id'] != null) {
      await prefs.setString('supabase_user_id', data['user']['id'].toString());
    }
  }

  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('supabase_user_id');
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('supabase_access_token');
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) {
      return {'apikey': supabaseAnonKey, 'Authorization': 'Bearer $token'};
    }
    return Map<String, String>.from(_headers);
  }

  // CRUD
  static Future<bool> insert(String table, Map<String, dynamic> row) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/$table');
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'return=representation'},
        body: jsonEncode(row),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> update(
    String table,
    Map<String, dynamic> row, [
    String? column,
    String? value,
    Map<String, String>? filters,
  ]) async {
    try {
      String queryParams = '';
      if (column != null && value != null) {
        queryParams = '$column=eq.$value';
      } else if (filters != null && filters.isNotEmpty) {
        queryParams = filters.entries.map((e) => '${e.key}=${e.value}').join('&');
      }
      final uri = Uri.parse('$supabaseUrl/rest/v1/$table?$queryParams');
      final response = await http.patch(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'return=representation'},
        body: jsonEncode(row),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> query(
    String table, {
    String select = '*',
    String? order,
    int? limit,
    Map<String, String>? filters,
  }) async {
    try {
      var queryParams = 'select=$select';
      if (order != null) queryParams += '&order=$order';
      if (limit != null) queryParams += '&limit=$limit';
      if (filters != null) {
        filters.forEach((k, v) {
          queryParams += '&$k=$v';
        });
      }
      final uri = Uri.parse('$supabaseUrl/rest/v1/$table?$queryParams');
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {}
    return [];
  }

  static Future<bool> delete(
    String table, [
    String? column,
    String? value,
    Map<String, String>? filters,
  ]) async {
    try {
      String queryParams = '';
      if (column != null && value != null) {
        queryParams = '$column=eq.$value';
      } else if (filters != null && filters.isNotEmpty) {
        queryParams = filters.entries.map((e) => '${e.key}=${e.value}').join('&');
      }
      final uri = Uri.parse('$supabaseUrl/rest/v1/$table?$queryParams');
      final response = await http.delete(uri, headers: _headers);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  // USERS
  static Future<bool> upsertUser(Map<String, dynamic> userData) async {
    try {
      final headers = await getAuthHeaders();
      final uri = Uri.parse('$supabaseUrl/rest/v1/users');
      final response = await http.post(
        uri,
        headers: {...headers, 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: jsonEncode(userData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getUser(String uid) async {
    final list = await query('users', filters: {'uid': 'eq.$uid'}, limit: 1);
    if (list.isNotEmpty) return list.first;
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(uid)) {
      final listById = await query('users', filters: {'id': 'eq.$uid'}, limit: 1);
      if (listById.isNotEmpty) return listById.first;
    }
    return null;
  }

  // POSTS
  static Future<Map<String, dynamic>?> savePost(Map<String, dynamic> postData) async {
    try {
      String? userId = postData['user_id']?.toString();
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (userId == null || !uuidRegex.hasMatch(userId)) {
        final currentSbId = await getCurrentUserId();
        if (currentSbId != null && uuidRegex.hasMatch(currentSbId)) {
          userId = currentSbId;
        } else {
          return null;
        }
      }
      final response = await _supabase.from('posts').insert({
        'user_id': userId,
        'content': postData['content'],
        'image_url': postData['image_url'],
        'video_url': postData['video_url'],
        'game': postData['game'] ?? 'All Games',
        'media_url': postData['media_url'] ?? postData['image_url'] ?? postData['video_url'],
        'likes_count': 0,
        'comments_count': 0,
      }).select().single();
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getPosts({int limit = 50, String? gameFilter}) async {
    final Map<String, String> filters = {};
    if (gameFilter != null && gameFilter != 'All' && gameFilter != 'All Games') {
      filters['game'] = 'eq.$gameFilter';
    }
    return await query('posts', filters: filters.isNotEmpty ? filters : null, order: 'created_at.desc', limit: limit);
  }

  // LIKES
  static Future<bool> toggleLike({required String postId, required String userId, String? username}) async {
    try {
      final existing = await query('likes', filters: {'post_id': 'eq.$postId', 'user_id': 'eq.$userId'}, limit: 1);
      if (existing.isNotEmpty) {
        final delUri = Uri.parse('$supabaseUrl/rest/v1/likes?post_id=eq.$postId&user_id=eq.$userId');
        await http.delete(delUri, headers: _headers);
        return false;
      } else {
        await insert('likes', {
          'post_id': postId,
          'user_id': userId,
          if (username != null) 'username': username,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isPostLiked(String postId, String userId) async {
    final existing = await query('likes', filters: {'post_id': 'eq.$postId', 'user_id': 'eq.$userId'}, limit: 1);
    return existing.isNotEmpty;
  }

  // COMMENTS
  static Future<bool> addComment({
    required String postId,
    required String userId,
    required String username,
    String? userAvatar,
    required String content,
  }) async {
    return await insert('comments', {
      'comment_id': 'c_${DateTime.now().millisecondsSinceEpoch}',
      'post_id': postId,
      'user_id': userId,
      'username': username,
      'user_avatar': userAvatar ?? '',
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    return await query('comments', filters: {'post_id': 'eq.$postId'}, order: 'created_at.asc');
  }

  // TEAMS
  static Future<bool> saveTeam(Map<String, dynamic> teamData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/teams');
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: jsonEncode(teamData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getTeams({String? gameFilter}) async {
    final Map<String, String> filters = {};
    if (gameFilter != null && gameFilter != 'All') {
      filters['game'] = 'eq.$gameFilter';
    }
    return await query('teams', filters: filters.isNotEmpty ? filters : null, order: 'created_at.desc');
  }

  static Future<Map<String, dynamic>?> getTeam(String teamId) async {
    final list = await query('teams', filters: {'team_id': 'eq.$teamId'}, limit: 1);
    return list.isNotEmpty ? list.first : null;
  }

  // TEAM MEMBERS
  static Future<bool> addTeamMember({
    required String teamId,
    required String userId,
    required String username,
    String role = 'Member',
  }) async {
    return await insert('team_members', {
      'team_id': teamId,
      'user_id': userId,
      'username': username,
      'role': role,
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<bool> removeTeamMember(String teamId, String userId) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/team_members?team_id=eq.$teamId&user_id=eq.$userId');
      final resp = await http.delete(uri, headers: _headers);
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
    return await query('team_members', filters: {'team_id': 'eq.$teamId'}, order: 'joined_at.asc');
  }

  // TEAM JOIN REQUESTS
  static Future<bool> createTeamJoinRequest({
    required String teamId,
    String? teamName,
    required String userId,
    required String username,
    String? userAvatar,
  }) async {
    final tUuid = toUuid(teamId);
    final effectiveSupabaseUid = client.auth.currentUser?.id ?? toUuid(userId);
    try {
      await client.from('team_join_requests').insert({
        'team_id': tUuid,
        'user_id': effectiveSupabaseUid,
        'status': 'pending',
      });
      return true;
    } catch (e) {}
    return await insert('team_join_requests', {
      'team_id': tUuid,
      'user_id': effectiveSupabaseUid,
      'status': 'pending',
    });
  }

  static Future<bool> updateTeamJoinRequestStatus(String teamId, String userId, String status) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/team_join_requests?team_id=eq.$teamId&user_id=eq.$userId');
      final resp = await http.patch(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getTeamJoinRequests(String teamId) async {
    return await query('team_join_requests', filters: {'team_id': 'eq.$teamId', 'status': 'eq.pending'});
  }

  // TEAM MATCHES
  static Future<bool> upsertTeamMatch(Map<String, dynamic> matchData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/team_matches');
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: jsonEncode(matchData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getTeamMatches({String? status}) async {
    final Map<String, String> filters = {};
    if (status != null && status != 'All') {
      filters['status'] = 'eq.$status';
    }
    return await query('team_matches', filters: filters.isNotEmpty ? filters : null, order: 'match_time.desc');
  }

  static Future<Map<String, dynamic>?> getTeamMatch(String matchId) async {
    final list = await query('team_matches', filters: {'match_id': 'eq.$matchId'}, limit: 1);
    return list.isNotEmpty ? list.first : null;
  }

  // MATCH CHAT
  static Future<bool> sendMatchChatMessage({
    required String matchId,
    String? roomId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String message,
    String? imageUrl,
    String messageType = 'text',
  }) async {
    return await insert('match_chat', {
      'match_id': matchId,
      if (roomId != null) 'room_id': roomId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar ?? '',
      'message': message,
      if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      'message_type': messageType,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getMatchChat(String matchId, {int limit = 50}) async {
    return await query('match_chat', filters: {'match_id': 'eq.$matchId'}, order: 'created_at.asc', limit: limit);
  }

  // ROOMS
  static Future<bool> saveRoom(Map<String, dynamic> roomData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/rooms');
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: jsonEncode(roomData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getRooms({String? status, String? gameFilter}) async {
    final Map<String, String> filters = {};
    if (status != null && status != 'All') {
      filters['status'] = 'eq.$status';
    }
    if (gameFilter != null && gameFilter != 'All') {
      filters['game'] = 'eq.$gameFilter';
    }
    return await query('rooms', filters: filters.isNotEmpty ? filters : null, order: 'created_at.desc');
  }

  // ROOM MEMBERS
  static Future<bool> addRoomMember(Map<String, dynamic> memberData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/room_members');
      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: jsonEncode(memberData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getRoomMembers(String roomId) async {
    return await query('room_members', filters: {'room_id': 'eq.$roomId'}, order: 'joined_at.asc');
  }

  // COIN TRANSACTIONS
  static Future<bool> recordCoinTransaction({
    required String userId,
    required int amount,
    required String type,
    String? description,
    int? balanceAfter,
    String? referenceId,
  }) async {
    return await insert('coin_transactions', {
      'user_id': userId,
      'amount': amount,
      'type': type,
      'description': description ?? '',
      if (balanceAfter != null) 'balance_after': balanceAfter,
      if (referenceId != null) 'reference_id': referenceId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getUserCoinTransactions(String userId, {int limit = 50}) async {
    return await query('coin_transactions', filters: {'user_id': 'eq.$userId'}, order: 'created_at.desc', limit: limit);
  }

  // NOTIFICATIONS
  static Future<bool> sendNotification(Map<String, dynamic> notifData) async {
    return await insert('notifications', {
      'user_id': notifData['userId'] ?? notifData['recipientUid'] ?? '',
      'title': notifData['title'] ?? '',
      'body': notifData['body'] ?? notifData['message'] ?? '',
      'type': notifData['type'] ?? 'general',
      if (notifData['data'] != null) 'data': notifData['data'],
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getUserNotifications(String userId, {int limit = 50}) async {
    return await query('notifications', filters: {'user_id': 'eq.$userId'}, order: 'created_at.desc', limit: limit);
  }

  // REALTIME STREAMS
  static Stream<List<Map<String, dynamic>>> getMatchChatStream(String matchId) async* {
    while (true) {
      final messages = await query(
        'match_chat',
        filters: {'match_id': 'eq.$matchId'},
        order: 'created_at.asc',
        limit: 50,
      );
      yield messages;
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  static Stream<List<Map<String, dynamic>>> getChatMessagesStream(String roomId) => getMatchChatStream(roomId);

  static Stream<Map<String, dynamic>?> getTeamMatchStream(String matchId) async* {
    while (true) {
      final matches = await query(
        'team_matches',
        filters: {'match_id': 'eq.$matchId'},
        limit: 1,
      );
      yield matches.isNotEmpty ? matches.first : null;
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  // ============================================================
  // ADMIN METHODS (NEW - 100% Supabase)
  // ============================================================

  /// Check if a user is admin
  static Future<bool> isAdmin(String userId) async {
    try {
      final user = await query('users', filters: {'id': 'eq.$userId'}, limit: 1);
      if (user.isEmpty) return false;
      final data = user.first;
      return data['is_admin'] == true || data['isAdmin'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Check current logged in user is admin
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;
      return await isAdmin(userId);
    } catch (e) {
      return false;
    }
  }

  /// Get admin stats for dashboard
  static Future<Map<String, int>> getAdminStats() async {
    int totalUsers = 0;
    int totalPosts = 0;
    int totalReports = 0;
    int totalCoins = 0;

    try {
      final users = await query('users', select: 'id,coins', limit: 1000);
      totalUsers = users.length;
      for (final u in users) {
        totalCoins += (u['coins'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {}

    try {
      final posts = await query('posts', select: 'id', limit: 1000);
      totalPosts = posts.length;
    } catch (e) {}

    try {
      final reports = await query('reports', select: 'id', limit: 1000);
      totalReports = reports.length;
    } catch (e) {}

    return {
      'totalUsers': totalUsers,
      'totalPosts': totalPosts,
      'totalReports': totalReports,
      'totalCoins': totalCoins,
    };
  }

  /// Get all reports
  static Future<List<Map<String, dynamic>>> getReports() async {
    return await query('reports', order: 'created_at.desc', limit: 100);
  }

  /// Update a report status
  static Future<bool> updateReport({
    required String reportId,
    required String status,
  }) async {
    return await update('reports', {'status': status}, 'id', reportId);
  }

  /// Delete a report
  static Future<bool> deleteReport(String reportId) async {
    return await delete('reports', 'id', reportId);
  }

  /// Ban a user
  static Future<bool> banUser({
    required String userId,
    required String adminId,
    String? reason,
  }) async {
    return await update('users', {
      'is_banned': true,
      'banned_at': DateTime.now().toIso8601String(),
      'banned_by': adminId,
      'banned_reason': reason ?? 'Violating community guidelines',
      'updated_at': DateTime.now().toIso8601String(),
    }, 'id', userId);
  }

  /// Unban a user
  static Future<bool> unbanUser(String userId) async {
    return await update('users', {
      'is_banned': false,
      'banned_at': null,
      'banned_reason': null,
      'banned_by': null,
      'updated_at': DateTime.now().toIso8601String(),
    }, 'id', userId);
  }

  /// Approve blue tick
  static Future<bool> approveBlueTick(String userId) async {
    return await update('users', {
      'is_blue_tick_verified': true,
      'blue_tick_status': 'approved',
      'is_verified_blue': true,
      'is_verified': true,
      'verification_status': 'verified',
      'updated_at': DateTime.now().toIso8601String(),
    }, 'id', userId);
  }

  /// Reject blue tick
  static Future<bool> rejectBlueTick(String userId) async {
    return await update('users', {
      'is_blue_tick_verified': false,
      'blue_tick_status': 'rejected',
      'is_verified_blue': false,
      'verification_status': 'rejected',
      'updated_at': DateTime.now().toIso8601String(),
    }, 'id', userId);
  }

  /// Approve rank verification
  static Future<bool> approveRank({
    required String userId,
    required String rank,
    required String gameName,
    required String adminName,
  }) async {
    return await update('users', {
      'rank': rank,
      'tier': rank,
      'selected_game': gameName,
      'selected_rank': rank,
      'is_rank_verified': true,
      'rank_status': 'Verified',
      'rank_verified_by': adminName,
      'rank_reject_reason': '',
      'updated_at': DateTime.now().toIso8601String(),
    }, 'id', userId);
  }

  /// Reject rank verification
  static Future<bool> rejectRank({
    required String userId,
    required String reason,
    required String adminName,
  }) async {
    return await update('users', {
      'is_rank_verified': false,
      'rank_status': 'Rejected',
      'rank_reject_reason': reason,
      'rank_verified_by': adminName,
      'updated_at': DateTime.now().toIso8601String(),
    }, 'id', userId);
  }

  /// Delete a post (admin)
  static Future<bool> deletePost(String postId) async {
    return await delete('posts', 'id', postId);
  }

  /// Award coins to user
  static Future<bool> awardCoins({
    required String userId,
    required int amount,
    required String adminId,
    String? adminEmail,
  }) async {
    try {
      // Get current coins
      final users = await query('users', select: 'coins', filters: {'id': 'eq.$userId'}, limit: 1);
      int currentCoins = 0;
      if (users.isNotEmpty) {
        currentCoins = (users.first['coins'] as num?)?.toInt() ?? 0;
      }
      final newTotal = currentCoins + amount;

      // Update user
      final ok = await update('users', {
        'coins': newTotal,
        'updated_at': DateTime.now().toIso8601String(),
      }, 'id', userId);

      if (ok) {
        // Record transaction
        await recordCoinTransaction(
          userId: userId,
          amount: amount,
          type: 'admin_grant',
          description: 'Admin ne $amount coins diye',
          balanceAfter: newTotal,
        );
      }
      return ok;
    } catch (e) {
      return false;
    }
  }

  /// Get pending proofs for admin review
  static Future<List<Map<String, dynamic>>> getPendingProofs() async {
    return await query(
      'active_matches',
      filters: {'status': 'eq.under_review'},
      order: 'created_at.desc',
      limit: 50,
    );
  }

  /// Approve a match proof
  static Future<bool> approveProof({
    required String matchId,
    required String winnerTeamId,
  }) async {
    return await update('active_matches', {
      'proof_status': 'accepted',
      'status': 'completed',
      'winner_team_id': winnerTeamId,
    }, 'id', matchId);
  }

  /// Reject a match proof
  static Future<bool> rejectProof({
    required String matchId,
    required String reason,
  }) async {
    return await update('active_matches', {
      'status': 'rejected',
      'proof_status': 'rejected',
      'admin_note': reason,
    }, 'id', matchId);
  }

  // REALTIME STREAMS FOR ADMIN
  static Stream<List<Map<String, dynamic>>> getRealtimeUsers() {
    try {
      return client.from('users').stream(primaryKey: ['id']).map((rows) {
        return rows.map((r) => Map<String, dynamic>.from(r)).toList();
      });
    } catch (e) {
      return Stream.value([]);
    }
  }

  static Stream<List<Map<String, dynamic>>> getRealtimePosts() {
    try {
      return client
          .from('posts')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) {
        return rows.map((r) => Map<String, dynamic>.from(r)).toList();
      });
    } catch (e) {
      return Stream.value([]);
    }
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeReports() {
    try {
      return client
          .from('reports')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) {
        return rows.map((r) => Map<String, dynamic>.from(r)).toList();
      });
    } catch (e) {
      return Stream.value([]);
    }
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeCoinTransactions() {
    try {
      return client
          .from('coin_transactions')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) {
        return rows.map((r) => Map<String, dynamic>.from(r)).toList();
      });
    } catch (e) {
      return Stream.value([]);
    }
  }

  static Stream<List<Map<String, dynamic>>> getRealtimeNotifications() {
    try {
      return client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) {
        return rows.map((r) => Map<String, dynamic>.from(r)).toList();
      });
    } catch (e) {
      return Stream.value([]);
    }
  }
}