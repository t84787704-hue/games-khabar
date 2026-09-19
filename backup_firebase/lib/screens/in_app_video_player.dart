import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class InAppVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? title;
  const InAppVideoPlayer({super.key, required this.videoUrl, this.title});

  @override
  State<InAppVideoPlayer> createState() => _InAppVideoPlayerState();
}

class _InAppVideoPlayerState extends State<InAppVideoPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
      );
      if (mounted) setState(() {});
    } catch (e) {
      setState(() {
        _hasError = true;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(widget.title ?? 'GAMING CLIP • 720P', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: _hasError
            ? Text('Error: $_error', style: TextStyle(color: Colors.white))
            : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : CircularProgressIndicator(color: Color(0xFF00E5FF)),
      ),
    );
  }
}