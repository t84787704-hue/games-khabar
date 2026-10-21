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
  bool _localRequested = false;
  bool _isMemberFromDb = false;
  bool _isOwnerFromDb = false;

  final Set<String> _localCancelledIds = {};

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
                backgroundColor: const Color(0xFF1877F2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
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
    final hasRequested = team.hasRequestedJoin(currentUid);

    final bool isOwnerFinal = isLeader || _isOwnerFromDb;
    final bool isMemberFinal = isMember || _isMemberFromDb || isOwnerFinal;

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

                    // Challenge / Action Button
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
                            : (hasRequested || _localRequested)
                                ? OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ThemeService.textSecondary,
                                      side: BorderSide(color: ThemeService.border),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      backgroundColor: ThemeService.cardSecondary,
                                      padding: EdgeInsets.zero,
                                    ),
                                    icon: const Icon(Icons.hourglass_top_rounded, size: 12),
                                    label: Text(
                                      'btn_requested_wait'.tr(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10.5,
                                        color: ThemeService.textSecondary,
                                      ),
                                    ),
                                    onPressed: null,
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
