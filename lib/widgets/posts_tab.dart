// ═══════════════════════════════════════════════════════════════════════════════
// EXACT DIFF:
// - Override post author avatar with live GamerAuthService().currentGamer?.photoUrl
//   or widget.user.photoUrl so posts always show the latest updated profile picture
// ═══════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_post_model.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/block_service.dart';
import '../services/profile_service.dart';
import '../widgets/post_card.dart';

/// PostsTab displays all posts for a user profile.
class PostsTab extends StatefulWidget {
  final GamerUser user;
  final bool isOwnProfile;

  const PostsTab({
    super.key,
    required this.user,
    required this.isOwnProfile,
  });

  @override
  State<PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<PostsTab>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 15;

  final _authService = GamerAuthService();
  final _blockService = BlockService();
  final _profileService = ProfileService();
  final ScrollController _scrollController = ScrollController();

  Set<String> _blockedIds = {};
  List<ProfileFeedItem> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initData();
  }

  @override
  void didUpdateWidget(covariant PostsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _currentPage = 0;
      _hasMore = true;
      _loadInitialPosts(forceRefresh: false);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 250;
    if (_scrollController.position.pixels >= threshold) {
      _loadMorePosts();
    }
  }

  Future<void> _initData() async {
    final uid = _authService.currentUid ?? '';
    if (uid.isNotEmpty) {
      _blockedIds = await _blockService.getBlockedIds(uid);
    }
    await _loadInitialPosts(forceRefresh: false);
  }

  Future<void> _loadInitialPosts({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = _posts.isEmpty;
      _currentPage = 0;
    });

    final fetched = await _profileService.fetchUserPostsPage(
      userId: widget.user.uid,
      page: 0,
      pageSize: _pageSize,
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;
    setState(() {
      _posts = fetched;
      _isLoading = false;
      _hasMore = fetched.length >= _pageSize;
    });
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final fetched = await _profileService.fetchUserPostsPage(
      userId: widget.user.uid,
      page: nextPage,
      pageSize: _pageSize,
    );

    if (!mounted) return;
    setState(() {
      if (fetched.isNotEmpty) {
        final existingIds = _posts.map((e) => e.id).toSet();
        for (final item in fetched) {
          if (!existingIds.contains(item.id)) {
            _posts.add(item);
          }
        }
        _currentPage = nextPage;
      }
      _hasMore = fetched.length >= _pageSize;
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: GamerTheme.accentBlue),
      );
    }

    // Filter out blocked users' posts
    final items = _posts.where((item) {
      final itemUid = item.userId.toString();
      if (widget.isOwnProfile &&
          itemUid == (_authService.currentUid ?? '')) {
        return true;
      }
      return !_blockedIds.contains(itemUid);
    }).toList();

    if (items.isEmpty) {
      return RefreshIndicator(
        color: GamerTheme.accentGreen,
        onRefresh: () => _loadInitialPosts(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.post_add_rounded,
                color: GamerTheme.textMuted, size: 48),
            const SizedBox(height: 10),
            Text(
              widget.isOwnProfile
                  ? 'You haven\'t posted anything yet.'
                  : '@${widget.user.username} hasn\'t posted yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: GamerTheme.textGray, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Share gameplay updates and squad room codes!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: GamerTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: GamerTheme.accentGreen,
      onRefresh: () => _loadInitialPosts(forceRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + (_isLoadingMore ? 1 : 0),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: GamerTheme.accentBlue,
                  ),
                ),
              ),
            );
          }

          final item = items[index];

          final currentGamer = _authService.currentGamer;
          final isCurrentUserPost = widget.isOwnProfile ||
              (currentGamer != null &&
                  (item.userId == currentGamer.uid ||
                      (item.username.isNotEmpty &&
                          item.username.toLowerCase() ==
                              currentGamer.username.toLowerCase())));

          final effectiveAvatar = isCurrentUserPost &&
                  (currentGamer?.photoUrl.isNotEmpty == true)
              ? currentGamer!.photoUrl
              : (widget.user.photoUrl.isNotEmpty &&
                      (item.userId == widget.user.uid ||
                          (item.username.isNotEmpty &&
                              item.username.toLowerCase() ==
                                  widget.user.username.toLowerCase()))
                  ? widget.user.photoUrl
                  : item.userPhoto);

          final post = (item.originalPost != null)
              ? item.originalPost!.copyWith(userPhoto: effectiveAvatar)
              : GamerPost(
                  postId: item.id,
                  userId: item.userId,
                  username: item.username,
                  displayName: item.displayName,
                  userPhoto: effectiveAvatar,
                  text: item.text,
                  imageUrl: item.mediaUrl,
                  gameTag: item.gameTag,
                  likesCount: item.likesCount,
                  commentsCount: item.commentsCount,
                  isVerified: item.isVerified,
                  createdAt: item.createdAt,
                );

          return PostCard(post: post);
        },
      ),
    );
  }
}