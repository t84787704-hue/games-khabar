import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../constants/gamer_theme.dart'; // اپنے پروجیکٹ کا صحیح راستہ چیک کر لیں

class InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const InlineVideoPlayer({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _InlineVideoPlayerState createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  bool _isPlaying = false;
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  Future<void> _playVideo() async {
    setState(() {
      _isPlaying = true;
    });

    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _videoPlayerController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      // فل اسکرین بٹن خود بخود کام کرے گا
    );
    setState(() {});
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPlaying) {
      // اگر ویڈیو چل رہی ہے تو پلیئر دکھائیں
      return Container(
        height: 210,
        width: double.infinity,
        color: Colors.black,
        child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
            ? AspectRatio(
                aspectRatio: _videoPlayerController.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              )
            : const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue)),
      );
    } else {
      // اگر ویڈیو نہیں چل رہی تو تھمب نیل دکھائیں
      return InkWell(
        onTap: _playVideo,
        child: Container(
          height: 210,
          width: double.infinity,
          color: GamerTheme.cardElevated,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: widget.videoUrl.endsWith('.mp4')
                    ? widget.videoUrl.replaceAll('.mp4', '.jpg')
                    : '${widget.videoUrl}.jpg',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: GamerTheme.surfaceDark,
                  child: const Center(
                    child: Icon(Icons.videogame_asset_rounded, color: GamerTheme.textMuted, size: 48),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: GamerTheme.blueOrangeGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: GamerTheme.accentBlue.withOpacity(0.5), blurRadius: 16, spreadRadius: 2),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: GamerTheme.neonGreen, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'GAMING CLIP • 720P',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 12),
                      SizedBox(width: 4),
                      Text('Tap to Play', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}