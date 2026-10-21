import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/supabase_service.dart';
import '../services/gamer_auth_service.dart';
import '../widgets/gamer_avatar.dart';
import 'squad_chat_screen.dart';

class DirectMessagesScreen extends StatefulWidget {
  const DirectMessagesScreen({super.key});

  @override
  State<DirectMessagesScreen> createState() => _DirectMessagesScreenState();
}

class _DirectMessagesScreenState extends State<DirectMessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Futuristic Gaming Colors
  static const Color darkBg = Color(0xFF0A0F1D);
  static const Color cardBg = Color(0xFF131B2E);
  static const Color cardBorder = Color(0xFF1E293B);
  static const Color neonBlue = Color(0xFF00E5FF);
  static const Color neonCyan = Color(0xFF1877F2);
  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getGameBadgeColor(String game) {
    switch (game.toUpperCase()) {
      case 'PUBG':
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: neonBlue, size: 28),
            onPressed: () {
              // Open user search or start new DM
            },
          ),
          const SizedBox(width: 8),
        ],
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
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
          ),

          // Chats List Stream
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
                  final members = List<dynamic>.from(chat['members'] ?? []);
                  if (currentUid.isNotEmpty && !members.contains(currentUid)) {
                    // Filter if members are present and currentUid is not in chat
                    if (members.isNotEmpty) return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final title = (chat['title'] ?? chat['displayName'] ?? '').toString().toLowerCase();
                    return title.contains(_searchQuery.toLowerCase());
                  }
                  return true;
                }).toList();

                if (userChats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mark_chat_unread_outlined,
                            size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        const Text(
                          'No Messages Yet',
                          style: TextStyle(
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

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: userChats.length,
                  itemBuilder: (context, index) {
                    final chat = userChats[index];
                    final chatId = chat['id']?.toString() ?? '';
                    final title = chat['title'] ?? chat['displayName'] ?? 'Gamer';
                    final lastMessage = chat['lastMessage'] ?? 'Tap to chat';
                    final avatarUrl = (chat['avatarUrl'] ?? '').toString();
                    final gameTag = (chat['game'] ?? chat['mode'] ?? 'PUBG').toString();
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
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Avatar with Glowing Online Dot
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
                                            border: Border.all(color: cardBg, width: 2),
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

                                // Chat Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _getGameBadgeColor(gameTag).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              gameTag.toUpperCase(),
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

                                // Timestamp & Unread Badge
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
                                        '2m ago',
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
