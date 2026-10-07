import "dart:io";
import "dart:async";
import "package:flutter/foundation.dart";
import "../models/team_model.dart";
import "supabase_service.dart";

/// Service to manage teams in Supabase
class TeamService {
  static final TeamService _instance = TeamService._internal();
  factory TeamService() => _instance;
  TeamService._internal();

  /// Get single team by ID
  Future<TeamModel?> getTeam(String teamId) async {
    if (teamId.isEmpty) return null;
    try {
      final teamUuid = SupabaseService.toUuid(teamId);
      final res = await SupabaseService.client
          .from("teams")
          .select()
          .or("id.eq.$teamUuid,id.eq.$teamId")
          .maybeSingle();
      if (res != null) {
        return TeamModel.fromSupabase(res);
      }
    } catch (e) {
      debugPrint("[TeamService] getTeam error: $e");
    }
    return null;
  }

  /// Get team stream
  Stream<TeamModel?> getTeamStream(String teamId) {
    if (teamId.isEmpty) return Stream.value(null);
    try {
      final teamUuid = SupabaseService.toUuid(teamId);
      return SupabaseService.client
          .from("teams")
          .stream(primaryKey: ["id"])
          .eq("id", teamUuid)
          .map((rows) => rows.isNotEmpty ? TeamModel.fromSupabase(rows.first) : null);
    } catch (e) {
      debugPrint("[TeamService] getTeamStream error: $e");
      return Stream.value(null);
    }
  }

