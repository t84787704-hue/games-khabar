import 'package:flutter/material.dart';
import 'package:supabase_service.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String currentUserId;
  final VoidCallback? onCommentTap;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    this.onCommentTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool isLiked;
  late int likesCount;

  @override
  void initState() {
    super.initState();
    likesCount = (widget.post['likes_count']?? 0) as int;
    isLiked = false;
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    try {
      final liked = await SupabaseService.isPostLiked(
        widget.post['id'].toString(),
        widget.currentUserId,
      );
      if (mounted) setState(() => isLiked = liked);
    } catch (_) {}
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
    final post = widget.post;
    final users = post['users'] as Map<String, dynamic>?;
    final username = users?['username']?? users?['display_name']?? 'Unknown';
    final avatarUrl = users?['avatar_url']?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          ListTile(
            leading: CircleAvatar(
              radius: 22,
              backgroundImage: avatarUrl.isNotEmpty? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty? const Icon(Icons.person) : null,
            ),
            title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(timeAgo(post['created_at']), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: const Icon(Icons.more_horiz),
          ),
          // CONTENT
          if (post['content']!= null && post['content'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(post['content'], style: const TextStyle(fontSize: 15)),
            ),
          // IMAGE
          if (post['image_url']!= null && post['image_url'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.network(post['image_url'], width: double.infinity, fit: BoxFit.cover),
            ),
          if (post['media_url']!= null && post['media_url'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.network(post['media_url'], width: double.infinity, fit: BoxFit.cover),
            ),
          // COUNTS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.thumb_up, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text('$likesCount Likes', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ]),
                Text('${post['comments_count']?? 0} Comments', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          const Divider(height: 1),
          // BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _actionButton(
                icon: isLiked? Icons.thumb_up : Icons.thumb_up_outlined,
                label: 'Like',
                color: isLiked? Colors.blue : Colors.grey[700]!,
                onTap: () async {
                  final newVal = await SupabaseService.toggleLike(
                    postId: post['id'].toString(),
                    userId: widget.currentUserId,
                  );
                  setState(() {
                    isLiked = newVal;
                    likesCount += newVal? 1 : -1;
                  });
                },
              ),
              _actionButton(icon: Icons.chat_bubble_outline, label: 'Comment', color: Colors.grey[700]!, onTap: widget.onCommentTap),
              _actionButton(icon: Icons.share_outlined, label: 'Share', color: Colors.grey[700]!, onTap: () {}),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}