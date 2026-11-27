import "dart:io";
import "dart:async";
import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../models/team_model.dart";
import "supabase_service.dart";
import "gamer_auth_service.dart";
import "coin_wallet_service.dart";
import "notification_service.dart";

/// Service to manage teams in Supabase
class TeamService {
  static final TeamService _instance = TeamService._internal();
  factory TeamService() => _instance;
  TeamService._internal();

  static const int maxTeamMembers = TeamModel.maxMembers; // 4 members max
  static const int weeklyGameRewardPkr = 1500; // 1,500 PKR equivalent in-game currency per game every week (updated from 3,000 PKR)
  static const int weeklyGameRewardPool = 1500; // 1,500 PKR equivalent prize pool per game
  static const List<String> supportedGames = [
    'Free Fire',
    'PUBG Mobile',
  ];

  /// Returns the in-game currency name for a supported weekly game
  static String getGameCurrencyLabel(String game) {
    if (matchesGameName(game, 'PUBG Mobile')) {
      return 'PUBG UC';
    }
    return 'Free Fire Diamonds';
  }

  /// Calculates each active member's equal PKR-equivalent share of the 1,500 PKR weekly #1 team prize
  static int getEqualPkrShare(int memberCount) {
    final clamped = memberCount.clamp(1, maxTeamMembers);
    return (weeklyGameRewardPkr / clamped).floor();
  }

  /// Checks whether [game] is one of the two weekly competition games (Free Fire or PUBG)
  static bool isWeeklyCompetitionGame(String game) {
    return matchesGameName(game, 'Free Fire') || matchesGameName(game, 'PUBG Mobile');
  }

  final Map<String, List<TeamModel>> _userTeamsCache = {};
  final Map<String, TeamModel> _teamsByIdCache = {};
  final Map<String, Map<String, dynamic>> _teamWeeklyStatsCache = {};
  final Map<String, List<Map<String, dynamic>>> _gameLeaderboardCache = {};

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValidUuid(String value) => _uuidRegex.hasMatch(value.trim());

  void _storeTeamCache(TeamModel team) {
    final clean = team.id.trim();
    if (clean.isEmpty) return;
    final uuid = SupabaseService.toUuid(clean);
    _teamsByIdCache[clean] = team;
    _teamsByIdCache[clean.toLowerCase()] = team;
    _teamsByIdCache[uuid] = team;
    _teamsByIdCache[uuid.toLowerCase()] = team;
  }

  /// Returns cached TeamModel by [teamId], or null if not yet cached in memory.
  TeamModel? getCachedTeam(String teamId) {
    final clean = teamId.trim();
    if (clean.isEmpty) return null;
    final uuid = SupabaseService.toUuid(clean);
    return _teamsByIdCache[clean] ??
        _teamsByIdCache[clean.toLowerCase()] ??
        _teamsByIdCache[uuid] ??
        _teamsByIdCache[uuid.toLowerCase()];
  }

  /// Returns cached active teams for [userId], or null if not yet fetched in this session.
  List<TeamModel>? getCachedUserTeams(String userId) {
    final clean = userId.trim();
    if (clean.isEmpty) return null;
    return _userTeamsCache[clean] ??
        _userTeamsCache[clean.toLowerCase()] ??
        _userTeamsCache[SupabaseService.toUuid(clean)] ??
        _userTeamsCache[SupabaseService.toUuid(clean).toLowerCase()];
  }

  /// Returns cached weekly coin stats for [teamId], or null if not yet fetched.
  Map<String, dynamic>? getCachedTeamWeeklyStats(String teamId) {
    final clean = teamId.trim();
    if (clean.isEmpty) return null;
    final uuidLower = SupabaseService.toUuid(clean).toLowerCase();
    return _teamWeeklyStatsCache[clean] ??
        _teamWeeklyStatsCache[clean.toLowerCase()] ??
        _teamWeeklyStatsCache[uuidLower];
  }

  void _storeTeamWeeklyStatsCache(String teamId, Map<String, dynamic> stats) {
    final clean = teamId.trim();
    if (clean.isEmpty) return;
    final uuid = SupabaseService.toUuid(clean);
    _teamWeeklyStatsCache[clean] = stats;
    _teamWeeklyStatsCache[clean.toLowerCase()] = stats;
    _teamWeeklyStatsCache[uuid] = stats;
    _teamWeeklyStatsCache[uuid.toLowerCase()] = stats;
  }

  /// Returns cached per-game weekly leaderboard for [game], or null if not yet fetched.
  List<Map<String, dynamic>>? getCachedGameWeeklyLeaderboard(String game) {
    final clean = game.trim();
    return _gameLeaderboardCache[clean] ?? _gameLeaderboardCache[clean.toLowerCase()];
  }

  /// Clears all weekly team stats, leaderboard, and user team caches so fresh post-reset totals load immediately.
  void invalidateWeeklyCaches() {
    _teamWeeklyStatsCache.clear();
    _gameLeaderboardCache.clear();
    _userTeamsCache.clear();
  }

  /// Parses an ISO timestamp string into UTC epoch milliseconds (0 if invalid/empty).
  static int parseUtcMs(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return 0;
    final dt = DateTime.tryParse(s);
    if (dt == null) return 0;
    return dt.toUtc().millisecondsSinceEpoch;
  }

  /// Extracts the UTC `delivered_at` timestamp from a reward claim map
  /// (falling back to `updated_at` or `created_at` only if `delivered_at` is absent).
  static DateTime? parseDeliveredAtUtc(Map<String, dynamic>? claim) {
    if (claim == null) return null;
    for (final key in const ['delivered_at', 'updated_at', 'created_at']) {
      final raw = (claim[key] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed.toUtc();
      }
    }
    return null;
  }

  /// Returns true when [claim] has status `Delivered` and at least 24 hours have passed
  /// since `delivered_at` (`DateTime.now().toUtc().difference(deliveredAt) >= Duration(hours: 24)`).
  static bool isDeliveredClaimExpired24h(
    Map<String, dynamic>? claim, {
    DateTime? nowUtc,
  }) {
    if (claim == null) return false;
    final String status =
        (claim['status'] ?? '').toString().trim().toLowerCase();
    if (status != 'delivered') return false;
    final DateTime? deliveredAt = parseDeliveredAtUtc(claim);
    if (deliveredAt == null) return false;
    final DateTime referenceUtc = (nowUtc ?? DateTime.now()).toUtc();
    return referenceUtc.difference(deliveredAt) >= const Duration(hours: 24);
  }

  /// Evaluates whether [team] has completed a delivered weekly reward cycle in [weekKey]
  /// based on [allClaims] from `public.reward_claims`.
  /// When a team's submitted weekly reward claim(s) are marked 'delivered' (and no older
  /// 'pending' claims from that batch remain waiting for delivery), all coin contributions
  /// from before `cutoffUtcMs` are reset to 0 so the next round/week starts cleanly from 0.
  static Map<String, dynamic> evaluateTeamRewardCycleReset({
    required TeamModel team,
    required List<Map<String, dynamic>> allClaims,
    String? weekKey,
  }) {
    final String targetWeekKey = (weekKey ?? getWeekCycleKey()).trim();
    final String rawTid = team.id.trim().toLowerCase();
    final String tidUuid =
        rawTid.isNotEmpty ? SupabaseService.toUuid(team.id.trim()).toLowerCase() : '';
    final String teamGameKey = normalizeGameKey(team.game);
    final String teamFullNameLower = '${team.name.trim()} [${team.tag.trim()}]'.toLowerCase();
    final String teamNameLower = team.name.trim().toLowerCase();

    final Set<String> memberIdsLower = {};
    if (team.leaderId.trim().isNotEmpty) {
      final lid = team.leaderId.trim();
      memberIdsLower.add(lid.toLowerCase());
      memberIdsLower.add(SupabaseService.toUuid(lid).toLowerCase());
    }
    for (final m in team.cappedMembers) {
      final mid = m.trim();
      if (mid.isNotEmpty) {
        memberIdsLower.add(mid.toLowerCase());
        memberIdsLower.add(SupabaseService.toUuid(mid).toLowerCase());
      }
    }

    final List<Map<String, dynamic>> teamClaims = [];
    for (final c in allClaims) {
      final String status = (c['status'] ?? 'pending').toString().trim().toLowerCase();
      if (status == 'rejected') continue;

      final String cGameRaw = (c['game_name'] ?? '').toString().trim();
      if (cGameRaw.isNotEmpty && normalizeGameKey(cGameRaw) != teamGameKey) {
        continue;
      }

      final String cWeek = (c['week_key'] ?? '').toString().trim();
      if (cWeek.isNotEmpty &&
          cWeek != targetWeekKey &&
          !cWeek.startsWith(targetWeekKey)) {
        continue;
      }

      final String cTid = (c['team_id'] ?? '').toString().trim().toLowerCase();
      final String cTidUuid =
          cTid.isNotEmpty ? SupabaseService.toUuid(cTid).toLowerCase() : '';
      final String cTeamName = (c['team_name'] ?? '').toString().trim().toLowerCase();
      final String cUid = (c['user_id'] ?? '').toString().trim().toLowerCase();
      final String cUidUuid =
          cUid.isNotEmpty ? SupabaseService.toUuid(cUid).toLowerCase() : '';

      bool matchesTeam = false;
      if (cTid.isNotEmpty &&
          (cTid == rawTid || cTid == tidUuid || (tidUuid.isNotEmpty && cTidUuid == tidUuid))) {
        matchesTeam = true;
      } else if (cTeamName.isNotEmpty &&
          (cTeamName == teamFullNameLower || cTeamName == teamNameLower)) {
        matchesTeam = true;
      } else if ((cTid.isEmpty || cTid == rawTid || cTidUuid == tidUuid) &&
          (memberIdsLower.contains(cUid) || memberIdsLower.contains(cUidUuid))) {
        matchesTeam = true;
      }

      if (matchesTeam) {
        teamClaims.add(c);
      }
    }

    int latestDeliveredMs = 0;
    int deliveredCount = 0;
    for (final c in teamClaims) {
      final String status = (c['status'] ?? 'pending').toString().trim().toLowerCase();
      if (status == 'delivered') {
        deliveredCount++;
        final int delMs = parseUtcMs(c['delivered_at']);
        final int updMs = parseUtcMs(c['updated_at']);
        final int creMs = parseUtcMs(c['created_at']);
        int bestMs = delMs > 0 ? delMs : (updMs > 0 ? updMs : creMs);
        if (creMs > bestMs) bestMs = creMs;
        if (bestMs <= 0) {
          bestMs = 1;
        }
        if (bestMs > latestDeliveredMs) {
          latestDeliveredMs = bestMs;
        }
      }
    }

    bool hasUnfinishedPendingInBatch = false;
    if (deliveredCount > 0) {
      for (final c in teamClaims) {
        final String status = (c['status'] ?? 'pending').toString().trim().toLowerCase();
        if (status == 'pending') {
          final int creMs = parseUtcMs(c['created_at']);
          if (creMs <= 0 || creMs <= latestDeliveredMs) {
            hasUnfinishedPendingInBatch = true;
            break;
          }
        }
      }
    }

    final bool hasCompletedDeliveredRound =
        deliveredCount > 0 && !hasUnfinishedPendingInBatch;
    final DateTime? latestDeliveredAtUtc = latestDeliveredMs > 1
        ? DateTime.fromMillisecondsSinceEpoch(latestDeliveredMs, isUtc: true)
        : null;
    final bool isDeliveredExpired24h = hasCompletedDeliveredRound &&
        latestDeliveredAtUtc != null &&
        DateTime.now().toUtc().difference(latestDeliveredAtUtc) >=
            const Duration(hours: 24);

    return {
      'hasCompletedDeliveredRound': hasCompletedDeliveredRound,
      'hasReset': hasCompletedDeliveredRound,
      'cutoffUtcMs': hasCompletedDeliveredRound ? latestDeliveredMs : 0,
      'deliveredCount': deliveredCount,
      'latestDeliveredAtUtc': latestDeliveredAtUtc?.toIso8601String(),
      'isDeliveredExpired24h': isDeliveredExpired24h,
    };
  }

  /// Canonical snake_case game key ('free_fire' or 'pubg_mobile')
  static String normalizeGameKey(String game) {
    return TeamModel.normalizeGameKey(game);
  }

  /// Clean display game label ('Free Fire' or 'PUBG Mobile', never 'BGMI')
  static String displayGameLabel(String game) {
    return TeamModel.normalizeDisplayGameName(game);
  }

  /// Normalizes game names so e.g. 'PUBG', 'BGMI', 'pubg_mobile', and 'PUBG Mobile'
  /// or 'Free Fire' and 'free_fire' match accurately.
  static bool matchesGameName(String teamGame, String targetGame) {
    final a = teamGame.trim().toLowerCase();
    final b = targetGame.trim().toLowerCase();
    if (a == b) return true;
    const pubgAliases = {'pubg', 'pubg mobile', 'pubg_mobile', 'bgmi'};
    if (pubgAliases.contains(a) && pubgAliases.contains(b)) {
      return true;
    }
    const freeFireAliases = {
      'free fire',
      'free_fire',
      'free fire max',
      'garena free fire',
    };
    if (freeFireAliases.contains(a) && freeFireAliases.contains(b)) {
      return true;
    }
    if ((a == 'cod' || a == 'cod mobile') && (b == 'cod' || b == 'cod mobile')) {
      return true;
    }
    return false;
  }

  /// Privacy & Data Minimization (Play Policy):
  /// Never expose email addresses, phone numbers, real names/addresses, or private credentials.
  static String sanitizePublicHandle(String? raw, {String fallback = "Gamer"}) {
    return TeamModel.sanitizePublicHandle(raw, fallback: fallback);
  }

