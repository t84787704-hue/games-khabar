import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../services/supabase_service.dart';
import '../services/team_service.dart';
import '../services/gamer_auth_service.dart';
import '../models/team_model.dart';

class MatchChatScreen extends StatefulWidget {
  final String matchId;
  final String? team1Id;
  final String? team2Id;
  final String? team1Name;
  final String? team2Name;
  final String? myTeamId;

  const MatchChatScreen({
    super.key,
    required this.matchId,
    this.team1Id,
    this.team2Id,
    this.team1Name,
    this.team2Name,
    this.myTeamId,
  });

  @override
  State<MatchChatScreen> createState() => _MatchChatScreenState();
}

class _MatchChatScreenState extends State<MatchChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TeamService _teamService = TeamService();

  String _resolvedTeam1Name = '';
  String _resolvedTeam2Name = '';
  String _resolvedMyTeamId = '';
  bool _isSending = false;

  // Design Theme Palette (Matched to Reference)
  static const Color darkBg = Color(0xFF0A0F1D);
  static const Color cardBg = Color(0xFF131B2E);
  static const Color cardBorder = Color(0xFF1E293B);
  static const Color neonBlue = Color(0xFF1877F2);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _resolvedTeam1Name = widget.team1Name ?? 'Team 1';
    _resolvedTeam2Name = widget.team2Name ?? 'Team 2';
    _resolvedMyTeamId = widget.myTeamId ?? '';
    _loadMatchDetails();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMatchDetails() async {
    try {
      final res = await SupabaseService.client
          .from('active_matches')
          .select('team1_id, team2_id')
          .eq('id', widget.matchId)
          .maybeSingle();

      if (res != null) {
        final t1 = res['team1_id']?.toString() ?? '';
        final t2 = res['team2_id']?.toString() ?? '';

        final t1Data = await _teamService.getTeam(t1);
        final t2Data = await _teamService.getTeam(t2);

        if (mounted) {
          setState(() {
            if (t1Data != null) _resolvedTeam1Name = t1Data.name;
            if (t2Data != null) _resolvedTeam2Name = t2Data.name;
          });
        }
      }
    } catch (e) {
      debugPrint('[MatchChat] Error loading match details: $e');
    }
  }

  Future<void> _sendMessage({required String message, String messageType = 'text'}) async {
    final text = message.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    final myUuid = _resolvedMyTeamId.isNotEmpty ? SupabaseService.toUuid(_resolvedMyTeamId) : null;

    try {
      try {
        await SupabaseService.client.from('match_messages').insert({
          'match_id': widget.matchId,
          if (myUuid != null) 'sender_team_id': myUuid,
          'message': text,
          'message_type': messageType,
        });
      } catch (e) {
        debugPrint('[MatchChat] fallback match_chat: $e');
        await SupabaseService.client.from('match_chat').insert({
          'match_id': widget.matchId,
          'sender_id': myUuid ?? 'team',
          'sender_name': _resolvedTeam1Name,
          'message': text,
          'message_type': messageType,
        });
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint('[MatchChat] Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_message_send_failed'.tr(args: [e.toString()])),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showUidShareDialog() {
    final roomIdController = TextEditingController();
    final passController = TextEditingController();
    String selectedMode = 'TDM 4v4';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: cardBorder)),
          title: Row(
            children: [
              const Text('🔑', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'dialog_share_room_uid_title'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'label_send_room_details'.tr(),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: roomIdController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'label_room_id'.tr(),
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintText: 'e.g. 1234567',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: darkBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'label_password'.tr(),
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintText: 'e.g. 1234',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: darkBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('label_game_mode'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['TDM 4v4', 'Classic Squad', 'Gun Game', 'Sniper Training'].map((m) {
                    final isSel = selectedMode == m;
                    return ChoiceChip(
                      label: Text(m, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: isSel,
                      selectedColor: const Color(0xFFFFD700),
                      backgroundColor: darkBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: isSel ? const Color(0xFFFFD700) : cardBorder),
                      onSelected: (_) => setDialogState(() => selectedMode = m),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr(), style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final rId = roomIdController.text.trim();
                final pass = passController.text.trim();
                if (rId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('err_room_id_mandatory'.tr()), backgroundColor: const Color(0xFFFF4655)),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final formattedMsg = "ROOM ID: $rId | PASS: ${pass.isNotEmpty ? pass : 'None'} | $selectedMode";
                _sendMessage(message: formattedMsg, messageType: 'uid_share');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text('btn_share_kara'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: neonBlue.withOpacity(0.4), width: 1),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opponentName = _resolvedTeam2Name.isNotEmpty ? _resolvedTeam2Name : 'Opponent';

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: neonCyan, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: neonBlue.withOpacity(0.6), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.shield_rounded, color: neonCyan, size: 24),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: neonGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: darkBg, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: neonGreen.withOpacity(0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'PUBG • Online',
                  style: TextStyle(
                    color: neonGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Share Room Credentials',
            icon: const Icon(Icons.vpn_key_rounded, color: Color(0xFFFFD700), size: 22),
            onPressed: _showUidShareDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Messages Stream
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.client
                  .from('match_messages')
                  .stream(primaryKey: ['id'])
                  .eq('match_id', widget.matchId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildFallbackChatStream();
                }

                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: neonCyan));
                }

                final messages = snapshot.data ?? [];
                messages.sort((a, b) {
                  final aD = a['created_at']?.toString() ?? '';
                  final bD = b['created_at']?.toString() ?? '';
                  return aD.compareTo(bD);
                });

                if (messages.isEmpty) {
                  return _buildEmptyChatPlaceholder();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  itemCount: messages.length + 1, // +1 for "Today" pill
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildDateSeparator('Today');
                    }
                    final msg = messages[index - 1];
                    return _buildMessageBubble(msg);
                  },
                );
              },
            ),
          ),

          _buildBottomInputArea(),
        ],
      ),
    );
  }

  Widget _buildFallbackChatStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('match_chat')
          .stream(primaryKey: ['id'])
          .eq('match_id', widget.matchId),
      builder: (context, snap) {
        final messages = snap.data ?? [];
        messages.sort((a, b) {
          final aD = a['created_at']?.toString() ?? '';
          final bD = b['created_at']?.toString() ?? '';
          return aD.compareTo(bD);
        });

        if (messages.isEmpty) return _buildEmptyChatPlaceholder();

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          itemCount: messages.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _buildDateSeparator('Today');
            return _buildMessageBubble(messages[index - 1]);
          },
        );
      },
    );
  }

  Widget _buildEmptyChatPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: cardBorder),
            ),
            child: const Icon(Icons.forum_outlined, color: neonCyan, size: 36),
          ),
          const SizedBox(height: 12),
          const Text(
            'Private Match Room',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'match_empty_chat_desc'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final text = msg['message']?.toString() ?? '';
    final type = (msg['message_type'] ?? 'text').toString();
    final senderTeamId = (msg['sender_team_id'] ?? msg['sender_id'])?.toString() ?? '';
    final createdAtRaw = msg['created_at'];

    final myUuid = _resolvedMyTeamId.isNotEmpty ? SupabaseService.toUuid(_resolvedMyTeamId).toLowerCase() : '';
    final isMe = senderTeamId.toLowerCase() == myUuid || senderTeamId.toLowerCase() == _resolvedMyTeamId.toLowerCase();

    String timeStr = '';
    if (createdAtRaw != null) {
      try {
        final dt = DateTime.parse(createdAtRaw.toString()).toLocal();
        timeStr = DateFormat('hh:mm a').format(dt);
      } catch (_) {}
    }

    final bool isUidShare = type == 'uid_share' || text.toUpperCase().contains('ROOM ID:');

    if (isUidShare) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.12),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.vpn_key_rounded, color: Color(0xFFFFD700), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'match_credentials_title'.tr(),
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('msg_room_info_copied'.tr()),
                        backgroundColor: neonGreen,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.copy_rounded, size: 12, color: Colors.black),
                        const SizedBox(width: 3),
                        Text('btn_copy'.tr(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
            if (timeStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ),
            ],
          ],
        ),
      );
    }

    // Standard Chat Bubble (Left/Right Layout Matching Reference)
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? null : cardBg,
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF1877F2), Color(0xFF00A3FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe ? neonCyan.withOpacity(0.5) : cardBorder,
            width: 1.2,
          ),
          boxShadow: [
            if (isMe)
              BoxShadow(
                color: neonCyan.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                timeStr,
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.white38,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: darkBg,
        border: Border(top: BorderSide(color: cardBorder, width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cardBorder),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                textInputAction: TextInputAction.send,
                onSubmitted: (val) => _sendMessage(message: val),
                decoration: const InputDecoration(
                  hintText: 'Type message...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1877F2), Color(0xFF00E5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: neonCyan.withOpacity(0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: () => _sendMessage(message: _textController.text),
            ),
          ),
        ],
      ),
    );
  }
}
