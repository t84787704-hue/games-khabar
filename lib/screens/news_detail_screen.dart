import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NewsDetailScreen extends StatefulWidget {
  final Map<String, dynamic> news;
  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    String? url = widget.news['link'] ?? widget.news['videoUrl'] ?? '';
    String? videoId = YoutubePlayer.convertUrlToId(url);
    
    if (videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
        ),
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
      appBar: AppBar(backgroundColor: const Color(0xFF1E1E24), title: Text(widget.news['category'] ?? 'News')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.news['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // VIDEO PLAYER - Ab ad ke bina
            if (_controller != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: YoutubePlayer(controller: _controller!, showVideoProgressIndicator: true),
              )
            else
              // Agar YouTube ID na mile to Image dikhao
              if (widget.news['imageUrl'] != null && widget.news['imageUrl'].toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(widget.news['imageUrl']),
                ),

            const SizedBox(height: 20),
            Text(widget.news['content'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 15)),
            
            // AdMob Ad ko yahan neeche le aao - video ke upar se hata diya
            const SizedBox(height: 30),
            // Yahan apna Native Ad widget lagana hai to lagao, warna khali chhod do
          ],
        ),
      ),
    );
  }
}