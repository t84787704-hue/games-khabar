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
  // Video state
  File? selectedVideoFile;
  String? selectedVideoUrl;
  String? selectedVideoPath;
  String? selectedVideoName;
  int? selectedVideoSizeBytes;

  VideoPlayerController? videoController;
  bool isVideoLoading = false;
  bool isPickerOpening = false;
  bool _isPickingVideo = false;
  Duration videoDuration = Duration.zero;

  // Upload state
  bool isUploading = false;
  double uploadProgress = 0.0;
  String uploadStatusText = '';
  bool isCancelled = false;

  // Form state
  String selectedGameTag = 'PUBG Mobile'; // Default to popular game tag
  final TextEditingController captionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  RangeValues trimRange = const RangeValues(0, 30);

  final List<String> availableGameTags = const [
    'PUBG Mobile',
    'BGMI',
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
    _scrollController.dispose();
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

  // 1. PICK VIDEO FUNCTION (Phone Gallery / Camera)
  Future<void> pickVideo({ImageSource source = ImageSource.gallery}) async {
    if (_isPickingVideo || isUploading) return;
    _isPickingVideo = true;

    setState(() {
      isPickerOpening = true;
    });

    try {
      final picker = ImagePicker();
      XFile? picked;

      try {
        if (source == ImageSource.camera) {
          picked = await picker.pickVideo(source: ImageSource.camera);
        } else {
          // Do NOT pass maxDuration here: on Android gallery it causes Intent failures
          picked = await picker.pickVideo(source: ImageSource.gallery);
        }
      } catch (pickerErr) {
        debugPrint('pickVideo direct call failed: $pickerErr, trying pickMedia fallback...');
        try {
          picked = await picker.pickMedia();
        } catch (mediaErr) {
          debugPrint('pickMedia fallback failed: $mediaErr');
        }
      }

      if (picked == null) {
        // User cancelled
        return;
      }

      final file = File(picked.path);
      int size = 0;
      try {
        size = await picked.length();
      } catch (_) {
        try {
          size = await file.length();
        } catch (_) {}
      }

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

      final name = picked.name.isNotEmpty ? picked.name : file.path.split('/').last;

      if (mounted) {
        setState(() {
          selectedVideoFile = file;
          selectedVideoUrl = null;
          selectedVideoPath = file.path;
          selectedVideoName = name.isNotEmpty ? name : 'gaming_clip.mp4';
          selectedVideoSizeBytes = size > 0 ? size : null;
          isVideoLoading = true;
          if (captionController.text.trim().isEmpty) {
            captionController.text = 'Insane Gaming Clip! 🔥🎮';
          }
        });
      }

      await _initializeVideoPreview(file: file);
    } catch (e) {
      debugPrint('Error in pickVideo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open video: $e. You can also use Quick Test Clip!'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    } finally {
      _isPickingVideo = false;
      if (mounted) {
        setState(() {
          isPickerOpening = false;
        });
      }
    }
  }

  // 2. INSTANT SAMPLE GAMING CLIP (Guaranteed to work 100% on any device/emulator)
  Future<void> _useSampleGamingClip() async {
    if (isUploading) return;

    setState(() {
      isPickerOpening = true;
      isVideoLoading = true;
    });

    try {
      final tempDir = Directory.systemTemp;
      final sampleFile = File('${tempDir.path}/pubg_clutch_sample.mp4');

      const sampleUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';

      if (!await sampleFile.exists() || await sampleFile.length() < 5000) {
        final res = await http.get(Uri.parse(sampleUrl)).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          await sampleFile.writeAsBytes(res.bodyBytes);
        } else {
          // If download fails, use direct network URL preview
          if (mounted) {
            setState(() {
              selectedVideoFile = null;
              selectedVideoUrl = sampleUrl;
              selectedVideoName = 'pubg_clutch_sample.mp4';
              selectedVideoSizeBytes = 2500000;
              if (captionController.text.trim().isEmpty) {
                captionController.text = '1v4 PUBG Clutch Moment! 🔥🏆';
              }
              if (selectedGameTag.isEmpty) {
                selectedGameTag = 'PUBG Mobile';
              }
            });
          }
          await _initializeVideoPreview(networkUrl: sampleUrl);
          return;
        }
      }

      final size = await sampleFile.length();

      if (mounted) {
        setState(() {
          selectedVideoFile = sampleFile;
          selectedVideoUrl = null;
          selectedVideoPath = sampleFile.path;
          selectedVideoName = 'pubg_clutch_sample.mp4';
          selectedVideoSizeBytes = size;
          if (captionController.text.trim().isEmpty) {
            captionController.text = '1v4 PUBG Mobile Clutch Moment! 🔥🏆';
          }
          if (selectedGameTag.isEmpty) {
            selectedGameTag = 'PUBG Mobile';
          }
        });
      }

      await _initializeVideoPreview(file: sampleFile);
    } catch (e) {
      debugPrint('Error loading sample clip: $e');
      // Fallback to direct network preview
      const fallbackUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
      if (mounted) {
        setState(() {
          selectedVideoFile = null;
          selectedVideoUrl = fallbackUrl;
          selectedVideoName = 'pubg_clutch_sample.mp4';
          selectedVideoSizeBytes = 2500000;
          if (captionController.text.trim().isEmpty) {
            captionController.text = '1v4 PUBG Mobile Clutch Moment! 🔥🏆';
          }
          if (selectedGameTag.isEmpty) {
            selectedGameTag = 'PUBG Mobile';
          }
        });
      }
      await _initializeVideoPreview(networkUrl: fallbackUrl);
    } finally {
      if (mounted) {
        setState(() {
          isPickerOpening = false;
          isVideoLoading = false;
        });
      }
    }
  }

  // 3. PASTE VIDEO LINK / URL DIALOG
  void _showPasteUrlDialog() {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link_rounded, color: GamerTheme.accentOrange),
            SizedBox(width: 8),
            Text('Paste Video URL', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter direct video link (MP4, WebM, Cloudinary, etc.):',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://example.com/clip.mp4',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: GamerTheme.bgDark,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: GamerTheme.borderLight),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('Use Sample BGMI Clip', style: TextStyle(fontSize: 10, color: GamerTheme.accentOrange)),
                  backgroundColor: GamerTheme.bgDark,
                  side: const BorderSide(color: GamerTheme.accentOrange),
                  onPressed: () {
                    urlController.text = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.accentOrange,
              foregroundColor: GamerTheme.bgDark,
            ),
            onPressed: () {
              final raw = urlController.text.trim();
              if (raw.isEmpty || (!raw.startsWith('http://') && !raw.startsWith('https://'))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid https:// URL'), backgroundColor: GamerTheme.redAccent),
                );
                return;
              }
              Navigator.pop(ctx);
              _setVideoFromUrl(raw);
            },
            child: const Text('Attach Video', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _setVideoFromUrl(String url) async {
    setState(() {
      selectedVideoFile = null;
      selectedVideoUrl = url;
      selectedVideoName = url.split('/').last.split('?').first;
      if (selectedVideoName!.isEmpty) selectedVideoName = 'online_clip.mp4';
      selectedVideoSizeBytes = 5 * 1024 * 1024;
      isVideoLoading = true;
      if (captionController.text.trim().isEmpty) {
        captionController.text = 'Gaming Moment! 🔥🏆';
      }
    });
    await _initializeVideoPreview(networkUrl: url);
  }

  void _removeSelectedVideo() {
    videoController?.pause();
    videoController?.dispose();
    videoController = null;
    setState(() {
      selectedVideoFile = null;
      selectedVideoUrl = null;
      selectedVideoPath = null;
      selectedVideoName = null;
      selectedVideoSizeBytes = null;
      videoDuration = Duration.zero;
      trimRange = const RangeValues(0, 30);
      isVideoLoading = false;
    });
  }

  Future<void> _initializeVideoPreview({File? file, String? networkUrl}) async {
    try {
      await videoController?.pause();
      await videoController?.dispose();
      videoController = null;

      final controller = file != null
          ? VideoPlayerController.file(file)
          : VideoPlayerController.networkUrl(Uri.parse(networkUrl!));

      await controller.initialize().timeout(const Duration(seconds: 8));

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
          if (videoDuration == Duration.zero) {
            videoDuration = const Duration(seconds: 30);
            trimRange = const RangeValues(0, 30);
          }
        });
      }
    }
  }

  // 4. TRIMMER PRESETS
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

  // 5. CLOUDINARY DIRECT UPLOAD
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
        request.fields['tags'] = 'gaming,${selectedGameTag.isNotEmpty ? selectedGameTag : "pubg"}';

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
          filename: filename.isNotEmpty ? filename : 'gaming_clip.mp4',
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
            final startInt = trimStart.round();
            final endInt = trimEnd.round();
            if (finalVideoUrl.contains('/video/upload/')) {
              finalVideoUrl = finalVideoUrl.replaceAll(
                '/video/upload/',
                '/video/upload/so_$startInt,eo_$endInt/',
              );
            }
          }

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

  // 6. POPUP TO PICK SOURCE IF USER TAPS SHARE WITHOUT SELECTING VIDEO
  void _showVideoSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.video_library_rounded, color: GamerTheme.accentOrange, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'CHOOSE GAMING VIDEO',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Select your video source to share to the Clips feed:',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Option 1: Phone Gallery
              ListTile(
                tileColor: GamerTheme.bgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const CircleAvatar(
                  backgroundColor: GamerTheme.accentOrange,
                  child: Icon(Icons.folder_rounded, color: GamerTheme.bgDark),
                ),
                title: const Text('Choose from Phone Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Pick MP4 / MOV clip from your phone', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  pickVideo(source: ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),

              // Option 2: Instant Sample Clip
              ListTile(
                tileColor: GamerTheme.bgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(
                  backgroundColor: GamerTheme.accentOrange.withOpacity(0.2),
                  child: const Icon(Icons.sports_esports_rounded, color: GamerTheme.accentOrange),
                ),
                title: const Text('🎮 Quick Test Clip (Instant)', style: TextStyle(color: GamerTheme.accentOrange, fontWeight: FontWeight.bold)),
                subtitle: const Text('Load sample PUBG/BGMI clutch video in 1 second', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _useSampleGamingClip();
                },
              ),
              const SizedBox(height: 10),

              // Option 3: Paste Video URL
              ListTile(
                tileColor: GamerTheme.bgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(
                  backgroundColor: Colors.white12,
                  child: const Icon(Icons.link_rounded, color: Colors.white),
                ),
                title: const Text('Paste Video URL / Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Direct MP4, Cloudinary or web video link', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPasteUrlDialog();
                },
              ),
              const SizedBox(height: 10),

              // Option 4: Record Camera
              ListTile(
                tileColor: GamerTheme.bgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(
                  backgroundColor: Colors.white12,
                  child: const Icon(Icons.videocam_rounded, color: Colors.white),
                ),
                title: const Text('Record Video with Camera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Capture live screen or gameplay', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  pickVideo(source: ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 7. SHARE BUTTON HANDLER (NEVER DISABLED - VALIDATES & EXECUTES)
  Future<void> _handleShare() async {
    if (isUploading) return;

    // Check 1: Video attached?
    final hasVideo = selectedVideoFile != null || (selectedVideoUrl != null && selectedVideoUrl!.isNotEmpty);
    if (!hasVideo) {
      _showVideoSourceOptions();
      return;
    }

    // Check 2: Caption provided?
    final caption = captionController.text.trim();
    if (caption.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please enter a caption/title (min 3 characters)!'),
          backgroundColor: GamerTheme.accentOrange,
        ),
      );
      return;
    }

    // Check 3: Game tag provided?
    if (selectedGameTag.isEmpty) {
      setState(() {
        selectedGameTag = 'PUBG Mobile';
      });
    }

    // Check 4: Non-gaming content filter
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
      uploadStatusText = 'Preparing clip... 🚀';
      isCancelled = false;
    });

    videoController?.pause();

    try {
      String finalVideoUrl = '';
      String finalThumbnailUrl = '';
      String finalPublicId = '';
      double finalDuration = 30.0;
      double finalOrigDuration = 30.0;

      if (selectedVideoFile != null) {
        // Direct upload to Cloudinary
        setState(() {
          uploadStatusText = 'Uploading to Cloudinary... 🚀';
        });

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

        finalVideoUrl = uploadResult['videoUrl'] as String;
        finalThumbnailUrl = uploadResult['thumbnailUrl'] as String;
        finalPublicId = uploadResult['publicId'] as String;
        finalDuration = uploadResult['duration'] as double;
        finalOrigDuration = uploadResult['originalDuration'] as double;
      } else if (selectedVideoUrl != null) {
        // Already a network URL
        finalVideoUrl = selectedVideoUrl!;
        finalThumbnailUrl = selectedVideoUrl!;
        finalPublicId = 'online_${DateTime.now().millisecondsSinceEpoch}';
        finalDuration = (trimRange.end - trimRange.start).clamp(1.0, 180.0);
        finalOrigDuration = finalDuration;
        setState(() {
          uploadProgress = 0.8;
          uploadStatusText = 'Publishing clip to Feed... ⚡';
        });
      }

      setState(() {
        uploadStatusText = 'Publishing to Clips Feed... ⚡';
      });

      // Save metadata to Firestore collection 'clips'
      final gamer = widget.currentGamer ?? GamerAuthService().currentGamer;
      final currentUid = gamer?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_gamer';
      final username = gamer?.username ?? 'gamer';
      final displayName = gamer?.displayName ?? 'Gamer';
      final userAvatar = gamer?.photoUrl ?? '';

      final docRef = FirebaseFirestore.instance.collection('clips').doc();
      await docRef.set({
        'id': docRef.id,
        'videoUrl': finalVideoUrl,
        'mediaUrl': finalVideoUrl,
        'thumbnail': finalThumbnailUrl,
        'thumbnailUrl': finalThumbnailUrl,
        'publicId': finalPublicId,
        'caption': caption,
        'title': caption,
        'gameTag': selectedGameTag,
        'songTitle': 'Original Audio - $displayName',
        'duration': finalDuration,
        'originalDuration': finalOrigDuration,
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
    final hasVideo = selectedVideoFile != null || (selectedVideoUrl != null && selectedVideoUrl!.isNotEmpty);
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
        controller: _scrollController,
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
            if (!hasVideo) ...[
              GestureDetector(
                onTap: (isUploading || isPickerOpening) ? null : () => pickVideo(source: ImageSource.gallery),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                  decoration: BoxDecoration(
                    color: GamerTheme.bgDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: GamerTheme.accentOrange, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: GamerTheme.accentOrange.withOpacity(0.18),
                        blurRadius: 12,
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
                        child: isPickerOpening
                            ? const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(color: GamerTheme.accentOrange, strokeWidth: 3),
                              )
                            : const Icon(Icons.video_library_rounded, color: GamerTheme.accentOrange, size: 32),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isPickerOpening ? 'OPENING GALLERY... ⏳' : 'SELECT CLIP FROM PHONE 📱',
                        style: const TextStyle(
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
                      const SizedBox(height: 12),
                      // Prominent Browse Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GamerTheme.accentOrange,
                          foregroundColor: GamerTheme.bgDark,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        onPressed: (isUploading || isPickerOpening)
                            ? null
                            : () => pickVideo(source: ImageSource.gallery),
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: const Text(
                          'OPEN GALLERY',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Alternative Quick Actions (Instant Test Clip, Paste URL, Camera)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GamerTheme.accentOrange.withOpacity(0.18),
                        foregroundColor: GamerTheme.accentOrange,
                        side: BorderSide(color: GamerTheme.accentOrange.withOpacity(0.6), width: 1.2),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: (isUploading || isPickerOpening) ? null : _useSampleGamingClip,
                      icon: const Icon(Icons.sports_esports_rounded, size: 16),
                      label: const Text('🎮 Quick Test Clip', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: GamerTheme.borderLight),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: (isUploading || isPickerOpening) ? null : _showPasteUrlDialog,
                      icon: const Icon(Icons.link_rounded, size: 16, color: Colors.white70),
                      label: const Text('🔗 Paste Link', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
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

                          // Quick Buttons + Change/Remove
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
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                ),
                                onPressed: isUploading ? null : _showVideoSourceOptions,
                                icon: const Icon(Icons.sync_rounded, size: 14),
                                label: const Text('Change', style: TextStyle(fontSize: 11)),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                icon: const Icon(Icons.delete_outline_rounded, color: GamerTheme.redAccent, size: 18),
                                tooltip: 'Remove Video',
                                onPressed: isUploading ? null : _removeSelectedVideo,
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
                hintText: 'e.g. Crazy 1v4 clutch in Bootcamp! 🔥 #PUBG',
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

            // Game Tag selection
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
                    'SELECTED',
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

            // Status message above share button
            if (!hasVideo && !isUploading) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, color: GamerTheme.accentOrange, size: 15),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Tap "Open Gallery" above or tap Share below to choose a clip!',
                        style: TextStyle(color: GamerTheme.accentOrange, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // SHARE BUTTON - NEVER BLURRED / NEVER DISABLED!
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GamerTheme.accentOrange,
                  foregroundColor: GamerTheme.bgDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: GamerTheme.accentOrange.withOpacity(0.5),
                ),
                onPressed: isUploading ? null : _handleShare,
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasVideo ? Icons.rocket_launch_rounded : Icons.add_circle_outline_rounded,
                            color: GamerTheme.bgDark,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasVideo ? 'SHARE TO CLIPS FEED 🚀' : 'CHOOSE VIDEO & SHARE 🚀',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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
