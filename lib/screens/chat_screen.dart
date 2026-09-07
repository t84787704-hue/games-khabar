import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/gamer_theme.dart';
import '../models/squad_post_model.dart';
import '../services/gamer_auth_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/squad_members_bottom_sheet.dart';

class ChatScreen extends StatefulWidget {
  final String postId;
  final SquadPost? squad;

  const ChatScreen({
    super.key,
    required this.postId,
    this.squad,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: GamerTheme.neonGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? GamerAuthService().currentUid;
    if (currentUid == null || currentUid.isEmpty) return;

    _textController.clear();
    setState(() => _isSending = true);

    try {
      final user = await GamerAuthService().getUserProfile(currentUid);
      final senderName = user?.displayName.isNotEmpty == true
          ? user!.displayName
          : (FirebaseAuth.instance.currentUser?.displayName ?? 'Gamer');
      final senderAvatar = user?.photoUrl ?? (FirebaseAuth.instance.currentUser?.photoURL ?? '');

      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.postId);

      await chatRef.collection('messages').add({
        'senderUid': currentUid,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'text': text,
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await chatRef.set({
        'lastMessage': '$senderName: $text',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? GamerAuthService().currentUid ?? '';

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.cardDark,
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: GamerTheme.textWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('chats').doc(widget.postId).snapshots(),
          builder: (context, chatSnap) {
            final chatData = chatSnap.data?.data() as Map<String, dynamic>? ?? {};
            final title = chatData['title'] as String? ??
                (widget.squad?.displayName.isNotEmpty == true
                    ? "${widget.squad!.displayName}'s Squad"
                    : 'Squad Chat');
            final mode = chatData['mode'] as String? ?? widget.squad?.mode ?? 'Classic Squad';
            final inGameUid = chatData['inGameUid'] as String? ?? widget.squad?.inGameUid ?? '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: GamerTheme.textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: GamerTheme.accentCyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: GamerTheme.accentCyan, width: 0.8),
                      ),
                      child: Text(
                        mode,
                        style: const TextStyle(
                          color: GamerTheme.accentCyan,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (inGameUid.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: () => _copyToClipboard(inGameUid, 'Leader BGMI UID'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Leader UID: $inGameUid',
                          style: const TextStyle(color: GamerTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded, size: 11, color: GamerTheme.neonGreen),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          // Squad Members bottom sheet button
          IconButton(
            tooltip: 'Squad Members',
            icon: const Icon(Icons.people_alt_rounded, color: GamerTheme.accentCyan),
            onPressed: () async {
              SquadPost? currentSquad = widget.squad;
              if (currentSquad == null) {
                final doc = await FirebaseFirestore.instance.collection('lfg_posts').doc(widget.postId).get();
                if (doc.exists) {
                  currentSquad = SquadPost.fromFirestore(doc);
                }
              }
              if (currentSquad != null && mounted) {
                SquadMembersBottomSheet.show(context, currentSquad);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.postId)
                    .collection('messages')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: GamerTheme.accentCyan),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.forum_outlined, size: 48, color: GamerTheme.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'Squad chat is ready!\nSay hello to your teammates.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final senderUid = data['senderUid'] as String? ?? '';
                      final senderName = data['senderName'] as String? ?? 'Gamer';
                      final senderAvatar = data['senderAvatar'] as String? ?? '';
                      final text = data['text'] as String? ?? '';
                      final type = data['type'] as String? ?? 'text';
                      final isMe = senderUid == currentUid;
                      final isSystem = type == 'system' || senderUid == 'system';

                      if (isSystem) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: GamerTheme.cardElevated.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: GamerTheme.borderDark),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 14, color: GamerTheme.accentCyan),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    text,
                                    style: const TextStyle(
                                      color: GamerTheme.textMuted,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              GamerAvatar(
                                photoUrl: senderAvatar,
                                displayName: senderName,
                                radius: 14,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? GamerTheme.accentCyan.withOpacity(0.18)
                                      : GamerTheme.cardElevated,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft: Radius.circular(isMe ? 14 : 2),
                                    bottomRight: Radius.circular(isMe ? 2 : 14),
                                  ),
                                  border: Border.all(
                                    color: isMe
                                        ? GamerTheme.accentCyan.withOpacity(0.5)
                                        : GamerTheme.borderDark,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          senderName,
                                          style: const TextStyle(
                                            color: GamerTheme.accentOrange,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      text,
                                      style: const TextStyle(
                                        color: GamerTheme.textWhite,
                                        fontSize: 13.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
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

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: GamerTheme.cardDark,
                border: Border(top: BorderSide(color: GamerTheme.borderDark)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: GamerTheme.bgDark,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: GamerTheme.borderLight.withOpacity(0.4)),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: GamerTheme.textWhite, fontSize: 13.5),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Message squad teammates...',
                          hintStyle: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: GamerTheme.accentCyan,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
