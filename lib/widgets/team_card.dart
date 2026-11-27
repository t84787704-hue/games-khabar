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
  final bool isUserTeam;
  final bool isHighlightedTarget;
  final Map<String, dynamic>? pendingChallenge;
  final Future<void> Function(String challengeId)? onCancelChallenge;

  const TeamCard({
    super.key,
    required this.team,
    this.myTeamId = '',
    this.myTeamName = '',
    this.isMyTeamFrozen = false,
    this.isUserTeam = false,
    this.isHighlightedTarget = false,
    this.pendingChallenge,
    this.onCancelChallenge,
  });

  @override
  State<TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<TeamCard> {
  static const Color kAccentOrange = Color(0xFFFF8A00);
  static const Color kAccentDeepOrange = Color(0xFFFF6B00);

  final TeamService _teamService = TeamService();
  bool _isRequesting = false;
  bool _isCancelling = false;
  bool _localRequested = false;
  bool _localCancelled = false;
  bool _isMemberFromDb = false;
  bool _isOwnerFromDb = false;

  bool _localSentChallenge = false;
  String? _localSentChallengeId;

  @override
  void initState() {
    super.initState();
    _checkMembership();
  }

  @override
  void didUpdateWidget(covariant TeamCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.team.id != widget.team.id ||
        oldWidget.isUserTeam != widget.isUserTeam) {
      _checkMembership();
    }
  }

  Future<void> _checkMembership() async {
    final currentUid = (GamerAuthService().currentUid ??
            SupabaseService.client.auth.currentUser?.id ??
            '')
        .trim();
    if (currentUid.isEmpty) return;

    final rawTeamId = widget.team.id.trim();
    if (rawTeamId.isEmpty) return;

    try {
      final uuid = SupabaseService.toUuid(currentUid);
      final teamUuid = SupabaseService.toUuid(rawTeamId);

      Map<String, dynamic>? res;
      try {
        res = await SupabaseService.client
            .from('team_members')
            .select('role')
            .or('user_id.eq.$uuid,user_id.eq.$currentUid')
            .or('team_id.eq.$teamUuid,team_id.eq.$rawTeamId')
            .limit(1)
            .maybeSingle();
      } catch (_) {
        try {
          res = await SupabaseService.client
              .from('team_members')
              .select('role')
              .eq('user_id', uuid)
              .eq('team_id', teamUuid)
              .maybeSingle();
        } catch (_) {}
      }

      if (res == null) {
        try {
          final squadRes = await SupabaseService.client
              .from('squad_members')
              .select()
              .or('user_id.eq.$uuid,user_id.eq.$currentUid')
              .limit(10);
          for (final row in squadRes) {
            final sTid =
                (row['team_id'] ?? row['squad_id'] ?? '').toString().trim();
            if (sTid.isEmpty) continue;
            final sTidLower = sTid.toLowerCase();
            final sTidUuidLower = SupabaseService.toUuid(sTid).toLowerCase();
            if (sTidLower == rawTeamId.toLowerCase() ||
                sTidLower == teamUuid.toLowerCase() ||
                sTidUuidLower == teamUuid.toLowerCase()) {
              res = Map<String, dynamic>.from(row);
              break;
            }
          }
        } catch (_) {}
      }

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
      case 'PUBG MOBILE':
        return const Color(0xFF1877F2);
      case 'VALORANT':
        return const Color(0xFF8B5CF6);
      case 'FREE FIRE':
        return const Color(0xFFFF5722);
      case 'COD':
      case 'COD MOBILE':
        return const Color(0xFFE11D48);
      default:
        return const Color(0xFF00E5FF);
    }
  }

  String _trClean(String key, String fallback) {
    final translated = key.tr();
    if (translated.isEmpty ||
        translated == key ||
        translated.contains('_')) {
      return fallback;
    }
    return translated;
  }

  void _openTeamProfile(TeamModel team) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamProfileScreen(
          teamId: team.id,
          team: team,
        ),
      ),
    );
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
          setState(() {
            _localSentChallenge = true;
          });

          final res = await SupabaseService.client.from('challenges').insert({
            'from_team_id': effectiveMyTeamId,
            'to_team_id': effectiveTargetId,
            'from_team_name': effectiveMyTeamName,
            'to_team_name': widget.team.name,
            'status': 'pending',
            'game': TeamService.displayGameLabel(widget.team.game),
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
    final currentUid = (GamerAuthService().currentUid ??
            SupabaseService.client.auth.currentUser?.id ??
            '')
        .trim();
    final isLeader = team.isLeader(currentUid);
    final isMember = team.isMember(currentUid);
    final rawHasRequested = team.hasRequestedJoin(currentUid);

    final hasRequested = !_localCancelled && (rawHasRequested || _localRequested);

    final bool myTeamIdMatches = widget.myTeamId.trim().isNotEmpty &&
        (team.id.trim().toLowerCase() == widget.myTeamId.trim().toLowerCase() ||
            SupabaseService.toUuid(team.id.trim()).toLowerCase() ==
                SupabaseService.toUuid(widget.myTeamId.trim()).toLowerCase());

    final bool isOwnerFinal = isLeader || _isOwnerFromDb || myTeamIdMatches;
    final bool isMemberFinal =
        isMember || _isMemberFromDb || isOwnerFinal || widget.isUserTeam;
    final bool isHighlighted = isMemberFinal || widget.isHighlightedTarget;

    final bool hasActiveChallenge = _localSentChallenge || (widget.pendingChallenge != null);
    final String activeChallengeId = widget.pendingChallenge?['id']?.toString() ??
        _localSentChallengeId ??
        '';

    final displayGame = TeamService.displayGameLabel(team.game);
    final gameColor = _getGameBadgeColor(displayGame);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        final isDark = ThemeService.isDarkMode;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isHighlighted
                ? (isDark ? const Color(0xFF1A1714) : const Color(0xFFFFF8F0))
                : ThemeService.card,
            gradient: isHighlighted
                ? LinearGradient(
                    colors: isDark
                        ? [
                            kAccentOrange.withOpacity(0.18),
                            const Color(0xFF151C2C),
                          ]
                        : [
                            kAccentOrange.withOpacity(0.14),
                            ThemeService.card,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isHighlighted
                  ? kAccentOrange
                  : ThemeService.border,
              width: isHighlighted ? 1.6 : 0.8,
            ),
            boxShadow: [
              if (isHighlighted)
                BoxShadow(
                  color: kAccentOrange.withOpacity(isDark ? 0.22 : 0.14),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isHighlighted) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isMemberFinal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [kAccentOrange, kAccentDeepOrange],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: kAccentOrange.withOpacity(0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  color: Colors.white,
                                  size: 11,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'YOUR TEAM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9.5,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isMemberFinal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: kAccentOrange.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: kAccentOrange.withOpacity(0.65),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOwnerFinal
                                      ? Icons.workspace_premium_rounded
                                      : Icons.verified_user_rounded,
                                  color: kAccentOrange,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isOwnerFinal ? 'LEADER' : 'MEMBER',
                                  style: const TextStyle(
                                    color: kAccentOrange,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9.5,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.isHighlightedTarget && !isMemberFinal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: kAccentOrange.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: kAccentOrange,
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_active_rounded,
                                  color: kAccentOrange,
                                  size: 11,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'SELECTED TEAM',
                                  style: TextStyle(
                                    color: kAccentOrange,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9.5,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openTeamProfile(team),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: ThemeService.cardSecondary,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isHighlighted
                                ? kAccentOrange
                                : gameColor.withOpacity(0.35),
                            width: isHighlighted ? 1.4 : 1.0,
                          ),
                          image: team.logo.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(team.logo),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: team.logo.isEmpty
                            ? Center(
                                child: Icon(
                                  Icons.shield_rounded,
                                  color: isHighlighted ? kAccentOrange : gameColor,
                                  size: 22,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
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
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (team.tag.trim().isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '[${team.tag.trim()}]',
                                    style: TextStyle(
                                      color: isHighlighted
                                          ? kAccentOrange
                                          : ThemeService.textSecondary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: gameColor.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    displayGame.toUpperCase(),
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
                              "Leader: @${TeamModel.sanitizePublicHandle(team.leaderName, fallback: 'Leader')}",
                              style: TextStyle(
                                color: ThemeService.textSecondary,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2.5),
                            Row(
                              children: [
                                Icon(
                                  Icons.group_rounded,
                                  color: isHighlighted
                                      ? kAccentOrange
                                      : const Color(0xFF1877F2),
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  "${team.memberCount}/${TeamModel.maxMembers} Members",
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
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ThemeService.textPrimary,
                            side: BorderSide(
                              color: isHighlighted
                                  ? kAccentOrange.withOpacity(0.55)
                                  : ThemeService.border,
                              width: 0.9,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            backgroundColor: ThemeService.cardSecondary,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => _openTeamProfile(team),
                          child: Text(
                            _trClean('view_team', 'View Team'),
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
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: isOwnerFinal || isMemberFinal
                            ? ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kAccentOrange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                ),
                                icon: const Icon(Icons.login_rounded, size: 13),
                                label: Text(
                                  _trClean('open_team', 'Open Team'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                onPressed: () => _openTeamProfile(team),
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
                                      _trClean('btn_requested', 'Requested'),
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
                                              ? _trClean('loading', 'Loading...')
                                              : _trClean('btn_cancel_request', 'Cancel Request'),
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
                                          _trClean('btn_challenge_caps', 'CHALLENGE'),
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
