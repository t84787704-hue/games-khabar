import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/clip_service.dart';
import '../services/cloudinary_service.dart';

/// Full-featured Clip / Meme creation modal with Video Preview,
/// Dual-handle Trimming slider, quick duration presets,
/// Cloudinary direct video upload with progress & cancel,
/// and instant Firestore sync.
class ClipUploadModalSheet extends StatefulWidget {
  final GamerUser currentGamer;
  final VoidCallback onUploadSuccess;

  const ClipUploadModalSheet({
    super.key,
    required this.currentGamer,
    required this.onUploadSuccess,
  });

  @override
  State<ClipUploadModalSheet> createState() => _ClipUploadModalSheetState();
}

class _ClipUploadModalSheetState extends State<ClipUploadModalSheet> {
  final TextEditingController _titleController = TextEditingController();
  final ClipService _clipService = ClipService();

  String? _selectedTag;
  File? _pickedFile;
  String? _fileName;
  int? _fileSizeBytes;
  bool _isVideo = true;

  // Video playback & trim state
  VideoPlayerController? _previewController;
  bool _isControllerInitialized = false;
  Duration _videoTotalDuration = Duration.zero;
  RangeValues _trimRange = const RangeValues(0, 0); // In seconds
  bool _isTrimming = false;

  // Upload status & progress
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatusText = '';
  bool _uploadCancelled = false;