  /// Get all teams where user is leader or member
  Future<List<TeamModel>> getUserTeams(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final userUuid = SupabaseService.toUuid(userId);
      final memberRows = await SupabaseService.client
          .from("team_members")
          .select("team_id")
          .or("user_id.eq.$userUuid,user_id.eq.$userId");

      final teamIds = <String>{};
      for (final r in memberRows) {
        final tid = r["team_id"]?.toString();
        if (tid != null && tid.isNotEmpty) teamIds.add(tid);
      }

      final res = await SupabaseService.client
          .from("teams")
          .select()
          .or("leader_id.eq.$userId,leader_id.eq.$userUuid");

      final result = <TeamModel>[];
      final seenIds = <String>{};
      for (final r in res) {
        final t = TeamModel.fromSupabase(r);
        seenIds.add(t.id);
        result.add(t);
      }

      for (final tid in teamIds) {
        if (!seenIds.contains(tid)) {
          final t = await getTeam(tid);
          if (t != null) {
            seenIds.add(t.id);
            result.add(t);
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint("[TeamService] getUserTeams error: $e");
      return [];
    }
  }

  /// Stream of user teams
  Stream<List<TeamModel>> getUserTeamsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    try {
      final userUuid = SupabaseService.toUuid(userId);
      return SupabaseService.client
          .from("teams")
          .stream(primaryKey: ["id"])
          .map((rows) {
            return rows
                .where((r) {
                  final leaderId = (r["leader_id"] ?? "").toString();
                  if (leaderId == userId || leaderId == userUuid) return true;
                  final members = r["members"];
                  if (members is List) {
                    return members.any((m) => m.toString() == userId || m.toString() == userUuid);
                  }
                  return false;
                })
                .map((r) => TeamModel.fromSupabase(r))
                .toList();
          });
    } catch (e) {
      debugPrint("[TeamService] getUserTeamsStream error: $e");
      return Stream.value([]);
    }
  }

  /// Get stream of all teams with optional game filter and search query
  Stream<List<TeamModel>> getTeamsStream({String? gameFilter, String? searchQuery}) {
    try {
      return SupabaseService.client
          .from("teams")
          .stream(primaryKey: ["id"])
          .order("points", ascending: false)
          .map((rows) {
            var filtered = rows.map((r) => TeamModel.fromSupabase(r)).toList();
            if (gameFilter != null && gameFilter.isNotEmpty && gameFilter != "All") {
              filtered = filtered.where((t) => t.game.toLowerCase() == gameFilter.toLowerCase()).toList();
            }
            if (searchQuery != null && searchQuery.trim().isNotEmpty) {
              final q = searchQuery.trim().toLowerCase();
              filtered = filtered.where((t) =>
                  t.name.toLowerCase().contains(q) || t.tag.toLowerCase().contains(q)
              ).toList();
            }
            return filtered;
          });
    } catch (e) {
      debugPrint("[TeamService] getTeamsStream error: $e");
      return Stream.value([]);
    }
  }

  /// Create a new team
  Future<String?> createTeam({
    required String name,
    required String tag,
    File? logoFile,
    required String game,
    required String description,
    required String requirements,
    required String leaderId,
    required String leaderName,
    required String leaderAvatar,
  }) async {
    try {
      String logoUrl = "";
      if (logoFile != null) {
        final uploaded = await SupabaseService.uploadFile(
          file: logoFile,
          folder: "team_logos",
          bucket: SupabaseService.bucketTeamLogos,
        );
        if (uploaded != null) logoUrl = uploaded;
      }

      final teamUuid = SupabaseService.toUuid(DateTime.now().millisecondsSinceEpoch.toString());
      final now = DateTime.now().toIso8601String();

      final row = {
        "id": teamUuid,
        "team_id": teamUuid,
        "name": name.trim(),
        "tag": tag.trim().toUpperCase(),
        "logo_url": logoUrl,
        "game": game,
        "description": description.trim(),
        "requirements": requirements.trim(),
        "leader_id": leaderId,
        "leader_name": leaderName,
        "leader_avatar": leaderAvatar,
        "members": [leaderId],
        "member_count": 1,
        "wins": 0,
        "losses": 0,
        "draws": 0,
        "points": 0,
        "created_at": now,
        "updated_at": now,
      };

      await SupabaseService.client.from("teams").insert(row);

      try {
        await SupabaseService.client.from("team_members").insert({
          "team_id": teamUuid,
          "user_id": leaderId,
          "username": leaderName,
          "role": "Owner",
          "joined_at": now,
        });
      } catch (_) {}

      return teamUuid;
    } catch (e) {
      debugPrint("[TeamService] createTeam error: $e");
      return null;
    }
  }

  /// Update existing team
  Future<bool> updateTeam({
    required String teamId,
    required String name,
    required String tag,
    File? newLogoFile,
    required String game,
    required String description,
    required String requirements,
  }) async {
    if (teamId.isEmpty) return false;
    try {
      final Map<String, dynamic> updates = {
        "name": name.trim(),
        "tag": tag.trim().toUpperCase(),
        "game": game,
        "description": description.trim(),
        "requirements": requirements.trim(),
        "updated_at": DateTime.now().toIso8601String(),
      };

      if (newLogoFile != null) {
        final newLogoUrl = await SupabaseService.uploadFile(
          file: newLogoFile,
          folder: "team_logos",
          bucket: SupabaseService.bucketTeamLogos,
        );
        if (newLogoUrl != null && newLogoUrl.isNotEmpty) {
          updates["logo_url"] = newLogoUrl;
        }
      }

      final teamUuid = SupabaseService.toUuid(teamId);
      await SupabaseService.client
          .from("teams")
          .update(updates)
          .or("id.eq.$teamUuid,id.eq.$teamId");

      debugPrint("[TeamService] ✅ Team updated: $teamId");
      return true;
    } catch (e) {
      debugPrint("[TeamService] updateTeam error: $e");
      return false;
    }
  }

  /// Delete team (Owner only)
  Future<String> deleteTeam({
    required String teamId,
    required String currentUserId,
  }) async {
    if (teamId.isEmpty || currentUserId.isEmpty) return "error";
    try {
      final userUuid = SupabaseService.toUuid(currentUserId);
      final teamUuid = SupabaseService.toUuid(teamId);

      // Verify owner
      final memberRow = await SupabaseService.client
          .from("team_members")
          .select("role")
          .or("team_id.eq.$teamUuid,team_id.eq.$teamId")
          .or("user_id.eq.$userUuid,user_id.eq.$currentUserId")
          .maybeSingle();

      if (memberRow != null) {
        final role = (memberRow["role"] ?? "").toString().toLowerCase();
        if (role != "owner" && role != "leader") {
          return "not_owner";
        }
      }

      // Check active matches
      final activeMatches = await SupabaseService.client
          .from("active_matches")
          .select("id")
          .or("team1_id.eq.$teamUuid,team2_id.eq.$teamUuid")
          .inFilter("status", ["active", "under_review"]);

      if (activeMatches.isNotEmpty) {
        return "active_match";
      }

      try {
        await SupabaseService.client.from("challenges").delete().eq("from_team_id", teamUuid);
      } catch (_) {}
      try {
        await SupabaseService.client.from("challenges").delete().eq("to_team_id", teamUuid);
      } catch (_) {}
      try {
        await SupabaseService.client.from("team_join_requests").delete().eq("team_id", teamUuid);
      } catch (_) {}
      try {
        await SupabaseService.client.from("team_members").delete().eq("team_id", teamUuid);
      } catch (_) {}

      await SupabaseService.client.from("teams").delete().or("id.eq.$teamUuid,id.eq.$teamId");
      debugPrint("[TeamService] ✅ Team deleted: $teamId");
      return "ok";
    } catch (e) {
      debugPrint("[TeamService] deleteTeam error: $e");
      return "error";
    }
  }

  /// Request to join team
  Future<bool> requestToJoinTeam({
    required String teamId,
    required String userId,
    String? userName,
    String? teamName,
  }) async {
    try {
      final teamUuid = SupabaseService.toUuid(teamId);
      final userUuid = SupabaseService.toUuid(userId);
      final name = userName ?? "Gamer";

      await SupabaseService.client.from("team_join_requests").insert({
        "team_id": teamUuid,
        "team_name": teamName ?? "",
        "user_id": userUuid,
        "username": name,
        "status": "pending",
        "created_at": DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint("[TeamService] requestToJoinTeam error: $e");
      return false;
    }
  }

  /// Accept join request
  Future<bool> acceptJoinRequest({
    required String teamId,
    required String userId,
    String? userName,
  }) async {
    try {
      final teamUuid = SupabaseService.toUuid(teamId);
      final userUuid = SupabaseService.toUuid(userId);

      await SupabaseService.client.from("team_members").insert({
        "team_id": teamUuid,
        "user_id": userUuid,
        "username": userName ?? "Member",
        "role": "Member",
        "joined_at": DateTime.now().toIso8601String(),
      });

      final team = await getTeam(teamId);
      if (team != null) {
        final updatedMembers = List<String>.from(team.members)..add(userId);
        await SupabaseService.client.from("teams").update({
          "members": updatedMembers,
          "member_count": updatedMembers.length,
        }).or("id.eq.$teamUuid,id.eq.$teamId");
      }

      await SupabaseService.client
          .from("team_join_requests")
          .delete()
          .eq("team_id", teamUuid)
          .eq("user_id", userUuid);

      return true;
    } catch (e) {
      debugPrint("[TeamService] acceptJoinRequest error: $e");
      return false;
    }
  }

  /// Reject join request
  Future<bool> rejectJoinRequest({
    required String teamId,
    required String userId,
  }) async {
    try {
      final teamUuid = SupabaseService.toUuid(teamId);
      final userUuid = SupabaseService.toUuid(userId);

      await SupabaseService.client
          .from("team_join_requests")
          .delete()
          .eq("team_id", teamUuid)
          .eq("user_id", userUuid);
      return true;
    } catch (e) {
      debugPrint("[TeamService] rejectJoinRequest error: $e");
      return false;
    }
  }
}

// Top-level helpers for backwards compatibility
Future<bool> updateTeam({
  required String teamId,
  required String name,
  required String tag,
  File? newLogoFile,
  required String game,
  required String description,
  required String requirements,
}) => TeamService().updateTeam(
  teamId: teamId,
  name: name,
  tag: tag,
  newLogoFile: newLogoFile,
  game: game,
  description: description,
  requirements: requirements,
);

Future<String> deleteTeam({
  required String teamId,
  required String currentUserId,
}) => TeamService().deleteTeam(
  teamId: teamId,
  currentUserId: currentUserId,
);