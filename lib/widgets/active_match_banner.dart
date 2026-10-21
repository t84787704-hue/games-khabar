import 'package:easy_localization/easy_localization.dart';
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
        "invalid_proof".tr();

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
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: Color(0xFF2E7D32), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "proof_accepted_you_won".tr(),
                style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5),
              ),
            ),
            const Padding(
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
                    'msg_proof_rejected_retry'.tr(args: [adminNote]),
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
                  child: Text("status_rejected_caps".tr(),
                      style: const TextStyle(
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
                        "default_opponent".tr(),
                  );
                  if (ended == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'proof_submitted_under_review'.tr()),
                          backgroundColor: const Color(0xFFFFB800)),
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
                label: Text("btn_add_proof_again".tr(args: ['']),
                    style: const TextStyle(
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
                  Text(
                    "sub_proof_under_review".tr(),
                    style: const TextStyle(
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
                          "default_opponent".tr();
                      return Text(
                        "versus_vs".tr() + " " + opponentName + " • " + "pending_admin_review".tr(),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility_rounded,
                          size: 13, color: Colors.black),
                      const SizedBox(width: 3),
                      Text("view_proof".tr(),
                          style: const TextStyle(
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
                child: Text("status_review".tr(),
                    style: const TextStyle(
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
                        "default_opponent".tr();
                    return Text(
                      'heading_active_match_live'.tr(args: [opponentName]),
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
                child: Text("status_live".tr(),
                    style: const TextStyle(
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
                      "default_opponent".tr();
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
                          SnackBar(
                              content: Text(
                                  'match_end_under_review'.tr()),
                              backgroundColor: const Color(0xFFFFB800),
                              duration: const Duration(seconds: 4)),
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
                    label: Text("btn_end_match".tr(),
                        style: const TextStyle(
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
      child: Text("badge_won".tr(),
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10)),
    );
  }
}