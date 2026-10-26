// ===============================================================================
// ADMIN POSTS MODERATION TAB — Review & Moderate Community Posts
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';

class AdminPostsModerationTab extends StatefulWidget {
  const AdminPostsModerationTab({super.key});

  @override
  State<AdminPostsModerationTab> createState() => AdminPostsModerationTabState();
}

class AdminPostsModerationTabState extends State<AdminPostsModerationTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deletePost(String postId) async {
    try {
      await SupabaseService.client.from('posts').delete().eq('id', postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted by admin.'),
            backgroundColor: Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting post: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search community posts...',
              hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00FF88), size: 18),
              filled: true,
              fillColor: ThemeService.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeService.border)),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.getRealtimePosts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
              }

              final posts = snapshot.data ?? [];
              final filteredPosts = posts.where((p) {
                if (_searchQuery.isEmpty) return true;
                final content = (p['content'] ?? p['caption'] ?? '').toString().toLowerCase();
                return content.contains(_searchQuery);
              }).toList();

              if (filteredPosts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: ThemeService.card, shape: BoxShape.circle, border: Border.all(color: ThemeService.border)),
                          child: const Icon(Icons.dynamic_feed_rounded, color: Color(0xFF00FF88), size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text('No posts found', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filteredPosts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final post = filteredPosts[index];
                  final postId = post['id']?.toString() ?? '';
                  final content = (post['content'] ?? post['caption'] ?? 'No content').toString();
                  final mediaUrl = post['media_url'] ?? post['image_url'] ?? '';
                  final authorName = post['username'] ?? post['gamer_name'] ?? 'Gamer';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ThemeService.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, color: Color(0xFF00FF88), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authorName,
                                style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4655), size: 20),
                              tooltip: 'Delete Post',
                              onPressed: () => _deletePost(postId),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          content,
                          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (mediaUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: mediaUrl,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
