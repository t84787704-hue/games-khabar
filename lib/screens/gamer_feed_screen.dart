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
  bool isLoading = true;
  String? currentUserId;
  Set<String> likedPostIds = {};

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<String?> _getUid() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid!= null) {
      debugPrint('Firebase UID mila: $uid');
      return uid;
    }
    uid = await SupabaseService.getCurrentUserId();
    debugPrint('Supabase UID: $uid');
    return uid?? 'test_user_123';
  }

  Future<void> _loadFeed() async {
    setState(() => isLoading = true);
    currentUserId = await _getUid();
    debugPrint('FINAL currentUserId: $currentUserId');

    try {
      final data = await SupabaseService.client
         .from('posts')
         .select('*, users!posts_user_id_fkey(username, display_name, avatar_url)')
         .order('created_at', ascending: false)
         .limit(50);

      try {
        if (currentUserId!= null) {
          final myLikes = await SupabaseService.client.from('likes').select('post_id').eq('user_id', currentUserId!);
          likedPostIds = (myLikes as List).map((e) => e['post_id'].toString()).toSet();
        }
      } catch (e) {
        debugPrint('Likes fetch error (ignore): $e');
      }

      setState(() {
        posts = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Feed error $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Feed Error: $e')));
    }
  }

  Future<void> _handleLike(Map<String, dynamic> post) async {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login ID null hai')));
      return;
    }
    final postId = post['id'].toString();
    final isLiked = likedPostIds.contains(postId);

    setState(() {
      if (isLiked) {
        likedPostIds.remove(postId);
        post['likes_count'] = (post['likes_count']?? 1) - 1;
        if(post['likes_count'] < 0) post['likes_count'] = 0;
      } else {
        likedPostIds.add(postId);
        post['likes_count'] = (post['likes_count']?? 0) + 1;
      }
    });

    try {
      debugPrint('Like try: post $postId, user $currentUserId');
      if (isLiked) {
        await SupabaseService.client.from('likes').delete().eq('post_id', postId).eq('user_id', currentUserId!);
      } else {
        await SupabaseService.client.from('likes').insert({'post_id': postId, 'user_id': currentUserId!});
      }
      await SupabaseService.client.from('posts').update({'likes_count': post['likes_count']}).eq('id', postId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isLiked? 'Unliked' : 'Liked!'), duration: const Duration(milliseconds: 500)));
    } catch (e) {
      debugPrint('Like FAILED: $e');
      try {
        await SupabaseService.client.from('posts').update({'likes_count': post['likes_count']}).eq('id', postId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Liked (count only)')));
      } catch (e2) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e2')));
      }
    }
  }

  void _handleShare(Map<String, dynamic> post) {
    Share.share('Games Khabar: ${post['content']?? ''}');
  }

  void _showComments(String postId) {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => CommentSheet(postId: postId, currentUserId: currentUserId)).then((_) => _loadFeed());
  }

  String timeAgo(String? iso) {
    if (iso == null) return '2d';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '2d';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 1, title: Text('Games Khabar - ${currentUserId?.substring(0,6)?? "null"}', style: const TextStyle(color: Color(0xFF1877F2), fontSize: 14))),
      body: RefreshIndicator(onRefresh: _loadFeed, child: isLoading? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: posts.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(margin: const EdgeInsets.all(8), child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(20)), child: const Text("What's on your mind?", style: TextStyle(color: Colors.grey)))));
          }
          final post = posts[index - 1];
          final users = post['users'] as Map<String, dynamic>?;
          final username = users?['username']?? post['username']?? 'Unknown';
          final avatarUrl = users?['avatar_url']?? '';
          final isLiked = likedPostIds.contains(post['id'].toString());
          return Card(margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0), elevation: 0, color: Colors.white, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ListTile(leading: CircleAvatar(backgroundImage: avatarUrl.toString().isNotEmpty? NetworkImage(avatarUrl) : null, child: avatarUrl.toString().isEmpty? const Icon(Icons.person) : null), title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text(timeAgo(post['created_at']), style: const TextStyle(fontSize: 11, color: Colors.grey))),
            if (post['content']!= null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text(post['content'], style: const TextStyle(fontSize: 15))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${post['likes_count']?? 0} Likes', style: const TextStyle(fontSize: 13, color: Colors.grey)), Text('${post['comments_count']?? 0} Comments', style: const TextStyle(fontSize: 13, color: Colors.grey))])),
            const Divider(height: 1),
            Row(children: [
              Expanded(child: InkWell(onTap: () => _handleLike(post), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isLiked? Icons.thumb_up : Icons.thumb_up_outlined, size: 20, color: isLiked? Colors.blue : Colors.grey[700]), const SizedBox(width: 6), Text('Like', style: TextStyle(color: isLiked? Colors.blue : Colors.grey[700], fontWeight: isLiked? FontWeight.bold : FontWeight.normal))])))),
              Expanded(child: InkWell(onTap: () => _showComments(post['id'].toString()), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey[700]), const SizedBox(width: 6), Text('Comment', style: TextStyle(color: Colors.grey[700]))])))),
              Expanded(child: InkWell(onTap: () => _handleShare(post), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.share_outlined, size: 20, color: Colors.grey[700]), const SizedBox(width: 6), Text('Share', style: TextStyle(color: Colors.grey[700]))])))),
            ]),
          ]));
        },
      )),
    );
  }
}

class CommentSheet extends StatefulWidget {
  final String postId;
  final String? currentUserId;
  const CommentSheet({super.key, required this.postId, this.currentUserId});
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
    try {
      final data = await SupabaseService.client.from('comments').select('*').eq('post_id', widget.postId).order('created_at');
      setState(() { comments = List<Map<String, dynamic>>.from(data); loading = false; });
    } catch (e) {
      setState(() => loading = false);
    }
  }
  Future<void> _addComment() async {
    if (ctrl.text.trim().isEmpty) return;
    final text = ctrl.text.trim();
    ctrl.clear();
    try {
      await SupabaseService.client.from('comments').insert({'post_id': widget.postId, 'user_id': widget.currentUserId?? 'test_user', 'content': text, 'username': 'You'});
      final postData = await SupabaseService.client.from('posts').select('comments_count').eq('id', widget.postId).single();
      final newCount = (postData['comments_count']?? 0) + 1;
      await SupabaseService.client.from('posts').update({'comments_count': newCount}).eq('id', widget.postId);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Comment error: $e')));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: SizedBox(height: 500, child: Column(children: [
      const SizedBox(height: 12), Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))), const SizedBox(height: 12), const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)), const Divider(),
      Expanded(child: loading? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: comments.length, itemBuilder: (_, i) { final c = comments[i]; return ListTile(title: Text(c['username']?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text(c['content']?? '')); })),
      Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: ctrl, decoration: InputDecoration(hintText: 'Write a comment...', filled: true, fillColor: const Color(0xFFF0F2F5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))), IconButton(icon: const Icon(Icons.send, color: Color(0xFF1877F2)), onPressed: _addComment)]))
    ])));
  }
}