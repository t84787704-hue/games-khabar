import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// GDPR / DPDP Act compliant data export service.
/// 
/// Exports all user data from Supabase into a single JSON map:
/// - Profile (users table row)
/// - Posts
/// - Comments
/// - Likes
/// - Followers / Following
/// - Teams & team memberships
/// - 1v1 challenges
/// - Coin transactions
/// - Notifications
/// 
/// Called from GamerDownloadDataScreen.
class GamerDataExportService {
  static final GamerDataExportService _instance =
      GamerDataExportService._internal();
  factory GamerDataExportService() => _instance;
  GamerDataExportService._internal();

  /// Fetch all user data and return as a Map.
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    if (userId.isEmpty) {
      return {'error': 'User ID is empty'};
    }

    final uuid = SupabaseService.toUuid(userId);

    final Map<String, dynamic> data = {
      'exported_at': DateTime.now().toIso8601String(),
      'user_id': userId,
      'app': 'Games Khabar / Gamers ID',
      'version': '1.0',
    };

    // 1. Profile
    try {
      final profile = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', uuid)
          .maybeSingle();
      data['profile'] = profile;
    } catch (e) {
      debugPrint('[Export] profile error: $e');
      data['profile'] = null;
    }

    // 2. Posts
    try {
      final posts = await SupabaseService.client
          .from('posts')
          .select()
          .eq('user_id', uuid)
          .order('created_at', ascending: false);
      data['posts'] = posts;
    } catch (e) {
      debugPrint('[Export] posts error: $e');
      data['posts'] = [];
    }

    // 3. Comments
    try {
      final comments = await SupabaseService.client
          .from('comments')
          .select()
          .eq('user_id', uuid)
          .order('created_at', ascending: false);
      data['comments'] = comments;
    } catch (e) {
      debugPrint('[Export] comments error: $e');
      data['comments'] = [];
    }

    // 4. Likes
    try {
      final likes = await SupabaseService.client
          .from('likes')
          .select()
          .eq('user_id', uuid);
      data['likes'] = likes;
    } catch (e) {
      debugPrint('[Export] likes error: $e');
      data['likes'] = [];
    }

    // 5. Followers
    try {
      final followers = await SupabaseService.client
          .from('follows')
          .select()
          .eq('following_id', uuid);
      data['followers'] = followers;
    } catch (e) {
      debugPrint('[Export] followers error: $e');
      data['followers'] = [];
    }

    // 6. Following
    try {
      final following = await SupabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', uuid);
      data['following'] = following;
    } catch (e) {
      debugPrint('[Export] following error: $e');
      data['following'] = [];
    }

    // 7. Teams (owned)
    try {
      final teams = await SupabaseService.client
          .from('teams')
          .select()
          .eq('leader_id', uuid);
      data['teams_owned'] = teams;
    } catch (e) {
      debugPrint('[Export] teams error: $e');
      data['teams_owned'] = [];
    }

    // 8. Team Memberships
    try {
      final memberships = await SupabaseService.client
          .from('team_members')
          .select()
          .eq('user_id', uuid);
      data['team_memberships'] = memberships;
    } catch (e) {
      debugPrint('[Export] memberships error: $e');
      data['team_memberships'] = [];
    }

    // 9. 1v1 Challenges (as challenger)
    try {
      final challengerChallenges = await SupabaseService.client
          .from('player_challenges')
          .select()
          .eq('challenger_id', uuid)
          .order('created_at', ascending: false);
      data['challenges_sent'] = challengerChallenges;
    } catch (e) {
      debugPrint('[Export] challenges_sent error: $e');
      data['challenges_sent'] = [];
    }

    // 10. 1v1 Challenges (as challenged)
    try {
      final challengedChallenges = await SupabaseService.client
          .from('player_challenges')
          .select()
          .eq('challenged_id', uuid)
          .order('created_at', ascending: false);
      data['challenges_received'] = challengedChallenges;
    } catch (e) {
      debugPrint('[Export] challenges_received error: $e');
      data['challenges_received'] = [];
    }

    // 11. Coin Transactions
    try {
      final coins = await SupabaseService.client
          .from('coin_transactions')
          .select()
          .eq('user_id', uuid)
          .order('created_at', ascending: false);
      data['coin_transactions'] = coins;
    } catch (e) {
      debugPrint('[Export] coins error: $e');
      data['coin_transactions'] = [];
    }

    // 12. Notifications
    try {
      final notifications = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', uuid)
          .order('created_at', ascending: false);
      data['notifications'] = notifications;
    } catch (e) {
      debugPrint('[Export] notifications error: $e');
      data['notifications'] = [];
    }

    return data;
  }

  /// Convert map to pretty JSON string.
  String toJsonString(Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }
}