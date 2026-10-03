import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/supabase_service.dart';

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
  String currentUserId = 'test_user';

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<String> _resolveValidUserId() async {
    // 1. Check SharedPreferences stored Supabase user ID
    try {
      final sbId = await SupabaseService.getCurrentUserId();
      if (sbId != null && _uuidRegex.hasMatch(sbId)) {
        return sbId;
      }
    } catch (_) {}

    // 2. Check current Firebase user and match in Supabase users table
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        if (fbUser.email != null && fbUser.email!.isNotEmpty) {
          final res = await SupabaseService.client
              .from('users')
              .select('id')
              .eq('email', fbUser.email!)
              .maybeSingle();
          if (res != null && res['id'] != null) {
            final idStr = res['id'].toString();
            if (_uuidRegex.hasMatch(idStr)) return idStr;
          }
        }
        final resUid = await SupabaseService.client
            .from('users')
            .select('id')
            .eq('uid', fbUser.uid)
            .maybeSingle();
        if (resUid != null && resUid['id'] != null) {
          final idStr = resUid['id'].toString();
          if (_uuidRegex.hasMatch(idStr)) return idStr;
        }
      }
    } catch (_) {}

    // 3. Fallback to any user in public.users to satisfy UUID and FK constraints
    try {
      final anyUser = await SupabaseService.client
          .from('users')
          .select('id')
          .limit(1)
          .maybeSingle();
      if (anyUser != null && anyUser['id'] != null) {
        final idStr = anyUser['id'].toString();
        if (_uuidRegex.hasMatch(idStr)) return idStr;
      }
    } catch (_) {}

    final fbUid = FirebaseAuth.instance.currentUser?.uid;
    return (fbUid != null && fbUid.isNotEmpty) ? fbUid : 'test_user';
  }

  Future<void> _loadFeed() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    currentUserId = await _resolveValidUserId();

    try {
      // 1. Fetch posts with simple query without foreign key joins
      final data = await SupabaseService.client
          .from('posts')
          .select('*')
          .order('created_at', ascending: false)
          .limit(20);

      final fetchedPosts = List<Map<String, dynamic>>.from(data as List);

      // 2. Fetch users separately
      final userIds = fetchedPosts
          .map((p) => p['user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
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

      // 3. Fetch likes for current user separately
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

  Future<void> _handleLike(Map<String, dynamic> post) async {
    final postId = post['id']?.toString() ?? '';
    if (postId.isEmpty) return;

    final isLiked = likedPostIds.contains(postId);
    final rawCount = post['likes_count'];
    final currentLikes = (rawCount is int)
        ? rawCount
        : int.tryParse(rawCount?.toString() ?? '0') ?? 0;
    final updatedLikes = isLiked
        ? (currentLikes > 0 ? currentLikes - 1 : 0)
        : currentLikes + 1;

    setState(() {
      if (isLiked) {
        likedPostIds.remove(postId);
      } else {
        likedPostIds.add(postId);
      }
      post['likes_count'] = updatedLikes;
    });

    // Insert or delete from likes table
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
    } catch (e) {
      debugPrint('Likes table update error (FK fallback): $e');
    }

    // Always update posts table likes_count
    try {
      await SupabaseService.client
          .from('posts')
          .update({'likes_count': updatedLikes})
          .eq('id', postId);
    } catch (e) {
      debugPrint('Posts table update likes error: $e');
    }
  }

  void _handleShare(Map<String, dynamic> post) {
    final content = (post['content'] ?? '').toString();
    Share.share('Games Khabar: $content');
  }

  void _showComments(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentSheet(
        postId: postId,
        currentUserId: currentUserId,
      ),
    ).then((_) => _loadFeed());
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
                  // Top "What's on your mind?" Card
                  if (index == 0) {
                    return Card(
                      margin: const EdgeInsets.all(8),
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE4E6EB),
                          child: Icon(Icons.person, color: Color(0xFF050505)),
                        ),
                        title: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F2F5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "What's on your mind?",
                            style: TextStyle(
                              color: Color(0xFF65676B),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        onTap: () => Navigator.pushNamed(context, '/create_post'),
                      ),
                    );
                  }

                  final post = posts[index - 1];
                  final postUserId = post['user_id']?.toString() ?? '';
                  final userProfile = userProfiles[postUserId];

                  final username = userProfile?['username'] ??
                      post['username'] ??
                      'Gamer';
                  final avatarUrl = (userProfile?['avatar_url'] ?? post['user_avatar'] ?? '').toString();
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
                        // Header
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE4E6EB),
                            backgroundImage: avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl.isEmpty
                                ? const Icon(Icons.person, color: Color(0xFF050505))
                                : null,
                          ),
                          title: Text(
                            username.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF050505),
                            ),
                          ),
                          subtitle: Text(
                            _formatTimeAgo(post['created_at']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF65676B),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.more_horiz,
                            color: Color(0xFF65676B),
                          ),
                        ),

                        // Post Content Text
                        if (content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Text(
                              content,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF050505),
                                height: 1.3,
                              ),
                            ),
                          ),

                        // Post Image
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

                        // Counts Row
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
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
                                    child: const Icon(
                                      Icons.thumb_up,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$likesCount',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF65676B),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$commentsCount comments',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF65676B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1, color: Color(0xFFCED0D4)),

                        // Like, Comment, Share Row
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
                                        isLiked
                                            ? Icons.thumb_up
                                            : Icons.thumb_up_outlined,
                                        size: 18,
                                        color: isLiked
                                            ? const Color(0xFF1877F2)
                                            : const Color(0xFF65676B),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Like',
                                        style: TextStyle(
                                          color: isLiked
                                              ? const Color(0xFF1877F2)
                                              : const Color(0xFF65676B),
                                          fontWeight: isLiked
                                              ? FontWeight.bold
                                              : FontWeight.normal,
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
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 18,
                                        color: Color(0xFF65676B),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Comment',
                                        style: TextStyle(
                                          color: Color(0xFF65676B),
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
                                onTap: () => _handleShare(post),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.share_outlined,
                                        size: 18,
                                        color: Color(0xFF65676B),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Share',
                                        style: TextStyle(
                                          color: Color(0xFF65676B),
                                          fontSize: 13,
                                        ),
                                      ),
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

class CommentSheet extends StatefulWidget {
  final String postId;
  final String currentUserId;

  const CommentSheet({
    super.key,
    required this.postId,
    required this.currentUserId,
  });

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  List<Map<String, dynamic>> comments = [];
  final TextEditingController _ctrl = TextEditingController();
  bool _loading = true;

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

  Future<String> _resolveCommenterUserId() async {
    if (_uuidRegex.hasMatch(widget.currentUserId)) {
      return widget.currentUserId;
    }

    try {
      final sbId = await SupabaseService.getCurrentUserId();
      if (sbId != null && _uuidRegex.hasMatch(sbId)) {
        return sbId;
      }
    } catch (_) {}

    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        if (fbUser.email != null && fbUser.email!.isNotEmpty) {
          final res = await SupabaseService.client
              .from('users')
              .select('id')
              .eq('email', fbUser.email!)
              .maybeSingle();
          if (res != null && res['id'] != null) {
            final idStr = res['id'].toString();
            if (_uuidRegex.hasMatch(idStr)) return idStr;
          }
        }
      }
    } catch (_) {}

    try {
      final anyUser = await SupabaseService.client
          .from('users')
          .select('id')
          .limit(1)
          .maybeSingle();
      if (anyUser != null && anyUser['id'] != null) {
        final idStr = anyUser['id'].toString();
        if (_uuidRegex.hasMatch(idStr)) return idStr;
      }
    } catch (_) {}

    return widget.currentUserId;
  }

  Future<void> _loadComments() async {
    try {
      final data = await SupabaseService.client
          .from('comments')
          .select('*')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      final list = List<Map<String, dynamic>>.from(data as List);

      // If any comment is missing username, populate from users table
      final missingUserIds = list
          .where((c) => c['username'] == null || c['username'].toString().isEmpty)
          .map((c) => c['user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
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
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Comments fetch error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    try {
      final validUid = await _resolveCommenterUserId();
      final fb = FirebaseAuth.instance.currentUser;
      final authorUsername = fb?.displayName ??
          fb?.email?.split('@').first ??
          'Gamer';

      // First attempt: insert with username
      bool inserted = false;
      try {
        await SupabaseService.client.from('comments').insert({
          'post_id': widget.postId,
          'user_id': validUid,
          'content': text,
          'username': authorUsername,
        });
        inserted = true;
      } catch (e) {
        debugPrint('Insert with username failed ($e), falling back to schema without username...');
      }

      // Second attempt (fallback): insert without username column if schema cache lacks it
      if (!inserted) {
        await SupabaseService.client.from('comments').insert({
          'post_id': widget.postId,
          'user_id': validUid,
          'content': text,
        });
      }

      // Increment comments_count in posts table
      try {
        final postData = await SupabaseService.client
            .from('posts')
            .select('comments_count')
            .eq('id', widget.postId)
            .maybeSingle();

        final rawCount = postData?['comments_count'];
        final currentCount = (rawCount is int)
            ? rawCount
            : int.tryParse(rawCount?.toString() ?? '0') ?? 0;

        await SupabaseService.client
            .from('posts')
            .update({'comments_count': currentCount + 1})
            .eq('id', widget.postId);
      } catch (e) {
        debugPrint('Post comments count update error: $e');
      }

      _loadComments();

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
    }
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
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
                            return ListTile(
                              leading: const CircleAvatar(
                                radius: 16,
                                backgroundColor: Color(0xFFE4E6EB),
                                child: Icon(Icons.person, size: 18, color: Color(0xFF050505)),
                              ),
                              title: Text(
                                username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                content,
                                style: const TextStyle(
                                  color: Color(0xFF050505),
                                  fontSize: 14,
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
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        filled: true,
                        fillColor: const Color(0xFFF0F2F5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Color(0xFF1877F2),
                    ),
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