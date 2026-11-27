import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/gamer_user_model.dart';
import '../services/direct_message_service.dart';
import '../services/supabase_service.dart';
import '../services/gamer_auth_service.dart';
import '../widgets/gamer_avatar.dart';
import 'gamer_chat_screen.dart';
import 'squad_chat_screen.dart';

class DirectMessagesScreen extends StatefulWidget {
  const DirectMessagesScreen({super.key});

  @override
  State<DirectMessagesScreen> createState() => _DirectMessagesScreenState();
}

class _DirectMessagesScreenState extends State<DirectMessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DirectMessageService _dmService = DirectMessageService();
  String _searchQuery = '';
  List<GamerUser> _searchedUsers = [];
  bool _searchingUsers = false;
  Timer? _searchDebounce;

  // Local cache for instantly hiding deleted conversations
  final Set<String> _deletedChatIds = {};

  // Futuristic Gaming Colors
  static const Color darkBg = Color(0xFF0A0F1D);
  static const Color cardBg = Color(0xFF131B2E);
  static const Color cardBorder = Color(0xFF1E293B);
  static const Color neonBlue = Color(0xFF00E5FF);
  static const Color neonCyan = Color(0xFF1877F2);
  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _dmService.updateUserPresence(force: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    final trimmed = val.trim();
    setState(() {
      _searchQuery = trimmed;
      if (trimmed.isEmpty) {
        _searchedUsers = [];
        _searchingUsers = false;
      } else {
        _searchingUsers = true;
      }
    });

    _searchDebounce?.cancel();
    if (trimmed.isEmpty) return;

    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      final currentUid = GamerAuthService().currentUid ??
          (SupabaseService.client.auth.currentUser?.id ?? '');
      final users = await _dmService.searchRegisteredUsers(
        trimmed,
        currentUserId: currentUid,
      );
      if (!mounted || _searchQuery != trimmed) return;
      setState(() {
        _searchedUsers = users;
        _searchingUsers = false;
      });
    });
  }

  Future<void> _openDirectChatWithUser(GamerUser u) async {
    final otherTableId = await _dmService.resolveToTableId(u.uid);
    final finalOtherId = otherTableId.isNotEmpty ? otherTableId : u.uid;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamerChatScreen(
          otherUserId: finalOtherId,
          otherUserName: u.displayName.isNotEmpty
              ? u.displayName
              : (u.username.isNotEmpty ? u.username : 'Gamer'),
          otherUserPhoto: u.photoUrl,
          otherUserVerified: u.isVerified,
        ),
      ),
    );
  }

  Color _getGameBadgeColor(String game) {
    switch (game.toUpperCase()) {
      case 'PUBG':
      case 'PUBG MOBILE':
      case 'BGMI':
        return const Color(0xFF1877F2);
      case 'VALORANT':
        return const Color(0xFF8B5CF6);
      case 'FREE FIRE':
        return const Color(0xFFFF5722);
      case 'COD':
        return const Color(0xFFE11D48);
      default:
        return const Color(0xFF00E5FF);
    }
  }

  Future<void> _handleDeleteChat(String chatId, String title) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Color(0xFFFF4655), size: 24),
            SizedBox(width: 8),
            Text(
              'Delete Conversation?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete your conversation with "$title"? All messages in this chat will be permanently removed.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _deletedChatIds.add(chatId);
    });

    try {
      try {
        await SupabaseService.client
            .from('messages')
            .delete()
            .eq('chat_id', chatId);
      } catch (_) {}

      await SupabaseService.client
          .from('chats')
          .delete()
          .eq('id', chatId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation deleted'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DirectMessages] Error deleting chat: $e');
      if (mounted) {
        setState(() {
          _deletedChatIds.remove(chatId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete chat: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  Widget _buildSearchedUserCard(GamerUser u) {
    final displayTitle = u.displayName.trim().isNotEmpty
        ? u.displayName.trim()
        : (u.username.trim().isNotEmpty ? u.username.trim() : 'Gamer');
    final rawGame = u.gameName.trim();
    final gameTag = rawGame.isNotEmpty
        ? (rawGame.toUpperCase().contains('PUBG') ? 'PUBG' : rawGame.toUpperCase())
        : 'PUBG';
    final shortId = u.gameId.trim().isNotEmpty
        ? u.gameId.trim()
        : (u.uid.length > 8 ? u.uid.substring(0, 8) : u.uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDirectChatWithUser(u),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GamerAvatar(
                  photoUrl: u.photoUrl,
                  displayName: displayTitle,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getGameBadgeColor(gameTag).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              gameTag,
                              style: TextStyle(
                                color: _getGameBadgeColor(gameTag),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shortId.isNotEmpty
                            ? '@${u.username} • ID: $shortId'
                            : '@${u.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: neonBlue,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = GamerAuthService().currentUid ??
        (SupabaseService.client.auth.currentUser?.id ?? '');

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: const Text(
          'Direct Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cardBorder),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Colors.white54),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),

          // Chats List Stream + Searched Users
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.client
                  .from('chats')
                  .stream(primaryKey: ['id'])
                  .order('updatedAt', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: neonBlue),
                  );
                }

                final rawChats = snapshot.data ?? [];
                final userChats = rawChats.where((chat) {
                  final chatId = chat['id']?.toString() ?? '';
                  if (_deletedChatIds.contains(chatId)) return false;

                  final members = List<dynamic>.from(chat['members'] ?? []);
                  if (currentUid.isNotEmpty && !members.contains(currentUid)) {
                    if (members.isNotEmpty) return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final title = (chat['title'] ?? chat['displayName'] ?? '').toString().toLowerCase();
                    final lastMsg = (chat['lastMessage'] ?? '').toString().toLowerCase();
                    return title.contains(q) || lastMsg.contains(q) || chatId.toLowerCase().contains(q);
                  }
                  return true;
                }).toList();

                if (userChats.isEmpty &&
                    _searchedUsers.isEmpty &&
                    !_searchingUsers) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mark_chat_unread_outlined,
                            size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No matching players or messages'
                              : 'No Messages Yet',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Start a conversation with squadmates or rivals',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  children: [
                    ...userChats.map((chat) {
                      final chatId = chat['id']?.toString() ?? '';
                      final title = chat['title'] ?? chat['displayName'] ?? 'Gamer';
                      final lastMessage = chat['lastMessage'] ?? 'Tap to chat';
                      final avatarUrl = (chat['avatarUrl'] ?? '').toString();

                      final dynamic rawGame = chat['game'] ?? chat['mode'];
                      final String gameTag =
                          (rawGame != null && rawGame.toString().trim().isNotEmpty)
                              ? rawGame.toString().trim()
                              : '';

                      final unreadCount = (chat['unreadCount'] as num?)?.toInt() ?? 0;
                      final isOnline = chat['isOnline'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder, width: 1.2),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SquadChatScreen(postId: chatId),
                                ),
                              );
                            },
                            onLongPress: () =>
                                _handleDeleteChat(chatId, title.toString()),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      GamerAvatar(
                                        photoUrl: avatarUrl,
                                        displayName: title,
                                        radius: 24,
                                      ),
                                      if (isOnline)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: neonGreen,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: cardBg, width: 2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color:
                                                      neonGreen.withOpacity(0.6),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (gameTag.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _getGameBadgeColor(
                                                          gameTag)
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  gameTag.toUpperCase(),
                                                  style: TextStyle(
                                                    color: _getGameBadgeColor(
                                                        gameTag),
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          lastMessage,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (unreadCount > 0)
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: neonCyan,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '$unreadCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        )
                                      else
                                        const Text(
                                          'now',
                                          style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_searchQuery.isNotEmpty && _searchingUsers)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: neonBlue,
                            ),
                          ),
                        ),
                      ),
                    if (_searchQuery.isNotEmpty && _searchedUsers.isNotEmpty)
                      ..._searchedUsers.map(_buildSearchedUserCard),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
