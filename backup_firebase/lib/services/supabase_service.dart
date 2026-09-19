import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Supabase Service for GAMERS ID NETWORK
/// Handles Supabase Storage (image/proof uploads), Auth (login/signup),
/// Database REST queries, and Realtime streaming.
class SupabaseService {
  static const String supabaseUrl = 'https://dxdkitnroypbblazblja.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_gL8ImGd6TS-gdPOr92leHQ_Cwjiw25Y';

  // Storage Buckets (matches user's Supabase buckets exactly)
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

  // --------------------------------------------------------------------------
  // 1. SUPABASE STORAGE (Upload Avatar, Match Proofs, Chat Images, Banners)
  // --------------------------------------------------------------------------

  /// Uploads a file directly to Supabase Storage and returns the public URL.
  /// Replaces Cloudinary completely.
  static Future<String?> uploadFile({
    required File file,
    String? folder,
    String bucket = bucketUploads,
    String? customFileName,
  }) async {
    try {
      if (!await file.exists()) {
        debugPrint('Supabase upload: File does not exist');
        return null;
      }

      final fileBytes = await file.readAsBytes();
      final extension = file.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = customFileName ?? 'file_${timestamp}_${fileBytes.length}.$extension';
      final path = folder != null && folder.isNotEmpty ? '$folder/$fileName' : fileName;

      // Supabase Storage REST API Upload Endpoint
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
        // Construct Public URL
        final publicUrl = '$supabaseUrl/storage/v1/object/public/$bucket/$path';
        debugPrint('✅ Supabase Storage Upload Success: $publicUrl');
        return publicUrl;
      } else {
        debugPrint('⚠️ Supabase Storage Upload Warning (${response.statusCode}): ${response.body}');
        
        // If the specified bucket returned 404 or 400, try the fallback bucket 'gamers_uploads'
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
            debugPrint('✅ Supabase Storage Fallback Upload Success: $publicUrl');
            return publicUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Supabase Storage upload error: $e');
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

  // --------------------------------------------------------------------------
  // 2. SUPABASE AUTHENTICATION (Sign Up, Sign In, Sign Out)
  // --------------------------------------------------------------------------

  /// Sign Up with Email and Password using Supabase Auth
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
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _saveAuthToken(data);
        return data;
      } else {
        debugPrint('Supabase Auth SignUp Error: ${data['error_description'] ?? data['msg'] ?? response.body}');
        return {'error': data['error_description'] ?? data['msg'] ?? 'Sign up failed'};
      }
    } catch (e) {
      debugPrint('Supabase SignUp Exception: $e');
      return {'error': e.toString()};
    }
  }

  /// Sign In with Email and Password using Supabase Auth
  static Future<Map<String, dynamic>?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password');
      final body = {
        'email': email.trim(),
        'password': password,
      };

      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await _saveAuthToken(data);
        return data;
      } else {
        debugPrint('Supabase Auth SignIn Error: ${data['error_description'] ?? data['msg'] ?? response.body}');
        return {'error': data['error_description'] ?? data['msg'] ?? 'Login failed'};
      }
    } catch (e) {
      debugPrint('Supabase SignIn Exception: $e');
      return {'error': e.toString()};
    }
  }

  /// Sign Out and clear Supabase Auth session
  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('supabase_access_token');

    if (token != null) {
      try {
        final uri = Uri.parse('$supabaseUrl/auth/v1/logout');
        await http.post(
          uri,
          headers: {
            ..._headers,
            'Authorization': 'Bearer $token',
          },
        );
      } catch (e) {
        debugPrint('Supabase SignOut error: $e');
      }
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

  /// Returns current Supabase user ID if logged in
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('supabase_user_id');
  }

  // --------------------------------------------------------------------------
  // 3. SUPABASE DATABASE REST CLIENT (CRUD)
  // --------------------------------------------------------------------------

  /// Insert a record into a table
  static Future<bool> insert(String table, Map<String, dynamic> row) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/$table');
      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode(row),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Supabase insert error in $table: $e');
      return false;
    }
  }

  /// Update records in a table
  static Future<bool> update(String table, Map<String, dynamic> row, String column, String value) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/$table?$column=eq.$value');
      final response = await http.patch(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode(row),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Supabase update error in $table: $e');
      return false;
    }
  }

  /// Query records from a table
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
    } catch (e) {
      debugPrint('Supabase query error in $table: $e');
    }
    return [];
  }

  // --------------------------------------------------------------------------
  // 3. SUPABASE DATABASE CRUD FOR ALL 13 TABLES
  // --------------------------------------------------------------------------

  /// Delete records from a table
  static Future<bool> delete(String table, String column, String value) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/$table?$column=eq.$value');
      final response = await http.delete(
        uri,
        headers: _headers,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Supabase delete error in $table: $e');
      return false;
    }
  }

  // --- 1. USERS TABLE ---
  /// Upsert a user in public.users
  static Future<bool> upsertUser(Map<String, dynamic> userData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/users');
      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates,return=representation',
        },
        body: jsonEncode(userData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Supabase upsertUser error: $e');
      return false;
    }
  }

  /// Get user by UID
  static Future<Map<String, dynamic>?> getUser(String uid) async {
    final list = await query('users', filters: {'uid': 'eq.$uid'}, limit: 1);
    return list.isNotEmpty ? list.first : null;
  }

  // --- 2. POSTS TABLE ---
  /// Save a post in public.posts
  static Future<bool> savePost(Map<String, dynamic> postData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/posts');
      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates,return=representation',
        },
        body: jsonEncode(postData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Supabase savePost error: $e');
      return false;
    }
  }

  /// Fetch posts from public.posts
  static Future<List<Map<String, dynamic>>> getPosts({int limit = 50, String? gameFilter}) async {
    final Map<String, String> filters = {};
    if (gameFilter != null && gameFilter != 'All' && gameFilter != 'All Games') {
      filters['game'] = 'eq.$gameFilter';
    }
    return await query('posts', filters: filters.isNotEmpty ? filters : null, order: 'created_at.desc', limit: limit);
  }

  // --- 3. LIKES TABLE ---
  /// Toggle like on a post in public.likes
  static Future<bool> toggleLike({required String postId, required String userId, String? username}) async {
    try {
      final existing = await query('likes', filters: {'post_id': 'eq.$postId', 'user_id': 'eq.$userId'}, limit: 1);
      if (existing.isNotEmpty) {
        // Unlike
        final delUri = Uri.parse('$supabaseUrl/rest/v1/likes?post_id=eq.$postId&user_id=eq.$userId');
        await http.delete(delUri, headers: _headers);
        return false;
      } else {
        // Like
        await insert('likes', {
          'post_id': postId,
          'user_id': userId,
          if (username != null) 'username': username,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      debugPrint('Supabase toggleLike error: $e');
      return false;
    }
  }

  /// Check if post is liked by user
  static Future<bool> isPostLiked(String postId, String userId) async {
    final existing = await query('likes', filters: {'post_id': 'eq.$postId', 'user_id': 'eq.$userId'}, limit: 1);
    return existing.isNotEmpty;
  }

  // --- 4. COMMENTS TABLE ---
  /// Add comment in public.comments
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

  /// Get comments for a post
  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    return await query('comments', filters: {'post_id': 'eq.$postId'}, order: 'created_at.asc');
  }

  // --- 5. TEAMS TABLE ---
  /// Save a team in public.teams
  static Future<bool> saveTeam(Map<String, dynamic> teamData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/teams');
      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates,return=representation',
        },
        body: jsonEncode(teamData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Supabase saveTeam error: $e');
      return false;
    }
  }

  /// Get teams from public.teams
  static Future<List<Map<String, dynamic>>> getTeams({String? gameFilter}) async {
    final Map<String, String> filters = {};
    if (gameFilter != null && gameFilter != 'All') {
      filters['game'] = 'eq.$gameFilter';
    }
    return await query('teams', filters: filters.isNotEmpty ? filters : null, order: 'created_at.desc');
  }

  /// Get a single team
  static Future<Map<String, dynamic>?> getTeam(String teamId) async {
    final list = await query('teams', filters: {'team_id': 'eq.$teamId'}, limit: 1);
    return list.isNotEmpty ? list.first : null;
  }

  // --- 6. TEAM MEMBERS TABLE ---
  /// Add member to team in public.team_members
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

  /// Remove member from team
  static Future<bool> removeTeamMember(String teamId, String userId) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/team_members?team_id=eq.$teamId&user_id=eq.$userId');
      final resp = await http.delete(uri, headers: _headers);
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  /// Get members of a team
  static Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
    return await query('team_members', filters: {'team_id': 'eq.$teamId'}, order: 'joined_at.asc');
  }

  // --- 7. TEAM JOIN REQUESTS TABLE ---
  /// Create a join request in public.team_join_requests
  static Future<bool> createTeamJoinRequest({
    required String teamId,
    String? teamName,
    required String userId,
    required String username,
    String? userAvatar,
  }) async {
    return await insert('team_join_requests', {
      'request_id': 'req_${teamId}_$userId',
      'team_id': teamId,
      if (teamName != null) 'team_name': teamName,
      'user_id': userId,
      'username': username,
      if (userAvatar != null) 'user_avatar': userAvatar,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Update join request status
  static Future<bool> updateTeamJoinRequestStatus(String teamId, String userId, String status) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/team_join_requests?team_id=eq.$teamId&user_id=eq.$userId');
      final resp = await http.patch(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  /// Get join requests for a team
  static Future<List<Map<String, dynamic>>> getTeamJoinRequests(String teamId) async {
    return await query('team_join_requests', filters: {'team_id': 'eq.$teamId', 'status': 'eq.pending'});
  }

  // --- 8. TEAM MATCHES TABLE ---
  /// Upsert a team match in public.team_matches
  static Future<bool> upsertTeamMatch(Map<String, dynamic> matchData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/team_matches');
      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates,return=representation',
        },
        body: jsonEncode(matchData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Supabase upsertTeamMatch error: $e');
      return false;
    }
  }

  /// Get team matches
  static Future<List<Map<String, dynamic>>> getTeamMatches({String? status}) async {
    final Map<String, String> filters = {};
    if (status != null && status != 'All') {
      filters['status'] = 'eq.$status';
    }
    return await query('team_matches', filters: filters.isNotEmpty ? filters : null, order: 'match_time.desc');
  }

  /// Get single team match
  static Future<Map<String, dynamic>?> getTeamMatch(String matchId) async {
    final list = await query('team_matches', filters: {'match_id': 'eq.$matchId'}, limit: 1);
    return list.isNotEmpty ? list.first : null;
  }

  // --- 9. MATCH CHAT TABLE ---
  /// Send chat message in public.match_chat
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

  /// Get chat messages for a match
  static Future<List<Map<String, dynamic>>> getMatchChat(String matchId, {int limit = 50}) async {
    return await query('match_chat', filters: {'match_id': 'eq.$matchId'}, order: 'created_at.asc', limit: limit);
  }

  // --- 10. ROOMS TABLE ---
  /// Save room in public.rooms
  static Future<bool> saveRoom(Map<String, dynamic> roomData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/rooms');
      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates,return=representation',
        },
        body: jsonEncode(roomData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Supabase saveRoom error: $e');
      return false;
    }
  }

  /// Get rooms
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

  // --- 11. ROOM MEMBERS TABLE ---
  /// Add member to custom room in public.room_members
  static Future<bool> addRoomMember(Map<String, dynamic> memberData) async {
    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/room_members');
      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates,return=representation',
        },
        body: jsonEncode(memberData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Supabase addRoomMember error: $e');
      return false;
    }
  }

  /// Get members of a room
  static Future<List<Map<String, dynamic>>> getRoomMembers(String roomId) async {
    return await query('room_members', filters: {'room_id': 'eq.$roomId'}, order: 'joined_at.asc');
  }

  // --- 12. COIN TRANSACTIONS TABLE (Virtual Coins Only) ---
  /// Record in-game coin transaction in public.coin_transactions (Strictly virtual coins, no real cash)
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

  /// Get user's coin transaction history
  static Future<List<Map<String, dynamic>>> getUserCoinTransactions(String userId, {int limit = 50}) async {
    return await query('coin_transactions', filters: {'user_id': 'eq.$userId'}, order: 'created_at.desc', limit: limit);
  }

  // --- 13. NOTIFICATIONS TABLE ---
  /// Save notification in public.notifications
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

  /// Get user notifications
  static Future<List<Map<String, dynamic>>> getUserNotifications(String userId, {int limit = 50}) async {
    return await query('notifications', filters: {'user_id': 'eq.$userId'}, order: 'created_at.desc', limit: limit);
  }

  // --------------------------------------------------------------------------
  // 4. REALTIME UPDATES (Chat & Matches)
  // --------------------------------------------------------------------------

  /// Stream of new chat messages for a match/room with active polling fallback
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

  /// Backward compatible alias for room/match chat stream
  static Stream<List<Map<String, dynamic>>> getChatMessagesStream(String roomId) => getMatchChatStream(roomId);

  /// Stream of team match status changes
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
}
