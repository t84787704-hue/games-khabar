import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';

class PostCard extends StatefulWidget {
  final dynamic post; // Tumhara post model
  final VoidCallback? onDeleteTap; // Firestore se delete ka function parent se ayega
  const PostCard({Key? key, required this.post, this.onDeleteTap}) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  String get cloudUrl {
    return (widget.post?.videoUrl ?? widget.post?.cloudinaryUrl ?? widget.post?.video)?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (cloudUrl.isEmpty) return;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(cloudUrl));
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: false,
      looping: false,
    );
    if (mounted) setState(() {});
  }

  // --- YAHAN SE SHARE FIX HAI ---
  Future<void> _sharePost() async {
    final appLink = 'https://play.google.com/store/apps/details?id=com.gamersid.app';
    final deepLink = (widget.post?.id != null) ? 'https://gamersid.com/post/${widget.post.id}' : '';
    
    final buffer = StringBuffer();
    final username = widget.post?.username?.toString() ?? '';
    final caption = widget.post?.caption?.toString() ?? '';
    final game = widget.post?.game?.toString() ?? '';

    if (username.isNotEmpty) buffer.writeln('🎮 $username on Gamers ID');
    if (caption.isNotEmpty) buffer.writeln(caption);
    if (game.isNotEmpty) buffer.writeln('Game: $game');
    
    if (cloudUrl.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(cloudUrl); // Cloudinary link alag line pe taake WhatsApp preview de
    }
    buffer.writeln();
    buffer.writeln('Get the app: $appLink');
    if (deepLink.isNotEmpty) buffer.writeln('View post: $deepLink');

    await Share.share(buffer.toString().trim());
  }

  // --- YAHAN SE DELETE AUDIO FIX HAI ---
  Future<void> _deletePost() async {
    // 1. Pehle audio band karo
    await _videoController?.pause();
    await _chewieController?.pause();
    // 2. Memory se maro
    await _videoController?.dispose();
    _chewieController?.dispose();
    _videoController = null;
    _chewieController = null;
    
    // 3. Ab parent ko bolo Firestore se delete kare
    widget.onDeleteTap?.call();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(widget.post?.username?.toString() ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(widget.post?.game?.toString() ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.share), onPressed: _sharePost),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deletePost),
              ],
            ),
          ),
          if (widget.post?.caption != null)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text(widget.post.caption.toString())),
          
          // Video Player
          if (_chewieController != null && _videoController!.value.isInitialized)
            AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: Chewie(controller: _chewieController!))
          else if (cloudUrl.isNotEmpty)
            Container(height: 200, color: Colors.black12, child: const Center(child: CircularProgressIndicator()))
        ],
      ),
    );
  }
}