  final List<String> _availableGameTags = const [
    'BGMI',
    'PUBG Mobile',
    'Free Fire',
    'Free Fire Max',
    'COD Mobile',
    'Valorant',
    'Fortnite',
    'Apex Legends',
    'Counter-Strike 2',
    'Clash Royale',
    'Brawl Stars',
    'Minecraft',
    'Roblox',
    '8 Ball Pool',
    'Ludo King',
    'Gaming Meme',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _previewController?.pause();
    _previewController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatSeconds(double sec) {
    final s = sec.round();
    final minutes = s ~/ 60;
    final remaining = s % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  bool _isNonGaming(String text, String fname) {
    final combined = '$text $fname'.toLowerCase();
    final nonGamingWords = [
      'car', 'cars', 'automobile', 'vehicle', 'driving', 'traffic', 'bmw', 'mercedes', 'audi',
      'lamborghini', 'ferrari', 'porsche', 'supercar', 'honda', 'bike', 'motorcycle', 'vlog',
      'cooking', 'recipe', 'food', 'restaurant', 'fashion', 'makeup', 'beauty', 'outfit',
      'gym', 'workout', 'fitness', 'dance', 'dancing', 'wedding', 'marriage', 'politics',
      'election', 'news', 'crypto', 'forex', 'stock', 'trading', 'baby', 'cat video', 'dog video',
      'real estate', 'house tour', 'shopping haul', 'travel vlog'
    ];
    final gamingAllowed = [
      'bgmi', 'pubg', 'free fire', 'cod', 'call of duty', 'valorant', 'fortnite', 'apex',
      'minecraft', 'roblox', 'clash royale', 'brawl stars', 'gta', 'asphalt', 'need for speed',
      'forza', 'rocket league', 'gameplay', 'clutch', 'sniper', 'kill', 'headshot', 'lobby'
    ];
    for (final w in nonGamingWords) {
      final reg = RegExp(r'\b' + RegExp.escape(w) + r'\b', caseSensitive: false);
      if (reg.hasMatch(combined)) {
        final hasGameContext = gamingAllowed.any((g) => combined.contains(g));
        if (!hasGameContext) return true;
      }
    }
    return false;
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);
      final size = await file.length();

      // Check max size 150MB
      const maxSizeBytes = 150 * 1024 * 1024;
      if (size > maxSizeBytes) {
        final mb = (size / (1024 * 1024)).toStringAsFixed(1);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video is too large ($mb MB). Max 150MB allowed!'),
              backgroundColor: GamerTheme.redAccent,
            ),
          );
        }
        return;
      }

      // Initialize preview video player to get duration
      await _previewController?.pause();
      await _previewController?.dispose();
      _previewController = null;
      _isControllerInitialized = false;

      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      final totalDuration = controller.value.duration;
      // Max duration 3 minutes
      if (totalDuration.inSeconds > 185) {
        await controller.dispose();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Max 3 min allowed! Please pick a video under 3 minutes.'),
              backgroundColor: GamerTheme.redAccent,
            ),
          );
        }
        return;
      }

      await controller.setLooping(false);
      await controller.setVolume(1.0);

      final totalSec = totalDuration.inSeconds.toDouble().clamp(1.0, 180.0);

      // Add listener to loop within trim range
      controller.addListener(() {
        if (!mounted || _previewController == null) return;
        final currentSec = _previewController!.value.position.inMilliseconds / 1000.0;
        if (currentSec >= _trimRange.end) {
          _previewController!.seekTo(Duration(milliseconds: (_trimRange.start * 1000).round()));
        }
      });

      setState(() {
        _pickedFile = file;
        _fileName = picked.name.isNotEmpty ? picked.name : file.path.split('/').last;
        _fileSizeBytes = size;
        _isVideo = true;
        _previewController = controller;
        _isControllerInitialized = true;
        _videoTotalDuration = totalDuration;
        _trimRange = RangeValues(0, totalSec);
      });

      _previewController?.play();
    } catch (e) {
      debugPrint('Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load video: $e'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    }
  }

  void _applyQuickTrim(double seconds) {
    if (!_isControllerInitialized || _videoTotalDuration.inSeconds == 0) return;
    final total = _videoTotalDuration.inSeconds.toDouble();
    if (seconds >= total) {
      // Full
      setState(() {
        _trimRange = RangeValues(0, total);
      });
    } else {
      setState(() {
        _trimRange = RangeValues(0, seconds.clamp(1.0, total));
      });
    }
    _previewController?.seekTo(Duration(milliseconds: (_trimRange.start * 1000).round()));
    _previewController?.play();
  }

  Future<void> _startUpload() async {
    // 1. Validation
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video clip from phone first!')),
      );
      return;
    }

    final caption = _titleController.text.trim();
    if (caption.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Caption must be at least 3 characters!'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }

    if (_selectedTag == null || _selectedTag!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game Tag is REQUIRED! Please select BGMI, PUBG Mobile etc.'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }

    // Gaming rule check
    if (_isNonGaming(caption, _fileName ?? '')) {
      if (_selectedTag != 'Gaming Meme') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only gaming clips allowed! If this is a meme, select the "Gaming Meme" tag.'),
            backgroundColor: GamerTheme.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _uploadStatusText = 'Preparing clip for upload...';
      _uploadCancelled = false;
    });

    _previewController?.pause();

    try {
      final originalDuration = _videoTotalDuration.inSeconds.toDouble();
      final trimmedDuration = (_trimRange.end - _trimRange.start).clamp(1.0, originalDuration > 0 ? originalDuration : 180.0);

      setState(() {
        _uploadStatusText = 'Uploading to Cloudinary (0%)... 🚀';
      });

      // Upload with progress stream directly to Cloudinary
      await _clipService.uploadClip(
        file: _pickedFile!,
        userId: widget.currentGamer.uid,
        caption: caption,
        username: widget.currentGamer.username,
        displayName: widget.currentGamer.displayName,
        userAvatar: widget.currentGamer.photoUrl,
        gameTag: _selectedTag!,
        songTitle: 'Original Audio - ${widget.currentGamer.displayName}',
        isVideo: true,
        trimmedDuration: trimmedDuration,
        originalDuration: originalDuration,
        onProgress: (progress) {
          if (mounted && !_uploadCancelled) {
            setState(() {
              _uploadProgress = progress;
              _uploadStatusText = 'Uploading to Cloudinary (${(progress * 100).toInt()}%)... 🚀';
            });
          }
        },
        isCancelled: () => _uploadCancelled,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 1.0;
        });
        Navigator.pop(context);
        widget.onUploadSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔥 Gaming clip uploaded to Cloudinary and live in feed!'),
            backgroundColor: GamerTheme.accentOrange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadStatusText = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: GamerTheme.redAccent,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canShare = !_isUploading &&
        _pickedFile != null &&
        _titleController.text.trim().length >= 3 &&
        _selectedTag != null;

    final selectedDurationSec = (_trimRange.end - _trimRange.start).clamp(0.0, 180.0);

    return Container(
      decoration: const BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GamerTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                const Text('🎬', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'POST GAMING CLIP / MEME',
                    style: TextStyle(
                      color: GamerTheme.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (_isUploading)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: GamerTheme.redAccent),
                    tooltip: 'Cancel Upload',
                    onPressed: () {
                      setState(() {
                        _uploadCancelled = true;
                        _isUploading = false;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Video Picker / Preview Area
            const Text(
              'SELECT CLIP FROM PHONE (GALLERY)',
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            if (_pickedFile == null) ...[
              InkWell(
                onTap: _isUploading ? null : _pickVideoFromGallery,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: GamerTheme.bgDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: GamerTheme.accentOrange.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: GamerTheme.accentOrange.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.video_library_rounded, color: GamerTheme.accentOrange, size: 32),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'SELECT CLIP FROM PHONE 📱',
                        style: TextStyle(
                          color: GamerTheme.accentOrange,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pick MP4 / MOV screen recording from gallery\n(Max 150MB, Max 3 minutes)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: GamerTheme.textMuted, fontSize: 11.5, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Video Player Preview Box
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: GamerTheme.bgDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GamerTheme.accentOrange, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.black,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isControllerInitialized && _previewController != null)
                              AspectRatio(
                                aspectRatio: _previewController!.value.aspectRatio > 0
                                    ? _previewController!.value.aspectRatio
                                    : (16 / 9),
                                child: VideoPlayer(_previewController!),
                              )
                            else
                              const CircularProgressIndicator(color: GamerTheme.accentOrange),

                            // Overlay Play / Pause Button
                            if (_isControllerInitialized && _previewController != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_previewController!.value.isPlaying) {
                                      _previewController!.pause();
                                    } else {
                                      _previewController!.play();
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white30),
                                  ),
                                  child: Icon(
                                    _previewController!.value.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),

                            // Top Info Badges
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black75,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam_rounded, color: GamerTheme.accentOrange, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(_fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: GamerTheme.accentOrange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Trim: ${_formatSeconds(selectedDurationSec)}',
                                  style: const TextStyle(color: GamerTheme.bgDark, fontWeight: FontWeight.w900, fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Trimmer Section
                    if (_isControllerInitialized && _videoTotalDuration.inSeconds > 0) ...[
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.content_cut_rounded, color: GamerTheme.accentOrange, size: 16),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'VIDEO TRIMMER',
                                      style: TextStyle(
                                        color: GamerTheme.accentOrange,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Selected: ${_formatSeconds(selectedDurationSec)} / Total: ${_formatDuration(_videoTotalDuration)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Range Slider
                            RangeSlider(
                              values: _trimRange,
                              min: 0.0,
                              max: _videoTotalDuration.inSeconds.toDouble().clamp(1.0, 180.0),
                              divisions: _videoTotalDuration.inSeconds > 0 ? _videoTotalDuration.inSeconds : null,
                              activeColor: GamerTheme.accentOrange,
                              inactiveColor: GamerTheme.borderLight,
                              labels: RangeLabels(
                                _formatSeconds(_trimRange.start),
                                _formatSeconds(_trimRange.end),
                              ),
                              onChanged: _isUploading
                                  ? null
                                  : (values) {
                                      if (values.end - values.start < 1.0) return;
                                      setState(() {
                                        _trimRange = values;
                                      });
                                      _previewController?.seekTo(
                                        Duration(milliseconds: (values.start * 1000).round()),
                                      );
                                    },
                            ),

                            // Quick Trim Buttons
                            Row(
                              children: [
                                const Text('Quick:', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                _buildQuickButton('15s', 15.0),
                                const SizedBox(width: 6),
                                _buildQuickButton('30s', 30.0),
                                const SizedBox(width: 6),
                                _buildQuickButton('60s', 60.0),
                                const SizedBox(width: 6),
                                _buildQuickButton('Full', _videoTotalDuration.inSeconds.toDouble()),
                                const Spacer(),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: GamerTheme.textMuted,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                  onPressed: _isUploading ? null : _pickVideoFromGallery,
                                  icon: const Icon(Icons.sync_rounded, size: 14),
                                  label: const Text('Change', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Clip Caption / Title
            const Text(
              'CLIP CAPTION / TITLE',
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              enabled: !_isUploading,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'e.g. Crazy 1v4 clutch in Bootcamp! 🔥 #BGMI',
                hintStyle: const TextStyle(color: GamerTheme.textMuted),
                filled: true,
                fillColor: GamerTheme.bgDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: GamerTheme.borderDark),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),

            // Required Game Tag selection
            Row(
              children: [
                const Text(
                  'SELECT GAME TAG',
                  style: TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GamerTheme.accentOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'REQUIRED',
                    style: TextStyle(color: GamerTheme.accentOrange, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _availableGameTags.map((tag) {
                final isSel = _selectedTag == tag;
                return GestureDetector(
                  onTap: _isUploading ? null : () => setState(() => _selectedTag = tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSel ? GamerTheme.accentOrange : GamerTheme.bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? GamerTheme.accentOrange : GamerTheme.borderLight,
                        width: isSel ? 1.5 : 1,
                      ),
                      boxShadow: isSel
                          ? [BoxShadow(color: GamerTheme.accentOrange.withOpacity(0.3), blurRadius: 4)]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSel) ...[
                          const Icon(Icons.check, color: GamerTheme.bgDark, size: 12),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          tag,
                          style: TextStyle(
                            color: isSel ? GamerTheme.bgDark : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w900 : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Gaming Only Notice
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GamerTheme.accentOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sports_esports_rounded, color: GamerTheme.accentOrange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GAMING CLIPS & MEMES ONLY',
                          style: TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Only gaming screen recordings and memes allowed. Non-gaming videos (cars, vlogs, etc.) are strictly prohibited unless tagged as Gaming Meme.',
                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Upload Progress Bar
            if (_isUploading) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.bgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: GamerTheme.accentOrange),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _uploadStatusText.isNotEmpty ? _uploadStatusText : 'Uploading clip to Cloudinary...',
                              style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _uploadCancelled = true;
                              _isUploading = false;
                            });
                          },
                          child: const Text('Cancel', style: TextStyle(color: GamerTheme.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        minHeight: 6,
                        backgroundColor: GamerTheme.borderDark,
                        color: GamerTheme.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Share Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canShare ? GamerTheme.accentOrange : GamerTheme.borderDark,
                  foregroundColor: canShare ? GamerTheme.bgDark : Colors.white38,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: canShare ? 3 : 0,
                ),
                onPressed: canShare ? _startUpload : null,
                child: _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: GamerTheme.bgDark),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'UPLOADING TO CLOUDINARY... ⏳',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        ],
                      )
                    : const Text(
                        'SHARE TO CLIPS FEED 🚀',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String label, double seconds) {
    return InkWell(
      onTap: _isUploading ? null : () => _applyQuickTrim(seconds),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: GamerTheme.bgDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GamerTheme.borderLight),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
