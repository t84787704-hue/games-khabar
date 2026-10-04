import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/team_service.dart';
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
      // 1. Try insert into match_messages
      try {
        await SupabaseService.client.from('match_messages').insert({
          'match_id': widget.matchId,
          if (myUuid != null) 'sender_team_id': myUuid,
          'message': text,
          'message_type': messageType,
        });
      } catch (e) {
        debugPrint('[MatchChat] insert into match_messages error: $e, trying match_chat fallback');
        // Fallback to match_chat if match_messages table does not exist
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
            content: Text('Message bhejne me masla hua: $e'),
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
          backgroundColor: const Color(0xFF131A29),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Text('🔑', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Share Room UID / Pass',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Opponent team ko game room details bhejen:',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: roomIdController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Room ID',
                    labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                    hintText: 'e.g. 1234567',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF0F141E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF2A3447)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                    hintText: 'e.g. 1234',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF0F141E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF2A3447)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Game Mode:', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['TDM 4v4', 'Classic Squad', 'Gun Game', 'Sniper Training'].map((m) {
                    final isSel = selectedMode == m;
                    return ChoiceChip(
                      label: Text(m, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: isSel,
                      selectedColor: const Color(0xFFFFD700),
                      backgroundColor: const Color(0xFF1B2436),
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
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E))),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final rId = roomIdController.text.trim();
                final pass = passController.text.trim();
                if (rId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Room ID daalna lazmi hai!'), backgroundColor: Color(0xFFFF4655)),
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
              label: const Text('Share Karo', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = '$_resolvedTeam1Name  VS  $_resolvedTeam2Name';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A29),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$titleText - Private Room',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              '🔒 Personal Room • UID / Password Share',
              style: TextStyle(
                color: Color(0xFF00FF88),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF10141D),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Color(0xFFFFD700), size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ye chat bilkul private hai. Yahan room ID aur password share karen.',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),

          // Messages Stream
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.client
                  .from('match_messages')
                  .stream(primaryKey: ['id'])
                  .eq('match_id', widget.matchId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  // Fallback to match_chat stream if match_messages table isn't created yet
                  return _buildFallbackChatStream();
                }

                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
                }

                final messages = snapshot.data ?? [];
                // Sort ascending by created_at
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
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg);
                  },
                );
              },
            ),
          ),

          // Bottom Bar: UID Share Button + Chat Input
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
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) => _buildMessageBubble(messages[index]),
        );
      },
    );
  }

  Widget _buildEmptyChatPlaceholder() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F2E),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2A3447)),
                ),
                child: const Text('💬', style: TextStyle(fontSize: 32)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Private Match Room',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Neeche "UID / Password Share Karo" button se credentials share karen ya baat cheet karen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final text = msg['message']?.toString() ?? '';
    final type = (msg['message_type'] ?? 'text').toString();
    final senderTeamId = msg['sender_team_id']?.toString() ?? msg['sender_id']?.toString() ?? '';
    final createdAtRaw = msg['created_at'];

    String timeStr = '';
    if (createdAtRaw != null) {
      try {
        final dt = DateTime.parse(createdAtRaw.toString()).toLocal();
        timeStr = DateFormat('hh:mm a').format(dt);
      } catch (_) {}
    }

    final bool isUidShare = type == 'uid_share' || text.toUpperCase().contains('ROOM ID:');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender team label
          FutureBuilder<TeamModel?>(
            future: senderTeamId.isNotEmpty ? _teamService.getTeam(senderTeamId) : Future.value(null),
            builder: (context, snap) {
              final senderName = snap.data?.name ?? msg['sender_name']?.toString() ?? 'Team';
              return Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  senderName,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              );
            },
          ),

          // Message Card
          if (isUidShare) ...[
            // Highlighted UID / Pass container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2818),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.vpn_key_rounded, color: Color(0xFFFFD700), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'MATCH CREDENTIALS 🔑',
                            style: TextStyle(
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
                            const SnackBar(
                              content: Text('Room info copy ho gayi!'),
                              backgroundColor: Color(0xFF00FF88),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 12, color: Colors.black),
                              SizedBox(width: 3),
                              Text('Copy', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10.5)),
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
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            // Normal message bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161F2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A3447)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(timeStr, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF131A29),
        border: Border(top: BorderSide(color: Color(0xFF2A3447))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Button: 🔑 UID / Password Share Karo
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: _showUidShareDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.key_rounded, size: 16, color: Colors.black),
              label: const Text(
                '🔑 UID / Password Share Karo',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Normal text chat row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (val) => _sendMessage(message: val),
                  decoration: InputDecoration(
                    hintText: 'Message likhein (e.g. Room ready hai? Aa jao)...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F141E),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFF2A3447)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFF2A3447)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFFFF6B00)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B00),
                  shape: BoxShape.circle,
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
        ],
      ),
    );
  }
}
