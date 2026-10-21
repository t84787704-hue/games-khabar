// ===============================================================================
// GAMER CHAT SCREEN — Dark Futuristic Neon Gaming Theme (Matched to Reference)
// File: lib/screens/gamer_chat_screen.dart
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/chat_model.dart';
import '../services/direct_message_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';

class GamerChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhoto;
  final bool otherUserVerified;

  const GamerChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto = '',
    this.otherUserVerified = false,
  });

  @override
  State<GamerChatScreen> createState() => _GamerChatScreenState();
}

class _GamerChatScreenState extends State<GamerChatScreen> {
  final _dmService = DirectMessageService();
  final _authService = GamerAuthService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isSending = false;
  bool _initialLoad = true;
  Set<String> _myAliases = {};
  String _effectiveMyId = '';
  String _effectiveOtherId = '';
  Stream<List<ChatMessage>>? _chatStream;

  // Futuristic Palette
  static const Color darkBg = Color(0xFF0A0F1D);
  static const Color cardBg = Color(0xFF131B2E);
  static const Color cardBorder = Color(0xFF1E293B);
  static const Color neonBlue = Color(0xFF1877F2);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    _effectiveMyId = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    _effectiveOtherId = widget.otherUserId;
    _chatStream = _dmService.getMessagesStream(
      userId1: _effectiveMyId,
      userId2: _effectiveOtherId,
    );
    _initIds();
    _markAsRead();
  }

  Future<void> _initIds() async {
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;

    if (sourceUid.isNotEmpty) {
      final myAliases = await _dmService.getUserAliases(sourceUid);
      final myTableId = await _dmService.resolveToTableId(sourceUid);
      final otherTableId = await _dmService.resolveToTableId(widget.otherUserId);
      if (mounted) {
        setState(() {
          _myAliases = myAliases;
          if (myTableId.isNotEmpty) {
            _effectiveMyId = myTableId;
            _myAliases.add(myTableId);
            _myAliases.add(myTableId.toLowerCase());
          }
          if (otherTableId.isNotEmpty) _effectiveOtherId = otherTableId;
          _chatStream = _dmService.getMessagesStream(
            userId1: _effectiveMyId,
            userId2: _effectiveOtherId,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final myUid = _effectiveMyId.isNotEmpty ? _effectiveMyId : (myGamerUid.isNotEmpty ? myGamerUid : myAuthUid);
    if (myUid.isEmpty) return;
    await _dmService.markAsRead(
      currentUserId: myUid,
      otherUserId: _effectiveOtherId.isNotEmpty ? _effectiveOtherId : widget.otherUserId,
    );
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent + 200;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final myUid = _effectiveMyId.isNotEmpty ? _effectiveMyId : sourceUid;
    if (myUid.isEmpty) return;

    final targetOtherId = _effectiveOtherId.isNotEmpty ? _effectiveOtherId : widget.otherUserId;

    if (_myAliases.any((a) => a.toLowerCase() == targetOtherId.toLowerCase()) ||
        myUid.toLowerCase() == targetOtherId.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('cannot_message_self'.tr()),
          backgroundColor: const Color(0xFFFF4655),
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    _messageController.clear();

    final ok = await _dmService.sendMessage(
      senderId: myUid,
      receiverId: targetOtherId,
      message: text,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (ok) {
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('message_send_failed'.tr()),
          backgroundColor: const Color(0xFFFF4655),
        ),
      );
    }
  }

  String _formatTime(DateTime dt) {
    return DateFormat('hh:mm a').format(dt);
  }

  String _formatDateDivider(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('dd MMMM yyyy').format(dt);
  }

  Widget _buildDatePill(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: neonBlue.withOpacity(0.4), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label,
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
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final myUid = _effectiveMyId.isNotEmpty ? _effectiveMyId : sourceUid;

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: neonCyan, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: neonBlue.withOpacity(0.6), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: widget.otherUserPhoto.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.otherUserPhoto,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: neonCyan),
                              ),
                            ),
                            errorWidget: (_, __, ___) => _buildInitials(widget.otherUserName, 42),
                          )
                        : _buildInitials(widget.otherUserName, 42),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 11,
                    height: 11,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.otherUserName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.otherUserVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: neonCyan, size: 15),
                      ],
                    ],
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
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _initialLoad) {
                  return const Center(
                    child: CircularProgressIndicator(color: neonCyan),
                  );
                }

                final messages = snapshot.data ?? [];
                if (_initialLoad) {
                  _initialLoad = false;
                  _scrollToBottom(animate: false);
                }

                if (messages.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final sLower = m.senderId.toLowerCase();
                    final isMyMsg = _myAliases.any((a) => a.toLowerCase() == sLower) ||
                        sLower == _effectiveMyId.toLowerCase() ||
                        sLower == myUid.toLowerCase() ||
                        sLower == SupabaseService.toUuid(myUid).toLowerCase();

                    bool showDate = false;
                    if (i == 0) {
                      showDate = true;
                    } else {
                      final prev = messages[i - 1];
                      final prevDay = DateTime(prev.createdAt.year,
                          prev.createdAt.month, prev.createdAt.day);
                      final curDay = DateTime(m.createdAt.year,
                          m.createdAt.month, m.createdAt.day);
                      if (prevDay != curDay) showDate = true;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDate) _buildDatePill(_formatDateDivider(m.createdAt)),
                        _buildMessageBubble(m, isMyMsg),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: cardBorder),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: neonCyan,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'say_hi_start_chat'.tr(),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage m, bool isMyMsg) {
    return Align(
      alignment: isMyMsg ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMyMsg ? null : cardBg,
          gradient: isMyMsg
              ? const LinearGradient(
                  colors: [Color(0xFF1877F2), Color(0xFF00A3FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMyMsg ? neonCyan.withOpacity(0.5) : cardBorder,
            width: 1.2,
          ),
          boxShadow: [
            if (isMyMsg)
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
              m.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: isMyMsg ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                _formatTime(m.createdAt),
                style: TextStyle(
                  color: isMyMsg ? Colors.white70 : Colors.white38,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
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
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type message...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(String name, double size) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF1A263D),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: neonCyan,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
