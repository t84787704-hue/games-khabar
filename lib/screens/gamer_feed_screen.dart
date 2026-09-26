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
  Map<String, Map<String, dynamic>> usersMap = {};
  bool isLoading = true;
  String? currentUserId;
  Set<String> likedPostIds = {};

  @override
  void initState() { super.initState(); _loadFeed(); }

  Future<String?> _getUid() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid!= null) return uid;
    uid = await SupabaseService.getCurrentUserId();
    return uid?? 'test_user_123';
  }

  Future<void> _loadFeed() async {
    setState(() => isLoading = true);
    currentUserId = await _getUid();
    try {
      // BINA JOIN KE POSTS - FK ki zarurat nahi
      final postsData = await SupabaseService.client.from('posts').select('*').order('created_at', ascending: false).limit(50);
      final postsList = List<Map<String, dynamic>>.from(postsData);

      // Users alag se lao
      final userIds = postsList.map((p) => p['user_id']?.toString()).where((id) => id!= null && id.isNotEmpty).toSet().toList();
      if (userIds.isNotEmpty) {
        try {
          final usersData = await SupabaseService.client.from('users').select('id, username, display_name, avatar_url').inFilter('id', userIds);
          for (var u in usersData) {
            usersMap[u['id'].toString()] = Map<String, dynamic>.from(u);
          }
        } catch (e) { debugPrint('Users fail: $e'); }
      }
      try {
        if (currentUserId!= null) {
          final myLikes = await SupabaseService.client.from('likes').select('post_id').eq('user_id', currentUserId!);
          likedPostIds = (myLikes as List).map((e) => e['post_id'].toString()).toSet();
        }
      } catch (e) {}

      setState(() { posts = postsList; isLoading = false; });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Feed Error: $e')));
    }
  }

  Future<void> _handleLike(Map<String, dynamic> post) async {
    final postId = post['id'].toString();
    final isLiked = likedPostIds.contains(postId);
    setState(() {
      if (isLiked) {
        likedPostIds.remove(postId);
        post['likes_count'] = (post['likes_count']?? 1) - 1;
      } else {
        likedPostIds.add(postId);
        post['likes_count'] = (post['likes_count']?? 0) + 1;
      }
    });
    try {
      if (isLiked) {
        await SupabaseService.client.from('likes').delete().eq('post_id', postId).eq('user_id', currentUserId!);
      } else {
        await SupabaseService.client.from('likes').insert({'post_id': postId, 'user_id': currentUserId!});
      }
      await SupabaseService.client.from('posts').update({'likes_count': post['likes_count']}).eq('id', postId);
    } catch (e) {
      try { await SupabaseService.client.from('posts').update({'likes_count': post['likes_count']}).eq('id', postId); } catch (_) {}
    }
  }

  void _handleShare(post) { Share.share('Games Khabar: ${post['content']?? ''}'); }
  void _showComments(String postId) { showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => CommentSheet(postId: postId, currentUserId: currentUserId)).then((_) => _loadFeed()); }
  String timeAgo(String? iso) {
    if (iso == null) return '2d';
    final dt = DateTime.tryParse(iso); if (dt == null) return '2d';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now'; if (diff.inMinutes < 60) return '${diff.inMinutes}m'; if (diff.inHours < 24) return '${diff.inHours}h'; return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Games Khabar', style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold))),
      body: RefreshIndicator(onRefresh: _loadFeed, child: isLoading? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: posts.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return Card(margin: const EdgeInsets.all(8), child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(20)), child: const Text("What's on your mind?", style: TextStyle(color: Colors.grey))))));
          final post = posts[index - 1];
          final userData = usersMap[post['user_id']?.toString()];
          final username = userData?['username']?? post['username']?? 'Unknown';
          final avatarUrl = userData?['avatar_url']?? '';
          final isLiked = likedPostIds.contains(post['id'].toString());
          return Card(margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0), color: Colors.white, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ListTile(leading: CircleAvatar(backgroundImage: avatarUrl.toString().isNotEmpty? NetworkImage(avatarUrl) : null), title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text(timeAgo(post['created_at']), style: const TextStyle(fontSize: 11, color: Colors.grey))),
            if (post['content']!= null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text(post['content'])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${post['likes_count']?? 0} Likes'), Text('${post['comments_count']?? 0} Comments')])),
            const Divider(height: 1),
            Row(children: [
              Expanded(child: InkWell(onTap: () => _handleLike(post), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isLiked? Icons.thumb_up : Icons.thumb_up_outlined, color: isLiked? Colors.blue : Colors.grey[700]), const SizedBox(width: 6), Text('Like', style: TextStyle(color: isLiked? Colors.blue : Colors.grey[700]))])))),
              Expanded(child: InkWell(onTap: () => _showComments(post['id'].toString()), child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline), SizedBox(width: 6), Text('Comment')])))),
              Expanded(child: InkWell(onTap: () => _handleShare(post), child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.share_outlined), SizedBox(width: 6), Text('Share')])))),
            ]),
          ]));
        },
      )),
    );
  }
}

class CommentSheet extends StatefulWidget {
  final String postId; final String? currentUserId;
  const CommentSheet({super.key, required this.postId, this.currentUserId});
  @override State<CommentSheet> createState() => _CommentSheetState();
}
class _CommentSheetState extends State<CommentSheet> {
  List<Map<String, dynamic>> comments = []; final ctrl = TextEditingController(); bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final data = await SupabaseService.client.from('comments').select('*').eq('post_id', widget.postId).order('created_at'); setState(() { comments = List<Map<String, dynamic>>.from(data); loading = false; }); } catch (e) { setState(() => loading = false); } }
  Future<void> _addComment() async { if (ctrl.text.trim().isEmpty) return; final text = ctrl.text.trim(); ctrl.clear(); try { await SupabaseService.client.from('comments').insert({'post_id': widget.postId, 'user_id': widget.currentUserId?? 'anon', 'content': text}); final postData = await SupabaseService.client.from('posts').select('comments_count').eq('id', widget.postId).single(); await SupabaseService.client.from('posts').update({'comments_count': (postData['comments_count']?? 0) + 1}).eq('id', widget.postId); _load(); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); } }
  @override Widget build(BuildContext context) { return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: SizedBox(height: 500, child: Column(children: [const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)), const Divider(), Expanded(child: loading? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: comments.length, itemBuilder: (_, i) => ListTile(title: Text(comments[i]['user_id']?? 'User'), subtitle: Text(comments[i]['content']?? '')))), Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Write a comment...'))), IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _addComment)]))]))); }
}