import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/team_model.dart';
import 'supabase_service.dart';

class TeamService {
  static final TeamService _instance = TeamService._internal();
  factory TeamService() => _instance;
  TeamService._internal();

  /// Create a new team
  Future<String?> createTeam({
    required String name,
    required String tag,
    File? logoFile,
    required String game,
    String description = '',
    String requirements = '',
    required String leaderId,
    required String leaderName,
    String leaderAvatar = '',
  }) async {
    try {
      String logoUrl = '';
      if (logoFile != null) {
        logoUrl = await SupabaseService.uploadFile(
              file: logoFile,
              folder: 'team_logos',
              bucket: SupabaseService.bucketTeamLogos,
            ) ??
            '';
      }

      // Generate a unique team id
      final teamId = SupabaseService.toUuid(
        'team_${DateTime.now().millisecondsSinceEpoch}_${name.trim()}',
      );
      final leaderUuid = SupabaseService.toUuid(leaderId);

      final teamData = {
        'id': teamId,
        'name': name.trim(),
        'tag': tag.trim().toUpperCase(),
        'logo_url': logoUrl,
        'game': game,
        'description': description.trim(),
        'requirements': requirements.trim(),
        'leader_id': leaderUuid,
        'wins': 0,
        'losses': 0,
        'draws': 0,
        'points': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint('[TeamService] createTeam data: $teamData');

      await SupabaseService.client.from('teams').insert(teamData);

      // Add leader as team member
      try {
        await SupabaseService.client.from('team_members').insert({
          'team_id': teamId,
          'user_id': leaderUuid,
          'role': 'Leader',
          'joined_at': DateTime.now().toIso8601String(),
        });
      } catch (memberErr) {
        debugPrint('[TeamService] add leader to team_members error: $memberErr');
      }

      debugPrint('[TeamService] team created: $teamId');
      return teamId;
    } catch (e) {
      debugPrint('[TeamService] createTeam error: $e');
      return null;
    }
  }

  /// Stream of all teams with optional game filter and search query
  Stream<List<TeamModel>> getTeamsStream({
    String gameFilter = 'All',
    String searchQuery = '',
  }) {
    return SupabaseService.client
        .from('teams')
        .stream(primaryKey: ['id'])
        .map((rows) {
      var teams = rows
          .map((row) => TeamModel.fromSupabase(row))
          .toList();

      if (gameFilter != 'All' && gameFilter.isNotEmpty) {
        teams = teams.where((t) => t.game == gameFilter).toList();
      }

      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        teams = teams.where((t) {
          return t.name.toLowerCase().contains(q) ||
              t.tag.toLowerCase().contains(q);
        }).toList();
      }

      teams.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return teams;
    });
  }

  /// Get single team
  Future<TeamModel?> getTeam(String teamId) async {
    if (teamId.isEmpty) return null;
    try {
      final row = await SupabaseService.client
          .from('teams')
          .select()
          .eq('id', teamId)
          .maybeSingle();

      if (row != null) return TeamModel.fromSupabase(row);
      return null;
    } catch (e) {
      debugPrint('[TeamService] getTeam error: $e');
      return null;
    }
  }

  /// Get team members
  Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
    try {
      final rows = await SupabaseService.client
          .from('team_members')
          .select()
          .eq('team_id', teamId);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('[TeamService] getTeamMembers error: $e');
      return [];
    }
  }

  /// Request to join a team
  Future<bool> requestToJoinTeam({
    required String teamId,
    required String userId,
    required String userName,
    String teamName = '',
  }) async {
    try {
      final userUuid = SupabaseService.toUuid(userId);
      await SupabaseService.client.from('team_join_requests').insert({
        'team_id': teamId,
        'user_id': userUuid,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Notify leader
      final team = await getTeam(teamId);
      if (team != null && team.leaderId != userUuid) {
        try {
          await SupabaseService.sendNotification({
            'userId': team.leaderId,
            'title': '🛡️ New Join Request',
            'message':
                '$userName نے آپ کی ٹیم "${team.name}" میں شامل ہونے کی درخواست کی ہے۔',
            'type': 'team_join_request',
          });
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('[TeamService] requestToJoinTeam error: $e');
      return false;
    }
  }

  /// Get pending join requests for a team
  Future<List<Map<String, dynamic>>> getPendingJoinRequests(
      String teamId) async {
    try {
      final rows = await SupabaseService.client
          .from('team_join_requests')
          .select()
          .eq('team_id', teamId)
          .eq('status', 'pending');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('[TeamService] getPendingJoinRequests error: $e');
      return [];
    }
  }

  /// Accept join request
  Future<bool> acceptJoinRequest({
    required String teamId,
    required String userId,
    required String userName,
    String userAvatar = '',
  }) async {
    try {
      final userUuid = SupabaseService.toUuid(userId);

      await SupabaseService.client.from('team_members').insert({
        'team_id': teamId,
        'user_id': userUuid,
        'role': 'Member',
        'joined_at': DateTime.now().toIso8601String(),
      });

      await SupabaseService.client
          .from('team_join_requests')
          .update({'status': 'accepted'})
          .eq('team_id', teamId)
          .eq('user_id', userUuid);

      // Notify user
      try {
        await SupabaseService.sendNotification({
          'userId': userUuid,
          'title': '🎉 Welcome to the Team!',
          'message': 'آپ کی ٹیم جوائن کرنے کی درخواست قبول کر لی گئی ہے!',
          'type': 'team_join_accepted',
        });
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('[TeamService] acceptJoinRequest error: $e');
      return false;
    }
  }

  /// Reject join request
  Future<bool> rejectJoinRequest({
    required String teamId,
    required String userId,
  }) async {
    try {
      final userUuid = SupabaseService.toUuid(userId);
      await SupabaseService.client
          .from('team_join_requests')
          .update({'status': 'rejected'})
          .eq('team_id', teamId)
          .eq('user_id', userUuid);
      return true;
    } catch (e) {
      debugPrint('[TeamService] rejectJoinRequest error: $e');
      return false;
    }
  }

  /// Get user's teams
  Future<List<TeamModel>> getUserTeams(String userId) async {
    try {
      final userUuid = SupabaseService.toUuid(userId);
      final memberships = await SupabaseService.client
          .from('team_members')
          .select('team_id')
          .eq('user_id', userUuid);

      final teamIds = memberships
          .map((m) => m['team_id'].toString())
          .toList();

      if (teamIds.isEmpty) return [];

      final rows = await SupabaseService.client
          .from('teams')
          .select()
          .inFilter('id', teamIds);

      return (rows as List)
          .map((r) => TeamModel.fromSupabase(r))
          .toList();
    } catch (e) {
      debugPrint('[TeamService] getUserTeams error: $e');
      return [];
    }
  }

  /// Stream of user's teams
  Stream<List<TeamModel>> getUserTeamsStream(String userId) {
    return SupabaseService.client
        .from('team_members')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) async {
      final userUuid = SupabaseService.toUuid(userId);
      final teamIds = rows
          .where((r) => r['user_id']?.toString() == userUuid)
          .map((r) => r['team_id'].toString())
          .toList();

      if (teamIds.isEmpty) return <TeamModel>[];

      final teams = await SupabaseService.client
          .from('teams')
          .select()
          .inFilter('id', teamIds);

      return (teams as List)
          .map((r) => TeamModel.fromSupabase(r))
          .toList();
    });
  }
}