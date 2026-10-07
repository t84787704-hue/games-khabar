import 'package:flutter/material.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../services/supabase_service.dart';
import '../services/gamer_auth_service.dart';
import '../screens/team_profile_screen.dart';
import '../screens/teams_screen.dart';

class TeamCard extends StatefulWidget {
  final TeamModel team;
  final String myTeamId;
  final String myTeamName;
  final Map<String, dynamic>? pendingChallenge;
  final Future<void> Function(String challengeId)? onCancelChallenge;

  const TeamCard({
    super.key,
    required this.team,
    this.myTeamId = '',
    this.myTeamName = '',
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

  /// Check Supabase team_members table to see if current user is already
  /// a member or owner of this team.
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
          const SnackBar(
            content: Text('براہ کرم پہلے لاگ ان کریں'),
            backgroundColor: Color(0xFFFF4655),
          ),
        );
      }
      return;
    }

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
          const SnackBar(
            content: Text('✅ شمولیت کی درخواست بھیج دی گئی ہے!'),
            backgroundColor: Color(0xFF1877F2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('درخواست بھیجنے میں مسئلہ ہوا، دوبارہ کوشش کریں'),
            backgroundColor: Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  Future<void> _handleChallenge(String currentUid) async {
    final myTeams = await _teamService.getUserTeams(currentUid);
    final myLeaderTeams =
        myTeams.where((t) => t.isLeader(currentUid)).toList();

    if (!mounted) return;

    if (myLeaderTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'چیلنج بھیجنے کے لیے پہلے اپنی ٹیم بنائیں (Create Team)!'),
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

    try {
      List<dynamic> existing = [];
      try {
        existing = await SupabaseService.client
            .from('challenges')
            .select()
            .eq('from_team_id', effectiveMyTeamId)
            .eq('to_team_id', effectiveTargetId)
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
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFF4655), size: 24),
                  SizedBox(width: 8),
                  Text('Challenge Already Sent',
                      style: TextStyle(
                          color: Color(0xFFFF4655),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              content: Text(
                '⚠️ Aap ne pehle hi challenge bheja hai - Aap ${widget.team.name} ko pehle se challenge bhej chuke hain, isko complete ya cancel kiye baghair dubara nahi bhej sakte',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close',
                      style: TextStyle(color: Color(0xFF8B949E))),
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
                  child: const Text('CANCEL',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return;
      }

      try {
        await SupabaseService.client.from('challenges').insert({
          'from_team_id': effectiveMyTeamId,
          'to_team_id': effectiveTargetId,
          'from_team_name': effectiveMyTeamName,
          'to_team_name': widget.team.name,
          'status': 'pending',
          'game': 'BGMI',
        });
      } catch (_) {
        await SupabaseService.client.from('challenges').insert({
          'from_team_id': effectiveMyTeamId,
          'to_team_id': effectiveTargetId,
          'from_team_name': effectiveMyTeamName,
          'to_team_name': widget.team.name,
          'status': 'pending',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Aapka challenge bhej diya gaya hai - ${widget.team.name} ko challenge bhej diya gaya hai, jawab ka intezar hai'),
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
            content: Text('Error sending challenge: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
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
          const SnackBar(
            content: Text('Challenge Cancel ho gaya'),
            backgroundColor: Color(0xFF1877F2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeamCard] Error cancelling challenge: $e');
    }
  }

  Widget _buildRedBanner(String challengeId) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1877F2).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: Color(0xFF1877F2), size: 14),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Challenge bhej diya hai - Jawab ka intezar hai',
              style: TextStyle(
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
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                'Cancel',
                style: TextStyle(
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE4E6EB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCED0D4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top_rounded,
                  size: 12, color: Color(0xFF65676B)),
              SizedBox(width: 4),
              Text(
                'Requested',
                style: TextStyle(
                  color: Color(0xFF65676B),
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
            backgroundColor: const Color(0xFFFEF2F2),
          ),
          icon: const Icon(Icons.close_rounded,
              size: 13, color: Color(0xFFFF4655)),
          label: const Text('Cancel',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
      label: const Text('CHALLENGE',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      onPressed: () => _handleChallenge(currentUid),
    );
  }

  /// REAL-TIME challenge section. Always listens to Supabase directly so the
  /// button updates the instant a challenge is inserted or cancelled.
  Widget _buildChallengeSection(String currentUid) {
    if (widget.myTeamId.isEmpty) {
      return _buildChallengeButton(currentUid);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('challenges')
          .stream(primaryKey: ['id'])
          .eq('from_team_id', SupabaseService.toUuid(widget.myTeamId)),
      builder: (context, cSnap) {
        final challenges = cSnap.data ?? [];
        final targetUuid = SupabaseService.toUuid(widget.team.id).toLowerCase();
        final rawTeamId = widget.team.id.toLowerCase();

        final pendingDoc = challenges.firstWhere(
          (d) {
            final toId = d['to_team_id']?.toString().toLowerCase();
            final st = (d['status'] ?? '').toString().toLowerCase();
            final id = d['id']?.toString() ?? '';
            return (toId == targetUuid || toId == rawTeamId) &&
                st == 'pending' &&
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

  /// 👑 Golden OWNER badge
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('👑', style: TextStyle(fontSize: 11)),
          SizedBox(width: 3),
          Text(
            'OWNER',
            style: TextStyle(
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

  /// 🛡️ Blue MEMBER badge
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🛡️', style: TextStyle(fontSize: 11)),
          SizedBox(width: 3),
          Text(
            'MEMBER',
            style: TextStyle(
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

  /// "Open Team" button shown to members/owners instead of Join
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
      label: const Text(
        'Open Team',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
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

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final currentUid = GamerAuthService().currentUid ??
        (SupabaseService.client.auth.currentUser?.id ?? '');
    final isLeader = team.isLeader(currentUid);
    final isMember = team.isMember(currentUid);
    final hasRequested = team.hasRequestedJoin(currentUid);

    // Combine local model check + DB check
    final bool isOwnerFinal = isLeader || _isOwnerFromDb;
    final bool isMemberFinal = isMember || _isMemberFromDb || isOwnerFinal;

    // Card background highlight for owner/member
    final Color cardBgColor = isOwnerFinal
        ? const Color(0xFFFFF8E1) // soft golden for owner
        : isMemberFinal
            ? const Color(0xFFE7F3FF) // soft blue for member
            : Colors.white;

    final Color cardBorderColor = isOwnerFinal
        ? const Color(0xFFFFD700)
        : isMemberFinal
            ? const Color(0xFF1877F2)
            : const Color(0xFFE4E6EB);

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
                    : Colors.black.withOpacity(0.04),
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
                // Top Row: Logo, Name, Tag & Leader
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team Logo
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE4E6EB),
                        border: Border.all(
                            color: isOwnerFinal
                                ? const Color(0xFFFFD700)
                                : isMemberFinal
                                    ? const Color(0xFF1877F2)
                                    : const Color(0xFFCED0D4),
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

                    // Name, Tag, Leader + Badges
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
                                    color: Color(0xFF050505),
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
                                  color: const Color(0xFFE7F3FF),
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

                          // 👑 Owner / 🛡️ Member badge row
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
                            'Leader: ${team.leaderName}',
                            style: const TextStyle(
                                color: Color(0xFF65676B), fontSize: 12),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F2F5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFE4E6EB)),
                                ),
                                child: Text(
                                  team.game,
                                  style: const TextStyle(
                                    color: Color(0xFF050505),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  const Icon(Icons.group_rounded,
                                      size: 14, color: Color(0xFF65676B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${team.memberCount} Members',
                                    style: const TextStyle(
                                        color: Color(0xFF65676B),
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
                  ],
                ),

                if (team.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    team.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF1C1E21), fontSize: 12.5),
                  ),
                ],

                // Red banner: pending challenge — real-time
                if (!isMemberFinal &&
                    currentUid.isNotEmpty &&
                    widget.myTeamId.isNotEmpty) ...[
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: SupabaseService.client
                        .from('challenges')
                        .stream(primaryKey: ['id'])
                        .eq('from_team_id',
                            SupabaseService.toUuid(widget.myTeamId)),
                    builder: (context, cSnap) {
                      final challenges = cSnap.data ?? [];
                      final targetUuid =
                          SupabaseService.toUuid(team.id).toLowerCase();
                      final rawTeamId = team.id.toLowerCase();
                      final pendingDoc = challenges.firstWhere(
                        (d) {
                          final toId =
                              d['to_team_id']?.toString().toLowerCase();
                          final st =
                              (d['status'] ?? '').toString().toLowerCase();
                          final id = d['id']?.toString() ?? '';
                          return (toId == targetUuid ||
                                  toId == rawTeamId) &&
                              st == 'pending' &&
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
                const Divider(color: Color(0xFFE4E6EB), height: 1),
                const SizedBox(height: 10),

                // Bottom action buttons
                Row(
                  children: [
                    Text(
                      'W: ${team.wins} | L: ${team.losses} | Pts: ${team.points}',
                      style: const TextStyle(
                          color: Color(0xFF65676B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),

                    // View Team button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF050505),
                        side: const BorderSide(color: Color(0xFFCED0D4)),
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
                      child: const Text('View Team',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),

                    // Owner/Member: Show Open Team
                    if (isOwnerFinal || isMemberFinal)
                      _buildOpenTeamButton()
                    else ...[
                      // Non-members: live Challenge + Join buttons
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

                          // If there's a live active match: show LIVE badge + DM
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
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                          Icons
                                              .local_fire_department_rounded,
                                          size: 14,
                                          color: Colors.black),
                                      SizedBox(width: 4),
                                      Text(
                                        'LIVE',
                                        style: TextStyle(
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
                                  label: const Text('Team DM 💬',
                                      style: TextStyle(
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

                          // Always use real-time challenge section
                          return _buildChallengeSection(currentUid);
                        },
                      ),
                      const SizedBox(width: 8),

                      // Join button
                      Builder(builder: (context) {
                        final bool isRequested =
                            hasRequested || _localRequested;
                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isRequested
                                ? const Color(0xFFE4E6EB)
                                : const Color(0xFF1877F2),
                            foregroundColor: isRequested
                                ? const Color(0xFF65676B)
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
                                ? const Color(0xFF65676B)
                                : Colors.white,
                          ),
                          label: Text(
                            isRequested ? 'Requested ⏳' : 'Join',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                              color: isRequested
                                  ? const Color(0xFF65676B)
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}