// ===============================================================================
// File: lib/services/team_service.dart
// Service to manage teams in Supabase with Enriched Member Details
// ===============================================================================

import "dart:io";
import "dart:async";
import "package:flutter/foundation.dart";
import "package:easy_localization/easy_localization.dart";
import "../models/team_model.dart";
import "supabase_service.dart";

/// Service to manage teams in Supabase
class TeamService {
  static final TeamService _instance = TeamService._internal();
  factory TeamService() => _instance;
  TeamService._internal();

  /// Helper to enrich a single raw team row with members, pending join requests, and leader info
  Future<TeamModel> _enrichTeamRow(Map<String, dynamic> rawRow) async {
    final teamId = (rawRow["id"] ?? "").toString();
    final teamUuid = SupabaseService.toUuid(teamId);

    final teamIds = {teamId, teamUuid}.where((e) => e.isNotEmpty).toList();

    // 1. Fetch members from team_members table and gather user IDs
    final members = <String>[];
    final List<Map<String, dynamic>> memberDetails = [];
    
    if (rawRow["members"] is List) {
      for (final m in (rawRow["members"] as List)) {
        final uid = m.toString().trim();
        if (uid.isNotEmpty && !members.contains(uid)) {
          members.add(uid);
        }
      }
    }
    
    try {
      final memberRows = await SupabaseService.client
          .from("team_members")
          .select("user_id, role")
          .filter("team_id", "in", teamIds);
      
      final memberUserIds = <String>[];
      final Map<String, String> memberRoles = {};
      
      for (final m in memberRows) {
        final uid = (m["user_id"] ?? "").toString().trim();
        final role = (m["role"] ?? "member").toString().trim();
        if (uid.isNotEmpty) {
          memberRoles[uid] = role;
          if (!members.contains(uid)) {
            members.add(uid);
          }
          memberUserIds.add(uid);
        }
      }

      final leaderId = (rawRow["leader_id"] ?? rawRow["leaderId"] ?? "").toString().trim();
      if (members.isEmpty && leaderId.isNotEmpty) {
        members.add(leaderId);
        memberUserIds.add(leaderId);
      }

      // Fetch user profile details (Name & Avatar) for all members in batch
      if (memberUserIds.isNotEmpty) {
        try {
          final userRows = await SupabaseService.client
              .from("users")
              .select("id, uid, display_name, username, avatar_url, photo_url")
              .inFilter("id", memberUserIds);

          final Map<String, Map<String, String>> userInfoMap = {};
          for (final u in userRows) {
            final id = (u["id"] ?? "").toString();
            final uid = (u["uid"] ?? "").toString();
            final dName = (u["display_name"] ?? "").toString().trim();
            final uName = (u["username"] ?? "").toString().trim();
            final avatar = (u["avatar_url"] ?? u["photo_url"] ?? "").toString().trim();

            String resolvedName = "Member";
            if (dName.isNotEmpty && dName.toLowerCase() != "null" && dName != 'gamer_id_display') {
              resolvedName = dName;
            } else if (uName.isNotEmpty && uName.toLowerCase() != "null") {
              resolvedName = uName.startsWith('@') ? uName : '@$uName';
            }

            final userMapData = {'name': resolvedName, 'avatar': avatar};
            if (id.isNotEmpty) userInfoMap[id] = userMapData;
            if (uid.isNotEmpty) userInfoMap[uid] = userMapData;
          }

          for (final mId in members) {
            final uInfo = userInfoMap[mId] ?? {'name': mId == leaderId ? 'Leader' : 'Member', 'avatar': ''};
            final isLeader = mId == leaderId || memberRoles[mId] == 'owner' || memberRoles[mId] == 'leader';
            
            memberDetails.add({
              'id': mId,
              'name': uInfo['name'],
              'avatar': uInfo['avatar'],
              'role': isLeader ? 'Leader' : (memberRoles[mId] ?? 'Member'),
            });
          }
        } catch (e) {
          debugPrint("[TeamService] member profiles batch fetch error: $e");
        }
      }
    } catch (e) {
      debugPrint("[TeamService] getTeam members fetch error: $e");
    }

    final leaderId = (rawRow["leader_id"] ?? rawRow["leaderId"] ?? "").toString().trim();

    // 2. Fetch pending join requests from team_join_requests table
    final pendingRequests = <String>[];
    try {
      final reqRows = await SupabaseService.client
          .from("team_join_requests")
          .select("user_id, status")
          .filter("team_id", "in", teamIds)
          .eq("status", "pending");
      
      for (final r in reqRows) {
        final uid = (r["user_id"] ?? "").toString().trim();
        if (uid.isNotEmpty && !members.contains(uid) && !pendingRequests.contains(uid)) {
          pendingRequests.add(uid);
        }
      }
    } catch (e) {
      debugPrint("[TeamService] pending requests fetch error: $e");
    }

    // 3. Fetch leader name & avatar from users table
    String leaderName = (rawRow["leader_name"] ?? rawRow["leaderName"] ?? "").toString().trim();
    String leaderAvatar = (rawRow["leader_avatar"] ?? rawRow["leaderAvatar"] ?? "").toString().trim();
    if (leaderId.isNotEmpty) {
      try {
        final userRes = await SupabaseService.client
            .from("users")
            .select("id, uid, display_name, username, avatar_url, photo_url")
            .or("id.eq.$leaderId,uid.eq.$leaderId")
            .maybeSingle();
        if (userRes != null) {
          final d = (userRes["display_name"] ?? "").toString().trim();
          final un = (userRes["username"] ?? "").toString().trim();
          if (d.isNotEmpty && d.toLowerCase() != "null") {
            leaderName = d;
          } else if (un.isNotEmpty && un.toLowerCase() != "null") {
            leaderName = un;
          }
          final av = (userRes["avatar_url"] ?? userRes["photo_url"] ?? "").toString().trim();
          if (av.isNotEmpty && av.toLowerCase() != "null") {
            leaderAvatar = av;
          }
        }
      } catch (e) {
        debugPrint("[TeamService] leader fetch error: $e");
      }
    }

    final enrichedMap = Map<String, dynamic>.from(rawRow);
    enrichedMap["members"] = members;
    enrichedMap["member_details"] = memberDetails;
    enrichedMap["memberDetails"] = memberDetails;
    enrichedMap["pending_join_requests"] = pendingRequests;
    enrichedMap["pendingJoinRequests"] = pendingRequests;
    enrichedMap["join_requests"] = pendingRequests;
    enrichedMap["leader_name"] = leaderName.isNotEmpty ? leaderName : "team_leader_fallback".tr();
    enrichedMap["leaderName"] = leaderName.isNotEmpty ? leaderName : "team_leader_fallback".tr();
    enrichedMap["leader_avatar"] = leaderAvatar;
    enrichedMap["leaderAvatar"] = leaderAvatar;

    final team = TeamModel.fromSupabase(enrichedMap);
    return team.copyWith(
      members: members,
      memberDetails: memberDetails,
      leaderName: leaderName.isNotEmpty ? leaderName : "team_leader_fallback".tr(),
      leaderAvatar: leaderAvatar,
    );
  }

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
        return await _enrichTeamRow(res);
      }
    } catch (e) {
      debugPrint("[TeamService] getTeam error: $e");
    }
    return null;
  }

  /// Get team stream (polls + real-time updates for team, members & join requests)
  Stream<TeamModel?> getTeamStream(String teamId) async* {
    if (teamId.isEmpty) {
      yield null;
      return;
    }
    while (true) {
      try {
        final team = await getTeam(teamId);
        yield team;
      } catch (e) {
        debugPrint("[TeamService] getTeamStream error: $e");
      }
      await Future.delayed(const Duration(seconds: 3));
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
        final t = await _enrichTeamRow(r);
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

  /// Stream of user teams (includes both leader and joined member teams)
  Stream<List<TeamModel>> getUserTeamsStream(String userId) async* {
    if (userId.isEmpty) {
      yield [];
      return;
    }
    while (true) {
      try {
        final teams = await getUserTeams(userId);
        yield teams;
      } catch (e) {
        debugPrint("[TeamService] getUserTeamsStream error: $e");
      }
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  /// Fetch all enriched teams with optional gameFilter and searchQuery
  Future<List<TeamModel>> _fetchAllTeamsEnriched({
    String? gameFilter,
    String? searchQuery,
  }) async {
    final rows = await SupabaseService.client
        .from("teams")
        .select()
        .order("points", ascending: false);

    if (rows.isEmpty) return <TeamModel>[];

    final teamIds = rows
        .map((r) => (r["id"] ?? "").toString())
        .where((id) => id.isNotEmpty)
        .toList();

    final Map<String, List<String>> membersByTeam = {};
    final Map<String, List<Map<String, dynamic>>> memberDetailsByTeam = {};
    final Map<String, List<String>> pendingByTeam = {};

    if (teamIds.isNotEmpty) {
      try {
        final memberRows = await SupabaseService.client
            .from("team_members")
            .select("team_id, user_id, role")
            .inFilter("team_id", teamIds);
            
        final allUserIds = memberRows.map((m) => (m["user_id"] ?? "").toString()).where((id) => id.isNotEmpty).toSet().toList();
        final Map<String, Map<String, String>> userInfoMap = {};
        
        if (allUserIds.isNotEmpty) {
          try {
            final userRows = await SupabaseService.client
                .from("users")
                .select("id, uid, display_name, username, avatar_url, photo_url")
                .inFilter("id", allUserIds);
            for (final u in userRows) {
              final id = (u["id"] ?? "").toString();
              final uid = (u["uid"] ?? "").toString();
              final dName = (u["display_name"] ?? "").toString().trim();
              final uName = (u["username"] ?? "").toString().trim();
              final avatar = (u["avatar_url"] ?? u["photo_url"] ?? "").toString().trim();

              String resolvedName = "Member";
              if (dName.isNotEmpty && dName.toLowerCase() != "null" && dName != 'gamer_id_display') {
                resolvedName = dName;
              } else if (uName.isNotEmpty && uName.toLowerCase() != "null") {
                resolvedName = uName.startsWith('@') ? uName : '@$uName';
              }

              final userMapData = {'name': resolvedName, 'avatar': avatar};
              if (id.isNotEmpty) userInfoMap[id] = userMapData;
              if (uid.isNotEmpty) userInfoMap[uid] = userMapData;
            }
          } catch (_) {}
        }

        for (final m in memberRows) {
          final tid = (m["team_id"] ?? "").toString();
          final uid = (m["user_id"] ?? "").toString();
          final role = (m["role"] ?? "member").toString();
          if (tid.isEmpty || uid.isEmpty) continue;
          
          final list = membersByTeam.putIfAbsent(tid, () => []);
          if (!list.contains(uid)) list.add(uid);

          final detailsList = memberDetailsByTeam.putIfAbsent(tid, () => []);
          final uInfo = userInfoMap[uid] ?? {'name': 'Member', 'avatar': ''};
          detailsList.add({
            'id': uid,
            'name': uInfo['name'],
            'avatar': uInfo['avatar'],
            'role': role,
          });
        }
      } catch (e) {
        debugPrint("[TeamService] members fetch error: $e");
      }

      try {
        final reqRows = await SupabaseService.client
            .from("team_join_requests")
            .select("team_id, user_id, status")
            .inFilter("team_id", teamIds)
            .eq("status", "pending");
        for (final r in reqRows) {
          final tid = (r["team_id"] ?? "").toString();
          final uid = (r["user_id"] ?? "").toString();
          if (tid.isEmpty || uid.isEmpty) continue;
          final list = pendingByTeam.putIfAbsent(tid, () => []);
          if (!list.contains(uid)) list.add(uid);
        }
      } catch (e) {
        debugPrint("[TeamService] team_join_requests batch fetch error: $e");
      }
    }

    final leaderIds = rows
        .map((r) => (r["leader_id"] ?? r["leaderId"] ?? "").toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final Map<String, String> leaderNameById = {};
    final Map<String, String> leaderAvatarById = {};
    if (leaderIds.isNotEmpty) {
      try {
        final userRows = await SupabaseService.client
            .from("users")
            .select("id, uid, display_name, username, avatar_url, photo_url")
            .inFilter("id", leaderIds);
        for (final u in userRows) {
          final id = (u["id"] ?? "").toString();
          final uid = (u["uid"] ?? "").toString();
          final d = (u["display_name"] ?? "").toString().trim();
          final un = (u["username"] ?? "").toString().trim();
          final name = (d.isNotEmpty && d.toLowerCase() != "null")
              ? d
              : ((un.isNotEmpty && un.toLowerCase() != "null") ? un : "team_leader_fallback".tr());
          final avatar = (u["avatar_url"] ?? u["photo_url"] ?? "").toString();
          if (id.isNotEmpty) {
            leaderNameById[id] = name;
            leaderAvatarById[id] = avatar;
          }
          if (uid.isNotEmpty) {
            leaderNameById[uid] = name;
            leaderAvatarById[uid] = avatar;
          }
        }
      } catch (e) {
        debugPrint("[TeamService] leader fetch error: $e");
      }
    }

    final enriched = rows.map((rawRow) {
      final tid = (rawRow["id"] ?? "").toString();
      final leaderId = (rawRow["leader_id"] ?? rawRow["leaderId"] ?? "").toString();

      var members = List<String>.from(membersByTeam[tid] ?? <String>[]);
      var memberDetails = List<Map<String, dynamic>>.from(memberDetailsByTeam[tid] ?? <Map<String, dynamic>>[]);
      
      if (members.isEmpty && leaderId.isNotEmpty) {
        members = [leaderId];
        memberDetails = [{
          'id': leaderId,
          'name': leaderNameById[leaderId] ?? 'Leader',
          'avatar': leaderAvatarById[leaderId] ?? '',
          'role': 'owner',
        }];
      }

      final pending = List<String>.from(pendingByTeam[tid] ?? <String>[]);

      final fallbackLeaderName =
          (rawRow["leader_name"] ?? rawRow["leaderId"] ?? "").toString().trim();
      final leaderName = leaderNameById[leaderId] ??
          (fallbackLeaderName.isNotEmpty ? fallbackLeaderName : "team_leader_fallback".tr());
      final leaderAvatar = leaderAvatarById[leaderId] ??
          (rawRow["leader_avatar"] ?? rawRow["leaderAvatar"] ?? "").toString();

      final mapCopy = Map<String, dynamic>.from(rawRow);
      mapCopy["members"] = members;
      mapCopy["member_details"] = memberDetails;
      mapCopy["memberDetails"] = memberDetails;
      mapCopy["pending_join_requests"] = pending;
      mapCopy["pendingJoinRequests"] = pending;
      mapCopy["join_requests"] = pending;
      mapCopy["leader_name"] = leaderName;
      mapCopy["leaderName"] = leaderName;
      mapCopy["leader_avatar"] = leaderAvatar;
      mapCopy["leaderAvatar"] = leaderAvatar;

      final t = TeamModel.fromSupabase(mapCopy);
      return t.copyWith(
        members: members,
        memberDetails: memberDetails,
        leaderName: leaderName,
        leaderAvatar: leaderAvatar,
      );
    }).toList();

    var filtered = enriched;
    if (gameFilter != null &&
        gameFilter.isNotEmpty &&
        gameFilter != "All" &&
        gameFilter != "all_games".tr()) {
      filtered = filtered
          .where((t) => t.game.toLowerCase() == gameFilter.toLowerCase())
          .toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      filtered = filtered
          .where((t) =>
              t.name.toLowerCase().contains(q) ||
              t.tag.toLowerCase().contains(q))
          .toList();
    }
    return filtered;
  }

  /// Get stream of all teams with optional game filter and search query
  Stream<List<TeamModel>> getTeamsStream({
    String? gameFilter,
    String? searchQuery,
  }) async* {
    while (true) {
      try {
        final list = await _fetchAllTeamsEnriched(
          gameFilter: gameFilter,
          searchQuery: searchQuery,
        );
        yield list;
      } catch (e) {
        debugPrint("[TeamService] getTeamsStream error: $e");
      }
      await Future.delayed(const Duration(seconds: 4));
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
      final authUserId = SupabaseService.client.auth.currentUser?.id;

      if (authUserId == null || authUserId.isEmpty) {
        throw Exception('err_user_not_authenticated'.tr());
      }

      final effectiveLeaderId = authUserId;

      String logoUrl = "";
      if (logoFile != null) {
        final uploaded = await SupabaseService.uploadFile(
          file: logoFile,
          folder: "team_logos",
          bucket: SupabaseService.bucketTeamLogos,
        );
        if (uploaded != null) logoUrl = uploaded;
      }

      final teamUuid = SupabaseService.toUuid(
          DateTime.now().millisecondsSinceEpoch.toString());
      final now = DateTime.now().toIso8601String();

      final row = {
        "id": teamUuid,
        "name": name.trim(),
        "tag": tag.trim().toUpperCase(),
        "logo_url": logoUrl,
        "game": game,
        "description": description.trim(),
        "requirements": requirements.trim(),
        "leader_id": effectiveLeaderId,
        "wins": 0,
        "losses": 0,
        "draws": 0,
        "points": 0,
        "created_at": now,
      };

      await SupabaseService.client.from("teams").insert(row);

      try {
        await SupabaseService.client.from("team_members").insert({
          "team_id": teamUuid,
          "user_id": effectiveLeaderId,
          "role": "owner",
          "joined_at": now,
        });
      } catch (e) {
        debugPrint("[TeamService] team_members insert note: $e");
      }

      debugPrint("[TeamService] ✅ Team created: $teamUuid");
      return teamUuid;
    } catch (e) {
      debugPrint("[TeamService] createTeam error: $e");
      rethrow;
    }
  }

  /// Update Team Details
  Future<void> updateTeam({
    required String teamId,
    required String name,
    required String tag,
    File? logoFile,
    required String description,
    required String requirements,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        "name": name.trim(),
        "tag": tag.trim().toUpperCase(),
        "description": description.trim(),
        "requirements": requirements.trim(),
      };

      if (logoFile != null) {
        final uploaded = await SupabaseService.uploadFile(
          file: logoFile,
          folder: "team_logos",
          bucket: SupabaseService.bucketTeamLogos,
        );
        if (uploaded != null) {
          updates["logo_url"] = uploaded;
        }
      }

      await SupabaseService.client
          .from("teams")
          .update(updates)
          .eq("id", teamId);
    } catch (e) {
      debugPrint("[TeamService] updateTeam error: $e");
      rethrow;
    }
  }

  /// Delete Team
  Future<void> deleteTeam(String teamId, String userId) async {
    try {
      await SupabaseService.client
          .from("team_members")
          .delete()
          .eq("team_id", teamId);

      await SupabaseService.client
          .from("teams")
          .delete()
          .eq("id", teamId)
          .eq("leader_id", userId);
    } catch (e) {
      debugPrint("[TeamService] deleteTeam error: $e");
      rethrow;
    }
  }

  /// Request to join a team
  Future<void> requestToJoinTeam(String teamId, String userId) async {
    try {
      await SupabaseService.client.from("team_join_requests").upsert({
        "team_id": teamId,
        "user_id": userId,
        "status": "pending",
        "created_at": DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("[TeamService] requestToJoinTeam error: $e");
      rethrow;
    }
  }

  /// Cancel join request
  Future<void> cancelJoinRequest(String teamId, String userId) async {
    try {
      await SupabaseService.client
          .from("team_join_requests")
          .delete()
          .eq("team_id", teamId)
          .eq("user_id", userId);
    } catch (e) {
      debugPrint("[TeamService] cancelJoinRequest error: $e");
      rethrow;
    }
  }

  /// Accept join request
  Future<void> acceptJoinRequest(String teamId, String userId) async {
    try {
      await SupabaseService.client
          .from("team_join_requests")
          .update({"status": "accepted"})
          .eq("team_id", teamId)
          .eq("user_id", userId);

      await SupabaseService.client.from("team_members").insert({
        "team_id": teamId,
        "user_id": userId,
        "role": "member",
        "joined_at": DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("[TeamService] acceptJoinRequest error: $e");
      rethrow;
    }
  }

  /// Reject join request
  Future<void> rejectJoinRequest(String teamId, String userId) async {
    try {
      await SupabaseService.client
          .from("team_join_requests")
          .update({"status": "rejected"})
          .eq("team_id", teamId)
          .eq("user_id", userId);
    } catch (e) {
      debugPrint("[TeamService] rejectJoinRequest error: $e");
      rethrow;
    }
  }
}
