import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:games_khabar/models/news_model.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsModel news;
  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    // Video URL jo bhi field me hai usko try karo
    final String url = widget.news.videoUrl ?? widget.news.link ?? widget.news.imageUrl ?? '';
    final String? videoId = YoutubePlayer.convertUrlToId(url);
    
    if (videoId != null && videoId.isNotEmpty) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(widget.news.category ?? 'PUBG'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.news.title ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Video - Ad ke bina
            if (_controller != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: YoutubePlayer(controller: _controller!, showVideoProgressIndicator: true),
              )
            else if (widget.news.imageUrl != null && widget.news.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(widget.news.imageUrl!),
              ),

            const SizedBox(height: 20),
            Text(widget.news.content ?? widget.news.description ?? '', style: const TextStyle(color: Colors.white70, fontSize: 15)),
            
            // Ad yahan neeche lagana hai to lagao, video ke upar mat lagana
          ],
        ),
      ),
    );
  }
}