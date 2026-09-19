import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/gamer_theme.dart';
import '../models/team_match_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/team_match_service.dart';
import '../services/cloudinary_service.dart';

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
    if (d == Duration.zero) return '00:00:00 (Match Time!)';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _handleUploadProof(TeamMatch match, bool isTeam1) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('میچ کا نتیجہ منتخب کریں', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'کیا آپ کی ٹیم نے یہ مقابلہ جیتا ہے یا آپ ہار رپورٹ کر رہے ہیں؟\nاسکرین شاٹ میں Score اور Win صاف نظر آنا چاہیے۔',
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'loss'),
            child: const Text('Report Loss / Defeat', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, 'win'),
            child: const Text('WE WON! (جیت کا دعویٰ)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == null) return;

    setState(() => _isUploadingProof = true);

    final success = await _matchService.submitProof(
      matchId: match.matchId,
      isTeam1: isTeam1,
      imageFile: File(picked.path),
      claim: confirm,
    );

    setState(() => _isUploadingProof = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ اسکرین شاٹ کامیابی سے اپلوڈ ہو گیا! ایڈمن جائزہ لے گا۔'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اسکرین شاٹ اپلوڈ کرنے میں ناکامی۔ دوبارہ کوشش کریں۔'),
            backgroundColor: Color(0xFFFF4655),
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

    // Auto-scroll chat
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
      const SnackBar(content: Text('Uploading image to chat...'), duration: Duration(seconds: 2)),
    );

    final url = await CloudinaryService.uploadFile(file: File(picked.path), folder: 'match_chat');
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
        title: const Text('Update Room ID & Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Custom Room ID',
                labelStyle: TextStyle(color: Color(0xFF8B949E)),
                filled: true,
                fillColor: Color(0xFF10141D),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Room Password',
                labelStyle: TextStyle(color: Color(0xFF8B949E)),
                filled: true,
                fillColor: Color(0xFF10141D),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00), foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              await _matchService.updateRoomCredentials(match.matchId, roomController.text, passController.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room details updated & Live!'), backgroundColor: Color(0xFFFF6B00)),
                );
              }
            },
            child: const Text('Save & Publish', style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655), size: 22),
            SizedBox(width: 8),
            Text('چیلنج منسوخ (Cancel) کریں؟', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'کیا آپ واقعی ${match.team2Name} کو بھیجا گیا چیلنج واپس لینا چاہتے ہیں؟ اس کے بعد آپ دوبارہ نیا چیلنج بھیج سکیں گے۔',
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('نہیں (Back)', style: TextStyle(color: Colors.grey)),
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
                    const SnackBar(
                      content: Text('چیلنج کامیابی سے Cancel کر دیا گیا!'),
                      backgroundColor: Color(0xFFFF6B00),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('چیلنج منسوخ کرنے میں خرابی ہوئی'),
                      backgroundColor: Color(0xFFFF4655),
                    ),
                  );
                }
              }
            },
            child: const Text('ہاں، Cancel کریں', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<TeamMatch?>(
      stream: _matchService.getMatchStream(widget.matchId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0F17),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
          );
        }

        final match = snapshot.data;
        if (match == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0F17),
            body: Center(child: Text('میچ نہیں ملا', style: TextStyle(color: Colors.white))),
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
              tabs: const [
                Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'Match Room'),
                Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 18), text: 'Team Chat'),
                Tab(icon: Icon(Icons.camera_alt_outlined, size: 18), text: 'Win Proof'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // 1. MATCH ROOM DETAILS & COUNTDOWN
              _buildMatchRoomTab(match, currentUid, isTeam1Leader, isTeam2Leader, isTeam1Member, isTeam2Member, remaining, isConfirmedByMyTeam),

              // 2. TEAM CHAT (Restricted to members of both teams)
              _buildChatTab(match, currentUid, isParticipant, isTeam1Member),

              // 3. WIN PROOF UPLOAD & VERIFICATION
              _buildWinProofTab(match, currentUid, isTeam1Member, isTeam2Member),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 1: Match Room Details & Countdown
  // ==========================================
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
          // Pending Challenge Banner (if user is Team 2 leader and status is Pending)
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
                  const Row(
                    children: [
                      Icon(Icons.notification_important_rounded, color: Color(0xFFFFB020), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'آپ کو چیلنج ملا ہے!',
                        style: TextStyle(color: Color(0xFFFFB020), fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${match.team1Name} کے لیڈر ${match.team1LeaderName} نے آپ کو ${match.game} (${match.mode}) میں چیلنج کیا ہے۔',
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
                          child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          child: const Text('ACCEPT CHALLENGE ✅', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Pending Challenge Banner for Team 1 Leader (Allowing Cancel Challenge)
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
                  const Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, color: Color(0xFFFFB020), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'چیلنج جواب کا منتظر ہے (Pending)',
                        style: TextStyle(color: Color(0xFFFFB020), fontWeight: FontWeight.w900, fontSize: 14.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'آپ نے ${match.team2Name} کو چیلنج بھیجا ہوا ہے۔ اگر آپ اس چیلنج کو واپس لینا چاہتے ہیں تو منسوخ کر سکتے ہیں۔',
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
                      label: const Text('CANCEL CHALLENGE (چیلنج منسوخ کریں)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Countdown Timer Card
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
                      remaining == Duration.zero ? 'MATCH IS LIVE NOW! 🔴' : 'COUNTDOWN TO MATCH TIME',
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
                  'Scheduled: ${DateFormat('dd MMM yyyy, hh:mm a').format(match.matchTime)}',
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // VS Arena Teams Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A3447)),
            ),
            child: Row(
              children: [
                // Team 1
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
                        'Leader: ${match.team1LeaderName}',
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
                          match.team1Confirmed ? 'CONFIRMED ✅' : 'NOT READY',
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

                // Center VS
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4655).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF4655)),
                  ),
                  child: const Text(
                    'VS',
                    style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),

                // Team 2
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
                        'Leader: ${match.team2LeaderName}',
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
                          match.team2Confirmed ? 'CONFIRMED ✅' : 'NOT READY',
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

          // Custom Room Credentials (ID & Password)
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
                    const Row(
                      children: [
                        Icon(Icons.vpn_key_rounded, color: Color(0xFFFF6B00), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'CUSTOM ROOM DETAILS',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5),
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
                          child: const Text('EDIT ROOM', style: TextStyle(color: Color(0xFFFF6B00), fontSize: 10, fontWeight: FontWeight.bold)),
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
                            const Text('Room ID:', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
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
                            const SnackBar(content: Text('Room ID copied!'), duration: Duration(seconds: 1)),
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
                            const Text('Password:', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                            Text(
                              match.customRoomPassword.isNotEmpty ? match.customRoomPassword : '(None)',
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
                              const SnackBar(content: Text('Password copied!'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                    ],
                  ),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'روم ID اور پاسورڈ میچ کے وقت لیڈر کی طرف سے فراہم کیا جائے گا۔',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Team Confirmation Button ("Match Confirmed")
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
                label: const Text(
                  'MATCH CONFIRMED (ہم تیار ہیں)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                onPressed: () async {
                  await _matchService.confirmMatch(match.matchId, isTeam1Member);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('میچ کی تصدیق کر دی گئی!'), backgroundColor: Color(0xFF00FF88)),
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

  // ==========================================
  // TAB 2: Team Chat (Private to both teams)
  // ==========================================
  Widget _buildChatTab(TeamMatch match, String currentUid, bool isParticipant, bool isTeam1) {
    if (!isParticipant) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 48, color: Color(0xFF8B949E)),
              SizedBox(height: 12),
              Text(
                'پرائیویٹ ٹیم چیٹ',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'یہ چیٹ صرف انہی دونوں ٹیموں کے ممبران کے لیے مخصوص ہے جو یہ مقابلہ کھیل رہی ہیں۔',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Chat Header with Match Confirmed indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF131A29),
          child: Row(
            children: [
              const Icon(Icons.security_rounded, size: 14, color: Color(0xFF00FF88)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Private Match Chat • End-to-End Logged for dispute resolution',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                ),
              ),
              // Match Confirmed quick button
              InkWell(
                onTap: () => _matchService.confirmMatch(match.matchId, isTeam1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00FF88)),
                  ),
                  child: const Text(
                    'Confirm Match',
                    style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Chat Message List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _matchService.getChatMessages(match.matchId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'کوئی پیغام نہیں ہے۔ بات چیت کا آغاز کریں!',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final isMe = data['senderId'] == currentUid;
                  final msgTeam = (data['teamName'] ?? '').toString();
                  final msgSender = (data['senderName'] ?? 'Player').toString();
                  final msgText = (data['text'] ?? '').toString();
                  final msgImage = (data['imageUrl'] ?? '').toString();
                  final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

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

        // Chat Input Field
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
                    decoration: const InputDecoration(
                      hintText: 'پیغام یا روم کی تفصیلات لکھیں...',
                      hintStyle: TextStyle(color: Color(0xFF555E6D), fontSize: 13),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Color(0xFF1A2234),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
  // TAB 3: Win Proof Upload & Review
  // ==========================================
  Widget _buildWinProofTab(TeamMatch match, String currentUid, bool isTeam1Member, bool isTeam2Member) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          const Text(
            'جیت کا ثبوت (WIN PROOF)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'میچ ختم ہونے پر اسکرین شاٹ اپلوڈ کریں جس میں Score / Victory صاف نظر آئے۔ ایڈمن جائزہ لے کر تصدیق کرے گا۔',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
          ),
          const SizedBox(height: 16),

          // Upload Proof Action Button
          if (isTeam1Member || isTeam2Member) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isUploadingProof
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.upload_file_rounded, color: Colors.black),
                label: Text(
                  _isUploadingProof ? 'Uploading Proof...' : 'UPLOAD RESULT SCREENSHOT 📸',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                ),
                onPressed: _isUploadingProof ? null : () => _handleUploadProof(match, isTeam1Member),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Team 1 Proof Card
          _buildProofCard(
            teamName: match.team1Name,
            claim: match.team1Claim,
            proofUrl: match.team1Proof,
            uploadedAt: match.team1ProofUploadedAt,
            isWinning: match.winnerId == match.team1Id,
          ),
          const SizedBox(height: 16),

          // Team 2 Proof Card
          _buildProofCard(
            teamName: match.team2Name,
            claim: match.team2Claim,
            proofUrl: match.team2Proof,
            uploadedAt: match.team2ProofUploadedAt,
            isWinning: match.winnerId == match.team2Id,
          ),
          const SizedBox(height: 20),

          // Admin Verdict Status
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
                  const Row(
                    children: [
                      Icon(Icons.emoji_events_rounded, color: Color(0xFF00FF88), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'OFFICIAL ADMIN VERIFIED WINNER',
                        style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'فاتح ٹیم: ${match.winnerName}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  if (match.verifiedBy != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'تصدیق کنندہ: ${match.verifiedBy}',
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
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DISPUTED MATCH ⚠️', style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold)),
                        Text('دونوں ٹیموں کے ثبوت ایڈمن کو بھیج دیے گئے ہیں۔ ایڈمن حتمی فیصلہ کرے گا۔', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                    claim == 'win' ? 'CLAIMED WIN 🏆' : 'CLAIMED LOSS',
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
                'Uploaded: ${DateFormat('dd MMM, hh:mm a').format(uploadedAt)}',
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
              child: const Center(
                child: Text(
                  'ابھی تک کوئی ثبوت جمع نہیں کرایا گیا',
                  style: TextStyle(color: Color(0xFF555E6D), fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