  /// Helper to enrich a single raw team row with members (max 4), pending join requests, and leader info
  Future<TeamModel> _enrichTeamRow(Map<String, dynamic> rawRow) async {
    final teamId = (rawRow["id"] ?? "").toString().trim();
    final teamUuid = SupabaseService.toUuid(teamId);
    final bool teamIdIsUuid = isValidUuid(teamId);

    final leaderId = (rawRow["leader_id"] ?? rawRow["leaderId"] ?? "").toString().trim();

    // 1. Fetch members from team_members table (strictly capped at 4 members, leader first)
    final members = <String>[];
    if (leaderId.isNotEmpty) {
      members.add(leaderId);
    }
    if (rawRow["members"] is List) {
      for (final m in (rawRow["members"] as List)) {
        final uid = m.toString().trim();
        if (uid.isNotEmpty && !members.contains(uid) && members.length < maxTeamMembers) {
          members.add(uid);
        }
      }
    }
    try {
      List<dynamic> memberRows = [];
      if (teamIdIsUuid) {
        memberRows = await SupabaseService.client
            .from("team_members")
            .select("user_id")
            .eq("team_id", teamId);
      } else {
        try {
          memberRows = await SupabaseService.client
              .from("team_members")
              .select("user_id")
              .eq("team_id", teamUuid);
        } catch (_) {}
        if (memberRows.isEmpty && teamId.isNotEmpty) {
          try {
            memberRows = await SupabaseService.client
                .from("team_members")
                .select("user_id")
                .eq("team_id", teamId);
          } catch (_) {}
        }
      }
      for (final m in memberRows) {
        final uid = (m["user_id"] ?? "").toString().trim();
        if (uid.isNotEmpty && !members.contains(uid) && members.length < maxTeamMembers) {
          members.add(uid);
        }
      }
    } catch (e) {
      debugPrint("[TeamService] getTeam members fetch error: $e");
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
      List<dynamic> reqRows = [];
      if (teamIdIsUuid) {
        reqRows = await SupabaseService.client
            .from("team_join_requests")
            .select("user_id, status")
            .eq("team_id", teamId);
      } else {
        try {
          reqRows = await SupabaseService.client
              .from("team_join_requests")
              .select("user_id, status")
              .eq("team_id", teamUuid);
        } catch (_) {}
        if (reqRows.isEmpty && teamId.isNotEmpty) {
          try {
            reqRows = await SupabaseService.client
                .from("team_join_requests")
                .select("user_id, status")
                .eq("team_id", teamId);
          } catch (_) {}
        }
      }
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

    // 3. Fetch public gaming handle & avatar from users table (Data Minimization: only public gaming handle)
    String leaderName = sanitizePublicHandle(
      (rawRow["leader_name"] ?? rawRow["leaderName"] ?? "").toString(),
      fallback: "",
    );
    String leaderAvatar = (rawRow["leader_avatar"] ?? rawRow["leaderAvatar"] ?? "").toString().trim();
    if (leaderId.isNotEmpty) {
      try {
        Map<String, dynamic>? userRes;
        final leaderUuid = SupabaseService.toUuid(leaderId);
        try {
          final rows = await SupabaseService.client
              .from("users")
              .select()
              .eq("id", isValidUuid(leaderId) ? leaderId : leaderUuid)
              .limit(1);
          if (rows.isNotEmpty) {
            userRes = Map<String, dynamic>.from(rows.first);
          }
        } catch (_) {}

        if (userRes == null && !isValidUuid(leaderId)) {
          try {
            final rows = await SupabaseService.client
                .from("users")
                .select()
                .eq("id", leaderId)
                .limit(1);
            if (rows.isNotEmpty) {
              userRes = Map<String, dynamic>.from(rows.first);
            }
          } catch (_) {}
        }

        if (userRes != null) {
          final un = (userRes["username"] ?? "").toString().trim();
          final gid = (userRes["gamer_id"] ?? userRes["game_id"] ?? "").toString().trim();
          final d = (userRes["display_name"] ?? "").toString().trim();
          if (un.isNotEmpty && un.toLowerCase() != "null") {
            leaderName = sanitizePublicHandle(un, fallback: "Leader");
          } else if (gid.isNotEmpty && gid.toLowerCase() != "null") {
            leaderName = sanitizePublicHandle(gid, fallback: "Leader");
          } else if (d.isNotEmpty && d.toLowerCase() != "null") {
            leaderName = sanitizePublicHandle(d, fallback: "Leader");
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

    final cleanLeaderHandle = leaderName.isNotEmpty ? leaderName : "Leader";

    final enrichedMap = Map<String, dynamic>.from(rawRow);
    enrichedMap["members"] = members;
    enrichedMap["pending_join_requests"] = pendingRequests;
    enrichedMap["pendingJoinRequests"] = pendingRequests;
    enrichedMap["join_requests"] = pendingRequests;
    enrichedMap["leader_name"] = cleanLeaderHandle;
    enrichedMap["leaderName"] = cleanLeaderHandle;
    enrichedMap["leader_avatar"] = leaderAvatar;
    enrichedMap["leaderAvatar"] = leaderAvatar;

    final team = TeamModel.fromSupabase(enrichedMap).copyWith(
      members: members,
      leaderName: cleanLeaderHandle,
      leaderAvatar: leaderAvatar,
    );
    _storeTeamCache(team);
    return team;
  }

  /// Get single team by ID (with safe UUID/raw ID lookup and in-memory cache fallback)
  Future<TeamModel?> getTeam(String teamId) async {
    final cleanId = teamId.trim();
    if (cleanId.isEmpty) return null;

    final teamUuid = SupabaseService.toUuid(cleanId);
    Map<String, dynamic>? matchedRow;

    // 1. Direct query using safe equality (avoids Postgrest 22P02 syntax errors on UUID/non-UUID columns)
    try {
      final rows = await SupabaseService.client
          .from("teams")
          .select()
          .eq("id", isValidUuid(cleanId) ? cleanId : teamUuid)
          .limit(1);
      if (rows.isNotEmpty) {
        matchedRow = Map<String, dynamic>.from(rows.first);
      }
    } catch (e) {
      debugPrint("[TeamService] getTeam primary eq query notice: $e");
    }

    // 2. If cleanId is not a standard UUID, also try querying by raw cleanId
    if (matchedRow == null && !isValidUuid(cleanId)) {
      try {
        final rows = await SupabaseService.client
            .from("teams")
            .select()
            .eq("id", cleanId)
            .limit(1);
        if (rows.isNotEmpty) {
          matchedRow = Map<String, dynamic>.from(rows.first);
        }
      } catch (_) {}
    }

    // 3. Fallback: scan all teams rows (same query used by TeamsScreen) to match by id or toUuid(id)
    if (matchedRow == null) {
      try {
        final allRows = await SupabaseService.client.from("teams").select();
        final cleanLower = cleanId.toLowerCase();
        final uuidLower = teamUuid.toLowerCase();
        for (final r in allRows) {
          final rid = (r["id"] ?? "").toString().trim();
          if (rid.isEmpty) continue;
          final ridLower = rid.toLowerCase();
          final ridUuidLower = SupabaseService.toUuid(rid).toLowerCase();
          if (ridLower == cleanLower ||
              ridLower == uuidLower ||
              ridUuidLower == uuidLower) {
            matchedRow = Map<String, dynamic>.from(r);
            break;
          }
        }
      } catch (e) {
        debugPrint("[TeamService] getTeam scan fallback notice: $e");
      }
    }

    if (matchedRow != null) {
      try {
        final enriched = await _enrichTeamRow(matchedRow);
        _storeTeamCache(enriched);
        return enriched;
      } catch (e) {
        debugPrint("[TeamService] _enrichTeamRow fallback notice: $e");
        final basic = TeamModel.fromSupabase(matchedRow);
        _storeTeamCache(basic);
        return basic;
      }
    }

    return getCachedTeam(cleanId);
  }

  /// Get team stream (yields cached team immediately if available, then polls + updates)
  Stream<TeamModel?> getTeamStream(String teamId) {
    return _getTeamStreamInternal(teamId).asBroadcastStream();
  }

  Stream<TeamModel?> _getTeamStreamInternal(String teamId) async* {
    final cleanId = teamId.trim();
    if (cleanId.isEmpty) {
      yield null;
      return;
    }
    final cached = getCachedTeam(cleanId);
    if (cached != null) {
      yield cached;
    }
    while (true) {
      try {
        final team = await getTeam(cleanId);
        yield team ?? getCachedTeam(cleanId);
      } catch (e) {
        debugPrint("[TeamService] getTeamStream error: $e");
        yield getCachedTeam(cleanId);
      }
      await Future.delayed(const Duration(seconds: 30));
    }
  }

  /// Get all teams where user is leader or member (enriched with weekly team coin stats & rank)
  Future<List<TeamModel>> getUserTeams(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final cleanUid = userId.trim();
      final userUuid = SupabaseService.toUuid(cleanUid);
      final teamIds = <String>{};

      try {
        final memberRows = await SupabaseService.client
            .from("team_members")
            .select("team_id")
            .or("user_id.eq.$userUuid,user_id.eq.$cleanUid");
        for (final r in memberRows) {
          final tid = r["team_id"]?.toString().trim();
          if (tid != null && tid.isNotEmpty) teamIds.add(tid);
        }
      } catch (e) {
        debugPrint("[TeamService] getUserTeams team_members notice: $e");
      }

      try {
        final squadRows = await SupabaseService.client
            .from("squad_members")
            .select()
            .or("user_id.eq.$userUuid,user_id.eq.$cleanUid");
        for (final r in squadRows) {
          final tid =
              (r["team_id"] ?? r["squad_id"])?.toString().trim();
          if (tid != null && tid.isNotEmpty) teamIds.add(tid);
        }
      } catch (_) {}

      final res = await SupabaseService.client
          .from("teams")
          .select()
          .or("leader_id.eq.$cleanUid,leader_id.eq.$userUuid");

      final rawResult = <TeamModel>[];
      final seenIds = <String>{};
      for (final r in res) {
        final t = await _enrichTeamRow(r);
        seenIds.add(t.id.toLowerCase());
        seenIds.add(SupabaseService.toUuid(t.id).toLowerCase());
        rawResult.add(t);
      }

      for (final tid in teamIds) {
        final tidLower = tid.toLowerCase();
        final tidUuidLower = SupabaseService.toUuid(tid).toLowerCase();
        if (!seenIds.contains(tidLower) && !seenIds.contains(tidUuidLower)) {
          var t = await getTeam(tid);
          if (t != null) {
            if (!t.isMember(cleanUid)) {
              final nextMembers = <String>[...t.members];
              if (!nextMembers.contains(cleanUid) &&
                  nextMembers.length < maxTeamMembers) {
                nextMembers.add(cleanUid);
              }
              t = t.copyWith(members: nextMembers);
            }
            seenIds.add(t.id.toLowerCase());
            seenIds.add(SupabaseService.toUuid(t.id).toLowerCase());
            rawResult.add(t);
          }
        }
      }

      // Attach synced weekly team coins, rank, and member breakdown so CoinWalletScreen
      // and TeamProfileScreen always show the exact same Weekly Team Coins total immediately.
      final result = <TeamModel>[];
      for (final t in rawResult) {
        try {
          final stats = await getTeamWeeklyCoinStats(t);
          final int syncedWeeklyCoins = (stats['weeklyCoins'] as num?)?.toInt() ?? t.weeklyCoins;
          final int syncedWeeklyRank = (stats['weeklyRank'] as num?)?.toInt() ?? t.weeklyRank;
          final Map<String, int> syncedMemberCoins = stats['memberCoins'] is Map
              ? (stats['memberCoins'] as Map).map(
                  (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
                )
              : t.memberWeeklyCoins;
          final Map<String, String> syncedMemberNames = stats['memberNames'] is Map
              ? (stats['memberNames'] as Map).map(
                  (k, v) => MapEntry(k.toString(), v.toString()),
                )
              : t.memberNames;
          final updatedTeam = t.copyWith(
            weeklyCoins: syncedWeeklyCoins,
            weeklyRank: syncedWeeklyRank,
            memberWeeklyCoins: syncedMemberCoins,
            memberNames: syncedMemberNames,
          );
          _storeTeamCache(updatedTeam);
          result.add(updatedTeam);
        } catch (_) {
          _storeTeamCache(t);
          result.add(t);
        }
      }

      _userTeamsCache[cleanUid] = result;
      _userTeamsCache[cleanUid.toLowerCase()] = result;
      _userTeamsCache[userUuid] = result;
      _userTeamsCache[userUuid.toLowerCase()] = result;
      return result;
    } catch (e) {
      debugPrint("[TeamService] getUserTeams error: $e");
      return getCachedUserTeams(userId) ?? [];
    }
  }

  /// Stream of user teams (includes both leader and joined member teams)
  Stream<List<TeamModel>> getUserTeamsStream(String userId) {
    return _getUserTeamsStreamInternal(userId).asBroadcastStream();
  }

  Stream<List<TeamModel>> _getUserTeamsStreamInternal(String userId) async* {
    if (userId.isEmpty) {
      yield [];
      return;
    }
    final cached = getCachedUserTeams(userId);
    if (cached != null) {
      yield cached;
    }
    while (true) {
      try {
        final teams = await getUserTeams(userId);
        yield teams;
      } catch (e) {
        debugPrint("[TeamService] getUserTeamsStream error: $e");
      }
      await Future.delayed(const Duration(seconds: 30));
    }
  }

  /// Fetch all enriched teams with optional gameFilter and searchQuery
  Future<List<TeamModel>> _fetchAllTeamsEnriched({
    String? gameFilter,
    String? searchQuery,
  }) async {
    final String currentUid = (GamerAuthService().currentUid ??
            SupabaseService.client.auth.currentUser?.id ??
            "")
        .trim();
    final String currentUuid =
        currentUid.isNotEmpty ? SupabaseService.toUuid(currentUid) : "";

    final List<Map<String, dynamic>> allRows = [];
    final Set<String> seenRowKeys = {};

    void addRawTeamRow(Map<String, dynamic> row) {
      final rawId = (row["id"] ?? "").toString().trim();
      if (rawId.isEmpty) return;
      final lower = rawId.toLowerCase();
      final uuidLower = SupabaseService.toUuid(rawId).toLowerCase();
      if (seenRowKeys.contains(lower) || seenRowKeys.contains(uuidLower)) {
        return;
      }
      seenRowKeys.add(lower);
      seenRowKeys.add(uuidLower);
      allRows.add(row);
    }

    // Track all team IDs that the current logged-in user belongs to (leader, team_members, squad_members)
    final Set<String> myJoinedTeamKeys = {};
    final Set<String> myLookupTeamIds = {};

    if (currentUid.isNotEmpty) {
      try {
        final myMemRows = await SupabaseService.client
            .from("team_members")
            .select("team_id")
            .or("user_id.eq.$currentUuid,user_id.eq.$currentUid");
        for (final r in myMemRows) {
          final tid = (r["team_id"] ?? "").toString().trim();
          if (tid.isNotEmpty) {
            myLookupTeamIds.add(tid);
            myLookupTeamIds.add(SupabaseService.toUuid(tid));
            myJoinedTeamKeys.add(tid.toLowerCase());
            myJoinedTeamKeys.add(SupabaseService.toUuid(tid).toLowerCase());
          }
        }
      } catch (_) {}

      try {
        final mySquadRows = await SupabaseService.client
            .from("squad_members")
            .select()
            .or("user_id.eq.$currentUuid,user_id.eq.$currentUid");
        for (final r in mySquadRows) {
          final tid =
              (r["team_id"] ?? r["squad_id"] ?? "").toString().trim();
          if (tid.isNotEmpty) {
            myLookupTeamIds.add(tid);
            myLookupTeamIds.add(SupabaseService.toUuid(tid));
            myJoinedTeamKeys.add(tid.toLowerCase());
            myJoinedTeamKeys.add(SupabaseService.toUuid(tid).toLowerCase());
          }
        }
      } catch (_) {}

      try {
        final myLeaderRows = await SupabaseService.client
            .from("teams")
            .select()
            .or("leader_id.eq.$currentUid,leader_id.eq.$currentUuid");
        for (final r in myLeaderRows) {
          final mapRow = Map<String, dynamic>.from(r);
          final tid = (mapRow["id"] ?? "").toString().trim();
          if (tid.isNotEmpty) {
            myJoinedTeamKeys.add(tid.toLowerCase());
            myJoinedTeamKeys.add(SupabaseService.toUuid(tid).toLowerCase());
            addRawTeamRow(mapRow);
          }
        }
      } catch (_) {}

      if (myLookupTeamIds.isNotEmpty) {
        try {
          final joinedTeamRows = await SupabaseService.client
              .from("teams")
              .select()
              .inFilter("id", myLookupTeamIds.toList());
          for (final r in joinedTeamRows) {
            addRawTeamRow(Map<String, dynamic>.from(r));
          }
        } catch (_) {}
      }
    }

    try {
      final topRows = await SupabaseService.client
          .from("teams")
          .select()
          .order("points", ascending: false)
          .limit(50);
      for (final r in topRows) {
        addRawTeamRow(Map<String, dynamic>.from(r));
      }
    } catch (e) {
      debugPrint("[TeamService] _fetchAllTeamsEnriched topRows error: $e");
    }

    if (allRows.isEmpty) return <TeamModel>[];

    // Filter rows early by gameFilter / searchQuery so we only enrich relevant teams
    final rows = allRows.where((rawRow) {
      if (gameFilter != null && gameFilter.isNotEmpty && gameFilter != "All") {
        final rowGame = (rawRow["game"] ?? "Free Fire").toString();
        if (!matchesGameName(rowGame, gameFilter)) return false;
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final name = (rawRow["name"] ?? "").toString().toLowerCase();
        final tag = (rawRow["tag"] ?? "").toString().toLowerCase();
        if (!name.contains(q) && !tag.contains(q)) return false;
      }
      return true;
    }).toList();

    if (rows.isEmpty) return <TeamModel>[];

    final lookupTeamIds = <String>{};
    for (final r in rows) {
      final id = (r["id"] ?? "").toString().trim();
      if (id.isNotEmpty) {
        lookupTeamIds.add(id);
        try {
          lookupTeamIds.add(SupabaseService.toUuid(id));
        } catch (_) {}
      }
    }

    final Map<String, List<String>> membersByTeam = {};
    final Map<String, List<String>> pendingByTeam = {};

    if (lookupTeamIds.isNotEmpty) {
      try {
        final memberRows = await SupabaseService.client
            .from("team_members")
            .select("team_id, user_id, role")
            .inFilter("team_id", lookupTeamIds.toList());
        for (final m in memberRows) {
          final tid = (m["team_id"] ?? "").toString().trim();
          final uid = (m["user_id"] ?? "").toString().trim();
          if (tid.isEmpty || uid.isEmpty) continue;
          for (final key in {
            tid,
            tid.toLowerCase(),
            SupabaseService.toUuid(tid).toLowerCase()
          }) {
            final list = membersByTeam.putIfAbsent(key, () => []);
            if (!list.contains(uid)) list.add(uid);
          }
        }
      } catch (e) {
        debugPrint("[TeamService] members fetch error: $e");
      }

      try {
        final reqRows = await SupabaseService.client
            .from("team_join_requests")
            .select("team_id, user_id, status")
            .inFilter("team_id", lookupTeamIds.toList());
        for (final r in reqRows) {
          final tid = (r["team_id"] ?? "").toString().trim();
          final uid = (r["user_id"] ?? "").toString().trim();
          final status = (r["status"] ?? "pending").toString().toLowerCase();
          if (tid.isEmpty || uid.isEmpty || status != "pending") continue;
          for (final key in {
            tid,
            tid.toLowerCase(),
            SupabaseService.toUuid(tid).toLowerCase()
          }) {
            final list = pendingByTeam.putIfAbsent(key, () => []);
            if (!list.contains(uid)) list.add(uid);
          }
        }
      } catch (e) {
        debugPrint("[TeamService] team_join_requests batch fetch error: $e");
      }
    }

    final leaderIds = rows
        .map((r) => (r["leader_id"] ?? r["leaderId"] ?? "").toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final Map<String, String> leaderNameById = {};
    final Map<String, String> leaderAvatarById = {};
    if (leaderIds.isNotEmpty) {
      try {
        final validUuidLeaderIds = leaderIds
            .map((id) => isValidUuid(id) ? id : SupabaseService.toUuid(id))
            .toSet()
            .toList();
        final userRows = await SupabaseService.client
            .from("users")
            .select()
            .inFilter("id", validUuidLeaderIds);
        for (final u in userRows) {
          final id = (u["id"] ?? "").toString().trim();
          final uid = (u["uid"] ?? "").toString().trim();
          final un = (u["username"] ?? "").toString().trim();
          final gid = (u["gamer_id"] ?? u["game_id"] ?? "").toString().trim();
          final d = (u["display_name"] ?? "").toString().trim();
          final rawHandle = (un.isNotEmpty && un.toLowerCase() != "null")
              ? un
              : ((gid.isNotEmpty && gid.toLowerCase() != "null")
                  ? gid
                  : ((d.isNotEmpty && d.toLowerCase() != "null")
                      ? d
                      : "Leader"));
          final name = sanitizePublicHandle(rawHandle, fallback: "Leader");
          final avatar = (u["avatar_url"] ?? "").toString();
          if (id.isNotEmpty) {
            leaderNameById[id] = name;
            leaderNameById[id.toLowerCase()] = name;
            leaderAvatarById[id] = avatar;
            leaderAvatarById[id.toLowerCase()] = avatar;
          }
          if (uid.isNotEmpty) {
            leaderNameById[uid] = name;
            leaderNameById[uid.toLowerCase()] = name;
            leaderAvatarById[uid] = avatar;
            leaderAvatarById[uid.toLowerCase()] = avatar;
          }
        }
      } catch (e) {
        debugPrint("[TeamService] leader fetch error: $e");
      }
    }

    final enriched = rows.map((rawRow) {
      final tid = (rawRow["id"] ?? "").toString().trim();
      final tidLower = tid.toLowerCase();
      final tidUuidLower = SupabaseService.toUuid(tid).toLowerCase();
      final leaderId =
          (rawRow["leader_id"] ?? rawRow["leaderId"] ?? "").toString().trim();

      final rawMembers = <String>[
        ...(membersByTeam[tid] ?? const <String>[]),
        ...(membersByTeam[tidLower] ?? const <String>[]),
        ...(membersByTeam[tidUuidLower] ?? const <String>[]),
      ];
      if (rawRow["members"] is List) {
        for (final m in (rawRow["members"] as List)) {
          final uid = m.toString().trim();
          if (uid.isNotEmpty) rawMembers.add(uid);
        }
      }

      final members = <String>[];
      final seenMemberUuids = <String>{};
      void addMemberUnique(String uid) {
        final clean = uid.trim();
        if (clean.isEmpty) return;
        final uuidKey = SupabaseService.toUuid(clean).toLowerCase();
        if (seenMemberUuids.contains(uuidKey) || members.contains(clean)) {
          return;
        }
        if (members.length >= maxTeamMembers) return;
        seenMemberUuids.add(uuidKey);
        members.add(clean);
      }

      if (leaderId.isNotEmpty) {
        addMemberUnique(leaderId);
      }
      // Guarantee current user is in members if they belong to this team via team_members / squad_members
      if (currentUid.isNotEmpty &&
          (myJoinedTeamKeys.contains(tidLower) ||
              myJoinedTeamKeys.contains(tidUuidLower))) {
        addMemberUnique(currentUid);
      }
      for (final m in rawMembers) {
        addMemberUnique(m);
      }

      final pending = List<String>.from(
        pendingByTeam[tid] ??
            pendingByTeam[tidLower] ??
            pendingByTeam[tidUuidLower] ??
            <String>[],
      );
      if (rawRow["pending_join_requests"] is List) {
        for (final p in (rawRow["pending_join_requests"] as List)) {
          final pStr = p.toString().trim();
          if (pStr.isNotEmpty &&
              !pending.contains(pStr) &&
              !members.contains(pStr)) {
            pending.add(pStr);
          }
        }
      }

      final fallbackLeaderName = sanitizePublicHandle(
        (rawRow["leader_name"] ?? rawRow["leaderName"] ?? "").toString(),
        fallback: "Leader",
      );
      final leaderUuidLower = leaderId.isNotEmpty
          ? SupabaseService.toUuid(leaderId).toLowerCase()
          : "";
      final leaderName = leaderNameById[leaderId] ??
          leaderNameById[leaderId.toLowerCase()] ??
          leaderNameById[leaderUuidLower] ??
          fallbackLeaderName;
      final leaderAvatar = leaderAvatarById[leaderId] ??
          leaderAvatarById[leaderId.toLowerCase()] ??
          leaderAvatarById[leaderUuidLower] ??
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

      final t = TeamModel.fromSupabase(mapCopy).copyWith(
        members: members,
        leaderName: leaderName,
        leaderAvatar: leaderAvatar,
      );
      _storeTeamCache(t);
      return t;
    }).toList();

    // Sort so any team where currentUid is leader or member appears at the very top
    if (currentUid.isNotEmpty) {
      enriched.sort((a, b) {
        final bool aIsLeader = a.isLeader(currentUid);
        final bool bIsLeader = b.isLeader(currentUid);
        final bool aIsMyTeam = aIsLeader ||
            a.isMember(currentUid) ||
            myJoinedTeamKeys.contains(a.id.trim().toLowerCase()) ||
            myJoinedTeamKeys
                .contains(SupabaseService.toUuid(a.id.trim()).toLowerCase());
        final bool bIsMyTeam = bIsLeader ||
            b.isMember(currentUid) ||
            myJoinedTeamKeys.contains(b.id.trim().toLowerCase()) ||
            myJoinedTeamKeys
                .contains(SupabaseService.toUuid(b.id.trim()).toLowerCase());

        if (aIsMyTeam && !bIsMyTeam) return -1;
        if (!aIsMyTeam && bIsMyTeam) return 1;
        if (aIsLeader && !bIsLeader) return -1;
        if (!aIsLeader && bIsLeader) return 1;
        return b.points.compareTo(a.points);
      });
    }

    return enriched;
  }

  /// Get stream of all teams with optional game filter and search query
  Stream<List<TeamModel>> getTeamsStream({
    String? gameFilter,
    String? searchQuery,
  }) {
    return _getTeamsStreamInternal(
      gameFilter: gameFilter,
      searchQuery: searchQuery,
    ).asBroadcastStream();
  }

  Stream<List<TeamModel>> _getTeamsStreamInternal({
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
      await Future.delayed(const Duration(seconds: 30));
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
        throw Exception('User not authenticated. Please log in again.');
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

      final normalizedGame = displayGameLabel(game);
      final row = {
        "id": teamUuid,
        "name": name.trim(),
        "tag": tag.trim().toUpperCase(),
        "logo_url": logoUrl,
        "game": normalizedGame,
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
      final normalizedGame = displayGameLabel(game);
      final Map<String, dynamic> updates = {
        "name": name.trim(),
        "tag": tag.trim().toUpperCase(),
        "game": normalizedGame,
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
    String? currentUserId,
  }) async {
    if (teamId.isEmpty || currentUserId == null || currentUserId.isEmpty) return "error";
    try {
      final userUuid = SupabaseService.toUuid(currentUserId!);
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

  /// Request to join team (enforces 4-member team limit)
  Future<bool> requestToJoinTeam({
    required String teamId,
    required String userId,
    String? userName,
    String? teamName,
  }) async {
    if (teamId.isEmpty || userId.isEmpty) return false;
    try {
      final currentTeam = await getTeam(teamId);
      if (currentTeam != null && currentTeam.memberCount >= maxTeamMembers && !currentTeam.isMember(userId)) {
        debugPrint("[TeamService] requestToJoinTeam blocked: Team already has $maxTeamMembers members");
        return false;
      }

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
      String resolvedTeamName = teamName ?? "Team";
      try {
        final teamRow = await SupabaseService.client
            .from("teams")
            .select()
            .or("id.eq.$teamUuid,id.eq.$teamId")
            .maybeSingle();

        if (teamRow != null) {
          leaderId = (teamRow["leader_id"] ?? teamRow["leaderId"] ?? "").toString();
          if (teamName == null || teamName.isEmpty) {
            resolvedTeamName = (teamRow["name"] ?? "Team").toString();
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

      // 3. Send notification to Team Leader (with sanitized public gaming handle)
      if (leaderId.isNotEmpty && leaderId != userUuid && leaderId != userId) {
        try {
          final senderDisplay = sanitizePublicHandle(userName, fallback: "A gamer");
          await SupabaseService.client.from("notifications").insert({
            "user_id": SupabaseService.toUuid(leaderId),
            "sender_id": userUuid,
            "sender_name": senderDisplay,
            "type": "team_join_request",
            "title": "New Team Join Request 🛡️",
            "body": "$senderDisplay requested to join $resolvedTeamName.",
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

  /// Accept join request (enforces max 4 members per team)
  Future<bool> acceptJoinRequest({
    required String teamId,
    required String userId,
    String? userName,
  }) async {
    if (teamId.isEmpty || userId.isEmpty) return false;
    try {
      final currentTeam = await getTeam(teamId);
      if (currentTeam != null && currentTeam.memberCount >= maxTeamMembers && !currentTeam.isMember(userId)) {
        debugPrint("[TeamService] acceptJoinRequest blocked: Team is full ($maxTeamMembers/$maxTeamMembers)");
        return false;
      }

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
      String teamName = "Team";
      try {
        final teamRow = await SupabaseService.client
            .from("teams")
            .select()
            .or("id.eq.$teamUuid,id.eq.$teamId")
            .maybeSingle();
        if (teamRow != null) {
          teamName = (teamRow["name"] ?? "Team").toString();
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
            if (!membersList.contains(userUuid) && membersList.length < maxTeamMembers) {
              membersList.add(userUuid);
            }
            updates["members"] = membersList.length > maxTeamMembers
                ? membersList.sublist(0, maxTeamMembers)
                : membersList;
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
          "title": "Team Request Accepted! 🎉",
          "body": "You are now a member of $teamName.",
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

  /// Cancel join request (called by requesting user)
  Future<bool> cancelJoinRequest({
    required String teamId,
    required String userId,
  }) async {
    return rejectJoinRequest(teamId: teamId, userId: userId);
  }

  /// Leave team (called by team member)
  Future<bool> leaveTeam({
    required String teamId,
    required String userId,
  }) async {
    if (teamId.isEmpty || userId.isEmpty) return false;
    try {
      final teamUuid = SupabaseService.toUuid(teamId);
      final userUuid = SupabaseService.toUuid(userId);

      await SupabaseService.client
          .from("team_members")
          .delete()
          .or("team_id.eq.$teamUuid,team_id.eq.$teamId")
          .or("user_id.eq.$userUuid,user_id.eq.$userId");

      try {
        final teamRow = await SupabaseService.client
            .from("teams")
            .select()
            .or("id.eq.$teamUuid,id.eq.$teamId")
            .maybeSingle();
        if (teamRow != null && teamRow.containsKey("members")) {
          final membersList = List<String>.from(
            (teamRow["members"] as List? ?? []).map((e) => e.toString()),
          )..removeWhere((id) => id == userUuid || id == userId);
          await SupabaseService.client
              .from("teams")
              .update({"members": membersList})
              .or("id.eq.$teamUuid,id.eq.$teamId");
        }
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint("[TeamService] leaveTeam error: $e");
      return false;
    }
  }

  /// 🏆 Award Tournament Winner:
  /// 1. Updates team: wins + 1, points + 25
  /// 2. Updates team_rankings for Top 100 Leaderboard: wins + 1, points + 25
  /// 3. Safely queries leader + all team_members
  /// 4. Splits prize pool equally among all members via CoinWalletService.updateCoins
  /// 5. Logs to active_matches / match history & notifications
  Future<bool> awardTournamentWinner({
    required String tournamentId,
    required String teamId,
    required int prizePool,
    String tournamentTitle = 'Tournament',
  }) async {
    try {
      debugPrint('[TeamService] awardTournamentWinner: tournament=$tournamentId, team=$teamId, prize=$prizePool');
      final teamUuid = SupabaseService.toUuid(teamId);

      // 1. Fetch team info
      Map<String, dynamic>? teamRow;
      try {
        teamRow = await SupabaseService.client
            .from('teams')
            .select()
            .or('id.eq.$teamUuid,id.eq.$teamId')
            .maybeSingle();
      } catch (e) {
        debugPrint('[TeamService] fetch team error: $e');
      }

      final teamName = teamRow?['name']?.toString() ?? 'Winning Team';
      final leaderId = (teamRow?['leader_id'] ?? teamRow?['leaderId'] ?? '').toString();
      final game = (teamRow?['game'] ?? 'Free Fire').toString();
      final avatar = (teamRow?['logo_url'] ?? teamRow?['avatar'] ?? '').toString();
      final currentWins = (teamRow?['wins'] as num?)?.toInt() ?? 0;
      final currentPoints = (teamRow?['points'] as num?)?.toInt() ?? (currentWins * 25);
      final currentLosses = (teamRow?['losses'] as num?)?.toInt() ?? 0;
      final currentDraws = (teamRow?['draws'] as num?)?.toInt() ?? 0;

      final int newWins = currentWins + 1;
      final int newPoints = currentPoints + 25; // ✅ Each tournament win gives +25 points
      final int totalMatches = newWins + currentLosses + currentDraws;
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // 2. Update teams table
      try {
        await SupabaseService.client.from('teams').update({
          'wins': newWins,
          'points': newPoints,
        }).or('id.eq.$teamUuid,id.eq.$teamId');
      } catch (e) {
        debugPrint('[TeamService] Error updating teams wins/points: $e');
      }

      // 3. Update team_rankings table (for Top 100 Leaderboard if table exists)
      try {
        await SupabaseService.client.from('team_rankings').upsert({
          'team_id': teamUuid,
          'teamId': teamUuid,
          'team_name': teamName,
          'teamName': teamName,
          'leader_id': leaderId,
          'leaderId': leaderId,
          'avatar': avatar,
          'game': game,
          'wins': newWins,
          'losses': currentLosses,
          'draws': currentDraws,
          'total_matches': totalMatches,
          'totalMatches': totalMatches,
          'points': newPoints,
          'updated_at': nowIso,
          'updatedAt': nowIso,
        });
      } catch (e) {
        debugPrint('[TeamService] Note: team_rankings table update: $e');
      }

      // 4. Gather all team member IDs (Leader + Members)
      final List<String> memberIds = [];
      if (leaderId.isNotEmpty) {
        memberIds.add(leaderId);
      }
      try {
        final memberRows = await SupabaseService.client
            .from('team_members')
            .select('user_id')
            .or('team_id.eq.$teamUuid,team_id.eq.$teamId');
        for (final m in memberRows) {
          final uid = (m['user_id'] ?? '').toString().trim();
          if (uid.isNotEmpty && !memberIds.contains(uid)) {
            memberIds.add(uid);
          }
        }
      } catch (e) {
        debugPrint('[TeamService] Error fetching member IDs: $e');
      }

      if (memberIds.isEmpty && leaderId.isNotEmpty) {
        memberIds.add(leaderId);
      }

      // 5. Distribute prize coins equally
      if (prizePool > 0 && memberIds.isNotEmpty) {
        final int share = (prizePool / memberIds.length).floor();
        for (final uid in memberIds) {
          if (share > 0) {
            try {
              await CoinWalletService.updateCoins(
                userId: uid,
                amount: share,
                type: 'tournament_win',
                roomId: tournamentId,
                description: '🏆 Tournament Win Prize ($share Coins): $tournamentTitle',
              );
            } catch (e) {
              debugPrint('[TeamService] Error updating coins for $uid: $e');
            }

            try {
              await NotificationService().sendNotification(
                userId: uid,
                type: 'tournament_result',
                title: '🏆 Tournament Champion! ($share Coins Added)',
                body: 'Your team "$teamName" won "$tournamentTitle"! Your $share coins prize share has been credited to your wallet.',
                data: {
                  'tournament_id': tournamentId,
                  'tournament_title': tournamentTitle,
                  'prize': share,
                  'team_id': teamId,
                  'team_name': teamName,
                },
                priority: 'high',
              );
            } catch (_) {}
          }
        }
      }

      // 6. Record victory in active_matches so it displays under Match & Tournament History
      try {
        final matchRecordUuid = SupabaseService.toUuid('tourn_${tournamentId}_$teamUuid');
        await SupabaseService.client.from('active_matches').upsert({
          'id': matchRecordUuid,
          'team1_id': teamUuid,
          'team2_id': teamUuid,
          'winner_team_id': teamUuid,
          'status': 'completed',
          'result': 'win',
          'admin_note': '🏆 Tournament: $tournamentTitle',
          'start_time': nowIso,
          'ended_at': nowIso,
          'created_at': nowIso,
        });
      } catch (e) {
        debugPrint('[TeamService] Error inserting match history: $e');
      }

      // 7. Update tournament record universally with winner team name & completed status
      final tournamentUpdatePayload = {
        'status': 'completed',
        'proof_status': 'approved',
        'winner_team_id': teamId,
        'winner_team_name': teamName,
        'proof_team_name': teamName,
      };

      try {
        await SupabaseService.client
            .from('tournaments')
            .update(tournamentUpdatePayload)
            .eq('id', tournamentId);
      } catch (_) {
        try {
          await SupabaseService.client
              .from('tournaments')
              .update(tournamentUpdatePayload)
              .eq('id', SupabaseService.toUuid(tournamentId));
        } catch (_) {}
      }

      // 8. Log proof history
      try {
        await SupabaseService.logProofHistory(
          username: teamName,
          proofType: 'Tournament Victory: $tournamentTitle',
          status: 'approved',
          adminName: 'Admin',
          tournamentId: tournamentId,
        );
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('[TeamService] awardTournamentWinner error: $e');
      return false;
    }
  }

  /// 🏆 UNIVERSAL TOURNAMENT SYNC & REPAIR:
  /// Scans all completed tournaments across the system.
  /// Dynamically ensures EVERY winning team across the app has:
  /// 1. Wins incremented/synced for every tournament victory.
  /// 2. Points incremented by +25 points per tournament win.
  /// 3. Top 100 Leaderboard updated dynamically.
  /// 4. Completed match record logged in `active_matches` for team history.
  /// 5. Prize coins split equally among all squad members (leader + members).
  /// Works universally for ANY team and ANY user with zero hardcoding!
  static bool _tournamentsSynced = false;
  Future<void> syncAllTeamsTournamentWins({bool force = false}) async {
    if (_tournamentsSynced && !force) return;
    _tournamentsSynced = true;

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final prefs = await SharedPreferences.getInstance();

      // 1. Fetch strictly completed tournaments
      List<dynamic> completedTourns = [];
      try {
        final res = await SupabaseService.client
            .from('tournaments')
            .select()
            .eq('status', 'completed');
        if (res is List) completedTourns = res;
      } catch (_) {
        try {
          final res = await SupabaseService.client.from('tournaments').select();
          if (res is List) {
            completedTourns = res.where((t) {
              final st = (t['status'] ?? '').toString().trim().toLowerCase();
              return st == 'completed';
            }).toList();
          }
        } catch (_) {}
      }

      // 2. Group completed tournaments by winner team ID
      final Map<String, List<Map<String, dynamic>>> tournamentsByTeam = {};
      final Set<String> syncedTournamentIds = {};
      for (final t in completedTourns) {
        if (t is! Map) continue;
        final tMap = Map<String, dynamic>.from(t);
        final st = (tMap['status'] ?? '').toString().trim().toLowerCase();
        if (st != 'completed') continue;

        final rawTournId = (tMap['id'] ?? '').toString().trim();
        if (rawTournId.isEmpty) continue;

        String winnerId = (tMap['winner_team_id'] ??
                tMap['proof_team_id'] ??
                tMap['submitted_team_id'] ??
                tMap['winner_team'] ??
                '')
            .toString()
            .trim();

        if (winnerId.isEmpty) {
          final wName = (tMap['proof_team_name'] ?? tMap['winner_team_name'] ?? '').toString().trim();
          if (wName.isNotEmpty) {
            try {
              final foundTeam = await SupabaseService.client
                  .from('teams')
                  .select('id')
                  .ilike('name', wName)
                  .maybeSingle();
              if (foundTeam != null) {
                winnerId = (foundTeam['id'] ?? '').toString().trim();
              }
            } catch (_) {}
          }
        }
        if (winnerId.isEmpty) continue;

        syncedTournamentIds.add(rawTournId.toLowerCase());
        final key = winnerId.toLowerCase();
        tournamentsByTeam.putIfAbsent(key, () => []).add(tMap);
      }

      // 2b. Check approved proof_history ONLY for tournaments confirmed as 'completed' in DB
      try {
        final approvedProofs = await SupabaseService.client
            .from('proof_history')
            .select()
            .eq('status', 'approved');

        for (final p in approvedProofs) {
          final uName = (p['username'] ?? '').toString().trim();
          final tId = (p['tournament_id'] ?? '').toString().trim();
          if (tId.isEmpty || uName.isEmpty) continue;
          if (syncedTournamentIds.contains(tId.toLowerCase())) continue;

          try {
            // Confirm this tournament ID actually exists in DB and has status == 'completed'
            final tRow = await SupabaseService.client
                .from('tournaments')
                .select()
                .eq('id', tId)
                .maybeSingle();
            if (tRow == null) continue;
            final tStatus = (tRow['status'] ?? '').toString().trim().toLowerCase();
            if (tStatus != 'completed') continue;

            // Exact case-insensitive match by team name or tag (never substring wildcard)
            var teamFound = await SupabaseService.client
                .from('teams')
                .select('id')
                .ilike('name', uName)
                .maybeSingle();
            teamFound ??= await SupabaseService.client
                .from('teams')
                .select('id')
                .ilike('tag', uName)
                .maybeSingle();

            if (teamFound != null) {
              final matchedTid = teamFound['id'].toString().toLowerCase();
              syncedTournamentIds.add(tId.toLowerCase());
              tournamentsByTeam.putIfAbsent(matchedTid, () => []).add(Map<String, dynamic>.from(tRow));
            }
          } catch (_) {}
        }
      } catch (err) {
        debugPrint('[TeamService] Proof history sync notice: $err');
      }

      // 3. For EVERY winning team, sync wins, points, leaderboard, match history & prize coins
      for (final entry in tournamentsByTeam.entries) {
        final rawTeamId = entry.key;
        final teamUuid = SupabaseService.toUuid(rawTeamId);
        final teamTournaments = entry.value;
        final completedWinsCount = teamTournaments.length;

        try {
          // Fetch team from Supabase
          final teamRow = await SupabaseService.client
              .from('teams')
              .select()
              .or('id.eq.$teamUuid,id.eq.$rawTeamId')
              .maybeSingle();

          if (teamRow == null) continue;

          final teamName = (teamRow['name'] ?? 'Team').toString();
          final leaderId = (teamRow['leader_id'] ?? teamRow['leaderId'] ?? '').toString().trim();
          final int dbWins = (teamRow['wins'] as num?)?.toInt() ?? 0;
          final int dbLosses = (teamRow['losses'] as num?)?.toInt() ?? 0;
          final int dbDraws = (teamRow['draws'] as num?)?.toInt() ?? 0;
          final int dbPoints = (teamRow['points'] as num?)?.toInt() ?? 0;

          // Universal rule: Wins must reflect all completed tournament victories
          final targetWins = dbWins < completedWinsCount ? completedWinsCount : dbWins;
          // Universal rule: Each win guarantees at least 25 points
          final minExpectedPoints = targetWins * 25;
          final targetPoints = dbPoints < minExpectedPoints ? minExpectedPoints : dbPoints;
          final totalMatches = targetWins + dbLosses + dbDraws;

          // Update teams table if needed (Note: teams table has no updated_at column)
          if (targetWins != dbWins || targetPoints != dbPoints) {
            await SupabaseService.client.from('teams').update({
              'wins': targetWins,
              'points': targetPoints,
            }).or('id.eq.$teamUuid,id.eq.$rawTeamId');
          }

          // Optional: team_rankings table fallback
          try {
            await SupabaseService.client.from('team_rankings').upsert({
              'team_id': teamUuid,
              'teamId': teamUuid,
              'team_name': teamName,
              'teamName': teamName,
              'leader_id': leaderId,
              'leaderId': leaderId,
              'avatar': teamRow['avatar_url'] ?? '',
              'game': teamRow['game'] ?? 'Free Fire',
              'wins': targetWins,
              'losses': dbLosses,
              'draws': dbDraws,
              'total_matches': totalMatches,
              'totalMatches': totalMatches,
              'points': targetPoints,
              'updated_at': nowIso,
              'updatedAt': nowIso,
            });
          } catch (_) {}

          // Fetch all squad members (Leader + team_members)
          final List<String> memberIds = [];
          if (leaderId.isNotEmpty) memberIds.add(leaderId);
          try {
            final memberRows = await SupabaseService.client
                .from('team_members')
                .select('user_id')
                .or('team_id.eq.$teamUuid,team_id.eq.$rawTeamId');
            for (final m in memberRows) {
              final uid = (m['user_id'] ?? '').toString().trim();
              if (uid.isNotEmpty && !memberIds.contains(uid)) {
                memberIds.add(uid);
              }
            }
          } catch (_) {}

          // For each tournament won by this team:
          for (int i = 0; i < teamTournaments.length; i++) {
            final t = teamTournaments[i];
            final tId = (t['id'] ?? '').toString();
            final tTitle = (t['title'] ?? 'Championship Tournament').toString();
            final prizePool = (t['prize_pool'] is num)
                ? (t['prize_pool'] as num).toInt()
                : int.tryParse(t['prize_pool']?.toString() ?? '0') ?? 0;

            if (tId.isEmpty) continue;

            // Ensure Match & Tournament History record in active_matches
            final matchHistoryUuid = SupabaseService.toUuid('tourn_win_${tId}_$teamUuid');
            try {
              await SupabaseService.client.from('active_matches').upsert({
                'id': matchHistoryUuid,
                'team1_id': teamUuid,
                'team2_id': teamUuid,
                'winner_team_id': teamUuid,
                'status': 'completed',
                'result': 'win',
                'admin_note': '🏆 Tournament: $tTitle',
                'start_time': t['created_at'] ?? nowIso,
                'ended_at': t['ended_at'] ?? t['created_at'] ?? nowIso,
                'created_at': t['created_at'] ?? nowIso,
              });
            } catch (_) {}

            // Ensure equal coin prize split among all members
            if (prizePool > 0 && memberIds.isNotEmpty) {
              bool alreadyDistributed = false;
              try {
                final existingTx = await SupabaseService.client
                    .from('coin_transactions')
                    .select('id')
                    .or('room_id.eq.$tId,reference_id.eq.$tId')
                    .eq('type', 'tournament_win')
                    .limit(1);
                if (existingTx is List && existingTx.isNotEmpty) {
                  alreadyDistributed = true;
                }
              } catch (_) {
                try {
                  final existingRefTx = await SupabaseService.client
                      .from('coin_transactions')
                      .select('id')
                      .eq('reference_id', tId)
                      .eq('type', 'tournament_win')
                      .limit(1);
                  if (existingRefTx is List && existingRefTx.isNotEmpty) {
                    alreadyDistributed = true;
                  }
                } catch (_) {
                  final distributedKey = 'tourn_prize_distributed_$tId';
                  alreadyDistributed = prefs.getBool(distributedKey) ?? false;
                }
              }

              if (!alreadyDistributed) {
                final int share = (prizePool / memberIds.length).floor();
                if (share > 0) {
                  for (final uid in memberIds) {
                    try {
                      await CoinWalletService.updateCoins(
                        userId: uid,
                        amount: share,
                        type: 'tournament_win',
                        roomId: tId,
                        title: '🏆 Tournament Win Prize ($share Coins): $tTitle',
                        description: '🏆 Tournament Win Prize ($share Coins): $tTitle',
                      );
                    } catch (err) {
                      debugPrint('[TeamService] Coin credit error for $uid: $err');
                    }
                  }
                  await prefs.setBool('tourn_prize_distributed_$tId', true);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[TeamService] Error syncing team $rawTeamId: $e');
        }
      }
    } catch (e) {
      debugPrint('[TeamService] syncAllTeamsTournamentWins error: $e');
    }
  }

  /// Backward-compatible alias
  Future<void> syncAndRepairMtkTeam() => syncAllTeamsTournamentWins();

  // ===========================================================================
  // WEEKLY TEAM COINS, PER-GAME LEADERBOARD & EQUAL REWARD DIVISION SYSTEM
  // ===========================================================================

  /// Returns Monday 00:00:00 UTC of the week containing [date]
  static DateTime getWeekStartUtc([DateTime? date]) {
    final target = (date ?? DateTime.now()).toUtc();
    final daysFromMonday = target.weekday - DateTime.monday;
    final monday = target.subtract(Duration(days: daysFromMonday));
    return DateTime.utc(monday.year, monday.month, monday.day);
  }

  /// Returns Sunday 23:59:59 UTC of the week containing [date]
  static DateTime getWeekEndUtc([DateTime? date]) {
    final start = getWeekStartUtc(date);
    return start.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
  }

  /// Unique key for a weekly cycle (e.g. "2026-11-16")
  static String getWeekCycleKey([DateTime? date]) {
    final start = getWeekStartUtc(date);
    final m = start.month.toString().padLeft(2, '0');
    final d = start.day.toString().padLeft(2, '0');
    return '${start.year}-$m-$d';
  }

  /// Alias returning the current or specified weekly cycle key
  static String getCurrentWeekKey([DateTime? date]) {
    return getWeekCycleKey(date);
  }

  /// Human-readable date range for a weekly cycle (e.g. "16 Nov - 22 Nov")
  static String getWeekRangeLabel([DateTime? date]) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final start = getWeekStartUtc(date);
    final end = getWeekEndUtc(date);
    return '${start.day} ${months[start.month - 1]} – ${end.day} ${months[end.month - 1]}';
  }

  /// Returns true only during the Week-End / Monday Claim Window:
  /// - Monday (00:00–23:59 UTC or local/PKT time), immediately following the conclusion
  ///   of the 7-day weekly cycle, OR
  /// - Sunday final hour (23:00–23:59 UTC) at the end of the weekly cycle.
  /// Mid-week coin transfers during the active weekly cycle remain locked until Week End / Monday.
  static bool isWeeklyClaimWindowOpen([DateTime? date]) {
    final nowUtc = (date ?? DateTime.now()).toUtc();
    final nowLocal = (date ?? DateTime.now()).toLocal();
    final bool isMondayUtcOrLocal =
        nowUtc.weekday == DateTime.monday || nowLocal.weekday == DateTime.monday;
    final bool isSundayCloseUtc =
        nowUtc.weekday == DateTime.sunday && nowUtc.hour >= 23;
    return isMondayUtcOrLocal || isSundayCloseUtc;
  }

  /// Returns a sample UTC date inside the concluded weekly cycle that is eligible
  /// for the Week-End / Monday Claim Window.
  /// - On Monday, returns the just-concluded previous 7-day week (Monday–Sunday before today's Monday 00:00 UTC reset),
  ///   so brand-new coin contributions made in the new Monday cycle never unlock claims prematurely.
  /// - On Sunday final hour (23:00–23:59 UTC), returns the concluding week.
  static DateTime getConcludedWeekSampleDate([DateTime? date]) {
    final nowUtc = (date ?? DateTime.now()).toUtc();
    if (nowUtc.weekday == DateTime.sunday && nowUtc.hour >= 23) {
      return getWeekStartUtc(nowUtc);
    }
    final currentWeekStart = getWeekStartUtc(nowUtc);
    return currentWeekStart.subtract(const Duration(days: 3));
  }

  /// Week key (e.g. "2026-11-16") of the concluded weekly cycle evaluated during Monday claim window
  static String getConcludedWeekKey([DateTime? date]) {
    return getWeekCycleKey(getConcludedWeekSampleDate(date));
  }

  /// Human-readable range label (e.g. "16 Nov – 22 Nov") of the concluded weekly cycle
  static String getConcludedWeekRangeLabel([DateTime? date]) {
    return getWeekRangeLabel(getConcludedWeekSampleDate(date));
  }

  /// Eligible transaction types that count toward a member's Weekly Team Coin contribution.
  /// Under the Personal Wallet First + Manual Team Contribution rule, earned coins go to the
  /// user's Personal Wallet first, and only manual contributions ('team_weekly_contribution')
  /// transferred from the Personal Wallet count toward the team's weekly competition score.
  static bool isEligibleTeamCoinActivity(String type) {
    final clean = type.trim().toLowerCase();
    return clean == 'team_weekly_contribution';
  }

  /// Ensures weekly caches are reset cleanly when a new 7-day weekly cycle begins,
  /// while preserving all personal wallet balances and past transaction history.
  Future<void> _ensureWeeklyCycleReset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentWeekKey = getWeekCycleKey();
      final lastActiveWeekKey = prefs.getString('active_weekly_cycle_key');
      if (lastActiveWeekKey != currentWeekKey) {
        _teamWeeklyStatsCache.clear();
        _gameLeaderboardCache.clear();
        await prefs.setString('active_weekly_cycle_key', currentWeekKey);
      }
    } catch (_) {}
  }

  /// Transfers [amount] G-Coins from [userId]'s Personal Wallet to their active [team]'s
  /// weekly competition score for the current 7-day cycle.
  /// - If [amount] == 0, keeps all coins in the Personal Wallet without deducting.
  /// - If [amount] > 0, deducts [amount] from Personal Wallet and adds [amount] to the
  ///   member's weekly contribution and the team's weekly total for that game.
  Future<Map<String, dynamic>> contributePersonalCoinsToTeam({
    required String userId,
    required TeamModel team,
    required int amount,
  }) async {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) {
      return {
        'success': false,
        'contributed': 0,
        'message': 'Please sign in to contribute coins to your team.',
      };
    }

    await _ensureWeeklyCycleReset();

    if (amount <= 0) {
      return {
        'success': true,
        'contributed': 0,
        'keptInWallet': true,
        'message': '0 G-Coins contributed. Your coins remain safely stored in your Personal Wallet.',
      };
    }

    final wallet = await CoinWalletService().getOrCreateWallet(cleanUid);
    if (wallet.coins < amount) {
      return {
        'success': false,
        'contributed': 0,
        'message': 'Insufficient Personal Wallet balance. Available: ${wallet.coins} G-Coins.',
      };
    }

    final weekKey = getWeekCycleKey();
    final weekLabel = getWeekRangeLabel();
    final rawTeamId = team.id.trim();
    final teamUuid = SupabaseService.toUuid(rawTeamId);
    final userUuid = SupabaseService.toUuid(cleanUid);
    final gameKey = normalizeGameKey(team.game); // strictly 'free_fire' or 'pubg_mobile'
    final gameDisplay = displayGameLabel(team.game); // 'Free Fire' or 'PUBG Mobile'
    final int contribUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    final structuredRoomId =
        'team_contrib|$weekKey|$teamUuid|$gameKey|$userUuid|$contribUtcMs';
    final structuredMeta =
        '[team_id:$teamUuid|raw_team_id:$rawTeamId|user_id:$userUuid|raw_user_id:$cleanUid|game_name:$gameKey|week_key:$weekKey|contrib_utc_ms:$contribUtcMs]';

    // 1. Deduct from Personal Wallet & record exact (team_id, user_id, game_name) contribution in history
    await CoinWalletService.updateCoins(
      userId: cleanUid,
      amount: -amount,
      type: 'team_weekly_contribution',
      roomId: structuredRoomId,
      teamId: teamUuid,
      gameName: gameKey,
      title: '🛡️ Team Weekly Contribution (${team.name} [${team.tag}])',
      description:
          'Transferred $amount G-Coins from Personal Wallet to Team "${team.name} [${team.tag}]" for $gameDisplay Weekly Competition ($weekLabel) $structuredMeta',
    );

    // 1b. Also persist into team_coin_contributions in the background if that table is provisioned
    Future<void>(() async {
      try {
        await SupabaseService.client.from('team_coin_contributions').insert({
          'team_id': teamUuid,
          'user_id': userUuid,
          'member_id': userUuid,
          'game_name': gameKey,
          'week_key': weekKey,
          'amount': amount,
          'created_at': DateTime.fromMillisecondsSinceEpoch(contribUtcMs, isUtc: true)
              .toIso8601String(),
        });
      } catch (_) {}
    });

    // 2. Increment local weekly contribution counter strictly scoped to (weekKey, teamUuid, gameKey, userUuid)
    int newMemberExactTotal = amount;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Remove any legacy cross-team per-user keys so old fallback totals never leak across teams
      await prefs.remove('weekly_user_contrib_${weekKey}_$cleanUid');
      await prefs.remove('weekly_user_contrib_${weekKey}_$userUuid');
      await prefs.remove('weekly_team_member_${weekKey}_${team.id}_$cleanUid');

      final exactLocalKey =
          'weekly_exact_contrib_v3_${weekKey}_${teamUuid.toLowerCase()}_${gameKey}_${userUuid.toLowerCase()}';
      final currentExact = prefs.getInt(exactLocalKey) ?? 0;
      newMemberExactTotal = currentExact + amount;
      await prefs.setInt(exactLocalKey, newMemberExactTotal);
    } catch (e) {
      debugPrint('[TeamService] contributePersonalCoinsToTeam prefs note: $e');
    }

    // 3. Optimistically update cached weekly stats for this team so UI updates instantaneously
    final prevCached = getCachedTeamWeeklyStats(team.id);
    _gameLeaderboardCache.clear();
    int optimisticTeamWeeklyCoins =
        ((prevCached?['weeklyCoins'] as num?)?.toInt() ?? team.weeklyCoins) + amount;
    int optimisticWeeklyRank =
        (prevCached?['weeklyRank'] as num?)?.toInt() ?? (team.weeklyRank > 0 ? team.weeklyRank : 1);

    final Map<String, int> optimisticMemberCoins = {};
    if (prevCached?['memberCoins'] is Map) {
      (prevCached!['memberCoins'] as Map).forEach((k, v) {
        optimisticMemberCoins[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    } else {
      team.memberWeeklyCoins.forEach((k, v) {
        optimisticMemberCoins[k] = v;
      });
    }
    final cleanLower = cleanUid.toLowerCase();
    final userUuidLower = userUuid.toLowerCase();
    optimisticMemberCoins[cleanUid] = newMemberExactTotal;
    optimisticMemberCoins[cleanLower] = newMemberExactTotal;
    optimisticMemberCoins[userUuidLower] = newMemberExactTotal;

    final List<Map<String, dynamic>> optimisticBreakdown = [];
    if (prevCached?['memberBreakdown'] is List) {
      for (final item in (prevCached!['memberBreakdown'] as List)) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final mUid = (m['userId'] ?? '').toString().trim();
          final mLower = mUid.toLowerCase();
          final mUuid = mUid.isNotEmpty ? SupabaseService.toUuid(mUid).toLowerCase() : '';
          if (mUid == cleanUid || mLower == cleanLower || mUuid == userUuidLower) {
            m['weeklyCoins'] = newMemberExactTotal;
            m['coins'] = newMemberExactTotal;
          }
          optimisticBreakdown.add(m);
        }
      }
    }

    if (optimisticBreakdown.isNotEmpty) {
      final sumBreakdown = optimisticBreakdown.fold<int>(
        0,
        (sum, m) => sum + ((m['weeklyCoins'] as num?)?.toInt() ?? 0),
      );
      if (sumBreakdown > 0) {
        optimisticTeamWeeklyCoins = sumBreakdown;
      }
    }

    final optimisticStats = <String, dynamic>{
      if (prevCached != null) ...prevCached,
      'teamId': team.id,
      'teamName': team.name,
      'teamTag': team.tag,
      'game': gameDisplay,
      'weeklyCoins': optimisticTeamWeeklyCoins,
      'weeklyRank': optimisticWeeklyRank,
      'memberCoins': optimisticMemberCoins,
      if (optimisticBreakdown.isNotEmpty) 'memberBreakdown': optimisticBreakdown,
      'weekRangeLabel': weekLabel,
      'weekKey': weekKey,
      // Contributing coins in the active weekly cycle NEVER unlocks reward claiming immediately
      'isClaimWindowOpen': prevCached?['isClaimWindowOpen'] ?? isWeeklyClaimWindowOpen(),
      'isClaimEligible': prevCached?['isClaimEligible'] == true,
    };
    _storeTeamWeeklyStatsCache(team.id, optimisticStats);

    // 4. Refresh exact leaderboard & user teams in the background without blocking button completion
    Future<void>(() async {
      try {
        await getTeamWeeklyCoinStats(team);
        await getUserTeams(cleanUid);
      } catch (_) {}
    });

    return {
      'success': true,
      'contributed': amount,
      'keptInWallet': false,
      'newPersonalBalance': (wallet.coins - amount).clamp(0, 999999999),
      'teamWeeklyCoins': optimisticTeamWeeklyCoins,
      'weeklyRank': optimisticWeeklyRank,
      'message':
          'Successfully contributed $amount G-Coins from your Personal Wallet to ${team.name} [${team.tag}] ($gameDisplay)!',
    };
  }

  /// Legacy helper preserved for signature compatibility; does not write global per-user counters
  /// so contributions are never shared across different teams or games.
  Future<void> recordMemberWeeklyCoinContribution({
    required String userId,
    required int amount,
    required String activityType,
    String? teamId,
    String? gameName,
  }) async {
    if (userId.isEmpty || amount <= 0) return;
    if (!isEligibleTeamCoinActivity(activityType)) return;
    if (teamId == null || teamId.trim().isEmpty || gameName == null || gameName.trim().isEmpty) {
      return;
    }
    try {
      final weekKey = getWeekCycleKey();
      final prefs = await SharedPreferences.getInstance();
      final teamUuid = SupabaseService.toUuid(teamId.trim()).toLowerCase();
      final userUuid = SupabaseService.toUuid(userId.trim()).toLowerCase();
      final gameKey = normalizeGameKey(gameName);
      final exactLocalKey =
          'weekly_exact_contrib_v3_${weekKey}_${teamUuid}_${gameKey}_$userUuid';
      final currentExact = prefs.getInt(exactLocalKey) ?? 0;
      await prefs.setInt(exactLocalKey, currentExact + amount);
    } catch (e) {
      debugPrint('[TeamService] recordMemberWeeklyCoinContribution note: $e');
    }
  }

  /// Fetches sanitized public gaming handles for a list of user IDs (Play Policy Data Minimization)
  Future<Map<String, Map<String, String>>> _fetchPublicHandlesForUsers(List<String> userIds) async {
    final Map<String, Map<String, String>> result = {};
    if (userIds.isEmpty) return result;

    final queryIds = <String>{};
    for (final uid in userIds) {
      final clean = uid.trim();
      if (clean.isEmpty) continue;
      try {
        queryIds.add(SupabaseService.toUuid(clean));
      } catch (_) {
        queryIds.add(clean);
      }
    }

    try {
      final rows = await SupabaseService.client
          .from('users')
          .select('id, uid, username, gamer_id, game_id, display_name, avatar_url')
          .inFilter('id', queryIds.toList());
      for (final r in rows) {
        final id = (r['id'] ?? '').toString().trim();
        final uid = (r['uid'] ?? '').toString().trim();
        final un = (r['username'] ?? '').toString().trim();
        final gid = (r['gamer_id'] ?? r['game_id'] ?? '').toString().trim();
        final dn = (r['display_name'] ?? '').toString().trim();
        final av = (r['avatar_url'] ?? '').toString().trim();

        String rawHandle = 'Gamer';
        for (final candidate in [un, gid, dn]) {
          if (candidate.isNotEmpty &&
              candidate.toLowerCase() != 'null' &&
              !candidate.toLowerCase().startsWith('user_')) {
            rawHandle = candidate;
            break;
          }
        }
        if (rawHandle == 'Gamer') {
          for (final candidate in [un, gid, dn]) {
            if (candidate.isNotEmpty && candidate.toLowerCase() != 'null') {
              rawHandle = candidate;
              break;
            }
          }
        }

        final handle = sanitizePublicHandle(rawHandle, fallback: 'Gamer');
        final gamerTag = (gid.isNotEmpty && gid.toLowerCase() != 'null')
            ? sanitizePublicHandle(gid, fallback: handle)
            : handle;

        final info = {
          'handle': handle,
          'gamerId': gamerTag,
          'avatar': (av.toLowerCase() != 'null') ? av : '',
        };
        if (id.isNotEmpty) result[id.toLowerCase()] = info;
        if (uid.isNotEmpty) result[uid.toLowerCase()] = info;
      }
    } catch (e) {
      debugPrint('[TeamService] _fetchPublicHandlesForUsers note: $e');
    }

    return result;
  }

  /// Calculates weekly coins manually contributed strictly per (team_id, user_id, game_name)
  /// during the 7-day weekly cycle of [forDate].
  /// Returns a map: `teamKey (teamIdLower / teamUuidLower) -> { memberKey (uidLower / uidUuidLower) -> coins }`.
  /// Never shares or leaks a user's contribution from one team or game into another team or game.
  Future<Map<String, Map<String, int>>> _getTeamsWeeklyContributionsByMember(
    List<TeamModel> teams, {
    DateTime? forDate,
  }) async {
    if (forDate == null) {
      await _ensureWeeklyCycleReset();
    }

    final Map<String, Map<String, int>> resultByTeam = {};
    if (teams.isEmpty) return resultByTeam;

    final weekStart = getWeekStartUtc(forDate);
    final weekEnd = getWeekEndUtc(forDate);
    final weekKey = getWeekCycleKey(forDate);

    // Build lookup descriptors for each team and initialize every member to 0
    final List<String> allUserLookupIds = [];
    final Set<String> seenUserLookupIds = {};

    // Canonical accumulator keyed by: "$teamUuidLower|$gameKey|$memberUuidLower"
    final Map<String, int> txSumByExactTuple = {};
    final Map<String, int> tableSumByExactTuple = {};

    void registerUserLookupId(String rawUid) {
      final clean = rawUid.trim();
      if (clean.isEmpty) return;
      if (seenUserLookupIds.add(clean)) {
        allUserLookupIds.add(clean);
      }
      try {
        final asUuid = SupabaseService.toUuid(clean);
        if (seenUserLookupIds.add(asUuid)) {
          allUserLookupIds.add(asUuid);
        }
      } catch (_) {}
    }

    for (final t in teams) {
      final rawTid = t.id.trim().toLowerCase();
      if (rawTid.isEmpty) continue;
      final tidUuid = SupabaseService.toUuid(t.id.trim()).toLowerCase();
      final Map<String, int> memberMap = {};
      resultByTeam[rawTid] = memberMap;
      resultByTeam[tidUuid] = memberMap;

      if (t.leaderId.trim().isNotEmpty) {
        final lid = t.leaderId.trim();
        memberMap[lid] = 0;
        memberMap[lid.toLowerCase()] = 0;
        memberMap[SupabaseService.toUuid(lid).toLowerCase()] = 0;
        registerUserLookupId(lid);
      }
      for (final m in t.cappedMembers) {
        final mid = m.trim();
        if (mid.isEmpty) continue;
        memberMap[mid] = 0;
        memberMap[mid.toLowerCase()] = 0;
        memberMap[SupabaseService.toUuid(mid).toLowerCase()] = 0;
        registerUserLookupId(mid);
      }
    }

    if (allUserLookupIds.isEmpty) return resultByTeam;

    // 0. Check public.reward_claims to determine if any team has already completed a delivered
    //    weekly reward cycle in this weekKey. Any contribution made at or before the team's
    //    delivered reward timestamp is reset to 0 so new rounds/weeks start cleanly from 0.
    final Map<String, bool> teamHasDeliveredReset = {};
    final Map<String, int> teamResetCutoffMs = {};
    try {
      final List<Map<String, dynamic>> mergedClaims = [];
      final Set<String> seenClaimKeys = {};
      for (final c in SupabaseService.cachedRewardClaims) {
        final k = ((c['id'] ?? c['claim_code']) ?? '').toString().trim();
        if (k.isNotEmpty && seenClaimKeys.add(k)) {
          mergedClaims.add(c);
        }
      }
      try {
        final dbClaims = await SupabaseService.client
            .from('reward_claims')
            .select()
            .order('created_at', ascending: false)
            .limit(500);
        for (final raw in dbClaims) {
          final c = Map<String, dynamic>.from(raw);
          final k = ((c['id'] ?? c['claim_code']) ?? '').toString().trim();
          if (k.isNotEmpty) {
            if (seenClaimKeys.add(k)) {
              mergedClaims.add(c);
            } else {
              final idx = mergedClaims.indexWhere(
                (x) => ((x['id'] ?? x['claim_code']) ?? '').toString().trim() == k,
              );
              if (idx >= 0) mergedClaims[idx] = c;
            }
          }
        }
      } catch (_) {}

      for (final t in teams) {
        final rawTid = t.id.trim().toLowerCase();
        if (rawTid.isEmpty) continue;
        final tidUuid = SupabaseService.toUuid(t.id.trim()).toLowerCase();
        final resetInfo = evaluateTeamRewardCycleReset(
          team: t,
          allClaims: mergedClaims,
          weekKey: weekKey,
        );
        final bool hasReset = resetInfo['hasCompletedDeliveredRound'] == true;
        final int cutoffMs = (resetInfo['cutoffUtcMs'] as int?) ?? 0;
        teamHasDeliveredReset[rawTid] = hasReset;
        teamHasDeliveredReset[tidUuid] = hasReset;
        teamResetCutoffMs[rawTid] = cutoffMs;
        teamResetCutoffMs[tidUuid] = cutoffMs;
      }
    } catch (_) {}

    // 1. Query dedicated team_coin_contributions table if provisioned in Supabase
    bool dbQuerySucceeded = false;
    try {
      final contribRows = await SupabaseService.client
          .from('team_coin_contributions')
          .select()
          .eq('week_key', weekKey);
      for (final r in contribRows) {
        final rawAmount = (r['amount'] as num?)?.toInt() ?? 0;
        final amount = rawAmount.abs();
        if (amount <= 0) continue;

        final rTeamId = (r['team_id'] ?? '').toString().trim();
        final rUserId = (r['user_id'] ?? r['member_id'] ?? '').toString().trim();
        final rGameRaw = (r['game_name'] ?? '').toString().trim();
        if (rTeamId.isEmpty || rUserId.isEmpty || rGameRaw.isEmpty) continue;

        final rTeamUuid = SupabaseService.toUuid(rTeamId).toLowerCase();
        final rUserUuid = SupabaseService.toUuid(rUserId).toLowerCase();
        final rGameKey = normalizeGameKey(rGameRaw);

        // If this team completed a delivered reward cycle, only count contributions strictly AFTER cutoffMs
        final bool hasReset = teamHasDeliveredReset[rTeamUuid] == true;
        final int cutoffMs = teamResetCutoffMs[rTeamUuid] ?? 0;
        if (hasReset) {
          final int rowMs = parseUtcMs(r['created_at']);
          if (rowMs <= 0 || rowMs <= cutoffMs) {
            continue;
          }
        }

        final tupleKey = '$rTeamUuid|$rGameKey|$rUserUuid';
        tableSumByExactTuple[tupleKey] = (tableSumByExactTuple[tupleKey] ?? 0) + amount;
      }
    } catch (_) {}

    // 2. Query coin_transactions for manual team_weekly_contribution records in this weekly cycle
    final int weekStartMs = weekStart.millisecondsSinceEpoch;
    final int weekEndMs = weekEnd.millisecondsSinceEpoch;
    try {
      final DateTime queryEndBound =
          forDate != null ? weekEnd : weekEnd.add(const Duration(hours: 2));
      final txRows = await SupabaseService.client
          .from('coin_transactions')
          .select()
          .inFilter('user_id', allUserLookupIds)
          .eq('type', 'team_weekly_contribution')
          .gte('created_at', weekStart.toIso8601String())
          .lte('created_at', queryEndBound.toIso8601String());
      dbQuerySucceeded = true;

      for (final r in txRows) {
        final type = (r['type'] ?? '').toString().trim().toLowerCase();
        if (type != 'team_weekly_contribution') continue;

        final rawAmount = (r['amount'] as num?)?.toInt() ?? 0;
        final contributedAmount = rawAmount.abs();
        if (contributedAmount <= 0) continue;

        final String desc = (r['description'] ?? '').toString();
        final String ref =
            (r['room_id'] ?? r['reference_id'] ?? r['roomId'] ?? '').toString().trim();

        String? extractedTeamId = (r['team_id'] ?? '').toString().trim();
        if (extractedTeamId.isEmpty) extractedTeamId = null;

        String? extractedUserId = (r['user_id'] ?? r['userId'] ?? '').toString().trim();
        if (extractedUserId.isEmpty) extractedUserId = null;

        String? extractedGameRaw = (r['game_name'] ?? '').toString().trim();
        if (extractedGameRaw.isEmpty) extractedGameRaw = null;

        String? extractedWeekKey;
        int? extractedContribUtcMs;

        // Parse structured metadata tag:
        // [team_id:<teamUuid>|raw_team_id:<rawTeamId>|user_id:<userUuid>|raw_user_id:<cleanUid>|game_name:<gameKey>|week_key:<weekKey>|contrib_utc_ms:<ms>]
        final teamTagMatch = RegExp(r'team_id:([^\|\]]+)').firstMatch(desc);
        if (teamTagMatch != null) {
          extractedTeamId = teamTagMatch.group(1)!.trim();
        }
        final userTagMatch = RegExp(r'user_id:([^\|\]]+)').firstMatch(desc);
        if (userTagMatch != null) {
          extractedUserId = userTagMatch.group(1)!.trim();
        }
        final gameTagMatch = RegExp(r'game_name:([^\|\]]+)').firstMatch(desc);
        if (gameTagMatch != null) {
          extractedGameRaw = gameTagMatch.group(1)!.trim();
        }
        final weekTagMatch = RegExp(r'week_key:([^\|\]]+)').firstMatch(desc);
        if (weekTagMatch != null) {
          extractedWeekKey = weekTagMatch.group(1)!.trim();
        }
        final msTagMatch = RegExp(r'contrib_utc_ms:(\d+)').firstMatch(desc);
        if (msTagMatch != null) {
          extractedContribUtcMs = int.tryParse(msTagMatch.group(1)!.trim());
        }

        // Parse pipe format in room_id / reference_id:
        // team_contrib|<weekKey>|<teamUuid>|<gameKey>|<userUuid>|<contribUtcMs>
        if (ref.startsWith('team_contrib|')) {
          final parts = ref.split('|');
          if (parts.length >= 4) {
            extractedWeekKey ??= parts[1].trim();
            extractedTeamId ??= parts[2].trim();
            extractedGameRaw ??= parts[3].trim();
            if (parts.length >= 5 && parts[4].trim().isNotEmpty) {
              extractedUserId ??= parts[4].trim();
            }
            if (parts.length >= 6 && parts[5].trim().isNotEmpty) {
              extractedContribUtcMs ??= int.tryParse(parts[5].trim());
            }
          }
        } else if (ref.startsWith('weekly_team_contrib_')) {
          final prefix = 'weekly_team_contrib_${weekKey}_';
          if (ref.startsWith(prefix)) {
            final tid = ref.substring(prefix.length).trim();
            if (tid.isNotEmpty) {
              extractedWeekKey ??= weekKey;
              extractedTeamId ??= tid;
            }
          }
        }

        if ((extractedTeamId == null || extractedTeamId.isEmpty) &&
            extractedUserId != null &&
            extractedUserId.isNotEmpty) {
          final descMatch = RegExp(
            r'to Team "([^"]+)" for ([^\(]+?) Weekly Competition',
            caseSensitive: false,
          ).firstMatch(desc);
          if (descMatch != null) {
            final targetTeamLabel = descMatch.group(1)!.trim().toLowerCase();
            final targetGameLabel = descMatch.group(2)!.trim();
            final targetGameKey = normalizeGameKey(targetGameLabel);
            final txUserUuidLower = SupabaseService.toUuid(extractedUserId).toLowerCase();
            final txUserRawLower = extractedUserId.toLowerCase();

            final matchingTeams = teams.where((t) {
              final tGameKey = normalizeGameKey(t.game);
              if (tGameKey != targetGameKey) return false;
              final tName = t.name.trim().toLowerCase();
              final tNameWithTag = '${t.name.trim()} [${t.tag.trim()}]'.toLowerCase();
              if (tName != targetTeamLabel && tNameWithTag != targetTeamLabel) {
                return false;
              }
              final isUserInTeam = t.isLeader(extractedUserId!) ||
                  t.isMember(extractedUserId) ||
                  SupabaseService.toUuid(t.leaderId).toLowerCase() == txUserUuidLower ||
                  t.cappedMembers.any((m) =>
                      m.trim().toLowerCase() == txUserRawLower ||
                      SupabaseService.toUuid(m.trim()).toLowerCase() == txUserUuidLower);
              return isUserInTeam;
            }).toList();

            if (matchingTeams.length == 1) {
              extractedTeamId = matchingTeams.first.id.trim();
              extractedGameRaw ??= targetGameKey;
            }
          }
        }

        if (extractedTeamId != null &&
            extractedTeamId.isNotEmpty &&
            (extractedGameRaw == null || extractedGameRaw.isEmpty)) {
          final tidUuid = SupabaseService.toUuid(extractedTeamId).toLowerCase();
          final tidRaw = extractedTeamId.toLowerCase();
          for (final t in teams) {
            if (t.id.trim().toLowerCase() == tidRaw ||
                SupabaseService.toUuid(t.id.trim()).toLowerCase() == tidUuid) {
              extractedGameRaw = normalizeGameKey(t.game);
              break;
            }
          }
        }

        if (extractedTeamId == null ||
            extractedTeamId.isEmpty ||
            extractedUserId == null ||
            extractedUserId.isEmpty ||
            extractedGameRaw == null ||
            extractedGameRaw.isEmpty) {
          continue;
        }

        if (extractedWeekKey != null &&
            extractedWeekKey.isNotEmpty &&
            extractedWeekKey != weekKey) {
          continue;
        }
        if (forDate != null) {
          final int txMs = extractedContribUtcMs ?? parseUtcMs(r['created_at']);
          if (txMs > 0 && (txMs < weekStartMs || txMs > weekEndMs)) {
            continue;
          }
        }

        final txTeamUuid = SupabaseService.toUuid(extractedTeamId).toLowerCase();
        final txUserUuid = SupabaseService.toUuid(extractedUserId).toLowerCase();
        final txGameKey = normalizeGameKey(extractedGameRaw);

        // If this team has already completed a delivered reward cycle in this week,
        // reset any pre-delivery contribution to 0 and only count new contributions made strictly AFTER cutoffMs.
        final bool hasReset = teamHasDeliveredReset[txTeamUuid] == true;
        final int cutoffMs = teamResetCutoffMs[txTeamUuid] ?? 0;
        if (hasReset) {
          if (extractedContribUtcMs != null) {
            if (extractedContribUtcMs <= cutoffMs) {
              continue;
            }
          } else {
            // Legacy contribution row before contrib_utc_ms tag was added belongs to the already-delivered cycle
            continue;
          }
        }

        final tupleKey = '$txTeamUuid|$txGameKey|$txUserUuid';
        txSumByExactTuple[tupleKey] = (txSumByExactTuple[tupleKey] ?? 0) + contributedAmount;
      }
    } catch (e) {
      debugPrint('[TeamService] _getTeamsWeeklyContributionsByMember Supabase query note: $e');
    }

    // 3. Populate each team's member map strictly for (teamUuid, teamGameKey, memberUuid)
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final oldKeys = prefs
          .getKeys()
          .where((k) =>
              k.startsWith('weekly_user_contrib_') ||
              k.startsWith('weekly_team_member_'))
          .toList();
      for (final k in oldKeys) {
        await prefs.remove(k);
      }
    } catch (_) {}

    for (final t in teams) {
      final rawTid = t.id.trim().toLowerCase();
      if (rawTid.isEmpty) continue;
      final teamUuid = SupabaseService.toUuid(t.id.trim()).toLowerCase();
      final teamGameKey = normalizeGameKey(t.game);
      final memberMap = resultByTeam[teamUuid];
      if (memberMap == null) continue;

      final bool hasReset = teamHasDeliveredReset[teamUuid] == true;

      final roster = <String>[];
      if (t.leaderId.trim().isNotEmpty) roster.add(t.leaderId.trim());
      for (final m in t.cappedMembers) {
        final cleanM = m.trim();
        if (cleanM.isNotEmpty && !roster.contains(cleanM)) {
          roster.add(cleanM);
        }
      }

      for (final uid in roster) {
        final uidLower = uid.toLowerCase();
        final userUuid = SupabaseService.toUuid(uid).toLowerCase();
        final tupleKey = '$teamUuid|$teamGameKey|$userUuid';

        final int txVal = txSumByExactTuple[tupleKey] ?? 0;
        final int tableVal = tableSumByExactTuple[tupleKey] ?? 0;
        int resolvedCoins = txVal > 0 ? txVal : tableVal;

        if (forDate == null && prefs != null) {
          final exactLocalKey =
              'weekly_exact_contrib_v3_${weekKey}_${teamUuid}_${teamGameKey}_$userUuid';
          if (hasReset || dbQuerySucceeded) {
            // Keep local cache strictly in sync with DB post-reset value (including 0 after reward delivery!)
            await prefs.setInt(exactLocalKey, resolvedCoins);
          } else {
            final localVal = prefs.getInt(exactLocalKey) ?? 0;
            if (resolvedCoins > 0) {
              if (localVal != resolvedCoins) {
                await prefs.setInt(exactLocalKey, resolvedCoins);
              }
            } else if (localVal > 0) {
              resolvedCoins = localVal;
            }
          }
        }

        memberMap[uid] = resolvedCoins;
        memberMap[uidLower] = resolvedCoins;
        memberMap[userUuid] = resolvedCoins;
      }
    }

    return resultByTeam;
  }

  /// Computes a team's 4-member Weekly Team Coins summary, current weekly rank in their game,
  /// and itemized breakdown of each member's weekly coin contribution strictly for
  /// (team_id, user_id, game_name).
  Future<Map<String, dynamic>> getTeamWeeklyCoinStats(
    TeamModel team, {
    DateTime? forDate,
  }) async {
    final normalizedGameDisplay = displayGameLabel(team.game);
    final leaderboard = await getGameWeeklyLeaderboard(normalizedGameDisplay, forDate: forDate);
    final teamIdLower = team.id.trim().toLowerCase();
    final teamUuidLower = SupabaseService.toUuid(team.id).toLowerCase();

    Map<String, dynamic>? matchedEntry;
    for (final entry in leaderboard) {
      final eId = (entry['teamId'] ?? '').toString().trim().toLowerCase();
      final eUuid = SupabaseService.toUuid(eId).toLowerCase();
      if (eId == teamIdLower || eUuid == teamUuidLower) {
        matchedEntry = Map<String, dynamic>.from(entry);
        break;
      }
    }

    // Evaluate Week-End / Monday Claim Window eligibility against the concluded weekly cycle
    // so mid-week or current-cycle coin contributions never prematurely unlock reward claims.
    bool claimWindowOpen = false;
    bool isClaimEligible = false;
    int concludedWeekRank = 0;
    int concludedWeekCoins = 0;
    final String concludedWeekKey = getConcludedWeekKey();
    final String concludedWeekRangeLabel = getConcludedWeekRangeLabel();

    if (forDate == null) {
      claimWindowOpen = isWeeklyClaimWindowOpen();
      if (claimWindowOpen && isWeeklyCompetitionGame(normalizedGameDisplay)) {
        try {
          final String concludedCacheKey =
              '${normalizedGameDisplay.toLowerCase()}_concluded_$concludedWeekKey';
          List<Map<String, dynamic>>? concludedLeaderboard =
              _gameLeaderboardCache[concludedCacheKey];
          if (concludedLeaderboard == null) {
            concludedLeaderboard = await getGameWeeklyLeaderboard(
              normalizedGameDisplay,
              forDate: getConcludedWeekSampleDate(),
            );
            _gameLeaderboardCache[concludedCacheKey] = concludedLeaderboard;
          }
          for (final entry in concludedLeaderboard) {
            final eId = (entry['teamId'] ?? '').toString().trim().toLowerCase();
            final eUuid = eId.isNotEmpty ? SupabaseService.toUuid(eId).toLowerCase() : '';
            if (eId == teamIdLower || eUuid == teamUuidLower) {
              concludedWeekRank = (entry['weeklyRank'] as num?)?.toInt() ?? 0;
              concludedWeekCoins = (entry['weeklyCoins'] as num?)?.toInt() ?? 0;
              break;
            }
          }
          if (concludedWeekRank == 1 && concludedWeekCoins > 0) {
            isClaimEligible = true;
          }
        } catch (_) {}
      }
    }

    if (matchedEntry != null) {
      final res = {
        ...matchedEntry,
        'game': normalizedGameDisplay,
        'totalTeamsInGame': leaderboard.length,
        'weekRangeLabel': getWeekRangeLabel(forDate),
        'weekKey': getWeekCycleKey(forDate),
        'rewardPool': weeklyGameRewardPool,
        'isClaimWindowOpen': claimWindowOpen,
        'isClaimEligible': isClaimEligible,
        'concludedWeekRank': concludedWeekRank,
        'concludedWeekCoins': concludedWeekCoins,
        'concludedWeekKey': concludedWeekKey,
        'concludedWeekRangeLabel': concludedWeekRangeLabel,
      };
      if (forDate == null) {
        _storeTeamWeeklyStatsCache(team.id, res);
      }
      return res;
    }

    // If team was not yet in leaderboard snapshot, compute strictly for this team
    final roster = <String>[];
    final seenRosterUuids = <String>{};
    void addRosterMember(String uid) {
      final clean = uid.trim();
      if (clean.isEmpty || roster.length >= maxTeamMembers) return;
      final uuidKey = SupabaseService.toUuid(clean).toLowerCase();
      if (seenRosterUuids.contains(uuidKey)) return;
      seenRosterUuids.add(uuidKey);
      roster.add(clean);
    }

    if (team.leaderId.isNotEmpty) addRosterMember(team.leaderId);
    for (final m in team.cappedMembers) {
      addRosterMember(m);
    }

    final teamWithDisplayGame = team.copyWith(
      game: normalizedGameDisplay,
      members: roster,
    );
    final contribsByTeam = await _getTeamsWeeklyContributionsByMember(
      [teamWithDisplayGame],
      forDate: forDate,
    );
    final memberContribs =
        contribsByTeam[teamUuidLower] ?? contribsByTeam[teamIdLower] ?? const <String, int>{};
    final handlesByUser = await _fetchPublicHandlesForUsers(roster);

    int directTotalWeeklyCoins = 0;
    final List<Map<String, dynamic>> directMemberBreakdown = [];
    final Map<String, String> directMemberNames = {};
    final Map<String, int> directMemberCoins = {};

    for (final uid in roster) {
      final lower = uid.trim().toLowerCase();
      final uuidLower = SupabaseService.toUuid(uid).toLowerCase();
      final earned =
          memberContribs[uid] ?? memberContribs[lower] ?? memberContribs[uuidLower] ?? 0;
      directTotalWeeklyCoins += earned;

      final handleInfo = handlesByUser[lower] ?? handlesByUser[uuidLower];
      final isLeader = team.isLeader(uid);
      final publicHandle = handleInfo?['handle'] ??
          (isLeader ? sanitizePublicHandle(team.leaderName, fallback: 'Leader') : 'Gamer');

      directMemberNames[uid] = publicHandle;
      directMemberCoins[uid] = earned;
      directMemberCoins[lower] = earned;
      directMemberCoins[uuidLower] = earned;

      directMemberBreakdown.add({
        'userId': uid,
        'handle': publicHandle,
        'gamerId': handleInfo?['gamerId'] ?? publicHandle,
        'avatar': handleInfo?['avatar'] ?? '',
        'role': isLeader ? 'Leader' : 'Member',
        'weeklyCoins': earned,
      });
    }

    final memberCount = roster.isNotEmpty ? roster.length : 1;
    final fallbackRes = {
      'teamId': team.id,
      'teamName': team.name,
      'teamTag': team.tag,
      'game': normalizedGameDisplay,
      'weeklyCoins': directTotalWeeklyCoins,
      'weeklyRank': leaderboard.isEmpty ? 1 : (leaderboard.length + 1),
      'totalTeamsInGame': leaderboard.isEmpty ? 1 : (leaderboard.length + 1),
      'memberCount': memberCount,
      'equalRewardShare': (weeklyGameRewardPool / memberCount).floor(),
      'rewardPool': weeklyGameRewardPool,
      'weekRangeLabel': getWeekRangeLabel(forDate),
      'weekKey': getWeekCycleKey(forDate),
      'isClaimWindowOpen': claimWindowOpen,
      'isClaimEligible': isClaimEligible,
      'concludedWeekRank': concludedWeekRank,
      'concludedWeekCoins': concludedWeekCoins,
      'concludedWeekKey': concludedWeekKey,
      'concludedWeekRangeLabel': concludedWeekRangeLabel,
      'memberIds': roster,
      'memberNames': directMemberNames,
      'memberCoins': directMemberCoins,
      'memberBreakdown': directMemberBreakdown,
    };
    if (forDate == null) {
      _storeTeamWeeklyStatsCache(team.id, fallbackRes);
    }
    return fallbackRes;
  }

  /// Returns the Per-Game Weekly Team Coins Leaderboard for [game].
  /// Each team's total coins and each member's contribution badge are strictly the sum
  /// of records matching that exact (team_id, user_id, game_name).
  Future<List<Map<String, dynamic>>> getGameWeeklyLeaderboard(
    String game, {
    DateTime? forDate,
  }) async {
    try {
      final rawTeams = await _fetchAllTeamsEnriched(
        gameFilter: (game.isEmpty || game == 'All') ? null : game,
      );
      if (rawTeams.isEmpty) return [];

      // Normalize every team's display game label ('PUBG Mobile' instead of 'BGMI', 'Free Fire')
      final allTeams = rawTeams
          .map((t) => t.copyWith(game: displayGameLabel(t.game)))
          .toList();

      final allMemberIds = <String>{};
      for (final t in allTeams) {
        if (t.leaderId.isNotEmpty) allMemberIds.add(t.leaderId);
        for (final m in t.cappedMembers) {
          if (m.isNotEmpty) allMemberIds.add(m);
        }
      }

      final contribsByTeam = await _getTeamsWeeklyContributionsByMember(
        allTeams,
        forDate: forDate,
      );
      final handlesByUser = await _fetchPublicHandlesForUsers(allMemberIds.toList());

      final List<Map<String, dynamic>> entries = [];
      for (final t in allTeams) {
        final roster = <String>[];
        final seenUuids = <String>{};
        void addMember(String uid) {
          final clean = uid.trim();
          if (clean.isEmpty || roster.length >= maxTeamMembers) return;
          final uuidKey = SupabaseService.toUuid(clean).toLowerCase();
          if (seenUuids.contains(uuidKey)) return;
          seenUuids.add(uuidKey);
          roster.add(clean);
        }

        if (t.leaderId.isNotEmpty) addMember(t.leaderId);
        for (final m in t.cappedMembers) {
          addMember(m);
        }

        final tIdLower = t.id.trim().toLowerCase();
        final tUuidLower = SupabaseService.toUuid(t.id.trim()).toLowerCase();
        final teamMemberContribs =
            contribsByTeam[tUuidLower] ?? contribsByTeam[tIdLower] ?? const <String, int>{};

        int teamWeeklyTotal = 0;
        final List<Map<String, dynamic>> memberBreakdown = [];
        final Map<String, String> memberNamesMap = {};
        final Map<String, int> memberCoinsMap = {};

        for (final uid in roster) {
          final lower = uid.trim().toLowerCase();
          final uuidLower = SupabaseService.toUuid(uid).toLowerCase();
          final earned = teamMemberContribs[uid] ??
              teamMemberContribs[lower] ??
              teamMemberContribs[uuidLower] ??
              0;
          teamWeeklyTotal += earned;

          final handleInfo = handlesByUser[lower] ?? handlesByUser[uuidLower];
          final isLeader = t.isLeader(uid);
          final publicHandle = handleInfo?['handle'] ??
              (isLeader ? sanitizePublicHandle(t.leaderName, fallback: 'Leader') : 'Gamer');

          memberNamesMap[uid] = publicHandle;
          memberNamesMap[lower] = publicHandle;
          memberNamesMap[uuidLower] = publicHandle;

          memberCoinsMap[uid] = earned;
          memberCoinsMap[lower] = earned;
          memberCoinsMap[uuidLower] = earned;

          memberBreakdown.add({
            'userId': uid,
            'handle': publicHandle,
            'gamerId': handleInfo?['gamerId'] ?? publicHandle,
            'avatar': handleInfo?['avatar'] ?? '',
            'role': isLeader ? 'Leader' : 'Member',
            'weeklyCoins': earned,
          });
        }

        final mCount = roster.isNotEmpty ? roster.length : 1;
        final displayGame = displayGameLabel(t.game);
        final enrichedTeam = t.copyWith(
          game: displayGame,
          members: roster,
          memberNames: memberNamesMap,
          weeklyCoins: teamWeeklyTotal,
          memberWeeklyCoins: memberCoinsMap,
        );

        entries.add({
          'team': enrichedTeam,
          'teamId': t.id,
          'teamName': t.name,
          'teamTag': t.tag,
          'game': displayGame,
          'wins': t.wins,
          'points': t.points,
          'weeklyCoins': teamWeeklyTotal,
          'memberCount': mCount,
          'maxMembers': maxTeamMembers,
          'equalRewardShare': (weeklyGameRewardPool / mCount).floor(),
          'rewardPool': weeklyGameRewardPool,
          'leaderHandle': sanitizePublicHandle(t.leaderName, fallback: 'Leader'),
          'memberIds': roster,
          'memberNames': memberNamesMap,
          'memberCoins': memberCoinsMap,
          'memberBreakdown': memberBreakdown,
        });
      }

      // Sort by weeklyCoins descending, then points descending, then wins descending
      entries.sort((a, b) {
        final wcComp = ((b['weeklyCoins'] as int?) ?? 0)
            .compareTo((a['weeklyCoins'] as int?) ?? 0);
        if (wcComp != 0) return wcComp;
        final ptComp = ((b['points'] as int?) ?? 0)
            .compareTo((a['points'] as int?) ?? 0);
        if (ptComp != 0) return ptComp;
        return ((b['wins'] as int?) ?? 0).compareTo((a['wins'] as int?) ?? 0);
      });

      for (int i = 0; i < entries.length; i++) {
        final rank = i + 1;
        entries[i]['weeklyRank'] = rank;
        entries[i]['rank'] = rank;
        entries[i]['totalTeamsInGame'] = entries.length;
        entries[i]['weekRangeLabel'] = getWeekRangeLabel(forDate);
        entries[i]['weekKey'] = getWeekCycleKey(forDate);
        final currentTeam = entries[i]['team'];
        if (currentTeam is TeamModel) {
          entries[i]['team'] = currentTeam.copyWith(weeklyRank: rank);
        }
        if (forDate == null) {
          final tid = (entries[i]['teamId'] ?? '').toString();
          if (tid.isNotEmpty) {
            _storeTeamWeeklyStatsCache(tid, entries[i]);
          }
        }
      }

      if (forDate == null) {
        _gameLeaderboardCache[game.trim()] = entries;
        _gameLeaderboardCache[game.trim().toLowerCase()] = entries;
      }
      return entries;
    } catch (e) {
      debugPrint('[TeamService] getGameWeeklyLeaderboard error: $e');
      return getCachedGameWeeklyLeaderboard(game) ?? [];
    }
  }

  /// At the end of each 7-day weekly cycle, identifies the #1 team with the highest weekly coins
  /// in Free Fire and PUBG Mobile separately, divides that game's 1,500 PKR equivalent in-game
  /// currency reward equally among that winning #1 team's active members (up to 4 members),
  /// and records the reward distribution in their redemption/transaction history with clear labels.
  static bool _isCheckingWeeklyRewards = false;
  Future<void> checkAndDistributeWeeklyGameRewards() async {
    if (_isCheckingWeeklyRewards) return;
    _isCheckingWeeklyRewards = true;

    try {
      await _ensureWeeklyCycleReset();
      final prefs = await SharedPreferences.getInstance();
      final currentWeekStart = getWeekStartUtc();
      final previousWeekDate = currentWeekStart.subtract(const Duration(days: 3));
      final prevWeekKey = getWeekCycleKey(previousWeekDate);
      final prevWeekLabel = getWeekRangeLabel(previousWeekDate);

      for (final game in supportedGames) {
        final gameSlug = game.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        final payoutRefId = 'weekly_top1_${prevWeekKey}_$gameSlug';
        final localPaidKey = 'paid_$payoutRefId';

        if (prefs.getBool(localPaidKey) == true) {
          continue;
        }

        // Check if already distributed in Supabase coin_transactions
        bool alreadyPaidInDb = false;
        try {
          final existingTx = await SupabaseService.client
              .from('coin_transactions')
              .select('id')
              .or('room_id.eq.$payoutRefId,reference_id.eq.$payoutRefId')
              .eq('type', 'weekly_team_reward')
              .limit(1);
          if (existingTx is List && existingTx.isNotEmpty) {
            alreadyPaidInDb = true;
          }
        } catch (_) {}

        if (alreadyPaidInDb) {
          await prefs.setBool(localPaidKey, true);
          continue;
        }

        // Evaluate previous week's leaderboard for this specific game (Free Fire or PUBG Mobile)
        final prevGameLeaderboard = await getGameWeeklyLeaderboard(
          game,
          forDate: previousWeekDate,
        );
        if (prevGameLeaderboard.isEmpty) continue;

        final topTeamEntry = prevGameLeaderboard.first;
        final topWeeklyCoins = (topTeamEntry['weeklyCoins'] as int?) ?? 0;
        if (topWeeklyCoins <= 0) {
          // Mark checked if no team contributed coins in that week for this game
          await prefs.setBool(localPaidKey, true);
          continue;
        }

        final winningTeamName = (topTeamEntry['teamName'] ?? 'Team').toString();
        final winningTeamTag = (topTeamEntry['teamTag'] ?? '').toString();
        final List<String> memberIds = List<String>.from(topTeamEntry['memberIds'] ?? <String>[])
            .take(maxTeamMembers)
            .toList();

        if (memberIds.isEmpty) continue;

        final int memberCount = memberIds.length.clamp(1, maxTeamMembers);
        final int equalPkrShare = getEqualPkrShare(memberCount);
        final String currencyLabel = getGameCurrencyLabel(game);

        if (equalPkrShare > 0) {
          for (final uid in memberIds) {
            try {
              await CoinWalletService.updateCoins(
                userId: uid,
                amount: equalPkrShare,
                type: 'weekly_team_reward',
                roomId: payoutRefId,
                title: '🏆 Weekly #1 Team Prize ($game • $equalPkrShare PKR $currencyLabel)',
                description:
                    'Equal Share (1/$memberCount of $weeklyGameRewardPkr PKR Equivalent in $currencyLabel) • #1 Team "$winningTeamName [$winningTeamTag]" in $game ($prevWeekLabel • $topWeeklyCoins Weekly Team Coins)',
              );

              try {
                await NotificationService().sendNotification(
                  userId: uid,
                  type: 'weekly_team_reward',
                  title: '🏆 Weekly #1 Team in $game! ($equalPkrShare PKR $currencyLabel)',
                  body:
                      'Your team "$winningTeamName" finished Rank #1 in $game for $prevWeekLabel! Your equal share ($equalPkrShare PKR equivalent in $currencyLabel • 1/$memberCount of 1,500 PKR) has been awarded.',
                  priority: 'high',
                );
              } catch (_) {}
            } catch (e) {
              debugPrint('[TeamService] Weekly reward payout error for $uid: $e');
            }
          }
        }

        await prefs.setBool(localPaidKey, true);
      }
    } catch (e) {
      debugPrint('[TeamService] checkAndDistributeWeeklyGameRewards error: $e');
    } finally {
      _isCheckingWeeklyRewards = false;
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
  String? currentUserId,
}) =>
    TeamService().deleteTeam(
      teamId: teamId,
      currentUserId: currentUserId,
    );
