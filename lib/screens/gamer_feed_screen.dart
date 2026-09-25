import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class GamerFeedScreen extends StatefulWidget {
  const GamerFeedScreen({super.key});
  @override
  State<GamerFeedScreen> createState() => _GamerFeedScreenState();
}

class _GamerFeedScreenState extends State<GamerFeedScreen> {
  List<Map<String, dynamic>> posts = [];
  bool isLoading = true;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => isLoading = true);
    currentUserId = await SupabaseService.getCurrentUserId();
    try {
      final data = await SupabaseService.client
         .from('posts')
         .select('*, users!posts_user_id_fkey(username, display_name, avatar_url)')
         .order('created_at', ascending: false)
         .limit(50);
      setState(() {
        posts = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      final fallback = await SupabaseService.getPosts(limit: 50);
      setState(() {
        posts = fallback;
        isLoading = false;
      });
    }
  }

  String timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
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
        title: const Text('Games Khabar', style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFeed,
        child: isLoading
           ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: posts.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(20)),
                          child: const Text("What's on your mind?", style: TextStyle(color: Colors.grey)),
                        ),
                        onTap: () => Navigator.pushNamed(context, '/create_post'),
                      ),
                    );
                  }
                  final post = posts[index - 1];
                  final users = post['users'] as Map<String, dynamic>?;
                  final username = users?['username']?? users?['display_name']?? post['username']?? 'Unknown';
                  final avatarUrl = users?['avatar_url']?? post['user_avatar']?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                    elevation: 0,
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundImage: avatarUrl.toString().isNotEmpty? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.toString().isEmpty? const Icon(Icons.person) : null,
                          ),
                          title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(timeAgo(post['created_at']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          trailing: const Icon(Icons.more_horiz),
                        ),
                        if (post['content']!= null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Text(post['content'], style: const TextStyle(fontSize: 15)),
                          ),
                        if (post['image_url']!= null && post['image_url'].toString().isNotEmpty)
                          Image.network(post['image_url'], width: double.infinity, fit: BoxFit.cover),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${post['likes_count']?? 0} Likes', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              Text('${post['comments_count']?? 0} Comments', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Row(
                          children: [
                            Expanded(child: InkWell(onTap: () async {
                              if (currentUserId == null) return;
                              await SupabaseService.toggleLike(postId: post['id'].toString(), userId: currentUserId!);
                              _loadFeed();
                            }, child: const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.thumb_up_outlined, size: 20), SizedBox(width: 6), Text('Like')])))),
                            Expanded(child: InkWell(onTap: () {
                              showModalBottomSheet(context: context, builder: (_) => CommentSheet(postId: post['id'].toString()));
                            }, child: const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 20), SizedBox(width: 6), Text('Comment')])))),
                            Expanded(child: InkWell(onTap: () {}, child: const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.share_outlined, size: 20), SizedBox(width: 6), Text('Share')])))),
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
  const CommentSheet({super.key, required this.postId});
  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  List<Map<String, dynamic>> comments = [];
  final ctrl = TextEditingController();
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final data = await SupabaseService.getComments(widget.postId);
    setState(() { comments = data; loading = false; });
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        Expanded(child: loading? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: comments.length, itemBuilder: (_, i) {
          final c = comments[i];
          return ListTile(title: Text(c['username']?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text(c['content']?? ''));
        })),
        Row(children: [
          Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Write a comment...'))),
          IconButton(icon: const Icon(Icons.send), onPressed: () async {
            final uid = await SupabaseService.getCurrentUserId()?? 'anon';
            await SupabaseService.addComment(postId: widget.postId, userId: uid, username: 'You', content: ctrl.text.trim());
            ctrl.clear(); _load();
          })
        ])
      ]),
    );
  }
}