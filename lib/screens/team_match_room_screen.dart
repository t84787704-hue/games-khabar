import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/gamer_theme.dart';
import '../models/team_match_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/team_match_service.dart';
import '../services/supabase_service.dart';

class TeamMatchRoomScreen extends StatefulWidget {
  final String matchId;

  const TeamMatchRoomScreen({super.key, required this.matchId});

  @override
  State<TeamMatchRoomScreen> createState() => _TeamMatchRoomScreenState();
}

class _TeamMatchRoomScreenState extends State<TeamMatchRoomScreen> with SingleTickerProviderStateMixin {
  final TeamMatchService _matchService = TeamMatchService();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late TabController _tabController;
  Timer? _countdownTimer;
  Duration _timeRemaining = Duration.zero;
  bool _isUploadingProof = false;
  bool _isSendingChat = false;
  String get currentUid => GamerAuthService().currentUid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startCountdownTicker();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _startCountdownTicker() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Duration _calculateRemaining(DateTime target) {
    final diff = target.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return 'match_time_started'.tr();
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _handleUploadProof(TeamMatch match, bool isTeam1, [String? uid]) async {
    final currentUid = uid ?? GamerAuthService().currentUid ?? '';
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('select_match_result_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'select_match_result_desc'.tr(),
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'loss'),
            child: Text('report_loss_btn'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, 'win'),
            child: Text('claim_win_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == null) return;

    setState(() => _isUploadingProof = true);

    final result = await _matchService.submitProof(
      matchId: match.matchId,
      teamId: isTeam1 ? match.team1Id : match.team2Id,
      userId: currentUid,
      isTeam1: isTeam1,
      imageFile: File(picked.path),
      proofImage: File(picked.path),
      claim: confirm,
    );

    setState(() => _isUploadingProof = false);

    if (mounted) {
      if (result['success'] == true) {
        final message = 'proof_submitted_wait_admin'.tr();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00FF88),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        final errorMsg = result['error']?.toString() ?? 'screenshot_upload_failed'.tr();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  Future<void> _handleSendChat(TeamMatch match, String currentUid, bool isTeam1) async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();
    setState(() => _isSendingChat = true);

    final currentGamer = GamerAuthService().currentGamer;
    final teamName = isTeam1 ? match.team1Name : match.team2Name;
    final senderName = currentGamer?.displayName ?? currentGamer?.username ?? 'Player';
    final senderAvatar = currentGamer?.photoUrl ?? '';

    await _matchService.sendChatMessage(
      matchId: match.matchId,
      senderId: currentUid,
      senderName: senderName,
      senderAvatar: senderAvatar,
      teamName: teamName,
      isTeam1: isTeam1,
      text: text,
    );

    setState(() => _isSendingChat = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendChatImage(TeamMatch match, String currentUid, bool isTeam1) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('uploading_chat_image'.tr()), duration: const Duration(seconds: 2)),
    );

    final url = await SupabaseService.uploadFile(
      file: File(picked.path),
      folder: 'match_chat',
      bucket: SupabaseService.bucketUploads,
    );
    if (url != null && mounted) {
      final currentGamer = GamerAuthService().currentGamer;
      final teamName = isTeam1 ? match.team1Name : match.team2Name;
      final senderName = currentGamer?.displayName ?? currentGamer?.username ?? 'Player';

      await _matchService.sendChatMessage(
        matchId: match.matchId,
        senderId: currentUid,
        senderName: senderName,
        senderAvatar: currentGamer?.photoUrl ?? '',
        teamName: teamName,
        isTeam1: isTeam1,
        imageUrl: url,
      );
    }
  }

  void _showRoomCredentialsDialog(TeamMatch match) {
    final roomController = TextEditingController(text: match.customRoomId);
    final passController = TextEditingController(text: match.customRoomPassword);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('update_room_details_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'custom_room_id_label'.tr(),
                labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                filled: true,
                fillColor: const Color(0xFF10141D),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'room_password_label'.tr(),
                labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                filled: true,
                fillColor: const Color(0xFF10141D),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00), foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              await _matchService.updateRoomCredentials(match.matchId, roomController.text, passController.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('room_details_updated_snackbar'.tr()), backgroundColor: const Color(0xFFFF6B00)),
                );
              }
            },
            child: Text('save_and_publish_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFFFB020);
      case 'Accepted':
        return const Color(0xFF00FF88);
      case 'Live':
        return const Color(0xFFFF4655);
      case 'Proof Submitted':
        return const Color(0xFF38BDF8);
      case 'Verified':
        return const Color(0xFF00FF88);
      case 'Disputed':
        return const Color(0xFFFF4655);
      case 'Rejected':
      case 'Cancelled':
        return Colors.grey;
      default:
        return const Color(0xFFFF6B00);
    }
  }

  void _showCancelChallengeDialog(TeamMatch match, String currentUid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655), size: 22),
            const SizedBox(width: 8),
            Text('cancel_challenge_confirm_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'cancel_challenge_confirm_desc'.tr(args: [match.team2Name]),
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('btn_no_back'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _matchService.cancelChallenge(match.matchId, cancelledByUid: currentUid);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('challenge_cancelled_success'.tr()),
                      backgroundColor: const Color(0xFFFF6B00),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('challenge_cancel_failed'.tr()),
                      backgroundColor: const Color(0xFFFF4655),
                    ),
                  );
                }
              }
            },
            child: Text('btn_yes_cancel'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = GamerAuthService().currentUid ?? '';

    return StreamBuilder<TeamMatch?>(
      stream: _matchService.getMatchStream(widget.matchId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0F17),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
          );
        }

        final match = snapshot.data;
        if (match == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0B0F17),
            appBar: AppBar(
              backgroundColor: const Color(0xFF131A29),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('match_room_title'.tr(), style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFFF4655)),
                  const SizedBox(height: 12),
                  Text('match_not_found'.tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
                    onPressed: () => Navigator.pop(context),
                    child: Text('btn_back'.tr(), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        final isTeam1Leader = match.isTeam1Leader(currentUid);
        final isTeam2Leader = match.isTeam2Leader(currentUid);
        final isTeam1Member = match.team1Members.contains(currentUid) || isTeam1Leader;
        final isTeam2Member = match.team2Members.contains(currentUid) || isTeam2Leader;
        final isParticipant = isTeam1Member || isTeam2Member;

        final isConfirmedByMyTeam = isTeam1Member ? match.team1Confirmed : (isTeam2Member ? match.team2Confirmed : false);
        final remaining = _calculateRemaining(match.matchTime);

        return Scaffold(
          backgroundColor: const Color(0xFF0B0F17),
          appBar: AppBar(
            backgroundColor: const Color(0xFF131A29),
            elevation: 2,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${match.team1Name} vs ${match.team2Name}',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Text(
                  '${match.game} • ${match.mode}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(match.status).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(match.status)),
                ),
                child: Center(
                  child: Text(
                    match.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(match.status),
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFF6B00),
              labelColor: const Color(0xFFFF6B00),
              unselectedLabelColor: const Color(0xFF8B949E),
              indicatorWeight: 3,
              tabs: [
                Tab(icon: const Icon(Icons.shield_outlined, size: 18), text: 'tab_match_room'.tr()),
                Tab(icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18), text: 'tab_team_chat'.tr()),
                Tab(icon: const Icon(Icons.camera_alt_outlined, size: 18), text: 'tab_win_proof'.tr()),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildMatchRoomTab(match, currentUid, isTeam1Leader, isTeam2Leader, isTeam1Member, isTeam2Member, remaining, isConfirmedByMyTeam),
              _buildChatTab(match, currentUid, isParticipant, isTeam1Member),
              _buildWinProofTab(match, currentUid, isTeam1Member, isTeam2Member),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatchRoomTab(
    TeamMatch match,
    String currentUid,
    bool isTeam1Leader,
    bool isTeam2Leader,
    bool isTeam1Member,
    bool isTeam2Member,
    Duration remaining,
    bool isConfirmedByMyTeam,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (match.isPending && isTeam2Leader) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB020).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFB020)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notification_important_rounded, color: Color(0xFFFFB020), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'you_got_challenge_title'.tr(),
                        style: const TextStyle(color: Color(0xFFFFB020), fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'challenge_invitation_desc'.tr(args: [match.team1Name, match.team1LeaderName, match.game, match.mode]),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _matchService.rejectChallenge(match.matchId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF4655),
                            side: const BorderSide(color: Color(0xFFFF4655)),
                          ),
                          child: Text('btn_reject'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _matchService.acceptChallenge(match.matchId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF88),
                            foregroundColor: Colors.black,
                          ),
                          child: Text('btn_accept_challenge'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (match.isPending && isTeam1Leader) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB020).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFB020)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFFB020), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'challenge_pending_response'.tr(),
                        style: const TextStyle(color: Color(0xFFFFB020), fontWeight: FontWeight.w900, fontSize: 14.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'challenge_sent_can_cancel_desc'.tr(args: [match.team2Name]),
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancelChallengeDialog(match, currentUid),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF4655),
                        side: const BorderSide(color: Color(0xFFFF4655)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text('cancel_challenge_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2436), Color(0xFF131A29)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.5), width: 1.2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      remaining == Duration.zero ? Icons.play_circle_filled_rounded : Icons.timer_outlined,
                      color: remaining == Duration.zero ? const Color(0xFFFF4655) : const Color(0xFFFF6B00),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      remaining == Duration.zero ? 'match_live_now_banner'.tr() : 'countdown_match_time'.tr(),
                      style: TextStyle(
                        color: remaining == Duration.zero ? const Color(0xFFFF4655) : const Color(0xFFFF6B00),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _formatDuration(remaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${'scheduled_label'.tr()}: ${DateFormat('dd MMM yyyy, hh:mm a').format(match.matchTime)}',
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A3447)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF26334D),
                          border: Border.all(color: const Color(0xFFFF6B00), width: 2),
                          image: match.team1Avatar.isNotEmpty
                              ? DecorationImage(image: NetworkImage(match.team1Avatar), fit: BoxFit.cover)
                              : null,
                        ),
                        child: match.team1Avatar.isEmpty
                            ? const Center(child: Text('⚔️', style: TextStyle(fontSize: 24)))
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        match.team1Name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${'team_leader'.tr()}: ${match.team1LeaderName}',
                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: match.team1Confirmed ? const Color(0xFF00FF88).withOpacity(0.2) : Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          match.team1Confirmed ? 'status_confirmed'.tr() : 'status_not_ready'.tr(),
                          style: TextStyle(
                            color: match.team1Confirmed ? const Color(0xFF00FF88) : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4655).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF4655)),
                  ),
                  child: Text(
                    'versus_vs'.tr(),
                    style: const TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF26334D),
                          border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                          image: match.team2Avatar.isNotEmpty
                              ? DecorationImage(image: NetworkImage(match.team2Avatar), fit: BoxFit.cover)
                              : null,
                        ),
                        child: match.team2Avatar.isEmpty
                            ? const Center(child: Text('🛡️', style: TextStyle(fontSize: 24)))
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        match.team2Name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${'team_leader'.tr()}: ${match.team2LeaderName}',
                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: match.team2Confirmed ? const Color(0xFF00FF88).withOpacity(0.2) : Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          match.team2Confirmed ? 'status_confirmed'.tr() : 'status_not_ready'.tr(),
                          style: TextStyle(
                            color: match.team2Confirmed ? const Color(0xFF00FF88) : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A3447)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vpn_key_rounded, color: Color(0xFFFF6B00), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'custom_room_details_title'.tr(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5),
                        ),
                      ],
                    ),
                    if (isTeam1Leader || isTeam2Leader) ...[
                      InkWell(
                        onTap: () => _showRoomCredentialsDialog(match),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B00).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('edit_room_btn'.tr(), style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (match.customRoomId.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${'room_id_label'.tr()}:', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                            Text(
                              match.customRoomId,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Color(0xFF00FF88), size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: match.customRoomId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('room_id_copied'.tr()), duration: const Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF2A3447), height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${'room_password_label'.tr()}:', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                            Text(
                              match.customRoomPassword.isNotEmpty ? match.customRoomPassword : 'label_none'.tr(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      if (match.customRoomPassword.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Color(0xFF00FF88), size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: match.customRoomPassword));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('room_password_copied'.tr()), duration: const Duration(seconds: 1)),
                            );
                          },
                        ),
                    ],
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'room_credentials_waiting_desc'.tr(),
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if ((isTeam1Member || isTeam2Member) && !isConfirmedByMyTeam) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.black),
                label: Text(
                  'btn_confirm_match_ready'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                onPressed: () async {
                  await _matchService.confirmMatch(match.matchId, isTeam1Member);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('match_confirmed_success'.tr()), backgroundColor: const Color(0xFF00FF88)),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildChatTab(TeamMatch match, String currentUid, bool isParticipant, bool isTeam1) {
    if (!isParticipant) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 48, color: Color(0xFF8B949E)),
              const SizedBox(height: 12),
              Text(
                'private_team_chat_title'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'private_team_chat_desc'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF131A29),
          child: Row(
            children: [
              const Icon(Icons.security_rounded, size: 14, color: Color(0xFF00FF88)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'private_chat_security_note'.tr(),
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                ),
              ),
              InkWell(
                onTap: () => _matchService.confirmMatch(match.matchId, isTeam1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00FF88)),
                  ),
                  child: Text(
                    'confirm_match_btn'.tr(),
                    style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _matchService.getChatMessages(match.matchId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
              }

              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'no_chat_messages_yet'.tr(),
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final data = messages[index];
                  final isMe = data['senderId'] == currentUid;
                  final msgTeam = (data['teamName'] ?? '').toString();
                  final msgSender = (data['senderName'] ?? 'Player').toString();
                  final msgText = (data['text'] ?? data['message'] ?? '').toString();
                  final msgImage = (data['imageUrl'] ?? '').toString();
                  DateTime? timestamp;
                  final rawTs = data['timestamp'] ?? data['created_at'];
                  if (rawTs is DateTime) {
                    timestamp = rawTs;
                  } else if (rawTs is String) {
                    timestamp = DateTime.tryParse(rawTs);
                  } else if (rawTs is int) {
                    timestamp = DateTime.fromMillisecondsSinceEpoch(rawTs);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFF26334D),
                            child: Text(
                              msgSender.isNotEmpty ? msgSender[0].toUpperCase() : 'P',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$msgSender ($msgTeam)',
                                style: TextStyle(
                                  color: isMe ? const Color(0xFFFF6B00) : const Color(0xFF38BDF8),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFFFF6B00).withOpacity(0.2) : const Color(0xFF1B2436),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isMe ? const Color(0xFFFF6B00).withOpacity(0.6) : const Color(0xFF2A3447),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (msgImage.isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: msgImage,
                                          height: 160,
                                          fit: BoxFit.cover,
                                          placeholder: (c, u) => const Center(child: CircularProgressIndicator()),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    if (msgText.isNotEmpty)
                                      Text(
                                        msgText,
                                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                      ),
                                    if (timestamp != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('hh:mm a').format(timestamp),
                                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 9.5),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: const Color(0xFF131A29),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_camera_rounded, color: Color(0xFFFF6B00)),
                  onPressed: () => _handleSendChatImage(match, currentUid, isTeam1),
                ),
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'chat_input_hint'.tr(),
                      hintStyle: const TextStyle(color: Color(0xFF555E6D), fontSize: 13),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: const Color(0xFF1A2234),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _handleSendChat(match, currentUid, isTeam1),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSendingChat
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B00)))
                      : const Icon(Icons.send_rounded, color: Color(0xFFFF6B00)),
                  onPressed: () => _handleSendChat(match, currentUid, isTeam1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: WIN PROOF - FIXED FOR TEAM-SPECIFIC NOTIFICATION
  // ==========================================
  Widget _buildWinProofTab(TeamMatch match, String currentUid, bool isTeam1Member, bool isTeam2Member) {
    final String? myProofUrl = isTeam1Member ? match.team1Proof : match.team2Proof;
    final bool iHaveUploadedProof = myProofUrl != null && myProofUrl.isNotEmpty;

    final bool isMyProofRejectedForMe = iHaveUploadedProof &&
        match.adminNote != null &&
        match.adminNote!.isNotEmpty &&
        !match.isProofSubmitted &&
        !match.isPermanentlyRejected;

    final bool isWaitingForMyReview = iHaveUploadedProof && match.isProofSubmitted;

    final bool canIUploadNow = (isTeam1Member || isTeam2Member) &&
        !match.isVerified &&
        !match.isPermanentlyRejected &&
        (!iHaveUploadedProof || isMyProofRejectedForMe || match.canUploadNewProof);

    final bool isReupload = iHaveUploadedProof && isMyProofRejectedForMe;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'win_proof_tab_heading'.tr(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (match.proofAttempts >= 2 ? const Color(0xFFFF4655) : const Color(0xFFFF6B00)).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: match.proofAttempts >= 2 ? const Color(0xFFFF4655) : const Color(0xFFFF6B00),
                  ),
                ),
                child: Text(
                  'attempts_count_fraction'.tr(args: ['${match.proofAttempts}', '2']),
                  style: TextStyle(
                    color: match.proofAttempts >= 2 ? const Color(0xFFFF4655) : const Color(0xFFFF6B00),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'win_proof_upload_instruction'.tr(),
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
          ),
          const SizedBox(height: 14),

          // 1. Proof Submitted Banner
          if (isWaitingForMyReview) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'proof_submitted_wait_admin'.tr(),
                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 2. Permanently Rejected Banner
          if (iHaveUploadedProof && match.isPermanentlyRejected) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4655).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF4655)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cancel_rounded, color: Color(0xFFFF4655), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'both_proofs_rejected_match_ended'.tr(),
                          style: const TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (match.adminNote != null && match.adminNote!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${'admin_reason_label'.tr()}: ${match.adminNote}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 3. Admin Note / Rejection Banner
          if (isMyProofRejectedForMe) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4655).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF4655)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cancel_outlined, color: Color(0xFFFF4655), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'your_proof_rejected_title'.tr(),
                        style: const TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${'admin_reason_label'.tr()}: ${match.adminNote}',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'reupload_second_chance_hint'.tr(),
                    style: const TextStyle(color: Color(0xFF00FF88), fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Upload Action Button
          if (canIUploadNow) ...[
            if (isWaitingForMyReview) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time_filled_rounded, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'new_proof_under_review'.tr(),
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReupload ? const Color(0xFF00FF88) : const Color(0xFFFF6B00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isUploadingProof
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Icon(isReupload ? Icons.replay_rounded : Icons.upload_file_rounded, color: Colors.black),
                  label: Text(
                    _isUploadingProof
                        ? 'uploading_proof_progress'.tr()
                        : (isReupload
                            ? 'btn_upload_new_proof'.tr()
                            : 'btn_upload_result_screenshot'.tr()),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  onPressed: _isUploadingProof ? null : () => _handleUploadProof(match, isTeam1Member),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ] else if (!match.isVerified && !match.isPermanentlyRejected && (isTeam1Member || isTeam2Member) && !isWaitingForMyReview) ...[
            if (iHaveUploadedProof) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block_rounded, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'proof_limit_exhausted_2_attempts'.tr(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],

          _buildProofCard(
            teamName: match.team1Name,
            claim: match.team1Claim,
            proofUrl: match.team1Proof,
            uploadedAt: match.team1ProofUploadedAt,
            isWinning: match.winnerId == match.team1Id,
          ),
          const SizedBox(height: 16),
          _buildProofCard(
            teamName: match.team2Name,
            claim: match.team2Claim,
            proofUrl: match.team2Proof,
            uploadedAt: match.team2ProofUploadedAt,
            isWinning: match.winnerId == match.team2Id,
          ),
          const SizedBox(height: 20),

          if (match.isVerified) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00FF88)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Color(0xFF00FF88), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'official_admin_verified_winner'.tr(),
                        style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${'winner_team_label'.tr()}: ${match.winnerName}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  if (match.verifiedBy != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${'verified_by_label'.tr()}: ${match.verifiedBy}',
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (match.isDisputed) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4655).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF4655)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('disputed_match_badge'.tr(), style: const TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold)),
                        Text('dispute_submitted_to_admin_note'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProofCard({
    required String teamName,
    required String? claim,
    required String? proofUrl,
    required DateTime? uploadedAt,
    required bool isWinning,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isWinning ? const Color(0xFF00FF88) : const Color(0xFF2A3447)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                teamName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
              ),
              if (claim != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: claim == 'win' ? const Color(0xFF00FF88).withOpacity(0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    claim == 'win' ? 'claimed_win_badge'.tr() : 'claimed_loss_badge'.tr(),
                    style: TextStyle(
                      color: claim == 'win' ? const Color(0xFF00FF88) : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (proofUrl != null && proofUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: proofUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (c, u) => const Center(child: CircularProgressIndicator()),
                errorWidget: (c, u, e) => const Center(child: Icon(Icons.broken_image, color: Colors.white30)),
              ),
            ),
            if (uploadedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                '${'uploaded_at_label'.tr()}: ${DateFormat('dd MMM, hh:mm a').format(uploadedAt)}',
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
              ),
            ],
          ] else ...[
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF10141D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Center(
                child: Text(
                  'no_proof_submitted_yet'.tr(),
                  style: const TextStyle(color: Color(0xFF555E6D), fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
