import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:games_khabar/compat/firebase_auth.dart';
import '../services/supabase_service.dart';
import 'gamer_profile_screen.dart';

class GamerFeedScreen extends StatefulWidget {
  const GamerFeedScreen({super.key});

  @override
  State<GamerFeedScreen> createState() => _GamerFeedScreenState();
}

class _GamerFeedScreenState extends State<GamerFeedScreen> {
  List<Map<String, dynamic>> posts = [];
  Map<String, Map<String, dynamic>> userProfiles = {};
  Set<String> likedPostIds = {};
  bool isLoading = true;
  String currentUserId = '';
  String currentUsername = 'Gamer';
  String currentAvatarUrl = '';

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _loadCurrentUserInfo();
    await _loadFeed();
  }

  Future<void> _loadCurrentUserInfo() async {
    try {
      try {
        final sbId = await SupabaseService.getCurrentUserId();
        if (sbId != null && _uuidRegex.hasMatch(sbId)) {
          currentUserId = sbId;
        }
      } catch (_) {}

      final fbUser = FirebaseAuth.instance.currentUser;

      if (currentUserId.isEmpty && fbUser != null) {
        if (fbUser.email != null && fbUser.email!.isNotEmpty) {
          try {
            final res = await SupabaseService.client
                .from('users')
                .select('id, username, avatar_url')
                .eq('email', fbUser.email!)
                .maybeSingle();
            if (res != null && res['id'] != null) {
              final idStr = res['id'].toString();
              if (_uuidRegex.hasMatch(idStr)) {
                currentUserId = idStr;
                currentUsername = (res['username'] ?? '').toString().isNotEmpty
                    ? res['username'].toString()
                    : (fbUser.displayName ?? fbUser.email?.split('@').first ?? 'Gamer');
                currentAvatarUrl = (res['avatar_url'] ?? '').toString();
              }
            }
          } catch (_) {}
        }

        if (currentUserId.isEmpty) {
          try {
            final resUid = await SupabaseService.client
                .from('users')
                .select('id, username, avatar_url')
                .eq('uid', fbUser.uid)
                .maybeSingle();
            if (resUid != null && resUid['id'] != null) {
              final idStr = resUid['id'].toString();
              if (_uuidRegex.hasMatch(idStr)) {
                currentUserId = idStr;
                currentUsername = (resUid['username'] ?? '').toString().isNotEmpty
                    ? resUid['username'].toString()
                    : (fbUser.displayName ?? fbUser.email?.split('@').first ?? 'Gamer');
                currentAvatarUrl = (resUid['avatar_url'] ?? '').toString();
              }
            }
          } catch (_) {}
        }
      }

      if (currentUserId.isEmpty) {
        try {
          final anyUser = await SupabaseService.client
              .from('users')
              .select('id, username, avatar_url')
              .limit(1)
              .maybeSingle();
          if (anyUser != null && anyUser['id'] != null) {
            final idStr = anyUser['id'].toString();
            if (_uuidRegex.hasMatch(idStr)) {
              currentUserId = idStr;
              currentUsername = (anyUser['username'] ?? 'Gamer').toString();
              currentAvatarUrl = (anyUser['avatar_url'] ?? '').toString();
            }
          }
        } catch (_) {}
      }

      if (currentUserId.isEmpty && fbUser != null && _uuidRegex.hasMatch(fbUser.uid)) {
        currentUserId = fbUser.uid;
        currentUsername = fbUser.displayName ?? fbUser.email?.split('@').first ?? 'Gamer';
      }

      if (currentUsername.trim().isEmpty) {
        currentUsername = 'Gamer';
      }
    } catch (e) {
      debugPrint('User info resolve error: $e');
    }
  }

  Future<void> _loadFeed() async {
    if (mounted) setState(() => isLoading = true);

    if (currentUserId.isEmpty) {
      await _loadCurrentUserInfo();
    }

    try {
      final data = await SupabaseService.client
          .from('posts')
          .select('*')
          .order('created_at', ascending: false)
          .limit(20);

      final fetchedPosts = List<Map<String, dynamic>>.from(data as List);

      final userIds = fetchedPosts
          .map((p) => p['user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty && _uuidRegex.hasMatch(id))
          .toSet()
          .toList();

      if (userIds.isNotEmpty) {
        try {
          final usersData = await SupabaseService.client
              .from('users')
              .select('id, username, avatar_url')
              .inFilter('id', userIds);

          final profiles = <String, Map<String, dynamic>>{};
          for (final u in (usersData as List)) {
            if (u is Map<String, dynamic> && u['id'] != null) {
              profiles[u['id'].toString()] = u;
            }
          }
          userProfiles = profiles;
        } catch (e) {
          debugPrint('Users fetch warning (ignored): $e');
        }
      }

      if (currentUserId.isNotEmpty && _uuidRegex.hasMatch(currentUserId)) {
        try {
          final likesData = await SupabaseService.client
              .from('likes')
              .select('post_id')
              .eq('user_id', currentUserId);

          likedPostIds = (likesData as List)
              .map((e) => e['post_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
        } catch (e) {
          debugPrint('Likes fetch warning (ignored): $e');
        }
      }

      if (mounted) {
        setState(() {
          posts = fetchedPosts;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Feed error: $e');
      if (mounted) {
        setState(() => isLoading = false);
        final errText = e.toString();
        final snackMsg = errText.contains('521')
            ? 'Server temporarily unavailable (521). Please retry.'
            : (errText.contains('PGRST200')
                ? 'Database schema updated. Retrying feed...'
                : 'Could not load feed: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackMsg),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: 'Retry', onPressed: _loadFeed),
          ),
        );
      }
    }
  }

  void _openUserProfile(String userId, String username) {
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamerProfileScreen(userId: userId),
      ),
    );
  }

  Future<void> _handleLike(Map<String, dynamic> post) async {
    final postId = post['id']?.toString() ?? '';
    if (postId.isEmpty) return;

    if (currentUserId.isEmpty || !_uuidRegex.hasMatch(currentUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to like posts.')),
      );
      return;
    }

    final isLiked = likedPostIds.contains(postId);
    final rawCount = post['likes_count'];
    final currentLikes = (rawCount is int)
        ? rawCount
        : int.tryParse(rawCount?.toString() ?? '0') ?? 0;
    final updatedLikes = isLiked
        ? (currentLikes > 0 ? currentLikes - 1 : 0)
        : currentLikes + 1;

    final previousLikes = currentLikes;

    setState(() {
      if (isLiked) {
        likedPostIds.remove(postId);
      } else {
        likedPostIds.add(postId);
      }
      post['likes_count'] = updatedLikes;
    });

    bool success = false;

    try {
      if (isLiked) {
        await SupabaseService.client
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUserId);
      } else {
        await SupabaseService.client.from('likes').insert({
          'post_id': postId,
          'user_id': currentUserId,
        });
      }
      success = true;
    } catch (e) {
      debugPrint('Likes table update error: $e');
    }

    if (success) {
      try {
        await SupabaseService.client
            .from('posts')
            .update({'likes_count': updatedLikes})
            .eq('id', postId);
      } catch (e) {
        debugPrint('Posts likes_count update error: $e');
      }
    } else {
      if (mounted) {
        setState(() {
          if (isLiked) {
            likedPostIds.add(postId);
          } else {
            likedPostIds.remove(postId);
          }
          post['likes_count'] = previousLikes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update like. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleShare(Map<String, dynamic> post) async {
    final content = (post['content'] ?? '').toString();
    final postUserId = post['user_id']?.toString() ?? '';
    final userProfile = userProfiles[postUserId];
    final username = userProfile?['username'] ?? post['username'] ?? 'Gamer';

    final shareText = '''
🎮 Games Khabar - $username ki post

"$content"

👤 Posted by: $username

🔥 Dekho aur bhi gaming khabrein Games Khabar App par!

📲 Download App:
https://play.google.com/store/apps/details?id=com.gameskhabar.app

#GamesKhabar #PUBG #BGMI #Esports
''';

    try {
      await Share.share(shareText.trim(), subject: 'Games Khabar - $username');
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  void _showComments(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CommentSheet(
        postId: postId,
        currentUserId: currentUserId,
        currentUsername: currentUsername,
      ),
    ).then((newCount) {
      if (newCount is int && mounted) {
        setState(() {
          final idx = posts.indexWhere((p) => p['id'].toString() == postId);
          if (idx != -1) {
            posts[idx]['comments_count'] = newCount;
          }
        });
      }
    });
  }

  /// Report a post — saves into the `reports` table.
  Future<void> _reportPost(String postId, String postContent, String postOwnerId) async {
    // Prevent reporting own post
    if (postOwnerId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aap apni post report nahi kar sakte')),
      );
      return;
    }

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Report Post?'),
        content: const Text('Kya aap ye post report karna chahte hain? Admin review karega.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.client.from('reports').insert({
        'reporter_id': currentUserId.isNotEmpty ? currentUserId : null,
        'reporter_username': currentUsername,
        'target_type': 'post',
        'target_id': postId,
        'target_content': postContent.length > 200
            ? postContent.substring(0, 200)
            : postContent,
        'reason': 'Reported by user',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Post report ho gayi — Admin review karega'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Feed] Report error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPostOptions(BuildContext context, String postId, String ownerId) {
    final isMyPost = ownerId == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            if (isMyPost) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete Post?'),
                      content: const Text('Kya aap ye post delete karna chahte hain?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      try {
                        await SupabaseService.client.from('likes').delete().eq('post_id', postId);
                      } catch (e) {
                        debugPrint('Likes delete warning: $e');
                      }
                      try {
                        await SupabaseService.client.from('comments').delete().eq('post_id', postId);
                      } catch (e) {
                        debugPrint('Comments delete warning: $e');
                      }

                      await SupabaseService.client.from('posts').delete().eq('id', postId);

                      if (mounted) {
                        setState(() {
                          posts.removeWhere((p) => p['id'].toString() == postId);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Post deleted'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Color(0xFF65676B)),
                title: const Text('Report Post'),
                onTap: () {
                  // Capture the current post content for the report
                  final targetPost = posts.firstWhere(
                    (p) => p['id'].toString() == postId,
                    orElse: () => <String, dynamic>{},
                  );
                  final content = (targetPost['content'] ?? '').toString();
                  Navigator.pop(ctx);
                  _reportPost(postId, content, ownerId);
                },
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showCreatePost() {
    final textController = TextEditingController();
    bool isPosting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFE4E6EB),
                      backgroundImage: currentAvatarUrl.isNotEmpty
                          ? NetworkImage(currentAvatarUrl)
                          : null,
                      child: currentAvatarUrl.isEmpty
                          ? const Icon(Icons.person, color: Color(0xFF050505))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentUsername,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF050505),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1877F2),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: isPosting
                          ? null
                          : () async {
                              final text = textController.text.trim();
                              if (text.isEmpty) return;

                              if (currentUserId.isEmpty || !_uuidRegex.hasMatch(currentUserId)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cannot post: user not logged in properly.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => isPosting = true);

                              try {
                                await SupabaseService.client.from('posts').insert({
                                  'content': text,
                                  'user_id': currentUserId,
                                  'username': currentUsername,
                                  'likes_count': 0,
                                  'comments_count': 0,
                                });

                                if (sheetCtx.mounted) {
                                  Navigator.pop(sheetCtx);
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Post created!'),
                                      backgroundColor: Color(0xFF1877F2),
                                    ),
                                  );
                                  _loadFeed();
                                }
                              } catch (e) {
                                debugPrint('Error creating post: $e');
                                if (sheetCtx.mounted) {
                                  setSheetState(() => isPosting = false);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to create post: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isPosting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLines: 5,
                  minLines: 3,
                  style: const TextStyle(color: Color(0xFF050505), fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: "What's on your mind?",
                    hintStyle: TextStyle(color: Color(0xFF65676B), fontSize: 16),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTimeAgo(dynamic raw) {
    if (raw == null) return 'Just now';
    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw is String) {
      dt = DateTime.tryParse(raw);
    }
    if (dt == null) return 'Just now';

    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Games Khabar',
          style: TextStyle(
            color: Color(0xFF1877F2),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFeed,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: posts.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return InkWell(
                      onTap: _showCreatePost,
                      borderRadius: BorderRadius.circular(10),
                      child: Card(
                        margin: const EdgeInsets.all(8),
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFE4E6EB),
                                backgroundImage: currentAvatarUrl.isNotEmpty
                                    ? NetworkImage(currentAvatarUrl)
                                    : null,
                                child: currentAvatarUrl.isEmpty
                                    ? const Icon(Icons.person, color: Color(0xFF050505))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F2F5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "What's on your mind?",
                                    style: TextStyle(color: Color(0xFF65676B), fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final post = posts[index - 1];
                  final postUserId = post['user_id']?.toString() ?? '';
                  final userProfile = userProfiles[postUserId];

                  final username = userProfile?['username'] ?? post['username'] ?? 'Gamer';
                  final avatarUrl =
                      (userProfile?['avatar_url'] ?? post['user_avatar'] ?? '').toString();
                  final postId = post['id']?.toString() ?? '';
                  final isLiked = likedPostIds.contains(postId);
                  final imageUrl = (post['image_url'] ?? '').toString();
                  final content = (post['content'] ?? '').toString();
                  final likesCount = post['likes_count'] ?? 0;
                  final commentsCount = post['comments_count'] ?? 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                    elevation: 0,
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: GestureDetector(
                            onTap: () => _openUserProfile(postUserId, username.toString()),
                            child: CircleAvatar(
                              backgroundColor: const Color(0xFFE4E6EB),
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? const Icon(Icons.person, color: Color(0xFF050505))
                                  : null,
                            ),
                          ),
                          title: GestureDetector(
                            onTap: () => _openUserProfile(postUserId, username.toString()),
                            child: Text(
                              username.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF050505),
                              ),
                            ),
                          ),
                          subtitle: Text(
                            _formatTimeAgo(post['created_at']),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF65676B)),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_horiz, color: Color(0xFF65676B)),
                            onPressed: () => _showPostOptions(context, postId, postUserId),
                          ),
                        ),
                        if (content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Text(
                              content,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF050505),
                                height: 1.3,
                              ),
                            ),
                          ),
                        if (imageUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1877F2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.thumb_up, size: 11, color: Colors.white),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$likesCount',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF65676B)),
                                  ),
                                ],
                              ),
                              Text(
                                '$commentsCount comments',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF65676B)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFCED0D4)),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _handleLike(post),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                        size: 18,
                                        color: isLiked ? const Color(0xFF1877F2) : const Color(0xFF65676B),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Like',
                                        style: TextStyle(
                                          color: isLiked ? const Color(0xFF1877F2) : const Color(0xFF65676B),
                                          fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => _showComments(postId),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF65676B)),
                                      SizedBox(width: 6),
                                      Text('Comment', style: TextStyle(color: Color(0xFF65676B), fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => _handleShare(post),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.share_outlined, size: 18, color: Color(0xFF65676B)),
                                      SizedBox(width: 6),
                                      Text('Share', style: TextStyle(color: Color(0xFF65676B), fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ─────────────────────────── CommentSheet ───────────────────────────

class CommentSheet extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final String currentUsername;

  const CommentSheet({
    super.key,
    required this.postId,
    required this.currentUserId,
    required this.currentUsername,
  });

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  List<Map<String, dynamic>> comments = [];
  final TextEditingController _ctrl = TextEditingController();
  bool _loading = true;
  bool _isPosting = false;
  int _commentsCount = 0;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final data = await SupabaseService.client
          .from('comments')
          .select('*')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      final list = List<Map<String, dynamic>>.from(data as List);

      final missingUserIds = list
          .where((c) => c['username'] == null || c['username'].toString().isEmpty)
          .map((c) => c['user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty && _uuidRegex.hasMatch(id))
          .toSet()
          .toList();

      if (missingUserIds.isNotEmpty) {
        try {
          final usersData = await SupabaseService.client
              .from('users')
              .select('id, username')
              .inFilter('id', missingUserIds);

          final userMap = <String, String>{};
          for (final u in (usersData as List)) {
            if (u is Map<String, dynamic> && u['id'] != null) {
              userMap[u['id'].toString()] = (u['username'] ?? 'Gamer').toString();
            }
          }

          for (final c in list) {
            if (c['username'] == null || c['username'].toString().isEmpty) {
              final uid = c['user_id']?.toString();
              if (uid != null && userMap.containsKey(uid)) {
                c['username'] = userMap[uid];
              }
            }
          }
        } catch (e) {
          debugPrint('Comments user lookup error: $e');
        }
      }

      if (mounted) {
        setState(() {
          comments = list;
          _commentsCount = list.length;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Comments fetch error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isPosting) return;

    if (widget.currentUserId.isEmpty || !_uuidRegex.hasMatch(widget.currentUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to comment.')),
      );
      return;
    }

    setState(() => _isPosting = true);
    _ctrl.clear();

    try {
      bool inserted = false;
      try {
        await SupabaseService.client.from('comments').insert({
          'post_id': widget.postId,
          'user_id': widget.currentUserId,
          'content': text,
          'username': widget.currentUsername,
        });
        inserted = true;
      } catch (e) {
        debugPrint('Insert with username failed ($e), trying without...');
      }

      if (!inserted) {
        await SupabaseService.client.from('comments').insert({
          'post_id': widget.postId,
          'user_id': widget.currentUserId,
          'content': text,
        });
      }

      await _loadComments();

      try {
        await SupabaseService.client
            .from('posts')
            .update({'comments_count': _commentsCount})
            .eq('id', widget.postId);
      } catch (e) {
        debugPrint('Post comments_count update error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted!'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1877F2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Comment insert error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  /// Report a comment — saves into the `reports` table.
  Future<void> _reportComment(String commentId, String commentContent) async {
    // Prevent reporting own comment
    // (commentUserId might be current user)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Report Comment?'),
        content: const Text('Kya aap ye comment report karna chahte hain? Admin review karega.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.client.from('reports').insert({
        'reporter_id': widget.currentUserId.isNotEmpty ? widget.currentUserId : null,
        'reporter_username': widget.currentUsername,
        'target_type': 'comment',
        'target_id': commentId,
        'target_content': commentContent.length > 200
            ? commentContent.substring(0, 200)
            : commentContent,
        'reason': 'Reported by user',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Comment report ho gayi — Admin review karega'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Comment] Report error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openCommentUserProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamerProfileScreen(userId: userId),
      ),
    );
  }

  void _showCommentOptions(Map<String, dynamic> comment, bool isMyComment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            if (isMyComment) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Comment',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final commentId = (comment['id'] ?? '').toString();
                  if (commentId.isEmpty) return;
                  try {
                    await SupabaseService.client
                        .from('comments')
                        .delete()
                        .eq('id', commentId);
                    await _loadComments();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comment deleted'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    debugPrint('[Comment] Delete error: $e');
                  }
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Color(0xFF65676B)),
                title: const Text('Report Comment'),
                onTap: () {
                  Navigator.pop(ctx);
                  final commentId = (comment['id'] ?? '').toString();
                  final commentContent = (comment['content'] ?? '').toString();
                  _reportComment(commentId, commentContent);
                },
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: 500,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Comments',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : comments.isEmpty
                      ? const Center(
                          child: Text(
                            'No comments yet. Be the first to comment!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (_, i) {
                            final c = comments[i];
                            final username = (c['username'] ?? 'Gamer').toString();
                            final content = (c['content'] ?? '').toString();
                            final commentUserId = (c['user_id'] ?? '').toString();
                            final isMyComment = commentUserId == widget.currentUserId;

                            return InkWell(
                              onLongPress: () => _showCommentOptions(c, isMyComment),
                              child: ListTile(
                                leading: GestureDetector(
                                  onTap: () => _openCommentUserProfile(commentUserId),
                                  child: const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Color(0xFFE4E6EB),
                                    child: Icon(Icons.person, size: 18, color: Color(0xFF050505)),
                                  ),
                                ),
                                title: GestureDetector(
                                  onTap: () => _openCommentUserProfile(commentUserId),
                                  child: Text(
                                    username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                subtitle: Text(
                                  content,
                                  style: const TextStyle(
                                    color: Color(0xFF050505),
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.flag_outlined,
                                    size: 16,
                                    color: Color(0xFF65676B),
                                  ),
                                  onPressed: () => _reportComment(
                                    (c['id'] ?? '').toString(),
                                    content,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      enabled: !_isPosting,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        filled: true,
                        fillColor: const Color(0xFFF0F2F5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isPosting
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1877F2),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF1877F2)),
                          onPressed: _submitComment,
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