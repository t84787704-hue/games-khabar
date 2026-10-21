// ===============================================================================
// GAMER MESSAGES SCREEN — Dark Futuristic Neon Gaming Theme (Matched to Reference)
// File: lib/screens/gamer_messages_screen.dart
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../constants/gamer_theme.dart';
import '../models/chat_model.dart';
import '../models/gamer_user_model.dart';
import '../services/direct_message_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../services/theme_service.dart';
import 'gamer_chat_screen.dart';

class GamerMessagesScreen extends StatefulWidget {
  const GamerMessagesScreen({super.key});

  @override
  State<GamerMessagesScreen> createState() => _GamerMessagesScreenState();
}

class _GamerMessagesScreenState extends State<GamerMessagesScreen> {
  final _dmService = DirectMessageService();
  final _authService = GamerAuthService();
  final TextEditingController _searchController = TextEditingController();

  List<ChatConversation> _conversations = [];
  bool _loading = true;
  String _searchQuery = '';

  // Futuristic Neon Palette (Exact match to sample screenshot)
  static const Color darkBg = Color(0xFF0A0F1D);
  static const Color cardBg = Color(0xFF131B2E);
  static const Color cardBorder = Color(0xFF1E293B);
  static const Color neonBlue = Color(0xFF1877F2);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final effectiveUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final canonicalId = await _dmService.resolveToTableId(effectiveUid);
    final list = await _dmService.getConversations(
      canonicalId.isNotEmpty ? canonicalId : effectiveUid,
    );
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
      final otherTableId = await _dmService.resolveToTableId(selectedUser.uid);
      final finalOtherId =
          otherTableId.isNotEmpty ? otherTableId : selectedUser.uid;

      final myAuthUid = _authService.currentUid ?? '';
      final myGamerUid = _authService.currentGamer?.uid ?? '';
      final effectiveUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
      final myAliases = await _dmService.getUserAliases(effectiveUid);

      if (myAliases.any((a) => a.toLowerCase() == finalOtherId.toLowerCase())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('cannot_message_self'.tr())),
          );
        }
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GamerChatScreen(
            otherUserId: finalOtherId,
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
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
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
    final filteredList = _conversations.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.otherUserName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
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
            icon: const Icon(Icons.edit_note_rounded, color: neonCyan, size: 28),
            tooltip: 'new_message'.tr(),
            onPressed: _openUserSearch,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Messages Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cardBorder, width: 1.2),
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

          // Conversation List / Loading / Empty
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: neonCyan),
                  )
                : filteredList.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: neonCyan,
                        backgroundColor: cardBg,
                        onRefresh: _loadConversations,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: filteredList.length,
                          itemBuilder: (context, i) {
                            final c = filteredList[i];
                            return _buildConversationCard(c);
                          },
                        ),
                      ),
          ),
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
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: cardBorder),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 50,
                color: neonCyan,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'no_messages_yet'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'start_conversation_desc'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _openUserSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: neonBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.edit_square, size: 18),
              label: Text(
                'new_message'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationCard(ChatConversation c) {
    final gameTag = 'PUBG'; // Default ya dynamically model se pass kiya ja sakta hai
    final gameColor = _getGameBadgeColor(gameTag);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.unreadCount > 0 ? neonBlue.withOpacity(0.4) : cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar with Neon Glow + Online Dot (Exact Match to Design)
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: darkBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: c.otherUserPhoto.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: c.otherUserPhoto,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: neonCyan,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => _buildInitials(c.otherUserName, 50),
                              )
                            : _buildInitials(c.otherUserName, 50),
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

                // Name, Game Badge, Last Message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.otherUserName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: gameColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              gameTag,
                              style: TextStyle(
                                color: gameColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.lastMessage.isNotEmpty ? c.lastMessage : 'Tap to chat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.unreadCount > 0 ? Colors.white : Colors.white60,
                          fontSize: 13,
                          fontWeight: c.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                // Timestamp & Glowing Unread Badge (Right Side)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(c.lastMessageTime),
                      style: TextStyle(
                        color: c.unreadCount > 0 ? neonCyan : Colors.white38,
                        fontSize: 11,
                        fontWeight: c.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (c.unreadCount > 0) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: neonBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: neonBlue.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          '${c.unreadCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
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

// ============================================
// USER SEARCH SHEET (Dark Gaming Theme)
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

  static const Color darkBg = Color(0xFF0A0F1D);
  static const Color cardBg = Color(0xFF131B2E);
  static const Color cardBorder = Color(0xFF1E293B);
  static const Color neonCyan = Color(0xFF00E5FF);

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
    final myAuthUid = GamerAuthService().currentUid ?? '';
    final myGamerUid = GamerAuthService().currentGamer?.uid ?? '';
    final effectiveMyUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final myAliases = await DirectMessageService().getUserAliases(effectiveMyUid);
    final filtered = results.where((u) {
      final uId = u.uid.toLowerCase();
      return !myAliases.any((a) => a.toLowerCase() == uId);
    }).toList();
    setState(() {
      _results = filtered;
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
        color: cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.person_search, color: neonCyan, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'new_message'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: darkBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cardBorder),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'search_users_hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: _search,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _searching
                ? const Center(
                    child: CircularProgressIndicator(color: neonCyan),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _query.isEmpty
                                ? 'type_to_search_users'.tr()
                                : 'no_users_found'.tr(),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
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
                              backgroundColor: darkBg,
                              backgroundImage: u.photoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(u.photoUrl)
                                  : null,
                              child: u.photoUrl.isEmpty
                                  ? Text(
                                      u.displayName.isNotEmpty
                                          ? u.displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: neonCyan,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (u.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: neonCyan, size: 14),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '@${u.username}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
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
