import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../services/supabase_service.dart";
import "../models/team_model.dart";
import "../services/team_service.dart";
import "../widgets/team_card.dart";
import "../widgets/create_team_dialog.dart";
import "../widgets/end_match_dialog.dart";
import "team_matches_screen.dart";
import "leaderboard_screen.dart";

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
          await SupabaseService.client.from("active_matches").insert({
            "team1_id": t1Uuid,
            "team2_id": t2Uuid,
            "participants": [t1Uuid, t2Uuid],
            "status": "active",
            "game": "BGMI",
          }).select().maybeSingle();
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
    // 100% Supabase Auth - No Firebase
    final currentUid = SupabaseService.client.auth.currentUser?.id ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text("Teams", style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            tooltip: "Team Matches",
            icon: const Icon(Icons.sports_esports_rounded, color: Color(0xFF65676B)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamMatchesScreen())),
          ),
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

              // 2. ACTIVE MATCH BANNER (Persists on restart, deduplicated by id Map, checks myTeamId and myTeamUuid)
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
                      if (status != "active" && status != "under_review") return false;
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
                        final matchId = match["id"];
                        final t1 = match["team1_id"]?.toString() ?? "";
                        final t2 = match["team2_id"]?.toString() ?? "";
                        final opponentId = (t1.toLowerCase() == myTeamUuid.toLowerCase() || t1.toLowerCase() == myTeamId.toLowerCase()) ? t2 : t1;
                        final status = (match["status"] ?? "").toString().toLowerCase();
                        final proofStatus = (match["proof_status"] ?? "").toString().toLowerCase();
                        final adminNote = match["admin_note"]?.toString() ?? "Invalid proof screenshot";

                        // Case 3: under_review & accepted -> 3 second auto-hide
                        if (status == "under_review" && proofStatus == "accepted") {
                          if (!_autoCompletingMatchIds.contains(matchId.toString())) {
                            _autoCompletingMatchIds.add(matchId.toString());
                            Future.delayed(const Duration(seconds: 3), () async {
                              try { await SupabaseService.client.from("active_matches").update({"status": "completed"}).eq("id", matchId); } catch (_) {}
                              if (mounted) setState(() => _completedMatchIds.add(matchId.toString()));
                            });
                          }

                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2E7D32), width: 1.5)),
                            child: Row(
                              children: [
                                const Icon(Icons.emoji_events_rounded, color: Color(0xFF2E7D32), size: 22),
                                const SizedBox(width: 8),
                                const Expanded(child: Text("✅ Your Proof Accepted - You Are Win! 🏆", style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 13.5))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(10)),
                                  child: const Text("WON 🏆", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                                ),
                              ],
                            ),
                          );
                        }

                        // Case 4: under_review & rejected -> Red banner + Add Proof Again
                        if (status == "under_review" && proofStatus == "rejected") {
                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFF4655), width: 1.5)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.cancel_rounded, color: Color(0xFFFF4655), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text("❌ Proof Rejected - $adminNote - Dubara Proof Add Karo", style: const TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold, fontSize: 13))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFFFF4655), borderRadius: BorderRadius.circular(10)),
                                      child: const Text("REJECTED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final ended = await EndMatchBottomSheet.show(context, activeMatchId: matchId.toString(), myTeamId: myTeamId, opponentId: opponentId, myTeamName: myTeamName);
                                      if (ended == true && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Naya proof bhej diya gaya! Under Review."), backgroundColor: Color(0xFFFFB800)));
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: const Size(0, 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                    icon: const Icon(Icons.upload_file_rounded, size: 14),
                                    label: const Text("Add Proof Again", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Case 2: under_review & pending -> Yellow banner + View Proof
                        if (status == "under_review") {
                          final proofUrl = match["proof_url"]?.toString();
                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFB300), width: 1.5)),
                            child: Row(
                              children: [
                                const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF8F00), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("⏳ Your Proof Under Review - Admin confirmation ka wait hai", style: TextStyle(color: Color(0xFFB78103), fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      FutureBuilder<TeamModel?>(
                                        future: _teamService.getTeam(opponentId),
                                        builder: (context, opSnap) {
                                          final opponentName = opSnap.data?.name ?? match["opponent_name"]?.toString() ?? "Opponent";
                                          return Text("vs $opponentName • Admin confirmation ka wait hai", style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 11));
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (proofUrl != null && proofUrl.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _showProofImageDialog(context, proofUrl),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFFFFB300), borderRadius: BorderRadius.circular(8)),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.visibility_rounded, size: 13, color: Colors.black),
                                          SizedBox(width: 3),
                                          Text("View Proof", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10.5)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFFFB300), borderRadius: BorderRadius.circular(10)),
                                    child: const Text("REVIEW", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                                  ),
                              ],
                            ),
                          );
                        }

                        // Case 1: status == active -> Green banner
                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2E7D32), width: 1.5)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFF2E7D32), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FutureBuilder<TeamModel?>(
                                      future: _teamService.getTeam(opponentId),
                                      builder: (context, opSnap) {
                                        final opponentName = opSnap.data?.name ?? match["opponent_name"]?.toString() ?? "Opponent";
                                        return Text("🔥 Active Match vs $opponentName - Match is Live", style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 13.5));
                                      },
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(10)),
                                    child: const Text("LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // REQUIREMENT 1 & 2: View Opponent opens PrivateMatchRoomScreen
                                  FutureBuilder<TeamModel?>(
                                    future: _teamService.getTeam(opponentId),
                                    builder: (context, opSnap) {
                                      final opponentName = opSnap.data?.name ?? match["opponent_name"]?.toString() ?? "Opponent";
                                      return OutlinedButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PrivateMatchRoomScreen(matchId: matchId.toString(), myTeamId: myTeamId, myTeamName: myTeamName, opponentId: opponentId, opponentName: opponentName),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1877F2), side: const BorderSide(color: Color(0xFF1877F2)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: const Size(0, 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                                        label: const Text("Team DM 💬", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final ended = await EndMatchBottomSheet.show(context, activeMatchId: matchId.toString(), myTeamId: myTeamId, opponentId: opponentId, myTeamName: myTeamName);
                                      if (ended == true && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Match End Request Submit ho gaya! Status Under Review."), backgroundColor: Color(0xFFFFB800), duration: Duration(seconds: 4)));
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: const Size(0, 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                                    icon: const Icon(Icons.check_circle_rounded, size: 14),
                                    label: const Text("END MATCH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ],
                              ),
                            ],
                          ),
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

/// Private Match Room Screen (Private chat between 2 teams only)
class PrivateMatchRoomScreen extends StatefulWidget {
  final String matchId;
  final String myTeamId;
  final String myTeamName;
  final String opponentId;
  final String opponentName;

  const PrivateMatchRoomScreen({
    super.key,
    required this.matchId,
    required this.myTeamId,
    required this.myTeamName,
    required this.opponentId,
    required this.opponentName,
  });

  @override
  State<PrivateMatchRoomScreen> createState() => _PrivateMatchRoomScreenState();
}

class _PrivateMatchRoomScreenState extends State<PrivateMatchRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  String _myTeamName = '';
  String _opponentName = '';

  @override
  void initState() {
    super.initState();
    _myTeamName = widget.myTeamName.isNotEmpty ? widget.myTeamName : 'My Team';
    _opponentName = widget.opponentName.isNotEmpty ? widget.opponentName : 'Opponent';
    _resolveTeamNames();
  }

  Future<void> _resolveTeamNames() async {
    final teamService = TeamService();
    if ((_myTeamName == 'My Team' || _myTeamName.isEmpty) && widget.myTeamId.isNotEmpty) {
      final t = await teamService.getTeam(widget.myTeamId);
      if (t != null && mounted) setState(() => _myTeamName = t.name);
    }
    if ((_opponentName == 'Opponent' || _opponentName.isEmpty) && widget.opponentId.isNotEmpty) {
      final t = await teamService.getTeam(widget.opponentId);
      if (t != null && mounted) setState(() => _opponentName = t.name);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final payload = {
      "match_id": widget.matchId,
      "sender_team_id": SupabaseService.toUuid(widget.myTeamId),
      "sender_team_name": _myTeamName.isNotEmpty ? _myTeamName : widget.myTeamName,
      "message": msg,
      "created_at": DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await SupabaseService.client.from("match_messages").insert(payload).select();
      _scrollToBottom();
    } catch (e) {
      debugPrint("[PrivateMatchRoom] Error sending message: $e");
      try {
        await SupabaseService.client.from("match_messages").insert({
          "match_id": widget.matchId,
          "sender_team_id": SupabaseService.toUuid(widget.myTeamId),
          "message": msg,
          "created_at": DateTime.now().toUtc().toIso8601String(),
        }).select();
        _scrollToBottom();
      } catch (err2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Message bhejne me masla: $err2"), backgroundColor: const Color(0xFFFF4655)));
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showUidPassDialog() {
    final uidController = TextEditingController();
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Color(0xFFFFD600), size: 22),
            SizedBox(width: 8),
            Text("Share Room UID / Pass", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Game Room ID aur Password darj karen:", style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: uidController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: "Room ID / UID",
                labelStyle: const TextStyle(color: Color(0xFFFFD600), fontSize: 12),
                hintText: "e.g. 5839201",
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0B0E16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: "Password",
                labelStyle: const TextStyle(color: Color(0xFFFFD600), fontSize: 12),
                hintText: "e.g. 1234",
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0B0E16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Color(0xFF8B949E)))),
          ElevatedButton(
            onPressed: () {
              final uid = uidController.text.trim();
              final pass = passController.text.trim();
              if (uid.isEmpty) return;
              Navigator.pop(ctx);
              final shareMsg = "🎮 ROOM UID: $uid | PASS: ${pass.isNotEmpty ? pass : "None"}";
              _sendMessage(shareMsg);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Room UID & Password share ho gaya!"), backgroundColor: Color(0xFF2E7D32)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("SHARE KARO", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = "$_myTeamName VS $_opponentName - Private Room";
    final myTeamUuid = SupabaseService.toUuid(widget.myTeamId).toLowerCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A29),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            const Text("Private Room • UID / Password Share", style: TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.w600, fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Top Info Banner & Share UID/Password Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF131A29),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_rounded, color: Color(0xFFFFD600), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text("Ye chat bilkul private hai dono teams ke darmiyan. Yahan game room ID aur password share karen.", style: TextStyle(color: Color(0xFF8B949E), fontSize: 11.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showUidPassDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                    icon: const Icon(Icons.vpn_key_rounded, size: 16, color: Colors.black),
                    label: const Text("UID / Password Share Karo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),

          // Messages Stream List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.client.from("match_messages").stream(primaryKey: ["id"]).eq("match_id", widget.matchId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)));
                }

                final msgs = List<Map<String, dynamic>>.from(snapshot.data ?? []);
                // Sort ascending by created_at (BUG 3 FIX)
                msgs.sort((a, b) => (a["created_at"] ?? "").toString().compareTo((b["created_at"] ?? "").toString()));

                if (msgs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF131A29), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF2A3447))),
                            child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF8B949E), size: 36),
                          ),
                          const SizedBox(height: 12),
                          const Text("No Messages Yet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text("Opponent ke sath room ID ya bat cheet shuru karen!", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final m = msgs[index];
                    final msgText = m["message"]?.toString() ?? "";
                    final senderTeamId = (m["sender_team_id"] ?? "").toString().toLowerCase();
                    final senderTeamName = m["sender_team_name"]?.toString() ?? (senderTeamId == myTeamUuid ? widget.myTeamName : widget.opponentName);
                    final isMyTeam = senderTeamId == myTeamUuid || senderTeamId == widget.myTeamId.toLowerCase();
                    final isUidShare = msgText.contains("ROOM UID");

                    if (isUidShare) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF241D05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD600), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.sports_esports_rounded, color: Color(0xFFFFD600), size: 18),
                                const SizedBox(width: 8),
                                Text("ROOM UID & PASSWORD • $senderTeamName", style: const TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold, fontSize: 12)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Color(0xFFFFD600), size: 16),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: msgText));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Room UID & Pass Copied!"), backgroundColor: Color(0xFF1877F2), duration: Duration(seconds: 2)));
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SelectableText(msgText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                          ],
                        ),
                      );
                    }

                    return Align(
                      alignment: isMyTeam ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMyTeam ? const Color(0xFF1877F2) : const Color(0xFF131A29),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isMyTeam ? Colors.transparent : const Color(0xFF2A3447)),
                        ),
                        child: Column(
                          crossAxisAlignment: isMyTeam ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(senderTeamName, style: TextStyle(color: isMyTeam ? Colors.white70 : const Color(0xFFFFD600), fontSize: 10.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            Text(msgText, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: const Color(0xFF131A29),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFF0B0E16), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF2A3447))),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: const InputDecoration(hintText: "Message likho...", hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 13), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10)),
                        onSubmitted: (val) => _sendMessage(val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(color: Color(0xFF1877F2), shape: BoxShape.circle),
                    child: IconButton(
                      icon: _isSending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: () => _sendMessage(_messageController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
