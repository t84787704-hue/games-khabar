import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import '../constants/gamer_theme.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';

/// Full-featured Clip / Meme creation modal with Video Preview,
/// Dual-handle Trimming slider, quick duration presets,
/// Direct Cloudinary video upload with progress, and instant Firestore sync.
class ClipUploadModalSheet extends StatefulWidget {
  final GamerUser? currentGamer;
  final VoidCallback? onUploadSuccess;

  const ClipUploadModalSheet({
    super.key,
    this.currentGamer,
    this.onUploadSuccess,
  });

  @override
  State<ClipUploadModalSheet> createState() => _ClipUploadModalSheetState();
}

class _ClipUploadModalSheetState extends State<ClipUploadModalSheet> {
  // 1. STATE VARIABLES as specified
  File? selectedVideoFile;
  String? selectedVideoPath;
  String? selectedVideoName;
  int? selectedVideoSizeBytes;

  VideoPlayerController? videoController;
  bool isVideoLoading = false;
  Duration videoDuration = Duration.zero;

  bool isUploading = false;
  double uploadProgress = 0.0;
  String uploadStatusText = '';
  bool isCancelled = false;

  String selectedGameTag = '';
  final TextEditingController captionController = TextEditingController();
  RangeValues trimRange = const RangeValues(0, 30);

