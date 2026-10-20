// ===============================================================================
// EXACT DIFF — Full Adaptive Day & Night Mode Support for TeamCard
// + Match Verification Rules Dialog on Challenge Action
// + Frozen Team Challenge Blocking Logic (Both Sender & Receiver)
// + Full Localization (easy_localization) Support - No Hardcoded Urdu
// -------------------------------------------------------------------------------
// File: lib/widgets/team_card.dart
// ===============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../services/supabase_service.dart';
import '../services/gamer_auth_service.dart';
import '../screens/team_profile_screen.dart';
import '../screens/teams_screen.dart';
import '../screens/private_match_room_screen.dart';
import '../services/theme_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/notification_service.dart';
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
  bool _checkingMembership = true;
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
    if (currentUid.isEmpty) {
      if (mounted) setState(() => _checkingMembership = false);
      return;
    }

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
        _checkingMembership = false;
      });
    } catch (e) {
      debugPrint('[TeamCard] _checkMembership error: $e');
      if (mounted) setState(() => _checkingMembership = false);
    }
  }

  Future<void> _handleJoin(String currentUid) async {
    final effectiveUid = currentUid.isNotEmpty
        ? currentUid
        : (GamerAuthService().currentUid ??
            SupabaseService.client.auth.currentUser?.id ??
            '');

    if (effectiveUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('please_login_first'.tr()),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
      return;
    }

    await CoinOrAdPopup.show(
      context: context,
      actionName: 'action_team_join'.tr(),
      onConfirm: () async {
        final currentGamer = GamerAuthService().currentGamer;
        final userName =
            currentGamer?.displayName ?? currentGamer?.username ?? 'Gamer';

        setState(() => _isRequesting = true);
        final success = await _teamService.requestToJoinTeam(
          teamId: widget.team.id,
          userId: effectiveUid,
          userName: userName,
          teamName: widget.team.name,
        );
        setState(() {
          _isRequesting = false;
          if (success) {
            _localRequested = true;
          }
        });

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('team_join_request_sent'.tr()),
                backgroundColor: const Color(0xFF1877F2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('team_join_request_error'.tr()),
                backgroundColor: const Color(0xFFFF4655),
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _handleChallenge(String currentUid) async {
    if (widget.isMyTeamFrozen) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ThemeService.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.lock_clock_rounded, color: Color(0xFFFF4655), size: 24),
                const SizedBox(width: 8),
                Text(
                  'team_frozen_title'.tr(),
                  style: const TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: Text(
              'team_frozen_my_balance_warning'.tr(),
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 13.5, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('btn_ok'.tr(), style: const TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (widget.team.leaderId.isNotEmpty) {
      try {
        final targetWallet = await CoinWalletService().getOrCreateWallet(widget.team.leaderId);
        if (targetWallet.coins < 1000) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: ThemeService.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded, color: Color(0xFFFF4655), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'team_frozen_title'.tr(),
                      style: const TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                content: Text(
                  'team_frozen_target_balance_warning'.tr(),
                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 13.5, height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('btn_ok'.tr(), style: const TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('[TeamCard] Error checking target team wallet: $e');
      }
    }

    final myTeams = await _teamService.getUserTeams(currentUid);
    final myLeaderTeams =
        myTeams.where((t) => t.isLeader(currentUid)).toList();

    if (!mounted) return;

    if (myLeaderTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('create_team_first_to_challenge'.tr()),
          backgroundColor: const Color(0xFF65676B),
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

    try {
      List<dynamic> existing = [];
      try {
        existing = await SupabaseService.client
            .from('challenges')
            .select()
            .or('from_team_id.eq.$effectiveMyTeamId,from_team_id.eq.${effectiveMyTeam.id}')
            .or('to_team_id.eq.$effectiveTargetId,to_team_id.eq.${widget.team.id}')
            .inFilter('status',
                ['pending', 'requested', 'active', 'under_review']);
      } catch (_) {
        existing = [];
      }

      if (existing.isNotEmpty) {
        final cId = existing[0]['id']?.toString() ?? '';
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF131A29),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFF4655), size: 24),
                  const SizedBox(width: 8),
                  Text('challenge_already_sent_title'.tr(),
                      style: const TextStyle(
                          color: Color(0xFFFF4655),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              content: Text(
                'challenge_already_sent_desc'.tr(args: [widget.team.name]),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('btn_close'.tr(),
                      style: const TextStyle(color: Color(0xFF8B949E))),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (widget.onCancelChallenge != null && cId.isNotEmpty) {
                      widget.onCancelChallenge!(cId);
                    } else if (cId.isNotEmpty) {
                      _cancelChallengeLocally(cId);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4655),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('btn_cancel'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return;
      }

      MatchRulesDialog.show(
        context,
        title: '${'challenge_rules_title'.tr()} (${widget.team.name})',
        onProceed: () async {
          try {
            Map<String, dynamic>? insertedChallenge;
            try {
              insertedChallenge = await SupabaseService.client.from('challenges').insert({
                'from_team_id': effectiveMyTeamId,
                'to_team_id': effectiveTargetId,
                'from_team_name': effectiveMyTeamName,
                'to_team_name': widget.team.name,
                'status': 'pending',
                'game': widget.team.game.isNotEmpty ? widget.team.game : 'BGMI',
              }).select().maybeSingle();
            } catch (_) {
              try {
                insertedChallenge = await SupabaseService.client.from('challenges').insert({
                  'from_team_id': effectiveMyTeamId,
                  'to_team_id': effectiveTargetId,
                  'from_team_name': effectiveMyTeamName,
                  'to_team_name': widget.team.name,
                  'status': 'pending',
                }).select().maybeSingle();
              } catch (_) {
                insertedChallenge = await SupabaseService.client.from('challenges').insert({
                  'from_team_id': effectiveMyTeamId,
                  'to_team_id': widget.team.id,
                  'from_team_name': effectiveMyTeamName,
                  'to_team_name': widget.team.name,
                  'status': 'pending',
                }).select().maybeSingle();
              }
            }

            if (widget.team.leaderId.isNotEmpty) {
              try {
                await NotificationService().sendNotification(
                  userId: widget.team.leaderId,
                  type: 'team_challenge',
                  title: 'notif_new_challenge_title'.tr(),
                  body: 'notif_new_challenge_body'.tr(args: [effectiveMyTeamName]),
                  data: {
                    'challenge_id': insertedChallenge?['id']?.toString() ?? '',
                    'from_team_id': effectiveMyTeamId,
                  },
                );
              } catch (_) {}
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('challenge_sent_success'.tr(args: [widget.team.name])),
                  backgroundColor: const Color(0xFF1877F2),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          } catch (e) {
            debugPrint('[TeamCard] Error sending challenge via Supabase: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${'error_sending_challenge'.tr()}: $e'),
                  backgroundColor: const Color(0xFFFF4655),
                ),
              );
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[TeamCard] Error in _handleChallenge: $e');
    }
  }

  Future<void> _cancelChallengeLocally(String challengeId) async {
    setState(() {
      _localCancelledIds.add(challengeId);
    });
    try {
      await SupabaseService.client
          .from('challenges')
          .delete()
          .eq('id', challengeId);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('challenge_cancelled_success'.tr()),
            backgroundColor: const Color(0xFF1877F2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamCard] Error cancelling challenge: $e');
    }
  }

  Widget _buildRedBanner(String challengeId) {
    final isDark = ThemeService.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D223A) : const Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1877F2).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: Color(0xFF1877F2), size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'challenge_sent_waiting_reply'.tr(),
              style: const TextStyle(
                  color: Color(0xFF1877F2),
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: () {
              if (widget.onCancelChallenge != null) {
                widget.onCancelChallenge!(challengeId);
              } else {
                _cancelChallengeLocally(challengeId);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                'btn_cancel'.tr(),
                style: const TextStyle(
                  color: Color(0xFFFF4655),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestedButton(String challengeId) {
    final isDark = ThemeService.isDarkMode;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: ThemeService.cardSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ThemeService.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top_rounded,
                  size: 12, color: ThemeService.textSecondary),
              const SizedBox(width: 4),
              Text(
                'requested_label'.tr(),
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF4655),
            side: const BorderSide(color: Color(0xFFFF4655), width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 32),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: isDark ? const Color(0xFF3B151A) : const Color(0xFFFEF2F2),
          ),
          icon: const Icon(Icons.close_rounded,
              size: 13, color: Color(0xFFFF4655)),
          label: Text('btn_cancel'.tr(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          onPressed: () {
            if (widget.onCancelChallenge != null) {
              widget.onCancelChallenge!(challengeId);
            } else {
              _cancelChallengeLocally(challengeId);
            }
          },
        ),
      ],
    );
  }

  Widget _buildChallengeButton(String currentUid) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      icon: const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
      label: Text('challenge_button'.tr(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      onPressed: () => _handleChallenge(currentUid),
    );
  }

  Widget _buildChallengeSection(String currentUid) {
    if (widget.myTeamId.isEmpty) {
      return _buildChallengeButton(currentUid);
    }

    final myUuid = SupabaseService.toUuid(widget.myTeamId).toLowerCase();
    final myRawId = widget.myTeamId.toLowerCase();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('challenges')
          .stream(primaryKey: ['id']),
      builder: (context, cSnap) {
        final challenges = cSnap.data ?? [];
        final targetUuid = SupabaseService.toUuid(widget.team.id).toLowerCase();
        final rawTeamId = widget.team.id.toLowerCase();

        final pendingDoc = challenges.firstWhere(
          (d) {
            final fromId = (d['from_team_id'] ?? '').toString().toLowerCase();
            final toId = (d['to_team_id'] ?? '').toString().toLowerCase();
            final st = (d['status'] ?? '').toString().toLowerCase();
            final id = d['id']?.toString() ?? '';

            final isFromMe = (fromId == myUuid || fromId == myRawId);
            final isToTarget = (toId == targetUuid || toId == rawTeamId);

            return isFromMe &&
                isToTarget &&
                (st == 'pending' || st == 'requested') &&
                !_localCancelledIds.contains(id);
          },
          orElse: () => {},
        );

        if (pendingDoc.isNotEmpty) {
          return _buildRequestedButton(
              pendingDoc['id']?.toString() ?? '');
        }

        return _buildChallengeButton(currentUid);
      },
    );
  }

  Widget _buildOwnerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA500).withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👑', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text(
            'badge_owner'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1877F2),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1877F2).withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🛡️', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text(
            'badge_member'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenTeamButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00C853),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: const Size(0, 32),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.login_rounded, size: 14, color: Colors.white),
      label: Text(
        'open_team_button'.tr(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamProfileScreen(teamId: widget.team.id),
          ),
        );
      },
    );
  }

  Future<void> _showEditTeamDialog() async {
    final nameCtrl = TextEditingController(text: widget.team.name);
    final tagCtrl = TextEditingController(text: widget.team.tag);
    final gameCtrl = TextEditingController(text: widget.team.game);
    final descCtrl = TextEditingController(text: widget.team.description);
    final reqCtrl = TextEditingController(text: widget.team.requirements);
    File? newLogoFile;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A29),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_rounded, color: Color(0xFF00FF88), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'edit_team_title'.tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                          source: ImageSource.gallery, imageQuality: 80);
                      if (picked != null) {
                        setDialogState(() {
                          newLogoFile = File(picked.path);
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1F2B3E),
                            border: Border.all(
                                color: const Color(0xFF00FF88), width: 2),
                            image: newLogoFile != null
                                ? DecorationImage(
                                    image: FileImage(newLogoFile!),
                                    fit: BoxFit.cover)
                                : (widget.team.logo.isNotEmpty
                                    ? DecorationImage(
                                        image:
                                            NetworkImage(widget.team.logo),
                                        fit: BoxFit.cover)
                                    : null),
                          ),
                          child: (newLogoFile == null &&
                                  widget.team.logo.isEmpty)
                              ? const Icon(Icons.shield_rounded,
                                  color: Color(0xFF00FF88), size: 36)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00FF88),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.black, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'tap_to_change_logo'.tr(),
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'team_name_label'.tr(),
                    labelStyle:
                        const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF10141D),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00FF88)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: tagCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'team_tag_label'.tr(),
                    labelStyle:
                        const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF10141D),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00FF88)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: gameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'game_label'.tr(),
                    labelStyle:
                        const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF10141D),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00FF88)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'description_label'.tr(),
                    labelStyle:
                        const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF10141D),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00FF88)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: reqCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'requirements_label'.tr(),
                    labelStyle:
                        const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF10141D),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00FF88)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text('btn_cancel'.tr(),
                  style: const TextStyle(color: Color(0xFF8B949E))),
            ),
            ElevatedButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          tagCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('name_tag_required'.tr()),
                            backgroundColor: const Color(0xFFFF4655),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      final ok = await _teamService.updateTeam(
                        teamId: widget.team.id,
                        name: nameCtrl.text.trim(),
                        tag: tagCtrl.text.trim(),
                        newLogoFile: newLogoFile,
                        game: gameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        requirements: reqCtrl.text.trim(),
                      );

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'team_updated_success'.tr()
                                : 'team_update_failed'.tr()),
                            backgroundColor: ok
                                ? const Color(0xFF00FF88)
                                : const Color(0xFFFF4655),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
              ),
              icon: isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(
                isSaving ? 'saving_label'.tr() : 'save_changes_btn'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteTeamDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFF4655), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'delete_team_title'.tr(),
                style: const TextStyle(
                    color: Color(0xFFFF4655),
                    fontWeight: FontWeight.bold,
                    fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'delete_team_confirm'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10141D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A3447)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded,
                      color: Color(0xFF00FF88), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.team.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'delete_team_warning'.tr(),
              style: const TextStyle(color: Color(0xFFFF4655), fontSize: 11.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('btn_cancel'.tr(),
                style: const TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: Text('delete_team_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentUid = GamerAuthService().currentUid ??
        (SupabaseService.client.auth.currentUser?.id ?? '');

    if (currentUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('user_not_logged_in'.tr()),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
      return;
    }

    final result = await _teamService.deleteTeam(
      teamId: widget.team.id,
      currentUserId: currentUid,
    );

    if (!mounted) return;

    String msg;
    Color bg;
    switch (result) {
      case 'ok':
        msg = 'team_deleted_success'.tr();
        bg = const Color(0xFF00FF88);
        break;
      case 'not_owner':
        msg = 'not_team_owner_error'.tr();
        bg = const Color(0xFFFF4655);
        break;
      case 'active_match':
        msg = 'active_match_exists_error'.tr();
        bg = const Color(0xFFFF4655);
        break;
      default:
        msg = 'team_delete_failed'.tr();
        bg = const Color(0xFFFF4655);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
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

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        final isDark = ThemeService.isDarkMode;

        final Color cardBgColor = isOwnerFinal
            ? (isDark ? const Color(0xFF2A2105) : const Color(0xFFFFF8E1))
            : isMemberFinal
                ? (isDark ? const Color(0xFF0D223A) : const Color(0xFFE7F3FF))
                : ThemeService.card;

        final Color cardBorderColor = isOwnerFinal
            ? const Color(0xFFFFD700)
            : isMemberFinal
                ? const Color(0xFF1877F2)
                : ThemeService.border;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cardBorderColor,
              width: (isOwnerFinal || isMemberFinal) ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isOwnerFinal
                    ? const Color(0xFFFFD700).withOpacity(0.15)
                    : isMemberFinal
                        ? const Color(0xFF1877F2).withOpacity(0.15)
                        : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamProfileScreen(teamId: team.id),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ThemeService.cardSecondary,
                            border: Border.all(
                                color: isOwnerFinal
                                    ? const Color(0xFFFFD700)
                                    : isMemberFinal
                                        ? const Color(0xFF1877F2)
                                        : ThemeService.border,
                                width: (isOwnerFinal || isMemberFinal) ? 2 : 1.2),
                            image: team.logo.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(team.logo),
                                    fit: BoxFit.cover)
                                : null,
                          ),
                          child: team.logo.isEmpty
                              ? const Center(
                                  child: Icon(Icons.shield_rounded,
                                      color: Color(0xFF1877F2), size: 28))
                              : null,
                        ),
                        const SizedBox(width: 12),

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
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0D223A) : const Color(0xFFE7F3FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFF1877F2)
                                              .withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      team.tag,
                                      style: const TextStyle(
                                        color: Color(0xFF1877F2),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              if (_checkingMembership) ...[
                                const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Color(0xFF1877F2)),
                                ),
                              ] else if (isOwnerFinal) ...[
                                _buildOwnerBadge(),
                              ] else if (isMemberFinal) ...[
                                _buildMemberBadge(),
                              ],

                              const SizedBox(height: 3),
                              Text(
                                '${'leader_label'.tr()}: ${team.leaderName}',
                                style: TextStyle(
                                    color: ThemeService.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ThemeService.cardSecondary,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: ThemeService.border),
                                    ),
                                    child: Text(
                                      team.game,
                                      style: TextStyle(
                                        color: ThemeService.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.group_rounded,
                                          size: 14, color: ThemeService.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${team.memberCount} ${'members_count_label'.tr()}',
                                        style: TextStyle(
                                            color: ThemeService.textSecondary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (isOwnerFinal && !_checkingMembership) ...[
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded,
                                color: ThemeService.textSecondary, size: 22),
                            color: const Color(0xFF131A29),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _showEditTeamDialog();
                              } else if (val == 'delete') {
                                _showDeleteTeamDialog();
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_rounded,
                                        color: Color(0xFF00FF88), size: 18),
                                    const SizedBox(width: 10),
                                    Text('edit_team_title'.tr(),
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_forever_rounded,
                                        color: Color(0xFFFF4655), size: 18),
                                    const SizedBox(width: 10),
                                    Text('delete_team_title'.tr(),
                                        style: const TextStyle(
                                            color: Color(0xFFFF4655),
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    if (team.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        team.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: ThemeService.textSecondary, fontSize: 12.5),
                      ),
                    ],

                    if (!isMemberFinal &&
                        currentUid.isNotEmpty &&
                        widget.myTeamId.isNotEmpty) ...[
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: SupabaseService.client
                            .from('challenges')
                            .stream(primaryKey: ['id']),
                        builder: (context, cSnap) {
                          final challenges = cSnap.data ?? [];
                          final myUuid = SupabaseService.toUuid(widget.myTeamId).toLowerCase();
                          final myRawId = widget.myTeamId.toLowerCase();
                          final targetUuid = SupabaseService.toUuid(team.id).toLowerCase();
                          final rawTeamId = team.id.toLowerCase();

                          final pendingDoc = challenges.firstWhere(
                            (d) {
                              final fromId = (d['from_team_id'] ?? '').toString().toLowerCase();
                              final toId = (d['to_team_id'] ?? '').toString().toLowerCase();
                              final st = (d['status'] ?? '').toString().toLowerCase();
                              final id = d['id']?.toString() ?? '';

                              final isFromMe = (fromId == myUuid || fromId == myRawId);
                              final isToTarget = (toId == targetUuid || toId == rawTeamId);

                              return isFromMe &&
                                  isToTarget &&
                                  (st == 'pending' || st == 'requested') &&
                                  !_localCancelledIds.contains(id);
                            },
                            orElse: () => {},
                          );

                          if (pendingDoc.isEmpty) return const SizedBox.shrink();
                          return _buildRedBanner(
                              pendingDoc['id']?.toString() ?? '');
                        },
                      ),
                    ],

                    const SizedBox(height: 12),
                    Divider(color: ThemeService.border, height: 1),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Text(
                          'team_stats_w_l_pts'.tr(args: [team.wins.toString(), team.losses.toString(), team.points.toString()]),
                          style: TextStyle(
                              color: ThemeService.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: ThemeService.textPrimary,
                                    side: BorderSide(color: ThemeService.border),
                                    backgroundColor: ThemeService.cardSecondary,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            TeamProfileScreen(teamId: team.id),
                                      ),
                                    );
                                  },
                                  child: Text('view_team_button'.tr(),
                                      style: TextStyle(
                                          color: ThemeService.textPrimary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),

                                if (isOwnerFinal || isMemberFinal)
                                  _buildOpenTeamButton()
                                else ...[
                                  StreamBuilder<List<Map<String, dynamic>>>(
                                    stream: widget.myTeamId.isNotEmpty
                                        ? SupabaseService.client
                                            .from('active_matches')
                                            .stream(primaryKey: ['id'])
                                            .eq('status', 'active')
                                        : Stream.value([]),
                                    builder: (context, activeSnap) {
                                      final activeMatches = activeSnap.data ?? [];
                                      final myUuid =
                                          SupabaseService.toUuid(widget.myTeamId)
                                              .toLowerCase();
                                      final myRawId = widget.myTeamId.toLowerCase();
                                      final targetUuid =
                                          SupabaseService.toUuid(team.id).toLowerCase();
                                      final targetRawId = team.id.toLowerCase();

                                      final activeMatchWithOpponent =
                                          activeMatches.firstWhere(
                                        (m) {
                                          if (m['status'] != 'active') return false;
                                          final participants = m['participants'];
                                          final List<String> pList = [];
                                          if (participants is List) {
                                            pList.addAll(participants.map(
                                                (p) => p.toString().toLowerCase()));
                                          }
                                          pList.add(
                                              m['team1_id']?.toString().toLowerCase() ??
                                                  '');
                                          pList.add(
                                              m['team2_id']?.toString().toLowerCase() ??
                                                  '');
                                          final hasMe = pList.contains(myUuid) ||
                                              pList.contains(myRawId);
                                          final hasTarget =
                                              pList.contains(targetUuid) ||
                                              pList.contains(targetRawId);
                                          return hasMe && hasTarget;
                                        },
                                        orElse: () => {},
                                      );

                                      if (activeMatchWithOpponent.isNotEmpty) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00FF88),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                      Icons
                                                          .local_fire_department_rounded,
                                                      size: 14,
                                                      color: Colors.black),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'status_live'.tr(),
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF1877F2),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 4),
                                                minimumSize: const Size(0, 32),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(8)),
                                                elevation: 0,
                                              ),
                                              icon: const Icon(
                                                  Icons.chat_bubble_rounded,
                                                  size: 14),
                                              label: Text('team_dm_button'.tr(),
                                                  style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.bold)),
                                              onPressed: () {
                                                final matchId =
                                                    activeMatchWithOpponent['id']
                                                            ?.toString() ??
                                                        '';
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        PrivateMatchRoomScreen(
                                                      matchId: matchId,
                                                      myTeamId: widget.myTeamId,
                                                      myTeamName: widget.myTeamName,
                                                      opponentId: team.id,
                                                      opponentName: team.name,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      }

                                      return _buildChallengeSection(currentUid);
                                    },
                                  ),
                                  const SizedBox(width: 8),

                                  Builder(builder: (context) {
                                    final bool isRequested =
                                        hasRequested || _localRequested;
                                    return ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isRequested
                                            ? ThemeService.cardSecondary
                                            : const Color(0xFF1877F2),
                                        foregroundColor: isRequested
                                            ? ThemeService.textSecondary
                                            : Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        minimumSize: const Size(0, 32),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: Icon(
                                        isRequested
                                            ? Icons.hourglass_top_rounded
                                            : Icons.person_add_rounded,
                                        size: 14,
                                        color: isRequested
                                            ? ThemeService.textSecondary
                                            : Colors.white,
                                      ),
                                      label: Text(
                                        isRequested ? 'requested_label'.tr() : 'join_btn'.tr(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          color: isRequested
                                              ? ThemeService.textSecondary
                                              : Colors.white,
                                        ),
                                      ),
                                      onPressed: (isRequested || _isRequesting)
                                          ? null
                                          : () => _handleJoin(currentUid),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
