// ===============================================================================
// EXACT DIFF — Full Adaptive Day & Night Mode Support for GamerChatScreen
// -------------------------------------------------------------------------------
// File: lib/screens/gamer_chat_screen.dart
//
// 1. Linked with ThemeService.themeModeNotifier for live day/night toggle.
// 2. Chat background, AppBar & incoming message bubbles adapt to active theme.
// 3. Date dividers, input bar & text fields synced with ThemeService.
//
// NO OTHER LOGIC, SERVICE OR DATABASE CODE CHANGED — byte-by-byte safe
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import '../services/direct_message_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';

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

  @override
  void initState() {
    super.initState();
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    _effectiveMyId = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    _effectiveOtherId = widget.otherUserId;
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
        const SnackBar(
          content: Text('Aap khud ko message nahi bhej sakte.'),
          backgroundColor: Color(0xFFFF4655),
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
        const SnackBar(
          content: Text('Message send nahi ho saka'),
          backgroundColor: Color(0xFFFF4655),
        ),
      );
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return DateFormat('hh:mm a').format(dt);
    if (diff == 1) return 'Yesterday ${DateFormat('hh:mm a').format(dt)}';
    if (diff < 7) return DateFormat('EEE hh:mm a').format(dt);
    return DateFormat('dd MMM, hh:mm a').format(dt);
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

  @override
  Widget build(BuildContext context) {
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final myUid = _effectiveMyId.isNotEmpty ? _effectiveMyId : sourceUid;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: ThemeService.isDarkMode ? 0 : 1,
            iconTheme: IconThemeData(color: ThemeService.textPrimary),
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: ThemeService.cardSecondary,
                  backgroundImage: widget.otherUserPhoto.isNotEmpty
                      ? CachedNetworkImageProvider(widget.otherUserPhoto)
                      : null,
                  child: widget.otherUserPhoto.isEmpty
                      ? Text(
                          widget.otherUserName.isNotEmpty
                              ? widget.otherUserName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: ThemeService.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.otherUserName,
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.otherUserVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            color: Color(0xFF1877F2), size: 16),
                      ],
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
                  stream: _dmService.getMessagesStream(
                    userId1: _effectiveMyId.isNotEmpty ? _effectiveMyId : myUid,
                    userId2: _effectiveOtherId.isNotEmpty ? _effectiveOtherId : widget.otherUserId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _initialLoad) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF1877F2)),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
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
                            if (showDate)
                              Center(
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ThemeService.cardSecondary,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: ThemeService.border),
                                  ),
                                  child: Text(
                                    _formatDateDivider(m.createdAt),
                                    style: TextStyle(
                                      color: ThemeService.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
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
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: ThemeService.cardSecondary,
              backgroundImage: widget.otherUserPhoto.isNotEmpty
                  ? CachedNetworkImageProvider(widget.otherUserPhoto)
                  : null,
              child: widget.otherUserPhoto.isEmpty
                  ? Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: ThemeService.textSecondary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              widget.otherUserName,
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Say hi to start the conversation',
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage m, bool isMyMsg) {
    final isDark = ThemeService.isDarkMode;

    return Align(
      alignment: isMyMsg ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMyMsg ? const Color(0xFF1877F2) : ThemeService.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMyMsg
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMyMsg
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          border: isMyMsg ? null : Border.all(color: ThemeService.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMyMsg ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              m.message,
              style: TextStyle(
                color: isMyMsg ? Colors.white : ThemeService.textPrimary,
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(m.createdAt),
              style: TextStyle(
                color: isMyMsg
                    ? Colors.white.withOpacity(0.7)
                    : ThemeService.textSecondary,
                fontSize: 10.5,
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
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: ThemeService.card,
        border: Border(top: BorderSide(color: ThemeService.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: ThemeService.cardSecondary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 14),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle:
                      TextStyle(color: ThemeService.textSecondary, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF1877F2),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
