import "dart:io";
import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:intl/intl.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../services/supabase_service.dart";
import "../models/team_model.dart";
import "../services/team_service.dart";
import "../widgets/team_card.dart";
import "../widgets/create_team_dialog.dart";
import "../widgets/end_match_dialog.dart";
import "team_matches_screen.dart";
import "team_match_room_screen.dart";
import "leaderboard_screen.dart";
import "private_match_room_screen.dart";
import "../services/coin_wallet_service.dart";
import "../services/notification_service.dart";

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TeamService _teamService = TeamService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedGameFilter = "All";
  String _searchQuery = "";
  final List<String> _gameFilterOptions = ["All", "BGMI", "Free Fire", "PUBG", "COD"];

  final Set<String> _cancelledChallengeIds = {};
  final Set<String> _acceptingChallengeIds = {};
  final Set<String> _acceptedChallengeIds = {};
  final Set<String> _completedMatchIds = {};
  final Set<String> _autoCompletingMatchIds = {};
  Map<String, String> _lastReadMatchTimes = {};

  @override
  void initState() {
    super.initState();
    _loadLastReadTimes();
  }

  Future<void> _loadLastReadTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith("last_read_match_"));
      final map = <String, String>{};
      for (final k in keys) {
        final mId = k.replaceFirst("last_read_match_", "");
        final v = prefs.getString(k);
        if (v != null) map[mId] = v;
      }
      if (mounted) setState(() => _lastReadMatchTimes = map);
    } catch (_) {}
  }

  Future<void> _markMatchAsRead(String matchId) async {
    final nowStr = DateTime.now().toUtc().toIso8601String();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("last_read_match_$matchId", nowStr);
    } catch (_) {}
    if (mounted) {
      setState(() => _lastReadMatchTimes[matchId] = nowStr);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showProofImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Match Proof 📸", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
            ),
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))),
                  errorWidget: (_, __, ___) => const SizedBox(height: 180, child: Center(child: Icon(Icons.broken_image, color: Colors.white30))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAcceptChallenge({
    required String challengeId,
    required String fromTeamId,
    required String toTeamId,
    Map<String, dynamic>? challengeData,
  }) async {
    final cId = challengeId.trim();
    if (_acceptingChallengeIds.contains(cId)) return;
    setState(() => _acceptingChallengeIds.add(cId));

    try {
      final targetChallengeId = challengeData?["id"]?.toString() ?? cId;
      bool rpcSuccess = false;
      try {
        await SupabaseService.client.rpc("accept_challenge_safe", params: {"p_challenge_id": targetChallengeId});
        rpcSuccess = true;
      } catch (rpcErr) {
        debugPrint("[TeamsScreen] accept_challenge_safe RPC notice: $rpcErr");
      }

      if (!rpcSuccess) {
        await SupabaseService.client.from("challenges").update({"status": "accepted"}).eq("id", targetChallengeId);

        final t1 = (challengeData?["from_team_id"] ?? fromTeamId).toString();
        final t2 = (challengeData?["to_team_id"] ?? toTeamId).toString();
        final t1Uuid = SupabaseService.toUuid(t1);
        final t2Uuid = SupabaseService.toUuid(t2);

        final existingMatches = await SupabaseService.client
            .from("active_matches")
            .select()
            .or('and(team1_id.eq.$t1Uuid,team2_id.eq.$t2Uuid),and(team1_id.eq.$t2Uuid,team2_id.eq.$t1Uuid)')
            .inFilter("status", ["active", "under_review"]);

        if (existingMatches.isEmpty) {
          final startTime =
              DateTime.now().add(const Duration(minutes: 1)).toUtc().toIso8601String();
          final matchPayload = <String, dynamic>{
            "team1_id": t1Uuid,
            "team2_id": t2Uuid,
            "participants": [t1Uuid, t2Uuid],
            "status": "active",
            "start_time": startTime,
            "created_at": DateTime.now().toUtc().toIso8601String(),
          };
          try {
            await SupabaseService.client
                .from("active_matches")
                .insert(matchPayload)
                .select()
                .maybeSingle();
          } catch (insertErr) {
            debugPrint("[TeamsScreen] Insert with participants notice: $insertErr");
            await SupabaseService.client.from("active_matches").insert({
              "team1_id": t1Uuid,
              "team2_id": t2Uuid,
              "status": "active",
              "start_time": startTime,
              "created_at": DateTime.now().toUtc().toIso8601String(),
            }).select().maybeSingle();
          }
        }
      }

      if (mounted) {
        setState(() => _acceptedChallengeIds.add(cId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Match Started! Live ho gaya"), backgroundColor: Color(0xFF2E7D32), duration: Duration(seconds: 3)),
        );
      }
    } catch (e) {
      debugPrint("[TeamsScreen] Error accepting challenge: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFFF4655)));
    } finally {
      if (mounted) setState(() => _acceptingChallengeIds.remove(cId));
    }
  }

  Future<void> _handleRejectChallenge(String challengeId) async {
    final cId = challengeId.trim();
    setState(() => _acceptedChallengeIds.add(cId));
    try {
      await SupabaseService.client.from("challenges").update({"status": "rejected"}).eq("id", cId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Challenge rejected")));
    } catch (e) {
      debugPrint("[TeamsScreen] Error rejecting challenge: $e");
    }
  }

  Future<void> _handleCancelChallenge(String challengeId) async {
    setState(() => _cancelledChallengeIds.add(challengeId));
    try {
      await SupabaseService.client.from("challenges").delete().eq("id", challengeId);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Challenge Cancel ho gaya"), backgroundColor: Color(0xFF1877F2)));
      }
    } catch (e) {
      debugPrint("[TeamsScreen] Error cancelling challenge: $e");
    }
  }

  void _openCreateTeamDialog() async {
    final created = await CreateTeamDialog.show(context);
    if (created == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Supabase Auth
    final currentUid = SupabaseService.client.auth.currentUser?.id ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text("Teams", style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            tooltip: "TOP 100 TEAMS Leaderboard",
            icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFF65676B)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          ),
        ],
      ),
      body: StreamBuilder<List<TeamModel>>(
        stream: currentUid.isNotEmpty ? _teamService.getUserTeamsStream(currentUid) : Stream.value([]),
        builder: (context, userTeamsSnap) {
          final userTeams = userTeamsSnap.data ?? [];
          final myLeaderTeams = userTeams.where((t) => t.isLeader(currentUid)).toList();
          final myTeam = myLeaderTeams.isNotEmpty ? myLeaderTeams.first : null;
          final String myTeamId = myTeam?.id ?? "";
          final String myTeamName = myTeam?.name ?? "";
          final String myTeamUuid = SupabaseService.toUuid(myTeamId);

          return Column(
            children: [
              // Top Bar: Search, Create Team, Game Filter
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE4E6EB)))),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(20)),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Color(0xFF050505), fontSize: 14),
                              decoration: InputDecoration(
                                hintText: "Search teams by name or tag...",
                                hintStyle: const TextStyle(color: Color(0xFF65676B), fontSize: 13),
                                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF65676B)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18, color: Color(0xFF65676B)),
                                        onPressed: () { _searchController.clear(); setState(() => _searchQuery = ""); },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val.trim()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _openCreateTeamDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1877F2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: const Size(0, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text("Create Team", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _gameFilterOptions.map((game) {
                          final isSel = _selectedGameFilter == game;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(game, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF050505), fontWeight: isSel ? FontWeight.bold : FontWeight.w600, fontSize: 12)),
                              selected: isSel,
                              selectedColor: const Color(0xFF1877F2),
                              backgroundColor: const Color(0xFFE4E6EB),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(color: isSel ? const Color(0xFF1877F2) : const Color(0xFFCED0D4)),
                              onSelected: (val) { if (val) setState(() => _selectedGameFilter = game); },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // 1. INCOMING CHALLENGES
              if (myTeamId.isNotEmpty)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client.from("challenges").stream(primaryKey: ["id"]).eq("to_team_id", myTeamUuid),
                  builder: (context, challengesSnap) {
                    if (!challengesSnap.hasData) return const SizedBox.shrink();
                    final docs = challengesSnap.data!
                        .where((d) => (d["status"] ?? "").toString().toLowerCase() == "pending")
                        .where((d) => !_acceptedChallengeIds.contains(d["id"]?.toString()))
                        .toList();
                    if (docs.isEmpty) return const SizedBox.shrink();

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1877F2).withOpacity(0.3), width: 1.5),
                        boxShadow: [BoxShadow(color: const Color(0xFF1877F2).withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: const Color(0xFFE7F3FF), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.flash_on_rounded, color: Color(0xFF1877F2), size: 18),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(child: Text("Incoming Challenges", style: TextStyle(color: Color(0xFF050505), fontWeight: FontWeight.bold, fontSize: 15))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFFF4655), borderRadius: BorderRadius.circular(12)),
                                child: Text("${docs.length} New", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...docs.map((doc) {
                            final challengeId = doc["id"];
                            final fromTeamName = doc["from_team_name"]?.toString() ?? "Opponent Team";
                            final fromTeamId = doc["from_team_id"]?.toString() ?? "";
                            final toTeamId = doc["to_team_id"]?.toString() ?? myTeamId;
                            final isAccepting = _acceptingChallengeIds.contains(challengeId.toString());

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCED0D4))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(radius: 18, backgroundColor: Color(0xFFCED0D4), child: Icon(Icons.shield_rounded, color: Color(0xFF1877F2), size: 20)),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text("Challenge from $fromTeamName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF050505)))),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: isAccepting ? null : () => _handleRejectChallenge(challengeId.toString()),
                                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF4655), side: const BorderSide(color: Color(0xFFFF4655)), padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: const Size(0, 34), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                          child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: isAccepting ? null : () => _handleAcceptChallenge(challengeId: challengeId.toString(), fromTeamId: fromTeamId, toTeamId: toTeamId, challengeData: doc),
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFF1877F2).withOpacity(0.6), disabledForegroundColor: Colors.white70, padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: const Size(0, 34), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                                          child: isAccepting
                                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                              : const Text("Accept", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),

              // 2. ACTIVE MATCH BANNER
              if (myTeamId.isNotEmpty)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client.from("active_matches").stream(primaryKey: ["id"]),
                  builder: (context, matchSnap) {
                    final rawList = matchSnap.data ?? [];
                    final sortedList = List<Map<String, dynamic>>.from(rawList);
                    sortedList.sort((a, b) => (b["created_at"] ?? "").toString().compareTo((a["created_at"] ?? "").toString()));

                    final Map<String, Map<String, dynamic>> dedupMap = {};
                    for (final m in sortedList) {
                      final id = m["id"]?.toString() ?? "";
                      if (id.isNotEmpty && !dedupMap.containsKey(id)) dedupMap[id] = m;
                    }

                    final myActiveMatches = dedupMap.values.where((m) {
                      final status = (m["status"] ?? "").toString().toLowerCase();
                      if (status != "active" && status != "under_review" && status != "rejected") return false;
                      if (_completedMatchIds.contains(m["id"]?.toString())) return false;

                      final List<String> pList = [];
                      final participants = m["participants"];
                      if (participants is List) {
                        for (final p in participants) { if (p != null) pList.add(p.toString().toLowerCase()); }
                      }
                      pList.add((m["team1_id"] ?? "").toString().toLowerCase());
                      pList.add((m["team2_id"] ?? "").toString().toLowerCase());

                      final myIdLower = myTeamId.toLowerCase();
                      final myUuidLower = myTeamUuid.toLowerCase();
                      return pList.any((p) => (myIdLower.isNotEmpty && (p == myIdLower || p.contains(myIdLower))) || (myUuidLower.isNotEmpty && (p == myUuidLower || p.contains(myUuidLower))));
                    }).toList();

                    if (myActiveMatches.isEmpty) return const SizedBox.shrink();

                    return Column(
                      children: myActiveMatches.map((match) {
                        return _ActiveMatchBothTeamsBanner(
                          key: ValueKey(match["id"]?.toString() ?? UniqueKey().toString()),
                          match: match,
                          myTeamId: myTeamId,
                          myTeamUuid: myTeamUuid,
                          myTeamName: myTeamName,
                          teamService: _teamService,
                          onShowProofImage: (url) => _showProofImageDialog(context, url),
                          onAutoCompleted: (mId) {
                            if (mounted) setState(() => _completedMatchIds.add(mId));
                          },
                        );
                      }).toList(),
                    );
                  },
                ),

              // 3. SENDER SIDE: Pending challenge banner & All Teams List
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: myTeamId.isNotEmpty ? SupabaseService.client.from("challenges").stream(primaryKey: ["id"]).eq("from_team_id", myTeamUuid) : Stream.value([]),
                  builder: (context, sentSnap) {
                    final sentDocs = sentSnap.data ?? [];
                    final activePendingList = sentDocs
                        .where((d) => (d["status"] ?? "").toString().toLowerCase() == "pending")
                        .where((d) => !_cancelledChallengeIds.contains(d["id"]?.toString()))
                        .toList();

                    return Column(
                      children: [
                        if (activePendingList.isNotEmpty)
                          ...activePendingList.map((doc) {
                            final challengeId = doc["id"]?.toString() ?? "";
                            final toTeamName = doc["to_team_name"]?.toString() ?? "Opponent Team";

                            return Container(
                              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFE8F4FD), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1877F2), width: 1.2)),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF1877F2), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text("✅ Aapka challenge bhej diya gaya hai - $toTeamName ko challenge bhej diya gaya hai, jawab ka intezar hai", style: const TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () => _handleCancelChallenge(challengeId),
                                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF4655), side: const BorderSide(color: Color(0xFFFF4655)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: const Size(0, 30), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), backgroundColor: Colors.white),
                                    child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ],
                              ),
                            );
                          }),

                        // All Teams List
                        Expanded(
                          child: StreamBuilder<List<TeamModel>>(
                            stream: _teamService.getTeamsStream(gameFilter: _selectedGameFilter, searchQuery: _searchQuery),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)));
                              }

                              final teams = snapshot.data ?? [];
                              if (teams.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.shield_rounded, size: 44, color: Color(0xFF65676B)),
                                        const SizedBox(height: 12),
                                        Text(_selectedGameFilter != "All" ? "No teams found for $_selectedGameFilter" : "No Teams Registered Yet", style: const TextStyle(color: Color(0xFF050505), fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        const Text("سب سے پہلے اپنی ٹیم بنائیں اور دوسری ٹیموں کے ساتھ مقابلہ کریں!", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF65676B), fontSize: 13)),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: _openCreateTeamDialog,
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                          icon: const Icon(Icons.add, color: Colors.white),
                                          label: const Text("Create First Team", style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                itemCount: teams.length,
                                itemBuilder: (context, index) {
                                  final team = teams[index];
                                  final targetUuid = SupabaseService.toUuid(team.id).toLowerCase();
                                  final rawTeamId = team.id.toLowerCase();
                                  final matchingPending = activePendingList.firstWhere(
                                    (d) {
                                      final toId = d["to_team_id"]?.toString().toLowerCase();
                                      return toId == targetUuid || toId == rawTeamId;
                                    },
                                    orElse: () => {},
                                  );

                                  return TeamCard(
                                    team: team,
                                    myTeamId: myTeamId,
                                    myTeamName: myTeamName,
                                    pendingChallenge: matchingPending.isNotEmpty ? matchingPending : null,
                                    onCancelChallenge: _handleCancelChallenge,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActiveMatchBothTeamsBanner extends StatefulWidget {
  final Map<String, dynamic> match;
  final String myTeamId;
  final String myTeamUuid;
  final String myTeamName;
  final TeamService teamService;
  final void Function(String imageUrl) onShowProofImage;
  final void Function(String matchId) onAutoCompleted;

  const _ActiveMatchBothTeamsBanner({
    super.key,
    required this.match,
    required this.myTeamId,
    required this.myTeamUuid,
    required this.myTeamName,
    required this.teamService,
    required this.onShowProofImage,
    required this.onAutoCompleted,
  });

  @override
  State<_ActiveMatchBothTeamsBanner> createState() =>
      _ActiveMatchBothTeamsBannerState();
}

class _ActiveMatchBothTeamsBannerState
    extends State<_ActiveMatchBothTeamsBanner> {
  Timer? _timer;
  TeamModel? _myTeam;
  TeamModel? _oppTeam;
  String _myLeaderName = "Leader";
  String _oppLeaderName = "Leader";
  int _myMemberCount = 1;
  int _oppMemberCount = 1;
  bool _isLoading = true;
  bool _autoCompletedTriggered = false;

  @override
  void initState() {
    super.initState();
    _fetchTeams();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTeams() async {
    final t1 = widget.match["team1_id"]?.toString() ?? "";
    final t2 = widget.match["team2_id"]?.toString() ?? "";

    final isT1Mine = t1.toLowerCase() == widget.myTeamUuid.toLowerCase() ||
        t1.toLowerCase() == widget.myTeamId.toLowerCase();
    final myTId = isT1Mine ? t1 : t2;
    final oppTId = isT1Mine ? t2 : t1;

    try {
      final myT = await widget.teamService.getTeam(myTId);
      final oppT = await widget.teamService.getTeam(oppTId);

      String myLeader = "Leader";
      String oppLeader = "Leader";

      if (myT?.leaderId != null && myT!.leaderId.isNotEmpty) {
        try {
          final u = await SupabaseService.client
              .from('users')
              .select('display_name, username')
              .eq('id', myT.leaderId)
              .maybeSingle();
          myLeader = u?['display_name'] ?? u?['username'] ?? 'Leader';
        } catch (_) {}
      }

      if (oppT?.leaderId != null && oppT!.leaderId.isNotEmpty) {
        try {
          final u = await SupabaseService.client
              .from('users')
              .select('display_name, username')
              .eq('id', oppT.leaderId)
              .maybeSingle();
          oppLeader = u?['display_name'] ?? u?['username'] ?? 'Leader';
        } catch (_) {}
      }

      int myCount = 1;
      int oppCount = 1;
      try {
        final res = await SupabaseService.client
            .from('team_members')
            .select('id')
            .eq('team_id', myTId);
        myCount = (res as List).length;
      } catch (_) {}

      try {
        final res = await SupabaseService.client
            .from('team_members')
            .select('id')
            .eq('team_id', oppTId);
        oppCount = (res as List).length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _myTeam = myT;
          _oppTeam = oppT;
          _myLeaderName = myLeader;
          _oppLeaderName = oppLeader;
          _myMemberCount = myCount;
          _oppMemberCount = oppCount;
          _isLoading = false;
        });
      }
      _checkProofLimitCancellation();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _hasCancelledDueToProofLimit = false;

  Future<void> _checkProofLimitCancellation() async {
    final status = (widget.match["status"] ?? "").toString().toLowerCase();
    final proofStatus =
        (widget.match["proof_status"] ?? "").toString().toLowerCase();
    final proofCount =
        (widget.match["proof_upload_count"] as num?)?.toInt() ?? 0;
    final isRejected = status == "rejected" ||
        (status == "under_review" && proofStatus == "rejected");

    if (isRejected &&
        proofCount >= 3 &&
        status != 'cancelled' &&
        !_hasCancelledDueToProofLimit) {
      _hasCancelledDueToProofLimit = true;
      final matchId = widget.match["id"]?.toString() ?? "";
      if (matchId.isEmpty) return;

      try {
        // 1. Update active_matches table
        await SupabaseService.client.from('active_matches').update({
          'status': 'cancelled',
          'admin_note': 'Proof limit reached - no valid winner',
        }).eq('id', matchId);

        // 2 & 3. Refund prize pool to host & entry fees to joiners
        Map<String, dynamic>? roomRow;
        try {
          final res = await SupabaseService.client
              .from('rooms')
              .select()
              .or('id.eq.$matchId,room_id.eq.$matchId')
              .maybeSingle();
          roomRow = res;
        } catch (_) {}

        final hostId = roomRow?['host_id']?.toString() ?? '';
        final prizePool = (roomRow?['prize_pool'] as num?)?.toInt() ?? 0;
        final entryFee =
            (roomRow?['entry_fee_coins'] as num?)?.toInt() ?? 0;
        final joinedUserIds = (roomRow?['joined_user_ids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        if (hostId.isNotEmpty && prizePool > 0) {
          await CoinWalletService().updateCoins(
            userId: hostId,
            amount: prizePool,
            type: 'refund',
            description:
                'Match cancelled - proof limit reached (Prize refunded)',
            inEscrowChange: -prizePool,
            roomId: matchId,
          );
        }

        for (final joinerId in joinedUserIds) {
          if (joinerId.isEmpty || joinerId == hostId) continue;
          if (entryFee > 0) {
            await CoinWalletService().updateCoins(
              userId: joinerId,
              amount: entryFee,
              type: 'refund',
              description: 'Match cancelled - entry fee refunded',
              inEscrowChange: -entryFee,
              roomId: matchId,
            );
          }
        }

        if (roomRow != null) {
          final rId = roomRow['id']?.toString() ?? matchId;
          await SupabaseService.client.from('rooms').update({
            'status': 'cancelled',
            'dispute_reason': 'Proof limit reached - no valid winner',
            'completed_at': DateTime.now().toIso8601String(),
          }).eq('id', rId);

          // 5. System chat message in room
          try {
            await SupabaseService.client.from('messages').insert({
              'room_id': rId,
              'sender_id': 'system',
              'sender_name': 'ROOM BOT',
              'message':
                  '❌ Proof limit reached. Match cancelled. Prize refunded to teams.',
              'type': 'system',
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}
        }

        // 4. Send notification to BOTH teams
        final t1LeaderId = _myTeam?.leaderId ?? '';
        final t2LeaderId = _oppTeam?.leaderId ?? '';
        final submittedBy =
            widget.match['submitted_by_team_id']?.toString() ?? '';
        final isMyTeamSubmitter = submittedBy.isNotEmpty &&
            (submittedBy.toLowerCase() == widget.myTeamUuid.toLowerCase() ||
                submittedBy.toLowerCase() == widget.myTeamId.toLowerCase());

        final winnerTeamLeader =
            isMyTeamSubmitter ? t1LeaderId : t2LeaderId;
        final loserTeamLeader =
            isMyTeamSubmitter ? t2LeaderId : t1LeaderId;

        if (winnerTeamLeader.isNotEmpty) {
          await NotificationService().sendNotification(
            userId: winnerTeamLeader,
            type: 'match_cancelled',
            title: 'Match Cancelled',
            body:
                '❌ Aapki 3 proof attempts khatam ho gayi hain. Match adhoora reh gaya. Prize refunded.',
            data: {'match_id': matchId},
          );
        }
        if (loserTeamLeader.isNotEmpty &&
            loserTeamLeader != winnerTeamLeader) {
          await NotificationService().sendNotification(
            userId: loserTeamLeader,
            type: 'match_cancelled',
            title: 'Match Cancelled',
            body:
                '❌ Match ended without result. Proof limit reached. Prize refunded.',
            data: {'match_id': matchId},
          );
        }
        if (hostId.isNotEmpty &&
            hostId != winnerTeamLeader &&
            hostId != loserTeamLeader) {
          final shortId =
              matchId.length > 6 ? matchId.substring(0, 6) : matchId;
          await NotificationService().sendNotification(
            userId: hostId,
            type: 'match_cancelled',
            title: 'Match Cancelled',
            body:
                '❌ Match #$shortId cancelled — proof limit reached. Prize refunded.',
            data: {'match_id': matchId},
          );
        }
      } catch (e) {
        debugPrint(
            '[TeamsScreen] Proof limit cancellation error: $e');
      }
    }
  }

  DateTime? _getStartTime() {
    final raw = widget.match["start_time"] ?? widget.match["startTime"];
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    final rawCreated = widget.match["created_at"];
    if (rawCreated is String && rawCreated.isNotEmpty) {
      return DateTime.tryParse(rawCreated)?.toLocal();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    _checkProofLimitCancellation();
    final match = widget.match;
    final matchId = match["id"]?.toString() ?? "";
    final t1 = match["team1_id"]?.toString() ?? "";
    final t2 = match["team2_id"]?.toString() ?? "";
    final opponentId = (t1.toLowerCase() == widget.myTeamUuid.toLowerCase() ||
            t1.toLowerCase() == widget.myTeamId.toLowerCase())
        ? t2
        : t1;
    final status = (match["status"] ?? "").toString().toLowerCase();
    final proofStatus = (match["proof_status"] ?? "").toString().toLowerCase();
    final adminNote =
        match["admin_note"]?.toString() ?? "Invalid proof screenshot";

    final submittedBy = (match["submitted_by_team_id"] ??
            match["winner_team_id"] ??
            "")
        .toString()
        .toLowerCase();
    final myIdLower = widget.myTeamId.toLowerCase();
    final myUuidLower = widget.myTeamUuid.toLowerCase();
    final isSubmitter =
        submittedBy == myIdLower || submittedBy == myUuidLower;

    if (status == "under_review" && proofStatus == "accepted") {
      if (!isSubmitter) return const SizedBox.shrink();
      if (!_autoCompletedTriggered) {
        _autoCompletedTriggered = true;
        Future.delayed(const Duration(seconds: 3), () async {
          try {
            await SupabaseService.client
                .from("active_matches")
                .update({"status": "completed"}).eq("id", matchId);
          } catch (_) {}
          widget.onAutoCompleted(matchId);
        });
      }
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: Color(0xFF2E7D32), size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text("✅ Your Proof Accepted - You Won! 🏆",
                  style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(10)),
              child: const Text("WON 🏆",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10)),
            ),
          ],
        ),
      );
    }

    final startTime = _getStartTime();
    final now = DateTime.now();
    bool isCountingDown = false;
    String countdownLabel = "";
    String startedTimeLabel = "Started recently";

    if (startTime != null) {
      if (now.isBefore(startTime)) {
        final diff = startTime.difference(now);
        isCountingDown = true;
        final mins = diff.inMinutes;
        final secs = diff.inSeconds % 60;
        countdownLabel = "Starts in: ${mins}m ${secs}s";
      } else {
        final diff = now.difference(startTime);
        startedTimeLabel = "Started: ${diff.inMinutes} min ago";
      }
    }

    final myTeamDisplay = _myTeam?.name ?? widget.myTeamName;
    final oppTeamDisplay =
        _oppTeam?.name ?? match["opponent_name"]?.toString() ?? "Opponent";

    final proofCount =
        (match["proof_upload_count"] as num?)?.toInt() ?? 0;
    final canAddMore = proofCount < 3;
    final isRejected =
        status == "rejected" || (status == "under_review" && proofStatus == "rejected");
    final isUnderReview = status == "under_review" && !isRejected;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRejected
            ? const Color(0xFFFFEBEE)
            : isUnderReview
                ? const Color(0xFFFFF8E1)
                : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRejected
              ? const Color(0xFFFF4655)
              : isUnderReview
                  ? const Color(0xFFFFB300)
                  : const Color(0xFF2E7D32),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: isRejected
                    ? const Color(0xFFFF4655)
                    : isUnderReview
                        ? const Color(0xFFFF8F00)
                        : const Color(0xFF2E7D32),
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isRejected
                      ? "❌ PROOF REJECTED"
                      : isUnderReview
                          ? "⏳ UNDER REVIEW"
                          : "🔥 LIVE MATCH",
                  style: TextStyle(
                    color: isRejected
                        ? const Color(0xFFFF4655)
                        : isUnderReview
                            ? const Color(0xFFB78103)
                            : const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCountingDown
                      ? const Color(0xFFFF8F00)
                      : (isRejected
                          ? const Color(0xFFFF4655)
                          : isUnderReview
                              ? const Color(0xFFFFB300)
                              : const Color(0xFF2E7D32)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isCountingDown
                      ? countdownLabel
                      : (isRejected
                          ? "REJECTED"
                          : isUnderReview
                              ? "REVIEW"
                              : "LIVE"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        myTeamDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFF050505),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Leader: $_myLeaderName",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF65676B),
                        ),
                      ),
                      Text(
                        "$_myMemberCount Members",
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF1877F2),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4655).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "VS",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF4655),
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        oppTeamDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFF050505),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Leader: $_oppLeaderName",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF65676B),
                        ),
                      ),
                      Text(
                        "$_oppMemberCount Members",
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFFFF8F00),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  size: 13, color: Color(0xFF65676B)),
              const SizedBox(width: 4),
              Text(
                isCountingDown ? countdownLabel : startedTimeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF65676B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isRejected)
                Text(
                  "Attempts: $proofCount/3",
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFFF4655),
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),

          if (isRejected && adminNote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "Note: $adminNote",
              style: const TextStyle(fontSize: 11, color: Color(0xFFFF4655)),
            ),
          ],

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TeamMatchRoomScreen(matchId: matchId),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1877F2)),
                  foregroundColor: const Color(0xFF1877F2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.forum_rounded, size: 13),
                label: const Text(
                  "Team DM",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              if (isRejected && isSubmitter)
                ElevatedButton.icon(
                  onPressed: canAddMore
                      ? () async {
                          final ended = await EndMatchBottomSheet.show(
                            context,
                            activeMatchId: matchId,
                            myTeamId: widget.myTeamId,
                            opponentId: opponentId,
                            myTeamName: widget.myTeamName,
                          );
                          if (ended == true && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Naya proof bhej diya gaya!"),
                                backgroundColor: Color(0xFFFFB800),
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAddMore
                        ? const Color(0xFFFF4655)
                        : const Color(0xFFBDBDBD),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 14),
                  label: Text(
                    canAddMore
                        ? "Add Proof ($proofCount/3)"
                        : "❌ Proof Limit Reached (3/3)",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                )
              else if (isUnderReview && isSubmitter)
                OutlinedButton.icon(
                  onPressed: () {
                    final proofUrl = match["proof_url"]?.toString();
                    if (proofUrl != null && proofUrl.isNotEmpty) {
                      widget.onShowProofImage(proofUrl);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFFB300)),
                    foregroundColor: const Color(0xFFB78103),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.visibility_rounded, size: 13),
                  label: const Text(
                    "View Proof",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () async {
                    final ended = await EndMatchBottomSheet.show(
                      context,
                      activeMatchId: matchId,
                      myTeamId: widget.myTeamId,
                      opponentId: opponentId,
                      myTeamName: widget.myTeamName,
                    );
                    if (ended == true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "Match End Request Submit! Status Under Review."),
                          backgroundColor: Color(0xFFFFB800),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 14),
                  label: const Text(
                    "END MATCH",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}