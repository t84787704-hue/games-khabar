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

  // Standard Storage Buckets
  static const String bucketUploads = 'gamers_uploads';
  static const String bucketMatchProofs = 'match_proofs';
  static const String bucketAvatars = 'user_avatars';
  static const String bucketCovers = 'user_covers';

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
  // 4. REALTIME UPDATES (Chat & Matches)
  // --------------------------------------------------------------------------

  /// Stream of new chat messages for a room/match with active polling fallback
  static Stream<List<Map<String, dynamic>>> getChatMessagesStream(String roomId) async* {
    while (true) {
      final messages = await query(
        'chat_messages',
        filters: {'room_id': 'eq.$roomId'},
        order: 'created_at.asc',
        limit: 50,
      );
      yield messages;
      await Future.delayed(const Duration(seconds: 3));
    }
  }

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
