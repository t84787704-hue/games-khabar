import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_social_service.dart';
import '../services/supabase_service.dart';
import '../widgets/gamer_avatar.dart';
import 'gamer_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GamerSocialService _socialService = GamerSocialService();
  final FocusNode _focusNode = FocusNode();

  List<GamerUser> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Auto-focus search bar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
          _hasSearched = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
        _hasSearched = true;
      });
    }

    try {
      final users = await _socialService.searchUsers(cleanQuery);

      if (mounted) {
        setState(() {
          _results = users;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('[UserSearch] Error: $e');
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
    }
  }

  void _openProfile(GamerUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamerProfileScreen(userId: user.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF1877F2)),
        title: const Text(
          'Search Gamers',
          style: TextStyle(
            color: Color(0xFF1877F2),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              style: const TextStyle(
                color: Color(0xFF050505),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search by name or @username...',
                hintStyle: const TextStyle(
                  color: Color(0xFF65676B),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF65676B),
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Color(0xFF65676B),
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF0F2F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFF1877F2),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    // Empty state — pehle search karo
    if (!_hasSearched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  color: Color(0xFF1877F2),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Search for Gamers',
                style: TextStyle(
                  color: Color(0xFF050505),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Apne dost ka naam ya @username likho\nunko dhoondne ke liye',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF65676B),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Loading
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1877F2)),
      );
    }

    // No results
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E6EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  color: Color(0xFF65676B),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Koi user nahi mila',
                style: TextStyle(
                  color: Color(0xFF050505),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Koi aur naam ya username try karo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF65676B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Results list
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(
        color: Color(0xFFE4E6EB),
        height: 1,
        indent: 76,
      ),
      itemBuilder: (context, index) {
        final user = _results[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(GamerUser user) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openProfile(user),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              GamerAvatar(
                photoUrl: user.photoUrl,
                displayName: user.displayName,
                radius: 26,
                hasGlow: false,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName
                                : user.username,
                            style: const TextStyle(
                              color: Color(0xFF050505),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.hasBlueTick) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFF1877F2),
                            size: 15,
                          ),
                        ],
                        if (user.isOwnerUser) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.shield_rounded,
                            color: Color(0xFFFF6B00),
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(
                        color: Color(0xFF65676B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        user.bio,
                        style: const TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF1877F2).withOpacity(0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF1877F2),
                      size: 13,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'View',
                      style: TextStyle(
                        color: Color(0xFF1877F2),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}