import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/chat_model.dart';
import '../models/gamer_user_model.dart';
import '../services/direct_message_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import 'gamer_chat_screen.dart';

class GamerMessagesScreen extends StatefulWidget {
  const GamerMessagesScreen({super.key});

  @override
  State<GamerMessagesScreen> createState() => _GamerMessagesScreenState();
}

class _GamerMessagesScreenState extends State<GamerMessagesScreen> {
  final _dmService = DirectMessageService();
  final _authService = GamerAuthService();

  List<ChatConversation> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    final uid = _authService.currentUid ?? '';
    final list = await _dmService.getConversations(uid);
    if (!mounted) return;
    setState(() {
      _conversations = list;
      _loading = false;
    });
  }

  Future<void> _openUserSearch() async {
    final selectedUser = await showModalBottomSheet<GamerUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _UserSearchSheet(),
    );

    if (selectedUser != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GamerChatScreen(
            otherUserId: selectedUser.uid,
            otherUserName: selectedUser.displayName,
            otherUserPhoto: selectedUser.photoUrl,
            otherUserVerified: selectedUser.isVerified,
          ),
        ),
      );
      _loadConversations();
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('d MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Color(0xFF1877F2),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Color(0xFF1877F2)),
            tooltip: 'New Message',
            onPressed: _openUserSearch,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1877F2)))
          : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFF1877F2),
                  onRefresh: _loadConversations,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFE4E6EB)),
                    itemBuilder: (context, i) {
                      final c = _conversations[i];
                      return _buildConversationTile(c);
                    },
                  ),
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
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFE7F3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 56,
                color: Color(0xFF1877F2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Messages Yet',
              style: TextStyle(
                color: Color(0xFF050505),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a conversation with other gamers!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF65676B), fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openUserSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.edit_square, size: 18),
              label: const Text(
                'New Message',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(ChatConversation c) {
    return ListTile(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GamerChatScreen(
              otherUserId: c.otherUserId,
              otherUserName: c.otherUserName,
              otherUserPhoto: c.otherUserPhoto,
              otherUserVerified: c.isVerified,
            ),
          ),
        );
        _loadConversations();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE4E6EB),
        ),
        child: ClipOval(
          child: c.otherUserPhoto.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: c.otherUserPhoto,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF1877F2)),
                    ),
                  ),
                  errorWidget: (_, __, ___) => _buildInitials(
                      c.otherUserName, 52),
                )
              : _buildInitials(c.otherUserName, 52),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              c.otherUserName,
              style: TextStyle(
                color: const Color(0xFF050505),
                fontSize: 15,
                fontWeight:
                    c.unreadCount > 0 ? FontWeight.w900 : FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (c.isVerified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, color: Color(0xFF1877F2), size: 14),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          c.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: c.unreadCount > 0
                ? const Color(0xFF050505)
                : const Color(0xFF65676B),
            fontSize: 13,
            fontWeight:
                c.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(c.lastMessageTime),
            style: TextStyle(
              color: c.unreadCount > 0
                  ? const Color(0xFF1877F2)
                  : const Color(0xFF65676B),
              fontSize: 11.5,
              fontWeight:
                  c.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (c.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1877F2),
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                '${c.unreadCount}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInitials(String name, double size) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF1877F2),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ============================================
// USER SEARCH SHEET (for starting new chat)
// ============================================
class _UserSearchSheet extends StatefulWidget {
  const _UserSearchSheet();

  @override
  State<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<_UserSearchSheet> {
  final _controller = TextEditingController();
  final _socialService = GamerSocialService();
  List<GamerUser> _results = [];
  bool _searching = false;
  String _query = '';

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _query = q;
    });
    final results = await _socialService.searchUsers(q);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFCED0D4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.person_search,
                    color: Color(0xFF1877F2), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'New Message',
                    style: TextStyle(
                      color: Color(0xFF050505),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Color(0xFF65676B), size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search users by name or @username...',
                  hintStyle:
                      TextStyle(color: Color(0xFF65676B), fontSize: 13),
                  prefixIcon: Icon(Icons.search,
                      color: Color(0xFF65676B), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: _search,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _searching
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF1877F2)))
                : _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _query.isEmpty
                                ? 'Type to search users'
                                : 'No users found',
                            style: const TextStyle(
                                color: Color(0xFF65676B), fontSize: 14),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final u = _results[i];
                          return ListTile(
                            onTap: () => Navigator.pop(context, u),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFE4E6EB),
                              backgroundImage: u.photoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(u.photoUrl)
                                  : null,
                              child: u.photoUrl.isEmpty
                                  ? Text(
                                      u.displayName.isNotEmpty
                                          ? u.displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    u.displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF050505)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (u.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified,
                                      color: Color(0xFF1877F2), size: 14),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '@${u.username}',
                              style: const TextStyle(
                                  color: Color(0xFF65676B), fontSize: 12),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}