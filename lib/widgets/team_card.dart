// ===============================================================================
// TEAM CARD — Compact Dark Neon Gaming Theme (Exact Match to Design)
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
  bool _localRequested = false;
  bool _isMemberFromDb = false;
  bool _isOwnerFromDb = false;

  final Set<String> _localCancelledIds = {};

  static const Color darkCardBg = Color(0xFF131B2E);
  static const Color darkCardBorder = Color(0xFF1E293B);
  static const Color neonBlue = Color(0xFF1877F2);
  static const Color neonGradientEnd = Color(0xFF00E5FF);
  static const Color alertRed = Color(0xFFFF4655);

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

  Color _getGameTagColor(String game) {
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

  Future<void> _handleChallenge(String currentUid) async {
    if (widget.isMyTeamFrozen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your team balance is below 1,000 coins!'),
          backgroundColor: alertRed,
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
          await SupabaseService.client.from('challenges').insert({
            'from_team_id': effectiveMyTeamId,
            'to_team_id': effectiveTargetId,
            'from_team_name': effectiveMyTeamName,
            'to_team_name': widget.team.name,
            'status': 'pending',
            'game': widget.team.game.isNotEmpty ? widget.team.game : 'PUBG',
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Challenge sent to ${widget.team.name}! ⚡'),
                backgroundColor: neonBlue,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: alertRed),
            );
          }
        }
      },
    );
  }

  Future<void> _handleJoin(String currentUid) async {
    await CoinOrAdPopup.show(
      context: context,
      actionName: 'Team Join',
      onConfirm: () async {
        final currentGamer = GamerAuthService().currentGamer;
        final userName = currentGamer?.displayName ?? currentGamer?.username ?? 'Gamer';

        setState(() => _isRequesting = true);
        final success = await _teamService.requestToJoinTeam(
          teamId: widget.team.id,
          userId: currentUid,
          userName: userName,
          teamName: widget.team.name,
        );
        setState(() {
          _isRequesting = false;
          if (success) _localRequested = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Join request sent!' : 'Failed to send request'),
              backgroundColor: success ? neonBlue : alertRed,
            ),
          );
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
    final hasRequested = team.hasRequestedJoin(currentUid);

    final bool isOwnerFinal = isLeader || _isOwnerFromDb;
    final bool isMemberFinal = isMember || _isMemberFromDb || isOwnerFinal;

    final gameColor = _getGameTagColor(team.game.isNotEmpty ? team.game : 'PUBG');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOwnerFinal
              ? const Color(0xFFFFD700).withOpacity(0.5)
              : darkCardBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Logo + Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Team Badge / Logo
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F1D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: gameColor.withOpacity(0.5), width: 1.5),
                    image: team.logo.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(team.logo),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: team.logo.isEmpty
                      ? Center(
                          child: Icon(Icons.shield_rounded, color: gameColor, size: 30),
                        )
                      : null,
                ),
                const SizedBox(width: 14),

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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: gameColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (team.game.isNotEmpty ? team.game : 'PUBG').toUpperCase(),
                              style: TextStyle(
                                color: gameColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Leader: ${team.leaderName}",
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.group_rounded, color: neonBlue, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "${team.memberCount} Members",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB800), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "${team.wins} Wins",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
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

            const SizedBox(height: 14),

            // Bottom Buttons Row (Exact match to Reference)
            Row(
              children: [
                // View Team Button
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF2E384D), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: const Color(0xFF0E1524),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamProfileScreen(teamId: team.id),
                          ),
                        );
                      },
                      child: const Text(
                        'View Team',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Challenge / Action Button
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: isOwnerFinal || isMemberFinal
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.login_rounded, size: 16),
                            label: const Text(
                              'Open Team',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                        : (hasRequested || _localRequested)
                            ? OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white54,
                                  side: const BorderSide(color: darkCardBorder),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  backgroundColor: const Color(0xFF0E1524),
                                ),
                                icon: const Icon(Icons.hourglass_top_rounded, size: 14),
                                label: const Text(
                                  'Requested',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                onPressed: null,
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1877F2), Color(0xFF00B0FF)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: neonBlue.withOpacity(0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                                  label: const Text(
                                    'Challenge',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  onPressed: () => _handleChallenge(currentUid),
                                ),
                              ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
