import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import '../services/direct_message_service.dart';
import '../services/gamer_auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final myUid = _authService.currentUid ?? '';
    if (myUid.isEmpty) return;
    await _dmService.markAsRead(
      currentUserId: myUid,
      otherUserId: widget.otherUserId,
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

    final myUid = _authService.currentUid ?? '';
    if (myUid.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final ok = await _dmService.sendMessage(
      senderId: myUid,
      receiverId: widget.otherUserId,
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
    final myUid = _authService.currentUid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF050505)),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE4E6EB),
              backgroundImage: widget.otherUserPhoto.isNotEmpty
                  ? CachedNetworkImageProvider(widget.otherUserPhoto)
                  : null,
              child: widget.otherUserPhoto.isEmpty
                  ? Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF65676B),
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
                      style: const TextStyle(
                        color: Color(0xFF050505),
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
                userId1: myUid,
                userId2: widget.otherUserId,
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
                    final isMyMsg = m.senderId == SupabaseService.toUuid(myUid) ||
                        m.senderId == myUid;

                    // Date divider
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
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE4E6EB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDateDivider(m.createdAt),
                                style: const TextStyle(
                                  color: Color(0xFF65676B),
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
              backgroundColor: const Color(0xFFE4E6EB),
              backgroundImage: widget.otherUserPhoto.isNotEmpty
                  ? CachedNetworkImageProvider(widget.otherUserPhoto)
                  : null,
              child: widget.otherUserPhoto.isEmpty
                  ? Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.b