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

    // 1. Fetch members from team_members table
    final members = <String>[];
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
          .select("user_id")
          .or("team_id.eq.$teamUuid,team_id.eq.$teamId");
      for (final m in memberRows) {
        final uid = (m["user_id"] ?? "").toString().trim();
        if (uid.isNotEmpty && !members.contains(uid)) {
          members.add(uid);
        }
      }
    } catch (e) {
      debugPrint("[TeamService] getTeam members fetch error: $e");
    }

    final leaderId = (rawRow["leader_id"] ?? rawRow["leaderId"] ?? "").toString().trim();
    if (members.isEmpty && leaderId.isNotEmpty) {
      members.add(leaderId);
    }

    // 2. Fetch pending join requests from team_join_requests table
    final pendingRequests = <String>[];
    if (rawRow["pending_join_requests"] is List) {
      for (final r in (rawRow["pending_join_requests"] as List)) {
        final uid = r.toString().trim();
        if (uid.isNotEmpty && !pendingRequests.contains(uid)) {
          pendingRequests.add(uid);
        }
      }
    }
    try {
      final reqRows = await SupabaseService.client
          .from("team_join_requests")
          .select("user_id, status")
          .or("team_id.eq.$teamUuid,team_id.eq.$teamId");
      for (final r in reqRows) {
        final status = (r["status"] ?? "pending").toString().toLowerCase();
        final uid = (r["user_id"] ?? "").toString().trim();
        if (uid.isNotEmpty &&
            status == "pending" &&
            !members.contains(uid) &&
            !pendingRequests.contains(uid)) {
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
            .select("id, uid, display_name, username, avatar_url")
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
          final av = (userRes["avatar_url"] ?? "").toString().trim();
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
    final Map<String, List<String>> pendingByTeam = {};

    if (teamIds.isNotEmpty) {
      try {
        final memberRows = await SupabaseService.client
            .from("team_members")
            .select("team_id, user_id, role")
            .inFilter("team_id", teamIds);
        for (final m in memberRows) {
          final tid = (m["team_id"] ?? "").toString();
          final uid = (m["user_id"] ?? "").toString();
          if (tid.isEmpty || uid.isEmpty) continue;
          final list = membersByTeam.putIfAbsent(tid, () => []);
          if (!list.contains(uid)) list.add(uid);
        }
      } catch (e) {
        debugPrint("[TeamService] members fetch error: $e");
      }

      try {
        final reqRows = await SupabaseService.client
            .from("team_join_requests")
            .select("team_id, user_id, status")
            .inFilter("team_id", teamIds);
        for (final r in reqRows) {
          final tid = (r["team_id"] ?? "").toString();
          final uid = (r["user_id"] ?? "").toString();
          final status = (r["status"] ?? "pending").toString().toLowerCase();
          if (tid.isEmpty || uid.isEmpty || status != "pending") continue;
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
            .select("id, uid, display_name, username, avatar_url")
            .inFilter("id", leaderIds);
        for (final u in userRows) {
          final id = (u["id"] ?? "").toString();
          final uid = (u["uid"] ?? "").toString();
          final d = (u["display_name"] ?? "").toString().trim();
          final un = (u["username"] ?? "").toString().trim();
          final name = (d.isNotEmpty && d.toLowerCase() != "null")
              ? d
              : ((un.isNotEmpty && un.toLowerCase() != "null") ? un : "team_leader_fallback".tr());
          final avatar = (u["avatar_url"] ?? "").toString();
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
      if (members.isEmpty && leaderId.isNotEmpty) {
        members = [leaderId];
      }

      final pending = List<String>.from(pendingByTeam[tid] ?? <String>[]);
      if (rawRow["pending_join_requests"] is List) {
        for (final p in (rawRow["pending_join_requests"] as List)) {
          final pStr = p.toString().trim();
          if (pStr.isNotEmpty && !pending.contains(pStr) && !members.contains(pStr)) {
            pending.add(pStr);
          }
        }
      }

      final fallbackLeaderName =
          (rawRow["leader_name"] ?? rawRow["leaderName"] ?? "").toString().trim();
      final leaderName = leaderNameById[leaderId] ??
          (fallbackLeaderName.isNotEmpty ? fallbackLeaderName : "team_leader_fallback".tr());
      final leaderAvatar = leaderAvatarById[leaderId] ??
          (rawRow["leader_avatar"] ?? rawRow["leaderAvatar"] ?? "").toString();

      final mapCopy = Map<String, dynamic>.from(rawRow);
      mapCopy["members"] = members;
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

      final activeMatches = await SupabaseService.client
          .from("active_matches")
          .select("id")
          .or("team1_id.eq.$teamUuid,team2_id.eq.$teamUuid")
          .inFilter("status", ["active", "under_review"]);

      if (activeMatches.isNotEmpty) {
        return "active_match";
      }

      try {
        await SupabaseService.client
            .from("challenges")
            .delete()
            .eq("from_team_id", teamUuid);
      } catch (_) {}
      try {
        await SupabaseService.client
            .from("challenges")
            .delete()
            .eq("to_team_id", teamUuid);
      } catch (_) {}
      try {
        await SupabaseService.client
            .from("team_join_requests")
            .delete()
            .eq("team_id", teamUuid);
      } catch (_) {}
      try {
        await SupabaseService.client
            .from("team_members")
            .delete()
            .eq("team_id", teamUuid);
      } catch (_) {}

      await SupabaseService.client
          .from("teams")
          .delete()
          .or("id.eq.$teamUuid,id.eq.$teamId");
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
    if (teamId.isEmpty || userId.isEmpty) return false;
    try {
      final teamUuid = SupabaseService.toUuid(teamId);
      final userUuid = SupabaseService.toUuid(userId);
      final nowIso = DateTime.now().toIso8601String();

      // 1. Check if request already exists in team_join_requests
      final existing = await SupabaseService.client
          .from("team_join_requests")
          .select("id")
          .eq("team_id", teamUuid)
          .eq("user_id", userUuid)
          .maybeSingle();

      if (existing == null) {
        await SupabaseService.client.from("team_join_requests").insert({
          "team_id": teamUuid,
          "user_id": userUuid,
          "status": "pending",
          "created_at": nowIso,
        });
      } else {
        await SupabaseService.client
            .from("team_join_requests")
            .update({"status": "pending", "created_at": nowIso})
            .eq("team_id", teamUuid)
            .eq("user_id", userUuid);
      }

      // 2. Sync pending_join_requests column on teams table (if column exists)
      String leaderId = "";
      String resolvedTeamName = teamName ?? 'team_default_name'.tr();
      try {
        final teamRow = await SupabaseService.client
            .from("teams")
            .select()
            .or("id.eq.$teamUuid,id.eq.$teamId")
            .maybeSingle();

        if (teamRow != null) {
          leaderId = (teamRow["leader_id"] ?? teamRow["leaderId"] ?? "").toString();
          if (teamName == null || teamName.isEmpty) {
            resolvedTeamName = (teamRow["name"] ?? 'team_default_name'.tr()).toString();
          }

          if (teamRow.containsKey("pending_join_requests")) {
            final currentList = List<String>.from(
              (teamRow["pending_join_requests"] as List? ?? []).map((e) => e.toString()),
            );
            if (!currentList.contains(userUuid)) {
              currentList.add(userUuid);
            }
            await SupabaseService.client
                .from("teams")
                .update({"pending_join_requests": currentList})
                .eq("id", teamUuid);
          }
        }
      } catch (e) {
        debugPrint("[TeamService] teams pending_join_requests sync note: $e");
      }

      // 3. Send notification to Team Leader
      if (leaderId.isNotEmpty && leaderId != userUuid && leaderId != userId) {
        try {
          final senderDisplay = (userName != null && userName.trim().isNotEmpty)
              ? userName.trim()
              : 'notif_a_gamer'.tr();
          await SupabaseService.client.from("notifications").insert({
            "user_id": SupabaseService.toUuid(leaderId),
            "sender_id": userUuid,
            "sender_name": senderDisplay,
            "type": "team_join_request",
            "title": 'notif_team_join_request_title'.tr(),
            "body": 'notif_team_join_request_body'.tr(args: [senderDisplay, resolvedTeamName]),
            "is_read": false,
            "data": {
              "team_id": teamUuid,
              "user_id": userUuid,
            },
            "created_at": nowIso,
          });
        } catch (e) {
          debugPrint("[TeamService] join notification note: $e");
        }
      }

      return true;
    } catch (e) {
      debugPrint("[TeamService] requestToJoinTeam error: $e");
      return false;
    }
  }

  /// Cancel join request sent by user
  Future<bool> cancelJoinRequest({
    required String teamId,
    required String userId,
  }) async {
    if (teamId.isEmpty || userId.isEmpty) return false;
    try {
      final teamUuid = SupabaseService.toUuid(teamId);
      final userUuid = SupabaseService.toUuid(userId);

      // 1. Delete from team_join_requests table
      await SupabaseService.client
          .from("team_join_requests")
          .delete()
          .or("team_id.eq.$teamUuid,team_id.eq.$teamId")
          .or("user_id.eq.$userUuid,user_id.eq.$userId");

      // 2. Remove user from pending_join_requests array in teams table if present
      try {
        final teamRow = await SupabaseService.client
            .from("teams")
            .select()
            .or("id.eq.$teamUuid,id.eq.$teamId")
            .maybeSingle();

        if (teamRow != null && teamRow.containsKey("pending_join_requests")) {
          final pendingList = List<String>.from(
            (teamRow["pending_join_requests"] as List? ?? []).map((e) => e.toString()),
          )..removeWhere((id) => id == userUuid || id == userId);

          await SupabaseService.client
              .from("teams")
              .update({"pending_join_requests": pendingList})
              .eq("id", teamUuid);
        }
      } catch (e) {
        debugPrint("[TeamService] cancelJoinRequest teams sync note: $e");
      }

      debugPrint("[TeamService] ✅ Join request cancelled for user $userId in team $teamId");
      return true;
    } catch (e) {
      debugPrint("[TeamService] cancelJoinRequest error: $e");
      return false;
    }
  }

  /// Accept join request
  Future<bool> acceptJoinRequest({
    required String teamId,
    required String userId,
    String? userName,
  }) async {
    if (teamId.isEmpty || userId.isEmpty) return false;
    try {
      final teamUuid = SupabaseService.toUuid(teamId);
      final userUuid = SupabaseService.toUuid(userId);
      final nowIso = DateTime.now().toIso8601String();

      // 1. Check if already in team_members
      final existingMember = await SupabaseService.client
          .from("team_members")
          .select("user_id")
          .eq("team_id", teamUuid)
          .eq("user_id", userUuid)
          .maybeSingle();

      if (existingMember == null) {
        await SupabaseService.client.from("team_members").insert({
          "team_id": teamUuid,
          "user_id": userUuid,
          "role": "member",
          "joined_at": nowIso,
        });
      }

      // 2. Delete from team_join_requests
      await SupabaseService.client
          .from("team_join_requests")
          .delete()
          .or("team_id.eq.$teamUuid,team_id.eq.$teamId")
          .or("user_id.eq.$userUuid,user_id.eq.$userId");

      // 3. Sync teams table columns if present
      String teamName = 'team_default_name'.tr();
      try {
        final teamRow = await SupabaseService.client
            .from("teams")
            .select()
            .or("id.eq.$teamUuid,id.eq.$teamId")
            .maybeSingle();
        if (teamRow != null) {
          teamName = (teamRow["name"] ?? 'team_default_name'.tr()).toString();
          final updates = <String, dynamic>{};

          if (teamRow.containsKey("pending_join_requests")) {
            final pendingList = List<String>.from(
              (teamRow["pending_join_requests"] as List? ?? []).map((e) => e.toString()),
            )..removeWhere((id) => id == userUuid || id == userId);
            updates["pending_join_requests"] = pendingList;
          }

          if (teamRow.containsKey("members")) {
            final membersList = List<String>.from(
              (teamRow["members"] as List? ?? []).map((e) => e.toString()),
            );
            if (!membersList.contains(userUuid)) {
              membersList.add(userUuid);
            }
            updates["members"] = membersList;
          }

          if (updates.isNotEmpty) {
            await SupabaseService.client
                .from("teams")
                .update(updates)
                .eq("id", teamUuid);
          }
        }
      } catch (_) {}

      // 4. Notify accepted player
      try {
        await SupabaseService.client.from("notifications").insert({
          "user_id": userUuid,
          "type": "team_join_accepted",
          "title": 'notif_team_approved_title'.tr(),
          "body": 'notif_team_approved_body'.tr(args: [teamName]),
          "is_read": false,
          "data": {"team_id": teamUuid},
          "created_at": nowIso,
        });
      } catch (_) {}

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
    if (teamId.isEmpty || userId.isEmpty) return false;
    try {
      final teamUuid = SupabaseService.toUuid(teamId);
      final userUuid = SupabaseService.toUuid(userId);

      await SupabaseService.client
          .from("team_join_requests")
          .delete()
          .or("team_id.eq.$teamUuid,team_id.eq.$teamId")
          .or("user_id.eq.$userUuid,user_id.eq.$userId");

      try {
        final teamRow = await SupabaseService.client
            .from("teams")
            .select()
            .or("id.eq.$teamUuid,id.eq.$teamId")
            .maybeSingle();
        if (teamRow != null && teamRow.containsKey("pending_join_requests")) {
          final pendingList = List<String>.from(
            (teamRow["pending_join_requests"] as List? ?? []).map((e) => e.toString()),
          )..removeWhere((id) => id == userUuid || id == userId);
          await SupabaseService.client
              .from("teams")
              .update({"pending_join_requests": pendingList})
              .eq("id", teamUuid);
        }
      } catch (_) {}

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
}) =>
    TeamService().updateTeam(
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
}) =>
    TeamService().deleteTeam(
      teamId: teamId,
      currentUserId: currentUserId,
    );
