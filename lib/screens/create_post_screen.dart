import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/gamer_post_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  String _selectedGame = 'Mobile Games';

  Future<void> _publishPost() async {
    // Resolve Supabase UUID or Auth UID
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    String? userId = await SupabaseService.getCurrentUserId();
    if (userId == null || !uuidRegex.hasMatch(userId)) {
      final currentUid = GamerAuthService().currentUid;
      if (currentUid != null && uuidRegex.hasMatch(currentUid)) {
        userId = currentUid;
      }
    }

    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login nahi ho, pehle login karo')),
      );
      return;
    }

    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kuch likho to sahi')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentGamer = GamerAuthService().currentGamer;
      final username = (currentGamer?.username.isNotEmpty == true) ? currentGamer!.username : 'mtk';
      final displayName = (currentGamer?.displayName.isNotEmpty == true) ? currentGamer!.displayName : 'M*TK';
      final userPhoto = currentGamer?.photoUrl ?? '';

      final newPost = GamerPost(
        postId: const Uuid().v4(),
        userId: userId,
        username: username,
        userPhoto: userPhoto,
        displayName: displayName,
        text: _textController.text.trim(),
        gameTag: _selectedGame == 'Mobile Games' ? 'BGMI' : _selectedGame,
        userRank: 'Ace',
        userKd: 2.5,
        likesCount: 0,
        commentsCount: 0,
      );

      // Supabase me insert via SupabaseService.client
      await SupabaseService.client.from('posts').insert(newPost.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: _publishPost,
                  child: const Text('POST', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(child: Text('M')),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('M*TK', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('@mtk', style: TextStyle(color: Colors.orange)),
                  ],
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _selectedGame,
                  items: const [
                    DropdownMenuItem(value: 'Mobile Games', child: Text('Mobile Games')),
                    DropdownMenuItem(value: 'BGMI', child: Text('BGMI')),
                    DropdownMenuItem(value: 'Free Fire', child: Text('Free Fire')),
                    DropdownMenuItem(value: 'COD Mobile', child: Text('COD Mobile')),
                  ],
                  onChanged: (v) => setState(() => _selectedGame = v!),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'hhh',
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}