import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../widgets/gamer_avatar.dart';
import 'gamer_profile_screen.dart';

class GamerSearchScreen extends StatefulWidget {
  const GamerSearchScreen({super.key});

  @override
  State<GamerSearchScreen> createState() => _GamerSearchScreenState();
}

class _GamerSearchScreenState extends State<GamerSearchScreen> {
  final _searchController = TextEditingController();
  final GamerSocialService _socialService = GamerSocialService();
  final GamerAuthService _authService = GamerAuthService();

  Timer? _debounce;
  List<GamerUser> _searchResults = [];
  bool _isSearching = false;
  String _activeQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();

    if (q.isEmpty) {
      setState(() {
        _activeQuery = '';
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _activeQuery = q;
    });

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await _socialService.searchUsers(q);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Widget _buildUserTile(GamerUser user) {
    final currentUid = _authService.currentUid ?? '';
    final isSelf = user.uid == currentUid;
    final gameColor = GamerTheme.gameColors[user.favoriteGame] ?? GamerTheme.accentBlue;
    final gameEmoji = GamerTheme.gameEmojis[user.favoriteGame] ?? '🎮';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Row(
        children: [
          GamerAvatar(
            photoUrl: user.photoUrl,
            displayName: user.displayName,
            radius: 24,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: user.uid)),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: user.uid)),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          style: const TextStyle(
                            color: GamerTheme.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.check_circle_rounded, color: GamerTheme.accentBlue, size: 14),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    style: const TextStyle(
                      color: GamerTheme.accentOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: gameColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$gameEmoji ${user.favoriteGame}',
                          style: TextStyle(color: gameColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${user.rank}',
                        style: const TextStyle(color: GamerTheme.textMuted, fontSize: 10.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!isSelf)
            StreamBuilder<bool>(
              stream: _socialService.isFollowingStream(currentUid, user.uid),
              builder: (context, snap) {
                final isFollowing = snap.data ?? false;
                return SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      backgroundColor: isFollowing ? GamerTheme.cardElevated : GamerTheme.accentBlue,
                      foregroundColor: isFollowing ? GamerTheme.textGray : GamerTheme.bgDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isFollowing ? GamerTheme.borderLight : Colors.transparent),
                      ),
                    ),
                    onPressed: () async {
                      if (currentUid.isEmpty) return;
                      if (isFollowing) {
                        await _socialService.unfollowUser(currentUid: currentUid, targetUid: user.uid);
                      } else {
                        await _socialService.followUser(currentUid: currentUid, targetUid: user.uid);
                      }
                    },
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: isFollowing ? GamerTheme.textWhite : GamerTheme.bgDark,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        title: const Text('Find Gamers'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: GamerTheme.textWhite),
                decoration: InputDecoration(
                  hintText: 'Search by @username or display name...',
                  prefixIcon: const Icon(Icons.search_rounded, color: GamerTheme.accentBlue),
                  suffixIcon: _activeQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: GamerTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Content Area
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue))
                  : _activeQuery.isNotEmpty
                      ? _searchResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.person_search_rounded, color: GamerTheme.textMuted, size: 54),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No gamers found for "$_activeQuery"',
                                    style: const TextStyle(color: GamerTheme.textGray, fontSize: 14),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Check spelling or search by unique username',
                                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) => _buildUserTile(_searchResults[index]),
                            )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                              child: Row(
                                children: [
                                  Icon(Icons.whatshot_rounded, color: GamerTheme.accentOrange, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'SUGGESTED GAMERS & SQUADS',
                                    style: TextStyle(
                                      color: GamerTheme.accentOrange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: StreamBuilder<List<GamerUser>>(
                                stream: _socialService.getSuggestedGamersStream(),
                                builder: (context, snap) {
                                  if (snap.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue));
                                  }

                                  final users = snap.data ?? [];
                                  if (users.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.sports_esports_rounded, color: GamerTheme.textMuted, size: 48),
                                          SizedBox(height: 10),
                                          Text('Welcome to Gamers ID!', style: TextStyle(color: GamerTheme.textWhite)),
                                          SizedBox(height: 4),
                                          Text('Start typing above to discover gaming IDs.', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                                        ],
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    itemCount: users.length,
                                    itemBuilder: (context, index) => _buildUserTile(users[index]),
                                  );
                                },
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
