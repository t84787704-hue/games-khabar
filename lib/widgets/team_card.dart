// ===============================================================================
// TEAM CARD — Super Compact & Slim Design (ThemeService & Localized)
// File: lib/widgets/team_card.dart
// ===============================================================================

import 'dart:io';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../services/supabase_service.dart';
import '../services/gamer_auth_service.dart';
import '../screens/team_profile_screen.dart';
import '../screens/private_match_room_screen.dart';
import '../services/theme_service.dart';
import '../services/coin_wallet_service.dart';
import 'coin_or_ad_popup.dart';
import 'match_rules_dialog.dart';

class TeamCard extends StatefulWidget {
  final TeamModel team;
  final String myTeamId;
  final String myTeamName;
  final bool isMyTeamFrozen;
  final Map<String, dynamic>? pendingChallenge;
  final Future<void> Function(String challengeId)? onCancelChallenge;

  const TeamCard({
    super.key,
    required this.team,
    this.myTeamId = '',
    this.myTeamName = '',
    this.isMyTeamFrozen = false,
    this.pendingChallenge,
    this.onCancelChallenge,
  });

  @override
  State<TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<TeamCard> {
  final TeamService _teamService = TeamService();
  bool _isRequesting = false;
  bool _isCancelling = false;
  bool _localRequested = false;
  bool _localCancelled = false;
  bool _isMemberFromDb = false;
  bool _isOwnerFromDb = false;

  // Local optimistic state for sent challenges
  bool _localSentChallenge = false;
  String? _localSentChallengeId;

  @override
  void initState() {
    super.initState();
    _checkMembership();
  }

  Future<void> _checkMembership() async {
    final currentUid = GamerAuthService().currentUid ??
        (SupabaseService.client.auth.currentUser?.id ?? '');
    if (currentUid.isEmpty) return;

    try {
      final uuid = SupabaseService.toUuid(currentUid);
      final teamUuid = SupabaseService.toUuid(widget.team.id);

      final res = await SupabaseService.client
          .from('team_members')
          .select('role')
          .eq('user_id', uuid)
          .eq('team_id', teamUuid)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        if (res != null) {
          _isMemberFromDb = true;
          final role = (res['role'] ?? '').toString().toLowerCase();
          _isOwnerFromDb =
              (role == 'owner' || role == 'co_leader' || role == 'leader');
        } else {
          _isMemberFromDb = false;
          _isOwnerFromDb = false;
        }
      });
    } catch (_) {}
  }

  Color _getGameBadgeColor(String game) {
    switch (game.toUpperCase()) {
      case 'PUBG':
        return const Color(0xFF1877F2);
      case 'VALORANT':
        return const Color(0xFF8B5CF6);
      case 'FREE FIRE':
        return const Color(0xFFFF5722);
      case 'COD':
        return const Color(0xFFE11D48);
      default:
        return const Color(0xFF00E5FF);
    }
  }

  Future<void> _handleCancelJoinRequest(String currentUid) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'dialog_cancel_request_title'.tr(),
          style: TextStyle(
            color: ThemeService.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'dialog_cancel_request_desc'.tr(namedArgs: {'team': widget.team.name}),
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'cancel'.tr(),
              style: TextStyle(color: ThemeService.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'btn_cancel_request'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);

    try {
      final success = await _teamService.cancelJoinRequest(
        teamId: widget.team.id,
        userId: currentUid,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _localRequested = false;
          _localCancelled = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('msg_request_cancelled_success'.tr()),
            backgroundColor: const Color(0xFFFF4655),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_something_went_wrong'.tr()),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _handleCancelSentChallenge(String challengeId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'confirm_cancel_challenge_title'.tr().contains('confirm_')
              ? 'Cancel Challenge?'
              : 'confirm_cancel_challenge_title'.tr(),
          style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'confirm_cancel_challenge_desc'.tr().contains('confirm_')
              ? 'Are you sure you want to cancel the challenge request sent to ${widget.team.name}?'
              : 'confirm_cancel_challenge_desc'.tr(),
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr(), style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('btn_cancel'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _localSentChallenge = false;
      _localSentChallengeId = null;
    });

    if (widget.onCancelChallenge != null && challengeId.isNotEmpty) {
      await widget.onCancelChallenge!(challengeId);
    } else if (challengeId.isNotEmpty) {
      try {
        await SupabaseService.client.from('challenges').delete().eq('id', challengeId);
      } catch (e) {
        debugPrint('[TeamCard] Error cancelling challenge: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('msg_challenge_cancelled_success'.tr().contains('msg_')
              ? 'Challenge cancelled successfully'
              : 'msg_challenge_cancelled_success'.tr()),
          backgroundColor: const Color(0xFFFF4655),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleChallenge(String currentUid) async {
    if (widget.isMyTeamFrozen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your team balance is below 1,000 coins!'),
          backgroundColor: Color(0xFFFF4655),
        ),
      );
      return;
    }

    final myTeams = await _teamService.getUserTeams(currentUid);
    final myLeaderTeams = myTeams.where((t) => t.isLeader(currentUid)).toList();

    if (!mounted) return;

    if (myLeaderTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a team first to challenge!'),
          backgroundColor: Color(0xFF65676B),
        ),
      );
      return;
    }

    final effectiveMyTeam = myLeaderTeams.firstWhere(
      (t) => t.id == widget.myTeamId,
      orElse: () => myLeaderTeams.first,
    );
    final effectiveMyTeamId = SupabaseService.toUuid(effectiveMyTeam.id);
    final effectiveTargetId = SupabaseService.toUuid(widget.team.id);
    final effectiveMyTeamName =
        widget.myTeamName.isNotEmpty ? widget.myTeamName : effectiveMyTeam.name;

    MatchRulesDialog.show(
      context,
      title: 'Challenge Rules (${widget.team.name})',
      onProceed: () async {
        try {
          // 0ms Optimistic UI update: instantly change button to "REQUESTED"
          setState(() {
            _localSentChallenge = true;
          });

          final res = await SupabaseService.client.from('challenges').insert({
            'from_team_id': effectiveMyTeamId,
            'to_team_id': effectiveTargetId,
            'from_team_name': effectiveMyTeamName,
            'to_team_name': widget.team.name,
            'status': 'pending',
            'game': widget.team.game.isNotEmpty ? widget.team.game : 'PUBG',
          }).select().maybeSingle();

          if (res != null && res['id'] != null) {
            _localSentChallengeId = res['id'].toString();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Challenge sent to ${widget.team.name}! ⚡'),
                backgroundColor: const Color(0xFF1877F2),
              ),
            );
          }
        } catch (e) {
          // Revert optimistic update on failure
          if (mounted) {
            setState(() {
              _localSentChallenge = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFFF4655)),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final currentUid = GamerAuthService().currentUid ??
        (SupabaseService.client.auth.currentUser?.id ?? '');
    final isLeader = team.isLeader(currentUid);
    final isMember = team.isMember(currentUid);
    final rawHasRequested = team.hasRequestedJoin(currentUid);

    // Agar local cancel kar diya ho to requested false ho jaye
    final hasRequested = !_localCancelled && (rawHasRequested || _localRequested);

    final bool isOwnerFinal = isLeader || _isOwnerFromDb;
    final bool isMemberFinal = isMember || _isMemberFromDb || isOwnerFinal;

    // Active Challenge detection: either from stream prop or locally triggered
    final bool hasActiveChallenge = _localSentChallenge || (widget.pendingChallenge != null);
    final String activeChallengeId = widget.pendingChallenge?['id']?.toString() ??
        _localSentChallengeId ??
        '';

    final gameColor = _getGameBadgeColor(team.game.isNotEmpty ? team.game : 'PUBG');

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        final isDark = ThemeService.isDarkMode;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOwnerFinal
                  ? const Color(0xFFFFD700).withOpacity(0.6)
                  : ThemeService.border,
              width: isOwnerFinal ? 1.4 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Logo + Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Slim Badge / Logo Box (40x40)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ThemeService.cardSecondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: gameColor.withOpacity(0.35), width: 1),
                        image: team.logo.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(team.logo),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: team.logo.isEmpty
                          ? Center(
                              child: Icon(Icons.shield_rounded, color: gameColor, size: 22),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),

                    // Name, Game Tag & Stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  team.name,
                                  style: TextStyle(
                                    color: ThemeService.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: gameColor.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (team.game.isNotEmpty ? team.game : 'PUBG').toUpperCase(),
                                  style: TextStyle(
                                    color: gameColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 8.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1.5),
                          Text(
                            "Leader: ${team.leaderName}",
                            style: TextStyle(
                              color: ThemeService.textSecondary,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2.5),
                          Row(
                            children: [
                              const Icon(Icons.group_rounded, color: Color(0xFF1877F2), size: 12),
                              const SizedBox(width: 3),
                              Text(
                                "${team.memberCount} Members",
                                style: TextStyle(
                                  color: ThemeService.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB800), size: 12),
                              const SizedBox(width: 3),
                              Text(
                                "${team.wins} Wins",
                                style: TextStyle(
                                  color: ThemeService.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Bottom Buttons Row (Compact height 30)
                Row(
                  children: [
                    // View Team Button
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ThemeService.textPrimary,
                            side: BorderSide(color: ThemeService.border, width: 0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            backgroundColor: ThemeService.cardSecondary,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeamProfileScreen(teamId: team.id),
                              ),
                            );
                          },
                          child: Text(
                            'view_team'.tr(),
                            style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Action Button (Open / Cancel Join Request / Cancel Challenge / Send Challenge)
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: isOwnerFinal || isMemberFinal
                            ? ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C853),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                ),
                                icon: const Icon(Icons.login_rounded, size: 13),
                                label: Text(
                                  'open_team'.tr(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TeamProfileScreen(teamId: team.id),
                                    ),
                                  );
                                },
                              )
                            : hasActiveChallenge
                                ? OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFFF8A00),
                                      side: const BorderSide(color: Color(0xFFFF8A00), width: 1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      backgroundColor: const Color(0xFFFF8A00).withOpacity(0.08),
                                      padding: EdgeInsets.zero,
                                    ),
                                    icon: const Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFFF8A00)),
                                    label: Text(
                                      'btn_requested'.tr().contains('btn_') ? 'Requested' : 'btn_requested'.tr(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10.5,
                                        color: Color(0xFFFF8A00),
                                      ),
                                    ),
                                    onPressed: () => _handleCancelSentChallenge(activeChallengeId),
                                  )
                                : hasRequested
                                    ? OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFFF8A00),
                                          side: const BorderSide(color: Color(0xFFFF8A00), width: 1),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          backgroundColor: const Color(0xFFFF8A00).withOpacity(0.08),
                                          padding: EdgeInsets.zero,
                                        ),
                                        icon: _isCancelling
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 1.5,
                                                  color: Color(0xFFFF8A00),
                                                ),
                                              )
                                            : const Icon(Icons.close_rounded, size: 12, color: Color(0xFFFF8A00)),
                                        label: Text(
                                          _isCancelling
                                              ? 'loading'.tr()
                                              : 'btn_cancel_request'.tr(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10.5,
                                            color: Color(0xFFFF8A00),
                                          ),
                                        ),
                                        onPressed: _isCancelling
                                            ? null
                                            : () => _handleCancelJoinRequest(currentUid),
                                      )
                                    : ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1877F2),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          padding: EdgeInsets.zero,
                                        ),
                                        icon: const Icon(Icons.flash_on_rounded, size: 13, color: Colors.white),
                                        label: Text(
                                          'btn_challenge_caps'.tr(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                        onPressed: () => _handleChallenge(currentUid),
                                      ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
  /// Update Team Details
  Future<bool> updateTeam({
    required String teamId,
    required String name,
    required String tag,
    File? logoFile,
    File? newLogoFile,
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

      final fileToUpload = logoFile ?? newLogoFile;
      if (fileToUpload != null) {
        final uploaded = await SupabaseService.uploadFile(
          file: fileToUpload,
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
      return true;
    } catch (e) {
      debugPrint("[TeamService] updateTeam error: $e");
      return false;
    }
  }

  /// Delete Team
  Future<bool> deleteTeam({
    required String teamId,
    required String userId,
  }) async {
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
      return true;
    } catch (e) {
      debugPrint("[TeamService] deleteTeam error: $e");
      return false;
    }
  }

  /// Request to join a team
  Future<bool> requestToJoinTeam({
    required String teamId,
    required String userId,
  }) async {
    try {
      await SupabaseService.client.from("team_join_requests").upsert({
        "team_id": teamId,
        "user_id": userId,
        "status": "pending",
        "created_at": DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint("[TeamService] requestToJoinTeam error: $e");
      return false;
    }
  }

  /// Cancel join request
  Future<bool> cancelJoinRequest({
    required String teamId,
    required String userId,
  }) async {
    try {
      await SupabaseService.client
          .from("team_join_requests")
          .delete()
          .eq("team_id", teamId)
          .eq("user_id", userId);
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
  }) async {
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
      await SupabaseService.client
          .from("team_join_requests")
          .update({"status": "rejected"})
          .eq("team_id", teamId)
          .eq("user_id", userId);
      return true;
    } catch (e) {
      debugPrint("[TeamService] rejectJoinRequest error: $e");
      return false;
    }
  }
}
