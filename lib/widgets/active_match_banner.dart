import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../services/team_service.dart';
import '../models/team_model.dart';
import 'end_match_dialog.dart';

/// Widget that displays the active match banner on the Teams screen.
/// Handles 4 states:
///   1. active         → Green banner + LIVE + End Match (if leader)
///   2. under_review   → Yellow banner + View Proof + Review
///   3. rejected       → Red banner + Add Proof Again
///   4. proof_accepted → Green celebration + auto-completes in 3s
class ActiveMatchBanner extends StatelessWidget {
  final Map<String, dynamic> match;
  final String myTeamId;
  final String myTeamUuid;
  final String myTeamName;
  final Set<String> completedMatchIds;
  final Set<String> autoCompletingMatchIds;
  final void Function(String matchId) onMatchCompleted;
  final void Function(String proofUrl) onShowProof;

  const ActiveMatchBanner({
    super.key,
    required this.match,
    required this.myTeamId,
    required this.myTeamUuid,
    required this.myTeamName,
    required this.completedMatchIds,
    required this.autoCompletingMatchIds,
    required this.onMatchCompleted,
    required this.onShowProof,
  });

  @override
  Widget build(BuildContext context) {
    final matchId = match["id"]?.toString() ?? "";
    final t1 = match["team1_id"]?.toString() ?? "";
    final t2 = match["team2_id"]?.toString() ?? "";
    final opponentId =
        (t1.toLowerCase() == myTeamUuid.toLowerCase() ||
                t1.toLowerCase() == myTeamId.toLowerCase())
            ? t2
            : t1;
    final status = (match["status"] ?? "").toString().toLowerCase();
    final proofStatus =
        (match["proof_status"] ?? "").toString().toLowerCase();
    final adminNote = match["admin_note"]?.toString() ??
        "Invalid proof screenshot";

    // ==========================================
    // STATE 3: under_review & accepted → 3s auto-hide
    // ==========================================
    if (status == "under_review" && proofStatus == "accepted") {
      if (!autoCompletingMatchIds.contains(matchId)) {
        autoCompletingMatchIds.add(matchId);
        Future.delayed(const Duration(seconds: 3), () async {
          try {
            await SupabaseService.client
                .from("active_matches")
                .update({"status": "completed"}).eq("id", matchId);
          } catch (_) {}
          onMatchCompleted(matchId);
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
        child: const Row(
          children: [
            Icon(Icons.emoji_events_rounded,
                color: Color(0xFF2E7D32), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "✅ Your Proof Accepted - You Are Win! 🏆",
                style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: _WonBadge(),
            ),
          ],
        ),
      );
    }

    // ==========================================
    // STATE 4: rejected → Red banner
    // ==========================================
    if (status == "rejected" ||
        (status == "under_review" && proofStatus == "rejected")) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel_rounded,
                    color: Color(0xFFFF4655), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "❌ Proof Rejected - $adminNote - Dubara Proof Add Karo",
                    style: const TextStyle(
                        color: Color(0xFFFF4655),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF4655),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text("REJECTED",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final ended = await EndMatchBottomSheet.show(
                    context,
                    activeMatchId: matchId,
                    myTeamId: myTeamId,
                    opponentId: opponentId,
                    myTeamName: myTeamName,
                    opponentName: match["opponent_name"]?.toString() ??
                        "Opponent",
                  );
                  if (ended == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              "Naya proof bhej diya gaya! Under Review."),
                          backgroundColor: Color(0xFFFFB800)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4655),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 14),
                label: const Text("Add Proof Again",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================
    // STATE 2: under_review & pending → Yellow
    // ==========================================
    if (status == "under_review") {
      final proofUrl = match["proof_url"]?.toString();
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded,
                color: Color(0xFFFF8F00), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "⏳ Your Proof Under Review - Admin confirmation ka wait hai",
                    style: TextStyle(
                        color: Color(0xFFB78103),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  FutureBuilder<TeamModel?>(
                    future: TeamService().getTeam(opponentId),
                    builder: (context, opSnap) {
                      final opponentName = opSnap.data?.name ??
                          match["opponent_name"]?.toString() ??
                          "Opponent";
                      return Text(
                        "vs $opponentName • Admin confirmation ka wait hai",
                        style: const TextStyle(
                            color: Color(0xFF8D6E63), fontSize: 11),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (proofUrl != null && proofUrl.isNotEmpty)
              InkWell(
                onTap: () => onShowProof(proofUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFB300),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_rounded,
                          size: 13, color: Colors.black),
                      SizedBox(width: 3),
                      Text("View Proof",
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5)),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFB300),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text("REVIEW",
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 10)),
              ),
          ],
        ),
      );
    }

    // ==========================================
    // STATE 1: active (LIVE)
    // ==========================================
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: FutureBuilder<TeamModel?>(
                  future: TeamService().getTeam(opponentId),
                  builder: (context, opSnap) {
                    final opponentName = opSnap.data?.name ??
                        match["opponent_name"]?.toString() ??
                        "Opponent";
                    return Text(
                      "🔥 Active Match vs $opponentName - Match is Live",
                      style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5),
                    );
                  },
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text("LIVE",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FutureBuilder<TeamModel?>(
                future: TeamService().getTeam(opponentId),
                builder: (context, opSnap) {
                  final opponentName = opSnap.data?.name ??
                      match["opponent_name"]?.toString() ??
                      "Opponent";
                  return ElevatedButton.icon(
                    onPressed: () async {
                      final ended = await EndMatchBottomSheet.show(
                        context,
                        activeMatchId: matchId,
                        myTeamId: myTeamId,
                        opponentId: opponentId,
                        myTeamName: myTeamName,
                        opponentName: opponentName,
                      );
                      if (ended == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Match End Request Submit ho gaya! Status Under Review."),
                              backgroundColor: Color(0xFFFFB800),
                              duration: Duration(seconds: 4)),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 14),
                    label: const Text("END MATCH",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WonBadge extends StatelessWidget {
  const _WonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(10)),
      child: const Text("WON 🏆",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10)),
    );
  }
}