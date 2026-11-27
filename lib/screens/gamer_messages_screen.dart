// ===============================================================================
// GAMER MESSAGES SCREEN — Adaptive Day/Night Theme with Dynamic Presence & Search
// File: lib/screens/gamer_messages_screen.dart
// ===============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/chat_model.dart';
import '../models/gamer_user_model.dart';
import '../services/direct_message_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import 'gamer_chat_screen.dart';

class GamerMessagesScreen extends StatefulWidget {
  const GamerMessagesScreen({super.key});

  @override
  State<GamerMessagesScreen> createState() => _GamerMessagesScreenState();
}

class _GamerMessagesScreenState extends State<GamerMessagesScreen>
    with WidgetsBindingObserver {
  final _dmService = DirectMessageService();
  final _authService = GamerAuthService();
  final TextEditingController _searchController = TextEditingController();

  List<ChatConversation> _conversations = [];
  List<GamerUser> _searchedUsers = [];
  bool _loading = true;
  bool _searchingUsers = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
  Timer? _presenceTimer;

  static const Color neonBlue = Color(0xFF1877F2);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dmService.updateUserPresence(force: true);
    _loadConversations();
    _presenceTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _dmService.updateUserPresence();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _dmService.updateUserPresence(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _presenceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final effectiveUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    unawaited(_dmService.updateUserPresence(userId: effectiveUid));
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

  void _onSearchChanged(String rawVal) {
    final trimmed = rawVal.trim();
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
      final myAuthUid = _authService.currentUid ?? '';
      final myGamerUid = _authService.currentGamer?.uid ?? '';
      final effectiveUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
      final users = await _dmService.searchRegisteredUsers(
        trimmed,
        currentUserId: effectiveUid,
      );
      if (!mounted || _searchQuery != trimmed) return;
      setState(() {
        _searchedUsers = users;
        _searchingUsers = false;
      });
    });
  }

  Future<void> _openChatWithUser(GamerUser user) async {
    final otherTableId = await _dmService.resolveToTableId(user.uid);
    final finalOtherId = otherTableId.isNotEmpty ? otherTableId : user.uid;

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

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamerChatScreen(
          otherUserId: finalOtherId,
          otherUserName: user.displayName.isNotEmpty
              ? user.displayName
              : (user.username.isNotEmpty ? user.username : 'Gamer'),
          otherUserPhoto: user.photoUrl,
          otherUserVerified: user.isVerified,
        ),
      ),
    );
    _loadConversations();
  }

  Future<void> _deleteConversation(ChatConversation c) async {
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
              'Delete Conversation?',
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all messages with ${c.otherUserName}?',
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
      final myAuthUid = _authService.currentUid ?? '';
      final myGamerUid = _authService.currentGamer?.uid ?? '';
      final effectiveUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
      final myTableId = await _dmService.resolveToTableId(effectiveUid);
      final otherTableId = await _dmService.resolveToTableId(c.otherUserId);

      final myAliases = await _dmService.getUserAliases(effectiveUid);
      final otherAliases = await _dmService.getUserAliases(c.otherUserId);

      final Set<String> allMyIds = {
        ...myAliases,
        effectiveUid,
        myAuthUid,
        myGamerUid,
        myTableId,
      }..removeWhere((id) => id.isEmpty);

      final Set<String> allOtherIds = {
        ...otherAliases,
        c.otherUserId,
        otherTableId,
      }..removeWhere((id) => id.isEmpty);

      for (final mId in allMyIds) {
        for (final oId in allOtherIds) {
          await SupabaseService.client
              .from('direct_messages')
              .delete()
              .eq('sender_id', mId)
              .eq('receiver_id', oId);

          await SupabaseService.client
              .from('direct_messages')
              .delete()
              .eq('sender_id', oId)
              .eq('receiver_id', mId);
        }
      }

      setState(() {
        _conversations.removeWhere((item) => item.otherUserId == c.otherUserId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation with ${c.otherUserName} deleted'),
            backgroundColor: const Color(0xFFFF4655),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[GamerMessagesScreen] Error deleting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting chat: $e')),
        );
      }
    }
  }

  Future<void> _openUserSearch() async {
    final selectedUser = await showModalBottomSheet<GamerUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _UserSearchSheet(),
    );

    if (selectedUser != null && mounted) {
      await _openChatWithUser(selectedUser);
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

  String _formatShortId(GamerUser u) {
    if (u.gameId.trim().isNotEmpty) {
      return u.gameId.trim();
    }
    final raw = u.uid.trim();
    if (raw.length > 8) {
      return raw.substring(0, 8);
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final qLower = _searchQuery.startsWith('@')
        ? _searchQuery.substring(1).trim().toLowerCase()
        : _searchQuery.toLowerCase();

    final filteredConversations = _conversations.where((c) {
      if (qLower.isEmpty) return true;
      return c.otherUserName.toLowerCase().contains(qLower) ||
          c.otherUsername.toLowerCase().contains(qLower) ||
          c.otherUserId.toLowerCase().contains(qLower) ||
          c.otherUserGameId.toLowerCase().contains(qLower) ||
          c.lastMessage.toLowerCase().contains(qLower);
    }).toList();

    final existingConversationUserIds = filteredConversations
        .map((c) => c.otherUserId.toLowerCase())
        .toSet();

    final unmatchedUsers = qLower.isEmpty
        ? <GamerUser>[]
        : _searchedUsers
            .where((u) =>
                !existingConversationUserIds.contains(u.uid.toLowerCase()))
            .toList();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 16,
            title: Text(
              'Direct Messages',
              style: TextStyle(
                color: ThemeService.textPrimary,
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
              // Search Messages & Registered Users Input Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: ThemeService.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ThemeService.border, width: 1.2),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: ThemeService.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search messages...',
                      hintStyle: TextStyle(
                        color: ThemeService.textSecondary.withOpacity(0.6),
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: ThemeService.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 18,
                                color: ThemeService.textSecondary,
                              ),
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

              // Conversation List & User Search Results
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: neonCyan),
                      )
                    : (filteredConversations.isEmpty &&
                            unmatchedUsers.isEmpty &&
                            !_searchingUsers)
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            color: neonCyan,
                            backgroundColor: ThemeService.card,
                            onRefresh: _loadConversations,
                            child: ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              children: [
                                ...filteredConversations.map(_buildConversationCard),
                                if (_searchQuery.isNotEmpty && _searchingUsers)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: neonCyan,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_searchQuery.isNotEmpty &&
                                    unmatchedUsers.isNotEmpty) ...[
                                  if (filteredConversations.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 8,
                                        left: 4,
                                      ),
                                      child: Text(
                                        'PLAYERS',
                                        style: TextStyle(
                                          color: ThemeService.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ...unmatchedUsers.map(_buildSearchedUserCard),
                                ],
                              ],
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: ThemeService.card,
                shape: BoxShape.circle,
                border: Border.all(color: ThemeService.border),
              ),
              child: Icon(
                isSearching
                    ? Icons.person_search_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 50,
                color: neonCyan,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isSearching ? 'No players or messages found' : 'no_messages_yet'.tr(),
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'Try searching by username, display name, or user ID'
                  : 'start_conversation_desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
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

  Widget _buildSearchedUserCard(GamerUser u) {
    final rawGame = u.gameName.trim();
    final gameTag = rawGame.isNotEmpty
        ? (rawGame.toUpperCase().contains('PUBG') ? 'PUBG' : rawGame.toUpperCase())
        : 'PUBG';
    final gameColor = _getGameBadgeColor(gameTag);
    final isDark = ThemeService.isDarkMode;
    final displayTitle = u.displayName.trim().isNotEmpty
        ? u.displayName.trim()
        : (u.username.trim().isNotEmpty ? u.username.trim() : 'Gamer');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeService.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openChatWithUser(u),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: ThemeService.cardSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ThemeService.border, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildPartnerAvatar(u.photoUrl, displayTitle, 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayTitle,
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (u.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: neonCyan, size: 14),
                      ],
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: gameColor.withOpacity(0.18),
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
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: neonBlue.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: neonCyan.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          color: neonCyan, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Message',
                        style: TextStyle(
                          color: neonCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(ChatConversation c) {
    final gameTag = c.otherUserGame.trim().isNotEmpty
        ? c.otherUserGame.trim().toUpperCase()
        : 'PUBG';
    final gameColor = _getGameBadgeColor(gameTag);
    final isDark = ThemeService.isDarkMode;

    return Dismissible(
      key: Key(c.otherUserId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deleteConversation(c);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4655),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.unreadCount > 0 ? neonBlue.withOpacity(0.5) : ThemeService.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
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
            onLongPress: () => _deleteConversation(c),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: ThemeService.cardSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ThemeService.border, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildPartnerAvatar(
                            c.otherUserPhoto,
                            c.otherUserName,
                            50,
                          ),
                        ),
                      ),
                      if (c.isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
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
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.otherUserName,
                                style: TextStyle(
                                  color: ThemeService.textPrimary,
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
                                color: gameColor.withOpacity(0.18),
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
                            color: c.unreadCount > 0
                                ? ThemeService.textPrimary
                                : ThemeService.textSecondary,
                            fontSize: 13,
                            fontWeight:
                                c.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(c.lastMessageTime),
                        style: TextStyle(
                          color: c.unreadCount > 0
                              ? neonCyan
                              : ThemeService.textSecondary.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight:
                              c.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
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
      ),
    );
  }

  Widget _buildPartnerAvatar(String rawPhotoUrl, String name, double size) {
    return _renderUserAvatarWidget(
      rawPhotoUrl: rawPhotoUrl,
      name: name,
      size: size,
    );
  }

  Widget _buildInitials(String name, double size) {
    return _buildAvatarInitialsWidget(name, size);
  }
}

Widget _renderUserAvatarWidget({
  required String rawPhotoUrl,
  required String name,
  required double size,
}) {
  final normalized = DirectMessageService.normalizeAvatarUrl(rawPhotoUrl);
  if (normalized.isEmpty) {
    return _buildAvatarInitialsWidget(name, size);
  }

  if (normalized.startsWith('preset:')) {
    final presetId = normalized.replaceFirst('preset:', '').trim().toLowerCase();
    IconData iconData = Icons.sports_esports_rounded;
    List<Color> gradientColors = const [Color(0xFF1E3A8A), Color(0xFF00E5FF)];

    switch (presetId) {
      case 'helmet':
        iconData = Icons.sports_motorsports_rounded;
        gradientColors = const [Color(0xFF1877F2), Color(0xFF00E5FF)];
        break;
      case 'controller':
      case 'skull':
        iconData = Icons.gamepad_rounded;
        gradientColors = const [Color(0xFF6D28D9), Color(0xFFEC4899)];
        break;
      case 'ninja':
      case 'shield':
        iconData = Icons.shield_rounded;
        gradientColors = const [Color(0xFF047857), Color(0xFF10B981)];
        break;
      case 'crown':
      case 'trophy':
        iconData = Icons.emoji_events_rounded;
        gradientColors = const [Color(0xFFB45309), Color(0xFFFBBF24)];
        break;
      case 'crosshair':
        iconData = Icons.gps_fixed_rounded;
        gradientColors = const [Color(0xFFBE123C), Color(0xFFFB7185)];
        break;
      default:
        iconData = Icons.sports_esports_rounded;
        gradientColors = const [Color(0xFF1E3A8A), Color(0xFF00E5FF)];
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          color: Colors.white,
          size: size * 0.52,
        ),
      ),
    );
  }

  if (normalized.startsWith('data:image')) {
    try {
      final commaIdx = normalized.indexOf(',');
      if (commaIdx != -1) {
        final b64 = normalized.substring(commaIdx + 1).trim();
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAvatarInitialsWidget(name, size),
        );
      }
    } catch (_) {
      return _buildAvatarInitialsWidget(name, size);
    }
  }

  if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
    return CachedNetworkImage(
      imageUrl: normalized,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => _buildAvatarInitialsWidget(name, size),
      errorWidget: (_, __, ___) => _buildAvatarInitialsWidget(name, size),
    );
  }

  return _buildAvatarInitialsWidget(name, size);
}

Widget _buildAvatarInitialsWidget(String name, double size) {
  final trimmed = name.trim();
  final initials = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  return Container(
    width: size,
    height: size,
    color: ThemeService.cardSecondary,
    child: Center(
      child: Text(
        initials,
        style: TextStyle(
          color: const Color(0xFF00E5FF),
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

// ============================================
// USER SEARCH SHEET (Adaptive Theme)
// ============================================
class _UserSearchSheet extends StatefulWidget {
  const _UserSearchSheet();

  @override
  State<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<_UserSearchSheet> {
  final _controller = TextEditingController();
  final _dmService = DirectMessageService();
  final _socialService = GamerSocialService();
  List<GamerUser> _results = [];
  bool _searching = false;
  String _query = '';

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
    final myAuthUid = GamerAuthService().currentUid ?? '';
    final myGamerUid = GamerAuthService().currentGamer?.uid ?? '';
    final effectiveMyUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;

    List<GamerUser> results = await _dmService.searchRegisteredUsers(
      q,
      currentUserId: effectiveMyUid,
    );
    if (results.isEmpty) {
      results = await _socialService.searchUsers(q);
    }
    if (!mounted) return;
    final myAliases = await _dmService.getUserAliases(effectiveMyUid);
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
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: ThemeService.textSecondary.withOpacity(0.3),
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
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: ThemeService.textSecondary, size: 22),
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
                color: ThemeService.cardSecondary,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ThemeService.border),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'search_users_hint'.tr(),
                  hintStyle: TextStyle(
                    color: ThemeService.textSecondary.withOpacity(0.6),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: ThemeService.textSecondary,
                    size: 20,
                  ),
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
                            style: TextStyle(
                              color: ThemeService.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final u = _results[i];
                          final displayName = u.displayName.trim().isNotEmpty
                              ? u.displayName.trim()
                              : (u.username.trim().isNotEmpty
                                  ? u.username.trim()
                                  : 'Gamer');
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            onTap: () => Navigator.pop(context, u),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: ThemeService.cardSecondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ThemeService.border,
                                  width: 1.2,
                                ),
                              ),
                              child: ClipOval(
                                child: _renderUserAvatarWidget(
                                  rawPhotoUrl: u.photoUrl,
                                  name: displayName,
                                  size: 44,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: ThemeService.textPrimary,
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
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
