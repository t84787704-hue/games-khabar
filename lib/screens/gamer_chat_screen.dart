// ===============================================================================
// GAMER CHAT SCREEN — Adaptive Day/Night Theme with Dynamic Online Status & Delete
// File: lib/screens/gamer_chat_screen.dart
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
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
  bool _isOtherUserOnline = false;
  String _otherUserGame = '';
  Set<String> _myAliases = {};
  String _effectiveMyId = '';
  String _effectiveOtherId = '';
  Stream<List<ChatMessage>>? _chatStream;

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
    _fetchOtherUserStatus();
    _markAsRead();
  }

  Future<void> _fetchOtherUserStatus() async {
    try {
      final res = await SupabaseService.client
          .from('gamers')
          .select('is_online, primary_game, last_seen')
          .or('id.eq.${widget.otherUserId},uid.eq.${widget.otherUserId}')
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _isOtherUserOnline = res['is_online'] == true;
          _otherUserGame = (res['primary_game'] ?? '').toString();
        });
      }
    } catch (_) {}
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

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Color(0xFFFF4655)),
            const SizedBox(width: 8),
            Text(
              'Delete Message?',
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final msgId = message.id;
      bool deleted = false;

      // 1. Try deleting from direct_messages table
      try {
        await SupabaseService.client
            .from('direct_messages')
            .delete()
            .eq('id', msgId);
        deleted = true;
      } catch (_) {}

      // 2. Fallback to messages table if needed
      if (!deleted) {
        try {
          await SupabaseService.client
              .from('messages')
              .delete()
              .eq('id', msgId);
          deleted = true;
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: Color(0xFFFF4655),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[GamerChatScreen] Delete message error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')),
        );
      }
    }
  }

  void _showMessageOptions(ChatMessage m, bool isMyMsg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeService.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeService.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: neonCyan),
              title: Text('Copy Text', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: m.message));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard!'),
                    backgroundColor: neonBlue,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            if (isMyMsg)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4655)),
                title: const Text('Delete Message', style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(m);
                },
              ),
          ],
        ),
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeService.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(ThemeService.isDarkMode ? 0.3 : 0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: ThemeService.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
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

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: ThemeService.textPrimary, size: 22),
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
                        color: ThemeService.cardSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ThemeService.border, width: 1.2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: widget.otherUserPhoto.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.otherUserPhoto,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: neonCyan),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => _buildInitials(widget.otherUserName, 40),
                              )
                            : _buildInitials(widget.otherUserName, 40),
                      ),
                    ),
                    if (_isOtherUserOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: neonGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: ThemeService.card, width: 2),
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
                              style: TextStyle(
                                color: ThemeService.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.otherUserVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: neonCyan, size: 14),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isOtherUserOnline
                            ? (_otherUserGame.isNotEmpty ? '$_otherUserGame • Online' : 'Online')
                            : (_otherUserGame.isNotEmpty ? '$_otherUserGame • Offline' : 'Offline'),
                        style: TextStyle(
                          color: _isOtherUserOnline ? neonGreen : ThemeService.textSecondary,
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThemeService.card,
                shape: BoxShape.circle,
                border: Border.all(color: ThemeService.border),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 46,
                color: neonCyan,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.otherUserName,
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'say_hi_start_chat'.tr(),
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage m, bool isMyMsg) {
    return Align(
      alignment: isMyMsg ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(m, isMyMsg),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMyMsg ? null : ThemeService.card,
            gradient: isMyMsg
                ? const LinearGradient(
                    colors: [Color(0xFF1877F2), Color(0xFF00A3FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMyMsg ? neonCyan.withOpacity(0.5) : ThemeService.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isMyMsg
                    ? neonCyan.withOpacity(0.18)
                    : Colors.black.withOpacity(ThemeService.isDarkMode ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.message,
                style: TextStyle(
                  color: isMyMsg ? Colors.white : ThemeService.textPrimary,
                  fontSize: 13.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: isMyMsg ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(
                  _formatTime(m.createdAt),
                  style: TextStyle(
                    color: isMyMsg ? Colors.white70 : ThemeService.textSecondary.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
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
      decoration: BoxDecoration(
        color: ThemeService.bg,
        border: Border(top: BorderSide(color: ThemeService.border, width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: ThemeService.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: ThemeService.border),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 13.5),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type message...',
                  hintStyle: TextStyle(color: ThemeService.textSecondary.withOpacity(0.6), fontSize: 13),
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
      color: ThemeService.cardSecondary,
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