  final List<String> availableGameTags = const [
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
  void initState() {
    super.initState();
    captionController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    captionController.dispose();
    videoController?.pause();
    videoController?.dispose();
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

  // 2. PICK VIDEO FUNCTION
  Future<void> pickVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      if (picked == null) return;

      final file = File(picked.path);
      final exists = await file.exists();
      if (!exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video file could not be accessed.'),
              backgroundColor: GamerTheme.redAccent,
            ),
          );
        }
        return;
      }

      final size = await file.length();
      const maxSizeBytes = 150 * 1024 * 1024; // 150MB
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

      // Set state IMMEDIATELY so the UI and share button logic update without waiting
      setState(() {
        selectedVideoFile = file;
        selectedVideoPath = file.path;
        selectedVideoName = picked.name.isNotEmpty ? picked.name : file.path.split('/').last;
        selectedVideoSizeBytes = size;
        isVideoLoading = true;
      });

      // Safely initialize preview player
      await _initializeVideoPreview(file);
    } catch (e) {
      debugPrint('Error in pickVideo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting video: $e'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _initializeVideoPreview(File file) async {
    try {
      await videoController?.pause();
      await videoController?.dispose();
      videoController = null;

      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      final totalDuration = controller.value.duration;
      final totalSec = totalDuration.inSeconds.toDouble().clamp(1.0, 180.0);

      await controller.setLooping(false);
      await controller.setVolume(1.0);

      controller.addListener(() {
        if (!mounted || videoController == null) return;
        final currentSec = videoController!.value.position.inMilliseconds / 1000.0;
        if (currentSec >= trimRange.end) {
          videoController!.seekTo(Duration(milliseconds: (trimRange.start * 1000).round()));
        }
      });

      if (mounted) {
        setState(() {
          videoController = controller;
          videoDuration = totalDuration;
          trimRange = RangeValues(0, totalSec);
          isVideoLoading = false;
        });
        controller.play();
      }
    } catch (e) {
      debugPrint('VideoPlayer preview warning: $e');
      if (mounted) {
        setState(() {
          isVideoLoading = false;
          // Even if local playback preview fails to decode, video is selected and ready to upload
          if (videoDuration == Duration.zero) {
            videoDuration = const Duration(seconds: 30);
            trimRange = const RangeValues(0, 30);
          }
        });
      }
    }
  }

  // 3. TRIMMER PRESETS
  void _applyQuickTrim(double seconds) {
    final total = videoDuration.inSeconds > 0 ? videoDuration.inSeconds.toDouble() : 30.0;
    setState(() {
      if (seconds >= total) {
        trimRange = RangeValues(0, total);
      } else {
        trimRange = RangeValues(0, seconds.clamp(1.0, total));
      }
    });
    videoController?.seekTo(Duration(milliseconds: (trimRange.start * 1000).round()));
    videoController?.play();
  }

  // 4. CLOUDINARY DIRECT UPLOAD
  Future<Map<String, dynamic>> _uploadToCloudinary({
    required File file,
    required double trimStart,
    required double trimEnd,
    required void Function(double progress) onProgress,
  }) async {
    const cloudName = 'fka9mgwu';
    final presets = ['gaming_clips_preset', 'clips_preset'];

    for (final preset in presets) {
      try {
        final client = http.Client();
        final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');
        final fileSize = await file.length();

        final request = http.MultipartRequest('POST', uri);
        request.fields['upload_preset'] = preset;
        request.fields['folder'] = 'gaming_clips';
        request.fields['tags'] = 'gaming,${selectedGameTag.isNotEmpty ? selectedGameTag : "bgmi"}';

        int bytesSent = 0;
        final fileStream = file.openRead();
        final progressStream = fileStream.transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (data, sink) {
              if (isCancelled) {
                sink.addError(Exception('Upload cancelled by user'));
                return;
              }
              bytesSent += data.length;
              sink.add(data);
              if (fileSize > 0) {
                final prog = (bytesSent / fileSize).clamp(0.0, 0.98);
                onProgress(prog);
              }
            },
          ),
        );

        final filename = file.path.split('/').last;
        final multipartFile = http.MultipartFile(
          'file',
          progressStream,
          fileSize,
          filename: filename.isNotEmpty ? filename : 'clip.mp4',
        );
        request.files.add(multipartFile);

        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);
        client.close();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final rawSecureUrl = data['secure_url']?.toString() ?? '';
          final publicId = data['public_id']?.toString() ?? '';
          final duration = (data['duration'] as num?)?.toDouble() ?? 0.0;

          if (rawSecureUrl.isEmpty) {
            throw Exception('Empty secure_url returned by Cloudinary');
          }

          onProgress(1.0);

          // Apply Cloudinary video trimming transformation if trimmed
          String finalVideoUrl = rawSecureUrl;
          final totalSec = duration > 0 ? duration : (videoDuration.inSeconds > 0 ? videoDuration.inSeconds.toDouble() : 0.0);
          final trimmedDuration = (trimEnd - trimStart).clamp(1.0, totalSec > 0 ? totalSec : 180.0);

          if (totalSec > 0 && (trimStart > 0.5 || trimEnd < totalSec - 0.5)) {
            // Trim via Cloudinary URL transformation: so_<start>,eo_<end>
            final startInt = trimStart.round();
            final endInt = trimEnd.round();
            if (finalVideoUrl.contains('/video/upload/')) {
              finalVideoUrl = finalVideoUrl.replaceAll(
                '/video/upload/',
                '/video/upload/so_$startInt,eo_$endInt/',
              );
            }
          }

          // Auto thumbnail at trim start
          final startInt = trimStart.round();
          String thumbnailUrl = '';
          if (rawSecureUrl.contains('/video/upload/')) {
            thumbnailUrl = rawSecureUrl
                .replaceAll('/video/upload/', '/video/upload/so_$startInt,w_400,h_700,c_fill/')
                .replaceAll(RegExp(r'\.(mp4|mov|mkv|webm)(\?.*)?$', caseSensitive: false), '.jpg');
          } else {
            thumbnailUrl = rawSecureUrl.replaceAll(RegExp(r'\.(mp4|mov|mkv|webm).*'), '.jpg');
          }

          return {
            'videoUrl': finalVideoUrl,
            'thumbnailUrl': thumbnailUrl,
            'publicId': publicId,
            'duration': trimmedDuration,
            'originalDuration': totalSec > 0 ? totalSec : duration,
          };
        } else {
          debugPrint('Cloudinary preset $preset returned error ${response.statusCode}: ${response.body}');
        }
      } catch (err) {
        debugPrint('Cloudinary attempt with preset $preset failed: $err');
      }
    }

    throw Exception('Failed to upload video to Cloudinary. Please check your internet connection.');
  }

  // 5. SHARE BUTTON TAP
  Future<void> _handleShare() async {
    if (selectedVideoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video clip from phone first!')),
      );
      return;
    }

    final caption = captionController.text.trim();
    if (caption.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Caption must be at least 3 characters!'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }

    if (selectedGameTag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game Tag is REQUIRED! Please select BGMI, PUBG Mobile etc.'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }

    // Gaming content check
    if (_isNonGaming(caption, selectedVideoName ?? '')) {
      if (selectedGameTag != 'Gaming Meme') {
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
      isUploading = true;
      uploadProgress = 0.05;
      uploadStatusText = 'Connecting to Cloudinary... 🚀';
      isCancelled = false;
    });

    videoController?.pause();

    try {
      // Step 1: Upload directly to Cloudinary (No Firebase Storage!)
      final uploadResult = await _uploadToCloudinary(
        file: selectedVideoFile!,
        trimStart: trimRange.start,
        trimEnd: trimRange.end,
        onProgress: (progress) {
          if (mounted && !isCancelled) {
            setState(() {
              uploadProgress = progress;
              uploadStatusText = 'Uploading to Cloudinary (${(progress * 100).toInt()}%)... 🚀';
            });
          }
        },
      );

      final videoUrl = uploadResult['videoUrl'] as String;
      final thumbnailUrl = uploadResult['thumbnailUrl'] as String;
      final publicId = uploadResult['publicId'] as String;
      final duration = uploadResult['duration'] as double;
      final originalDuration = uploadResult['originalDuration'] as double;

      setState(() {
        uploadStatusText = 'Publishing clip to Feed... ⚡';
      });

      // Step 2: Save metadata to Firestore collection 'clips'
      final gamer = widget.currentGamer ?? GamerAuthService().currentGamer;
      final currentUid = gamer?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_gamer';
      final username = gamer?.username ?? 'gamer';
      final displayName = gamer?.displayName ?? 'Gamer';
      final userAvatar = gamer?.photoUrl ?? '';

      final docRef = FirebaseFirestore.instance.collection('clips').doc();
      await docRef.set({
        'id': docRef.id,
        'videoUrl': videoUrl,
        'mediaUrl': videoUrl,
        'thumbnail': thumbnailUrl,
        'thumbnailUrl': thumbnailUrl,
        'publicId': publicId,
        'caption': caption,
        'title': caption,
        'gameTag': selectedGameTag,
        'songTitle': 'Original Audio - $displayName',
        'duration': duration,
        'originalDuration': originalDuration,
        'uploaderId': currentUid,
        'userId': currentUid,
        'authorId': currentUid,
        'username': username,
        'displayName': displayName,
        'userAvatar': userAvatar,
        'isGamingClip': true,
        'likes': 0,
        'views': 0,
        'likesCount': 0,
        'viewsCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'likedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          isUploading = false;
          uploadProgress = 1.0;
        });
        Navigator.pop(context);
        widget.onUploadSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔥 Gaming clip uploaded to Cloudinary and live in feed!'),
            backgroundColor: GamerTheme.accentOrange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload failure: $e');
      if (mounted) {
        setState(() {
          isUploading = false;
          uploadProgress = 0.0;
          uploadStatusText = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: GamerTheme.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 5. SHARE BUTTON LOGIC - Button enabled ONLY when:
    // selectedVideoFile != null && captionController.text.length >= 3 && selectedGameTag != ""
    final hasVideo = selectedVideoFile != null;
    final hasCaption = captionController.text.trim().length >= 3;
    final hasTag = selectedGameTag.isNotEmpty;
    final canShare = !isUploading && hasVideo && hasCaption && hasTag;

    final selectedDurationSec = (trimRange.end - trimRange.start).clamp(0.0, 180.0);

    return Container(
      decoration: const BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle
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
            const SizedBox(height: 14),

            // Header Row
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
                if (isUploading)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: GamerTheme.redAccent),
                    tooltip: 'Cancel Upload',
                    onPressed: () {
                      setState(() {
                        isCancelled = true;
                        isUploading = false;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Video Picker Area
            const Text(
              'SELECT CLIP FROM PHONE (GALLERY)',
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            // WHEN NO VIDEO SELECTED:
            if (selectedVideoFile == null) ...[
              InkWell(
                onTap: isUploading ? null : pickVideo,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
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
                        'Tap here to choose MP4 / MOV clip from gallery\n(Max 150MB, Max 3 minutes)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: GamerTheme.textMuted, fontSize: 11.5, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // WHEN VIDEO IS SELECTED:
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
                    // Video Preview Player Box
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Container(
                        height: 210,
                        width: double.infinity,
                        color: Colors.black,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (videoController != null && videoController!.value.isInitialized)
                              AspectRatio(
                                aspectRatio: videoController!.value.aspectRatio > 0
                                    ? videoController!.value.aspectRatio
                                    : (16 / 9),
                                child: VideoPlayer(videoController!),
                              )
                            else if (isVideoLoading)
                              const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: GamerTheme.accentOrange),
                                  SizedBox(height: 10),
                                  Text(
                                    'Loading clip preview...',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              )
                            else
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: GamerTheme.accentOrange, size: 48),
                                  const SizedBox(height: 8),
                                  Text(
                                    selectedVideoName ?? 'Video Clip Selected',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Clip ready to upload',
                                    style: TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),

                            // Play / Pause Overlay Button
                            if (videoController != null && videoController!.value.isInitialized)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (videoController!.value.isPlaying) {
                                      videoController!.pause();
                                    } else {
                                      videoController!.play();
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white30),
                                  ),
                                  child: Icon(
                                    videoController!.value.isPlaying
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
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam_rounded, color: GamerTheme.accentOrange, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      selectedVideoSizeBytes != null
                                          ? '${(selectedVideoSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB'
                                          : 'Video',
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
                                  'Duration: ${_formatSeconds(selectedDurationSec)}',
                                  style: const TextStyle(color: GamerTheme.bgDark, fontWeight: FontWeight.w900, fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Trimmer Section
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.content_cut_rounded, color: GamerTheme.accentOrange, size: 16),
                                  SizedBox(width: 6),
                                  Text(
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
                                'Selected: ${_formatSeconds(selectedDurationSec)} / Total: ${_formatDuration(videoDuration)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Range Slider
                          RangeSlider(
                            values: trimRange,
                            min: 0.0,
                            max: (videoDuration.inSeconds > 0
                                ? videoDuration.inSeconds.toDouble()
                                : 30.0).clamp(1.0, 180.0),
                            activeColor: GamerTheme.accentOrange,
                            inactiveColor: GamerTheme.borderLight,
                            labels: RangeLabels(
                              _formatSeconds(trimRange.start),
                              _formatSeconds(trimRange.end),
                            ),
                            onChanged: isUploading
                                ? null
                                : (values) {
                                    if (values.end - values.start < 1.0) return;
                                    setState(() {
                                      trimRange = values;
                                    });
                                    videoController?.seekTo(
                                      Duration(milliseconds: (values.start * 1000).round()),
                                    );
                                  },
                          ),

                          // Quick Buttons
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
                              _buildQuickButton(
                                'Full',
                                videoDuration.inSeconds > 0 ? videoDuration.inSeconds.toDouble() : 30.0,
                              ),
                              const Spacer(),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: GamerTheme.textMuted,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                onPressed: isUploading ? null : pickVideo,
                                icon: const Icon(Icons.sync_rounded, size: 14),
                                label: const Text('Change', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
              controller: captionController,
              enabled: !isUploading,
              style: const TextStyle(color: Colors.white, fontSize: 13),
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
              children: availableGameTags.map((tag) {
                final isSel = selectedGameTag == tag;
                return GestureDetector(
                  onTap: isUploading ? null : () => setState(() => selectedGameTag = tag),
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
            if (isUploading) ...[
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
                              uploadStatusText.isNotEmpty ? uploadStatusText : 'Uploading clip to Cloudinary...',
                              style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isCancelled = true;
                              isUploading = false;
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
                        value: uploadProgress > 0 ? uploadProgress : null,
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

            // Share Button Helper Notice if disabled
            if (!canShare && !isUploading) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      !hasVideo
                          ? 'Select a video from phone above'
                          : !hasCaption
                              ? 'Enter caption (min 3 characters)'
                              : !hasTag
                                  ? 'Select a Game Tag above'
                                  : '',
                      style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],

            // SHARE BUTTON
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
                onPressed: canShare ? _handleShare : null,
                child: isUploading
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
      onTap: isUploading ? null : () => _applyQuickTrim(seconds),
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
